create table if not exists public.analytics_events (
  id uuid primary key default gen_random_uuid(),
  event_name text not null,
  occurred_at timestamptz not null default statement_timestamp(),
  user_id uuid,
  room_id uuid,
  source text not null default 'client',
  properties jsonb not null default '{}'::jsonb,
  constraint analytics_events_event_name_check check (
    event_name in (
      'app_open',
      'onboarding_completed',
      'invite_link_copied',
      'paywall_viewed',
      'purchase_started',
      'purchase_cancelled',
      'purchase_failed',
      'premium_activated'
    )
  ),
  constraint analytics_events_source_check check (source in ('client', 'server')),
  constraint analytics_events_properties_object_check check (jsonb_typeof(properties) = 'object'),
  constraint analytics_events_properties_size_check check (octet_length(properties::text) <= 2048)
);

create index if not exists analytics_events_occurred_at_idx
  on public.analytics_events (occurred_at desc);
create index if not exists analytics_events_name_occurred_idx
  on public.analytics_events (event_name, occurred_at desc);
create index if not exists analytics_events_user_occurred_idx
  on public.analytics_events (user_id, occurred_at desc)
  where user_id is not null;
create index if not exists analytics_events_room_occurred_idx
  on public.analytics_events (room_id, occurred_at desc)
  where room_id is not null;

alter table public.analytics_events enable row level security;
revoke all on table public.analytics_events from anon, authenticated;

create or replace function public.track_analytics_event_v1(
  p_event_name text,
  p_room_id uuid default null,
  p_properties jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_event_name text := lower(btrim(coalesce(p_event_name, '')));
  v_properties jsonb := coalesce(p_properties, '{}'::jsonb);
begin
  if v_user_id is null then
    raise exception using errcode = '42501', message = 'AUTH_REQUIRED';
  end if;

  if v_event_name not in (
    'app_open',
    'onboarding_completed',
    'invite_link_copied',
    'paywall_viewed',
    'purchase_started',
    'purchase_cancelled',
    'purchase_failed'
  ) then
    raise exception using errcode = '22023', message = 'INVALID_ANALYTICS_EVENT';
  end if;

  if jsonb_typeof(v_properties) <> 'object' then
    raise exception using errcode = '22023', message = 'INVALID_ANALYTICS_PROPERTIES';
  end if;

  if octet_length(v_properties::text) > 2048 then
    raise exception using errcode = '22023', message = 'ANALYTICS_PROPERTIES_TOO_LARGE';
  end if;

  if p_room_id is not null and not exists (
    select 1
    from public.players p
    where p.room_id = p_room_id
      and p.auth_user_id = v_user_id
  ) then
    raise exception using errcode = '42501', message = 'ROOM_MEMBERSHIP_REQUIRED';
  end if;

  insert into public.analytics_events (
    event_name,
    user_id,
    room_id,
    source,
    properties
  ) values (
    v_event_name,
    v_user_id,
    p_room_id,
    'client',
    v_properties
  );
end;
$$;

revoke all on function public.track_analytics_event_v1(text, uuid, jsonb) from public, anon;
grant execute on function public.track_analytics_event_v1(text, uuid, jsonb) to authenticated;

create or replace function private.capture_premium_activation_analytics_v1()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_lifetime_activated boolean := false;
  v_expiry_extended boolean := false;
begin
  v_lifetime_activated :=
    coalesce(new.lifetime_premium, false)
    and (
      tg_op = 'INSERT'
      or not coalesce(old.lifetime_premium, false)
    );

  v_expiry_extended :=
    not coalesce(new.lifetime_premium, false)
    and new.premium_expires_at is not null
    and new.premium_expires_at > statement_timestamp()
    and (
      tg_op = 'INSERT'
      or old.premium_expires_at is null
      or new.premium_expires_at > old.premium_expires_at
    );

  if v_lifetime_activated or v_expiry_extended then
    insert into public.analytics_events (
      event_name,
      user_id,
      source,
      properties
    ) values (
      'premium_activated',
      new.user_id,
      'server',
      jsonb_strip_nulls(
        jsonb_build_object(
          'kind', case when coalesce(new.lifetime_premium, false) then 'lifetime' else 'pass' end,
          'premium_expires_at', new.premium_expires_at
        )
      )
    );
  end if;

  return new;
end;
$$;

revoke all on function private.capture_premium_activation_analytics_v1() from public, anon, authenticated;

drop trigger if exists monetization_profiles_capture_premium_activation_analytics
  on public.monetization_profiles;
create trigger monetization_profiles_capture_premium_activation_analytics
after insert or update of lifetime_premium, premium_expires_at
on public.monetization_profiles
for each row
execute function private.capture_premium_activation_analytics_v1();
