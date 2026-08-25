begin;

-- Restore the canonical V1 null-safe player predicates. All V2 behavior,
-- including ten-player capacity and the post-validation host-credit order,
-- remains unchanged.
create or replace function public.start_party_poll_v2(
  p_room_id uuid,
  p_betting_duration_seconds integer default 30
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room public.rooms%rowtype;
  v_turn_order uuid[];
  v_active_count integer;
  v_performer_id uuid;
  v_witness_id uuid;
  v_challenge_id uuid;
begin
  if p_betting_duration_seconds not between 10 and 120 then
    raise exception using errcode = '22023', message = 'INVALID_BETTING_DURATION';
  end if;

  select * into v_room
  from public.rooms
  where id = p_room_id
  for update;

  if not found or v_room.game_mode <> 'party' then
    raise exception using errcode = 'P0002', message = 'PARTY_ROOM_NOT_FOUND';
  end if;

  if not exists (
    select 1
    from public.players p
    where p.room_id = p_room_id
      and p.auth_user_id = (select auth.uid())
      and coalesce(p.is_host, false) = true
  ) then
    raise exception using errcode = '42501', message = 'HOST_ACCESS_REQUIRED';
  end if;

  if v_room.status = 'playing'
     and exists (
       select 1 from public.party_matches m where m.room_id = p_room_id
     ) then
    return public.get_party_poll_snapshot_v1(p_room_id);
  end if;

  if v_room.status <> 'waiting' then
    raise exception using errcode = '40001', message = 'ROOM_NOT_WAITING';
  end if;

  if not exists (
    select 1
    from public.party_challenges c
    where c.enabled = true
      and c.challenge_type = 'poll'
  ) then
    raise exception using errcode = 'P0002', message = 'NO_POLL_CHALLENGE_AVAILABLE';
  end if;

  if exists (
    select 1
    from public.players p
    where p.room_id = p_room_id
      and (
        coalesce(p.is_connected, false) = true
        or p.auth_user_id = (select auth.uid())
      )
      and coalesce(p.is_host, false) = false
      and coalesce(p.is_ready, false) = false
  ) then
    raise exception using errcode = 'P0001', message = 'ALL_PLAYERS_MUST_BE_READY';
  end if;

  select array_agg(p.id order by random())
  into v_turn_order
  from public.players p
  where p.room_id = p_room_id
    and (
      coalesce(p.is_connected, false) = true
      or p.auth_user_id = (select auth.uid())
    );

  v_active_count := coalesce(cardinality(v_turn_order), 0);

  if v_active_count < 3 then
    raise exception using errcode = 'P0001', message = 'PARTY_REQUIRES_THREE_PLAYERS';
  end if;

  if v_active_count > 10 then
    raise exception using errcode = '22023',
      message = 'PARTY_POLL_SUPPORTS_MAX_TEN_PLAYERS';
  end if;

  v_performer_id := v_turn_order[1];
  v_witness_id := v_turn_order[2];

  select c.id into v_challenge_id
  from public.party_challenges c
  where c.enabled = true
    and c.challenge_type = 'poll'
  order by random()
  limit 1;

  perform public.consume_host_game_credit_v1();

  -- A waiting room may retain rows from an interrupted match. New-match start
  -- is the sole safe boundary to clear that state.
  delete from public.party_bets where room_id = p_room_id;
  delete from public.party_guesses where room_id = p_room_id;
  delete from public.party_rounds where room_id = p_room_id;
  delete from public.party_scores where room_id = p_room_id;
  delete from public.party_matches where room_id = p_room_id;

  update public.players p
  set score = 0,
      bank_score = 0
  where p.room_id = p_room_id
    and p.id = any(v_turn_order);

  insert into public.party_matches (
    room_id,
    turn_order,
    turn_index,
    state_version
  ) values (
    p_room_id,
    v_turn_order,
    0,
    1
  );

  insert into public.party_scores (room_id, player_id, score)
  select p_room_id, player_id, 0
  from unnest(v_turn_order) as active_players(player_id);

  insert into public.party_rounds (
    room_id,
    round_number,
    performer_id,
    witness_id,
    challenge_id,
    phase,
    phase_started_at,
    phase_ends_at
  ) values (
    p_room_id,
    1,
    v_performer_id,
    v_witness_id,
    v_challenge_id,
    'betting',
    statement_timestamp(),
    statement_timestamp() + make_interval(secs => p_betting_duration_seconds)
  );

  update public.rooms
  set status = 'playing',
      current_round = 1,
      max_rounds = greatest(1, coalesce(v_room.max_rounds, v_active_count)),
      round_phase = 'betting',
      current_question_id = null,
      phase_started_at = statement_timestamp(),
      phase_ends_at = statement_timestamp()
        + make_interval(secs => p_betting_duration_seconds)
  where id = p_room_id;

  return public.get_party_poll_snapshot_v1(p_room_id);
end;
$$;

revoke all on function public.start_party_poll_v2(uuid, integer)
  from public, anon, authenticated;
grant execute on function public.start_party_poll_v2(uuid, integer)
  to authenticated;

notify pgrst, 'reload schema';

commit;