begin;

-- This helper is deliberately caller-bound: the user id and entitlement both
-- come from the authenticated database session, never from an RPC argument.
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

  insert into public.monetization_profiles (user_id)
  values ((select auth.uid()))
  on conflict (user_id) do nothing;

  -- This is a global per-host lock. Starts in different rooms for the same
  -- host must serialize before consuming the final free credit.
  select *
  into v_profile
  from public.monetization_profiles
  where user_id = (select auth.uid())
  for update;

  if v_profile.lifetime_premium
     or coalesce(v_profile.premium_expires_at > statement_timestamp(), false) then
    return;
  end if;

  if v_profile.free_host_games_used >= 3 then
    raise exception using errcode = 'P0001', message = 'FREE_HOST_LIMIT_REACHED';
  end if;

  update public.monetization_profiles
  set free_host_games_used = free_host_games_used + 1,
      updated_at = statement_timestamp()
  where user_id = (select auth.uid());
end;
$$;

-- Classic remains owned by start_game_v2. V3 only serializes the global
-- entitlement and preserves the idempotent active-game retry response.
create or replace function public.start_game_v3(
  p_room_id uuid,
  p_duration_seconds integer
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room public.rooms%rowtype;
  v_scores jsonb;
begin
  if (select auth.uid()) is null then
    raise exception using errcode = '42501', message = 'AUTH_REQUIRED';
  end if;

  select *
  into v_room
  from public.rooms
  where id = p_room_id
  for update;

  if not found then
    raise exception using errcode = 'P0002', message = 'Room not found';
  end if;

  if not exists (
    select 1
    from public.players p
    where p.room_id = p_room_id
      and p.auth_user_id = (select auth.uid())
      and p.is_host = true
      and p.is_connected = true
  ) then
    raise exception using errcode = '42501', message = 'Host access required';
  end if;

  if v_room.status = 'playing' and v_room.current_question_id is not null then
    select coalesce(jsonb_object_agg(p.id::text, p.score), '{}'::jsonb)
    into v_scores
    from public.players p
    where p.room_id = p_room_id
      and p.is_connected;

    return jsonb_build_object(
      'room', to_jsonb(v_room),
      'question', public.public_question_json_v2(v_room.current_question_id, false),
      'scores', v_scores
    );
  end if;

  if v_room.status <> 'waiting' then
    raise exception using errcode = '40001', message = 'Room is not waiting';
  end if;

  perform public.consume_host_game_credit_v1();
  return public.start_game_v2(p_room_id, p_duration_seconds);
end;
$$;

-- Party gameplay remains owned by start_party_game_v2. The profile update and
-- V2 invocation share this transaction, so any failed V2 validation rolls the
-- credit increment back automatically.
create or replace function public.start_party_game_v3(
  p_room_id uuid,
  p_betting_duration_seconds integer default 20
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room public.rooms%rowtype;
begin
  if (select auth.uid()) is null then
    raise exception using errcode = '42501', message = 'AUTH_REQUIRED';
  end if;

  select *
  into v_room
  from public.rooms
  where id = p_room_id
  for update;

  if not found or v_room.game_mode <> 'party' then
    raise exception using errcode = 'P0002', message = 'Party room not found';
  end if;

  if not exists (
    select 1
    from public.players p
    where p.room_id = p_room_id
      and p.auth_user_id = (select auth.uid())
      and p.is_host = true
      and p.is_connected = true
  ) then
    raise exception using errcode = '42501', message = 'Host access required';
  end if;

  if v_room.status = 'playing'
     and exists (
       select 1
       from public.party_matches m
       where m.room_id = p_room_id
     ) then
    return public.get_party_snapshot_v1(p_room_id);
  end if;

  if v_room.status <> 'waiting' then
    raise exception using errcode = '40001', message = 'Room is not waiting';
  end if;

  perform public.consume_host_game_credit_v1();
  return public.start_party_game_v2(p_room_id, p_betting_duration_seconds);
end;
$$;

revoke all on function public.consume_host_game_credit_v1()
  from public, anon, authenticated;

revoke all on function public.start_game_v3(uuid, integer)
  from public, anon, authenticated;
grant execute on function public.start_game_v3(uuid, integer)
  to authenticated;

revoke all on function public.start_party_game_v3(uuid, integer)
  from public, anon, authenticated;
grant execute on function public.start_party_game_v3(uuid, integer)
  to authenticated;

notify pgrst, 'reload schema';

commit;
