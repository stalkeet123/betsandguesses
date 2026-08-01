-- Bets & Guesses: chart-ready activity and funnel report for the last 24 hours.
-- Each row is one Istanbul hour. Activity totals are attributed to the hour
-- in which their room was created; player joins use their actual join hour.
with
params as (
  select
    now() - interval '24 hours' as since,
    now() - interval '10 minutes' as abandonment_cutoff
),
hours as (
  select generate_series(
    date_trunc('hour', now()) - interval '23 hours',
    date_trunc('hour', now()),
    interval '1 hour'
  ) as hour_start
),
rooms_24h as (
  select room.*
  from public.rooms room, params
  where room.created_at >= params.since
),
players_by_room as (
  select
    player.room_id,
    count(*)::integer as player_rows,
    count(distinct player.device_id)::integer as unique_devices,
    count(*) filter (where player.is_connected)::integer as connected_rows
  from public.players player
  join rooms_24h room on room.id = player.room_id
  group by player.room_id
),
players_by_hour as (
  select
    date_trunc('hour', player.joined_at) as hour_start,
    count(*)::integer as players_joined,
    count(distinct player.device_id)::integer as unique_devices_joined
  from public.players player, params
  where player.joined_at >= params.since
  group by 1
),
classic_guesses_by_room as (
  select guess.room_id, count(*)::integer as guesses
  from public.guesses guess
  join rooms_24h room on room.id = guess.room_id
  group by guess.room_id
),
classic_bets_by_room as (
  select
    bet.room_id,
    count(*)::integer as bets,
    coalesce(sum(bet.chips), 0)::bigint as chips
  from public.bets bet
  join rooms_24h room on room.id = bet.room_id
  group by bet.room_id
),
party_rounds_by_room as (
  select
    round.room_id,
    count(*)::integer as rounds,
    count(*) filter (where round.settled_at is not null)::integer
      as settled_rounds,
    count(*) filter (where round.performer_ready_at is not null)::integer
      as performances_readied
  from public.party_rounds round
  join rooms_24h room on room.id = round.room_id
  group by round.room_id
),
party_guesses_by_room as (
  select guess.room_id, count(*)::integer as guesses
  from public.party_guesses guess
  join rooms_24h room on room.id = guess.room_id
  group by guess.room_id
),
party_bets_by_room as (
  select
    bet.room_id,
    count(*)::integer as bets,
    coalesce(sum(bet.chips), 0)::bigint as chips
  from public.party_bets bet
  join rooms_24h room on room.id = bet.room_id
  group by bet.room_id
),
party_media_by_room as (
  select media.room_id, count(*)::integer as media_rows
  from public.party_round_media media
  join rooms_24h room on room.id = media.room_id
  group by media.room_id
),
room_stage as (
  select
    room.id,
    room.created_at,
    coalesce(room.game_mode, 'classic') as game_mode,
    room.status,
    room.current_round,
    coalesce(players.player_rows, 0) as player_rows,
    coalesce(players.unique_devices, 0) as unique_devices,
    coalesce(players.connected_rows, 0) as connected_rows,
    coalesce(classic_guesses.guesses, 0) as classic_guesses,
    coalesce(classic_bets.bets, 0) as classic_bets,
    coalesce(classic_bets.chips, 0) as classic_chips,
    coalesce(party_rounds.rounds, 0) as party_rounds,
    coalesce(party_rounds.settled_rounds, 0) as party_settled_rounds,
    coalesce(party_rounds.performances_readied, 0)
      as party_performances_readied,
    coalesce(party_guesses.guesses, 0) as party_guesses,
    coalesce(party_bets.bets, 0) as party_bets,
    coalesce(party_bets.chips, 0) as party_chips,
    coalesce(media.media_rows, 0) as media_rows,
    (
      room.status <> 'waiting'
      or room.current_round > 0
      or coalesce(classic_guesses.guesses, 0) > 0
      or coalesce(classic_bets.bets, 0) > 0
      or coalesce(party_rounds.rounds, 0) > 0
    ) as started
  from rooms_24h room
  left join players_by_room players on players.room_id = room.id
  left join classic_guesses_by_room classic_guesses
    on classic_guesses.room_id = room.id
  left join classic_bets_by_room classic_bets on classic_bets.room_id = room.id
  left join party_rounds_by_room party_rounds
    on party_rounds.room_id = room.id
  left join party_guesses_by_room party_guesses
    on party_guesses.room_id = room.id
  left join party_bets_by_room party_bets on party_bets.room_id = room.id
  left join party_media_by_room media on media.room_id = room.id
),
room_facts as (
  select
    stage.*,
    stage.status = 'finished' as finished,
    (
      stage.created_at < params.abandonment_cutoff
      and not stage.started
      and stage.player_rows <= 1
    ) as abandoned_lobby,
    (
      stage.created_at < now() - interval '2 hours'
      and stage.started
      and stage.status <> 'finished'
    ) as stalled_game
  from room_stage stage, params
)
select
  hours.hour_start,
  to_char(
    hours.hour_start at time zone 'Europe/Istanbul',
    'DD Mon HH24:00'
  ) as istanbul_hour,
  count(fact.id)::integer as lobbies_created,
  count(fact.id) filter (where fact.game_mode = 'classic')::integer
    as classic_lobbies,
  count(fact.id) filter (where fact.game_mode = 'party')::integer
    as party_lobbies,
  coalesce(player_hour.players_joined, 0) as players_joined,
  coalesce(player_hour.unique_devices_joined, 0) as unique_devices_joined,
  coalesce(round(avg(fact.player_rows), 2), 0) as avg_players_per_lobby,
  coalesce(max(fact.player_rows), 0)::integer as largest_lobby,
  coalesce(sum(fact.connected_rows), 0)::integer as connected_rows_now,
  count(fact.id) filter (where fact.started)::integer as games_started,
  count(fact.id) filter (where fact.finished)::integer as games_finished,
  count(fact.id) filter (where fact.abandoned_lobby)::integer
    as abandoned_lobbies,
  count(fact.id) filter (where fact.stalled_game)::integer as stalled_games,
  coalesce(round(
    100.0 * count(fact.id) filter (where fact.started)
    / nullif(count(fact.id), 0),
    1
  ), 0) as lobby_to_game_rate_pct,
  coalesce(round(
    100.0 * count(fact.id) filter (where fact.finished)
    / nullif(count(fact.id) filter (where fact.started), 0),
    1
  ), 0) as game_completion_rate_pct,
  coalesce(round(
    100.0 * count(fact.id) filter (where fact.abandoned_lobby)
    / nullif(count(fact.id), 0),
    1
  ), 0) as lobby_abandon_rate_pct,
  coalesce(sum(fact.classic_guesses + fact.party_guesses), 0)::bigint
    as guesses_submitted,
  coalesce(sum(fact.classic_bets + fact.party_bets), 0)::bigint
    as bets_placed,
  coalesce(sum(fact.classic_chips + fact.party_chips), 0)::bigint
    as chips_wagered,
  coalesce(sum(fact.party_rounds), 0)::bigint as party_rounds,
  coalesce(sum(fact.party_performances_readied), 0)::bigint
    as party_performances_readied,
  coalesce(sum(fact.party_settled_rounds), 0)::bigint as party_rounds_settled,
  coalesce(sum(fact.media_rows), 0)::bigint as cloud_media_rows
from hours
left join room_facts fact
  on date_trunc('hour', fact.created_at) = hours.hour_start
left join players_by_hour player_hour
  on player_hour.hour_start = hours.hour_start
group by
  hours.hour_start,
  player_hour.players_joined,
  player_hour.unique_devices_joined
order by hours.hour_start;
