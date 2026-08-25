begin;

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create table if not exists private.debug_monetization_testers (
  user_id uuid primary key references auth.users(id) on delete cascade,
  premium_override boolean,
  updated_at timestamptz not null default statement_timestamp()
);
revoke all on table private.debug_monetization_testers from public, anon, authenticated;

create or replace function private.is_effective_premium_v1(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select d.premium_override from private.debug_monetization_testers d where d.user_id = p_user_id),
    (
      select coalesce(m.lifetime_premium, false)
        or coalesce(m.premium_expires_at > statement_timestamp(), false)
      from public.monetization_profiles m
      where m.user_id = p_user_id
    ),
    false
  );
$$;
revoke all on function private.is_effective_premium_v1(uuid) from public, anon, authenticated;

create or replace function public.get_monetization_status_v1()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  p public.monetization_profiles%rowtype;
  v_real_is_premium boolean := false;
  v_is_premium boolean := false;
  v_debug_allowed boolean := false;
  v_debug_override boolean;
begin
  if (select auth.uid()) is null then
    raise exception using errcode = '42501', message = 'AUTH_REQUIRED';
  end if;

  insert into public.monetization_profiles(user_id)
  values ((select auth.uid()))
  on conflict (user_id) do nothing;

  select * into p
  from public.monetization_profiles
  where user_id = (select auth.uid());

  v_real_is_premium := coalesce(p.lifetime_premium, false)
    or coalesce(p.premium_expires_at > statement_timestamp(), false);

  select exists (
    select 1 from private.debug_monetization_testers d
    where d.user_id = (select auth.uid())
  ) into v_debug_allowed;

  if v_debug_allowed then
    select d.premium_override into v_debug_override
    from private.debug_monetization_testers d
    where d.user_id = (select auth.uid());
  end if;

  v_is_premium := coalesce(v_debug_override, v_real_is_premium);

  return jsonb_build_object(
    'is_premium', v_is_premium,
    'real_is_premium', v_real_is_premium,
    'is_lifetime', p.lifetime_premium,
    'premium_expires_at', p.premium_expires_at,
    'free_host_games_used', p.free_host_games_used,
    'free_host_games_remaining', greatest(0, 3 - p.free_host_games_used),
    'debug_override_allowed', v_debug_allowed,
    'debug_premium_override', v_debug_override
  );
end;
$$;

create or replace function public.set_debug_premium_override_v1(p_override boolean)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null then
    raise exception using errcode = '42501', message = 'AUTH_REQUIRED';
  end if;

  update private.debug_monetization_testers
  set premium_override = p_override,
      updated_at = statement_timestamp()
  where user_id = (select auth.uid());

  if not found then
    raise exception using errcode = '42501', message = 'DEBUG_OVERRIDE_NOT_ALLOWED';
  end if;

  return public.get_monetization_status_v1();
end;
$$;

create or replace function public.set_debug_free_host_games_used_v1(p_used integer)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null then
    raise exception using errcode = '42501', message = 'AUTH_REQUIRED';
  end if;
  if p_used not between 0 and 3 then
    raise exception using errcode = '22023', message = 'INVALID_DEBUG_FREE_HOST_GAMES_USED';
  end if;
  if not exists (
    select 1 from private.debug_monetization_testers d
    where d.user_id = (select auth.uid())
  ) then
    raise exception using errcode = '42501', message = 'DEBUG_OVERRIDE_NOT_ALLOWED';
  end if;

  insert into public.monetization_profiles(user_id)
  values ((select auth.uid()))
  on conflict (user_id) do nothing;

  update public.monetization_profiles
  set free_host_games_used = p_used,
      updated_at = statement_timestamp()
  where user_id = (select auth.uid());

  return public.get_monetization_status_v1();
end;
$$;

create or replace function public.consume_host_game_credit_v1()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile public.monetization_profiles%rowtype;
begin
  if (select auth.uid()) is null then
    raise exception using errcode = '42501', message = 'AUTH_REQUIRED';
  end if;
  insert into public.monetization_profiles(user_id)
  values ((select auth.uid()))
  on conflict (user_id) do nothing;
  select * into v_profile
  from public.monetization_profiles
  where user_id = (select auth.uid())
  for update;

  if private.is_effective_premium_v1((select auth.uid())) then return; end if;
  if v_profile.free_host_games_used >= 3 then
    raise exception using errcode = 'P0001', message = 'FREE_HOST_LIMIT_REACHED';
  end if;

  update public.monetization_profiles
  set free_host_games_used = free_host_games_used + 1,
      updated_at = statement_timestamp()
  where user_id = (select auth.uid());
end;
$$;

