-- Bets & Guesses: launch growth / viral / monetization funnel.
-- Three rows only: 24H / 7D / 30D.
-- premium_activated is server-authoritative; purchase_started/cancelled/failed are client intent/outcome events.
-- guest_to_host is a cohort signal and recent windows are naturally immature.
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
event_metrics as (
  select
    b.label,
    count(distinct e.user_id) filter (
      where e.event_name = 'app_open'
        and coalesce(e.properties->>'surface', 'app') = 'app'
    )::int as app_users,
    count(distinct e.user_id) filter (where e.event_name = 'onboarding_completed')::int as onboarding_users,
    count(*) filter (where e.event_name = 'invite_link_copied')::int as invite_copies,
    count(distinct e.user_id) filter (where e.event_name = 'invite_link_copied')::int as invite_sharers,
    count(*) filter (where e.event_name = 'paywall_viewed')::int as paywall_views,
    count(distinct e.user_id) filter (where e.event_name = 'paywall_viewed')::int as paywall_users,
    count(*) filter (where e.event_name = 'purchase_started')::int as purchase_starts,
    count(*) filter (where e.event_name = 'purchase_cancelled')::int as purchase_cancels,
    count(*) filter (where e.event_name = 'purchase_failed')::int as purchase_failures,
    count(*) filter (where e.event_name = 'premium_activated')::int as premium_activations,
    count(distinct e.user_id) filter (where e.event_name = 'premium_activated')::int as premium_users,
    count(*) filter (
      where e.event_name = 'premium_activated' and e.properties->>'kind' = 'pass'
    )::int as pass_activations,
    count(*) filter (
      where e.event_name = 'premium_activated' and e.properties->>'kind' = 'lifetime'
    )::int as lifetime_activations
  from bounds b
  left join public.analytics_events e on e.occurred_at >= b.since_at
  group by b.label
),
guest_firsts as (
  select
    b.label,
    p.device_id,
    min(p.joined_at) as first_guest_at
  from bounds b
  join public.players p
    on p.joined_at >= b.since_at
   and p.device_id is not null
   and coalesce(p.is_host, false) = false
  group by b.label, p.device_id
),
guest_metrics as (
  select
    b.label,
    count(g.device_id)::int as guest_devices,
    count(g.device_id) filter (
      where exists (
        select 1
        from public.players hp
        where hp.device_id = g.device_id
          and coalesce(hp.is_host, false) = true
          and hp.joined_at > g.first_guest_at
      )
    )::int as guest_to_host
  from bounds b
  left join guest_firsts g on g.label = b.label
  group by b.label
)
select
  b.label as period,
  e.app_users,
  e.onboarding_users,
  e.invite_sharers,
  e.invite_copies,
  g.guest_to_host,
  coalesce(round(100.0 * g.guest_to_host / nullif(g.guest_devices, 0), 1), 0) as guest_to_host_pct,
  e.paywall_users,
  e.paywall_views,
  e.purchase_starts,
  e.purchase_cancels,
  e.purchase_failures,
  e.premium_activations,
  coalesce(round(100.0 * e.premium_users / nullif(e.paywall_users, 0), 1), 0) as paywall_to_premium_pct,
  e.pass_activations,
  e.lifetime_activations
from bounds b
join event_metrics e using (label)
join guest_metrics g using (label)
order by b.sort_order;
