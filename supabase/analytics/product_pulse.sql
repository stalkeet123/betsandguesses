-- Bets & Guesses: clean launch product pulse.
-- Three rows only: 24H / 7D / 30D.
-- Uses authoritative analytics_game_sessions created by the server-side room-status trigger.
-- Pre-pipeline development traffic is intentionally excluded by tracking_floor.
with
config as (
  select timestamptz '2026-08-31 10:10:43+00' as tracking_floor
),
periods(label, raw_since, sort_order) as (
  values
    ('24H', now() - interval '24 hours', 1),
    ('7D', now() - interval '7 days', 2),
    ('30D', now() - interval '30 days', 3)
),
bounds as (
  select p.label, greatest(p.raw_since, c.tracking_floor) as since_at, p.sort_order
  from periods p cross join config c
),
room_players as (
  select room_id, count(distinct device_id)::int as unique_devices
  from public.players
  where device_id is not null
  group by room_id
),
room_metrics as (
  select
    b.label,
    b.sort_order,
    count(r.id)::int as lobbies_created,
    count(r.id) filter (
      where exists (
        select 1 from public.analytics_game_sessions s where s.room_id = r.id
      )
    )::int as lobbies_started,
    count(r.id) filter (
      where r.created_at < now() - interval '10 minutes'
        and coalesce(rp.unique_devices, 0) <= 1
        and not exists (
          select 1 from public.analytics_game_sessions s where s.room_id = r.id
        )
    )::int as abandoned_lobbies
  from bounds b
  left join public.rooms r on r.created_at >= b.since_at
  left join room_players rp on rp.room_id = r.id
  group by b.label, b.sort_order
),
session_metrics as (
  select
    b.label,
    count(s.id)::int as games_started,
    count(s.id) filter (where s.finished_at is not null)::int as games_finished,
    coalesce(round(avg(s.starting_player_count), 2), 0) as avg_players,
    count(s.id) filter (where s.game_mode = 'party')::int as party_games
  from bounds b
  left join public.analytics_game_sessions s on s.started_at >= b.since_at
  group by b.label
),
device_metrics as (
  select
    b.label,
    count(distinct p.device_id)::int as unique_devices
  from bounds b
  left join public.players p
    on p.joined_at >= b.since_at
   and p.device_id is not null
  group by b.label
),
host_rollup as (
  select b.label, s.host_user_id, count(*)::int as games
  from bounds b
  join public.analytics_game_sessions s
    on s.started_at >= b.since_at
   and s.host_user_id is not null
  group by b.label, s.host_user_id
),
host_metrics as (
  select
    b.label,
    count(h.host_user_id)::int as active_hosts,
    count(h.host_user_id) filter (where h.games >= 2)::int as repeat_hosts
  from bounds b
  left join host_rollup h on h.label = b.label
  group by b.label
)
select
  r.label as period,
  d.unique_devices,
  r.lobbies_created,
  s.games_started,
  coalesce(round(100.0 * r.lobbies_started / nullif(r.lobbies_created, 0), 1), 0) as start_rate_pct,
  s.games_finished,
  coalesce(round(100.0 * s.games_finished / nullif(s.games_started, 0), 1), 0) as completion_pct,
  s.avg_players,
  h.repeat_hosts,
  coalesce(round(100.0 * h.repeat_hosts / nullif(h.active_hosts, 0), 1), 0) as repeat_host_pct,
  coalesce(round(100.0 * s.party_games / nullif(s.games_started, 0), 1), 0) as party_share_pct,
  r.abandoned_lobbies
from room_metrics r
join session_metrics s using (label)
join device_metrics d using (label)
join host_metrics h using (label)
order by r.sort_order;