create or replace function public.create_room_v4(
  p_code text,
  p_max_rounds integer,
  p_max_players integer,
  p_category text default null,
  p_game_mode text default 'classic'
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile public.monetization_profiles%rowtype;
  v_is_premium boolean;
  v_game_mode text := lower(btrim(coalesce(p_game_mode, 'classic')));
  v_category text := nullif(btrim(p_category), '');
begin
  if (select auth.uid()) is null then
    raise exception using errcode = '28000', message = 'Authentication required';
  end if;
  insert into public.monetization_profiles(user_id)
  values ((select auth.uid()))
  on conflict (user_id) do nothing;
  select * into v_profile
  from public.monetization_profiles
  where user_id = (select auth.uid());

  v_is_premium := private.is_effective_premium_v1((select auth.uid()));

  if not v_is_premium then
    if v_profile.free_host_games_used >= 3 then
      raise exception using errcode = 'P0001', message = 'FREE_HOST_LIMIT_REACHED';
    end if;
    if p_max_rounds > 6 then
      raise exception using errcode = 'P0001', message = 'PREMIUM_ROUNDS_REQUIRED';
    end if;
    if p_max_players > 4 then
      raise exception using errcode = 'P0001', message = 'PREMIUM_PLAYERS_REQUIRED';
    end if;
    if v_game_mode = 'classic'
       and v_category is not null
       and lower(v_category) <> 'mixed' then
      raise exception using errcode = 'P0001', message = 'PREMIUM_CATEGORY_REQUIRED';
    end if;
  end if;

  return public.create_room_v3(p_code, p_max_rounds, p_max_players, p_category, p_game_mode);
end;
$$;

create or replace function public.pick_question_id_v3(p_room_id uuid, p_category text)
returns uuid
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_room public.rooms%rowtype;
  v_host_user_id uuid;
  v_profile public.monetization_profiles%rowtype;
  v_is_premium boolean := false;
  v_question_id uuid;
  v_normalized_text text;
begin
  select * into v_room from public.rooms where id = p_room_id for update;
  if not found or coalesce(v_room.game_mode, 'classic') <> 'classic' then return null; end if;

  v_host_user_id := v_room.created_by;
  if v_host_user_id is null then
    select p.auth_user_id into v_host_user_id
    from public.players p
    where p.room_id = p_room_id
      and coalesce(p.is_host, false) = true
      and p.auth_user_id is not null
    order by p.joined_at nulls last, p.id
    limit 1;
  end if;
  if v_host_user_id is null then return null; end if;

  insert into public.monetization_profiles(user_id)
  values (v_host_user_id)
  on conflict (user_id) do nothing;
  select * into v_profile
  from public.monetization_profiles
  where user_id = v_host_user_id
  for update;

  v_is_premium := private.is_effective_premium_v1(v_host_user_id);

  if v_room.classic_match_id is null then
    update public.rooms set classic_match_id = gen_random_uuid()
    where id = p_room_id returning * into v_room;
  end if;

  with candidates as (
    select distinct on (lower(btrim(q.text_en)))
      q.id, lower(btrim(q.text_en)) as normalized_text
    from public.questions q
    where q.text_en is not null and btrim(q.text_en) <> ''
      and (
        (not v_is_premium and q.access_tier = 'starter')
        or (
          v_is_premium and (
            p_category is null or btrim(p_category) = ''
            or lower(btrim(p_category)) = 'mixed'
            or q.category = p_category
          )
        )
      )
    order by lower(btrim(q.text_en)), q.id
  )
  select c.id, c.normalized_text into v_question_id, v_normalized_text
  from candidates c
  where not exists (
      select 1 from public.classic_question_serves h
      where h.host_user_id = v_host_user_id and h.normalized_text = c.normalized_text
    )
    and not exists (
      select 1 from public.classic_question_serves m
      where m.match_id = v_room.classic_match_id and m.normalized_text = c.normalized_text
    )
  order by random() limit 1;

  if v_question_id is null then
    with candidates as (
      select distinct on (lower(btrim(q.text_en)))
        q.id, lower(btrim(q.text_en)) as normalized_text
      from public.questions q
      where q.text_en is not null and btrim(q.text_en) <> ''
        and (
          (not v_is_premium and q.access_tier = 'starter')
          or (
            v_is_premium and (
              p_category is null or btrim(p_category) = ''
              or lower(btrim(p_category)) = 'mixed'
              or q.category = p_category
            )
          )
        )
      order by lower(btrim(q.text_en)), q.id
    )
    select c.id, c.normalized_text into v_question_id, v_normalized_text
    from candidates c
    where not exists (
      select 1 from public.classic_question_serves m
      where m.match_id = v_room.classic_match_id and m.normalized_text = c.normalized_text
    )
    order by random() limit 1;
  end if;

  if v_question_id is null then return null; end if;
  insert into public.classic_question_serves(room_id, match_id, host_user_id, question_id, normalized_text)
  values (p_room_id, v_room.classic_match_id, v_host_user_id, v_question_id, v_normalized_text);
  return v_question_id;
end;
$$;

revoke all on function public.get_monetization_status_v1() from public, anon, authenticated;
grant execute on function public.get_monetization_status_v1() to authenticated;
revoke all on function public.set_debug_premium_override_v1(boolean) from public, anon, authenticated;
grant execute on function public.set_debug_premium_override_v1(boolean) to authenticated;
revoke all on function public.set_debug_free_host_games_used_v1(integer) from public, anon, authenticated;
grant execute on function public.set_debug_free_host_games_used_v1(integer) to authenticated;
revoke all on function public.consume_host_game_credit_v1() from public, anon, authenticated;
revoke all on function public.create_room_v4(text, integer, integer, text, text) from public, anon, authenticated;
grant execute on function public.create_room_v4(text, integer, integer, text, text) to authenticated;
revoke all on function public.pick_question_id_v3(uuid, text) from public, anon, authenticated;

notify pgrst, 'reload schema';
commit;