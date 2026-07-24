create or replace function public.confirm_party_result_v1(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room public.rooms%rowtype;
  v_round public.party_rounds%rowtype;
  v_match public.party_matches%rowtype;
  v_player public.players%rowtype;
  v_host_id uuid;
  v_required_confirmer uuid;
  v_boundaries bigint[];
  v_winning_slot integer;
  v_crowd_line integer;
begin
  select * into v_room from public.rooms where id = p_room_id for update;
  select * into v_match from public.party_matches
  where room_id = p_room_id for update;
  select * into v_round from public.party_rounds
  where room_id = p_room_id and round_number = v_room.current_round for update;
  select * into v_player from public.players
  where room_id = p_room_id and auth_user_id = (select auth.uid())
    and is_connected = true order by joined_at desc limit 1;
  select p.id into v_host_id from public.players p
  where p.room_id = p_room_id and p.is_host = true and p.is_connected = true
  order by p.joined_at limit 1;

  if v_player.id is null then
    raise exception using errcode = '42501', message = 'Room membership required';
  end if;
  if v_round.phase = 'reveal' then
    return public.get_party_snapshot_v1(p_room_id);
  end if;
  if v_round.phase <> 'resultConfirm' or v_round.proposed_result is null then
    raise exception using errcode = '40001', message = 'Result confirmation is not active';
  end if;

  v_required_confirmer := case
    when v_round.performer_id = v_host_id then v_round.witness_id
    else v_round.performer_id
  end;
  if v_player.id <> v_required_confirmer then
    raise exception using errcode = '42501', message = 'Result confirmer access required';
  end if;

  v_boundaries := public.party_board_boundaries_v1(
    p_room_id,
    v_room.current_round
  );
  v_winning_slot := case
    when v_round.proposed_result < v_boundaries[1] then 0
    when v_round.proposed_result < v_boundaries[2] then 1
    when v_round.proposed_result <= v_boundaries[3] then 2
    when v_round.proposed_result <= v_boundaries[4] then 3
    else 4
  end;

  select ceil(percentile_cont(0.5) within group (order by g.value))::integer
  into v_crowd_line
  from public.party_guesses g
  where g.room_id = p_room_id
    and g.round_number = v_room.current_round
    and g.is_performer_prediction = false;

  update public.party_bets
  set won = (slot_index = v_winning_slot)
  where room_id = p_room_id and round_number = v_room.current_round;

  update public.party_scores s
  set score = greatest(
    15,
    s.score
      - coalesce((
          select sum(b.chips)
          from public.party_bets b
          where b.room_id = p_room_id
            and b.round_number = v_room.current_round
            and b.player_id = s.player_id
        ), 0)
      + coalesce((
          select sum(
            b.chips * (array[4, 3, 2, 3, 4])[b.slot_index + 1]
          )
          from public.party_bets b
          where b.room_id = p_room_id
            and b.round_number = v_room.current_round
            and b.player_id = s.player_id
            and b.slot_index = v_winning_slot
        ), 0)
  )
  where s.room_id = p_room_id
    and s.player_id <> v_round.performer_id;

  if v_crowd_line is not null
     and v_round.proposed_result >= v_crowd_line then
    update public.party_scores
    set score = score + 2
    where room_id = p_room_id and player_id = v_round.performer_id;
  end if;

  update public.party_rounds
  set phase = 'reveal',
      result_confirmed_by = v_player.id,
      settled_at = statement_timestamp(),
      phase_started_at = statement_timestamp(),
      phase_ends_at = statement_timestamp() + interval '7 seconds'
  where id = v_round.id and settled_at is null;

  update public.rooms
  set round_phase = 'revealAnswer',
      phase_started_at = statement_timestamp(),
      phase_ends_at = statement_timestamp() + interval '7 seconds'
  where id = p_room_id;

  update public.party_matches
  set state_version = state_version + 1
  where room_id = p_room_id;

  return public.get_party_snapshot_v1(p_room_id);
end;
$$;

create or replace function public.dispute_party_result_v1(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room public.rooms%rowtype;
  v_round public.party_rounds%rowtype;
  v_player public.players%rowtype;
  v_host_id uuid;
  v_required_confirmer uuid;
begin
  select * into v_room from public.rooms where id = p_room_id for update;
  select * into v_round from public.party_rounds
  where room_id = p_room_id and round_number = v_room.current_round for update;
  select * into v_player from public.players
  where room_id = p_room_id and auth_user_id = (select auth.uid())
    and is_connected = true order by joined_at desc limit 1;
  select p.id into v_host_id from public.players p
  where p.room_id = p_room_id and p.is_host and p.is_connected
  order by p.joined_at limit 1;
  v_required_confirmer := case
    when v_round.performer_id = v_host_id then v_round.witness_id
    else v_round.performer_id
  end;
  if v_player.id is null or v_player.id <> v_required_confirmer then
    raise exception using errcode = '42501', message = 'Result confirmer access required';
  end if;
  if v_round.phase = 'resultEntry' and v_round.proposed_result is null then
    return public.get_party_snapshot_v1(p_room_id);
  end if;
  if v_round.phase <> 'resultConfirm' or v_round.settled_at is not null then
    raise exception using errcode = '40001', message = 'Result cannot be disputed';
  end if;
  update public.party_rounds
  set phase = 'resultEntry', proposed_result = null,
      result_submitted_by = null, phase_started_at = statement_timestamp()
  where id = v_round.id;
  update public.rooms
  set round_phase = 'partyResultEntry', phase_started_at = statement_timestamp()
  where id = p_room_id;
  update public.party_matches set state_version = state_version + 1
  where room_id = p_room_id;
  return public.get_party_snapshot_v1(p_room_id);
end;
$$;

create or replace function public.advance_party_round_v1(
  p_room_id uuid,
  p_guess_duration_seconds integer default 30
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room public.rooms%rowtype;
  v_round public.party_rounds%rowtype;
  v_match public.party_matches%rowtype;
  v_next_index integer;
  v_next_round integer;
  v_performer_id uuid;
  v_witness_id uuid;
  v_challenge_id uuid;
  v_scores jsonb;
begin
  if p_guess_duration_seconds not between 15 and 90 then
    raise exception using errcode = '22023', message = 'Invalid guess duration';
  end if;
  select * into v_room from public.rooms where id = p_room_id for update;
  if not exists (
    select 1 from public.players p where p.room_id = p_room_id
      and p.auth_user_id = (select auth.uid()) and p.is_host and p.is_connected
  ) then
    raise exception using errcode = '42501', message = 'Host access required';
  end if;
  if v_room.status = 'finished' then
    select coalesce(jsonb_object_agg(s.player_id::text, s.score), '{}'::jsonb)
    into v_scores from public.party_scores s where s.room_id = p_room_id;
    return jsonb_build_object('finished', true, 'room', to_jsonb(v_room), 'scores', v_scores);
  end if;
  select * into v_match from public.party_matches
  where room_id = p_room_id for update;
  select * into v_round from public.party_rounds
  where room_id = p_room_id and round_number = v_room.current_round for update;
  if v_round.phase = 'guessing' and v_match.turn_index > 0 then
    return public.get_party_snapshot_v1(p_room_id);
  end if;
  if v_round.phase <> 'reveal' or v_round.settled_at is null
     or (v_round.phase_ends_at is not null and v_round.phase_ends_at > statement_timestamp()) then
    raise exception using errcode = '40001', message = 'Reveal is still active';
  end if;

  v_next_index := v_match.turn_index + 1;
  if v_next_index >= cardinality(v_match.turn_order) then
    update public.players p
    set score = s.score
    from public.party_scores s
    where s.room_id = p_room_id
      and s.player_id = p.id;
    update public.rooms
    set status = 'finished', round_phase = 'idle',
        phase_started_at = statement_timestamp(), phase_ends_at = null
    where id = p_room_id returning * into v_room;
    update public.party_matches
    set state_version = state_version + 1
    where room_id = p_room_id;
    select coalesce(jsonb_object_agg(s.player_id::text, s.score), '{}'::jsonb)
    into v_scores from public.party_scores s where s.room_id = p_room_id;
    return jsonb_build_object('finished', true, 'room', to_jsonb(v_room), 'scores', v_scores);
  end if;

  v_next_round := v_room.current_round + 1;
  v_performer_id := v_match.turn_order[v_next_index + 1];
  v_witness_id := (
    select player_id
    from unnest(v_match.turn_order) with ordinality as t(player_id, position)
    where player_id <> v_performer_id
    order by position
    limit 1
  );
  select c.id into v_challenge_id
  from public.party_challenges c
  where c.enabled
    and not exists (
      select 1 from public.party_rounds pr
      where pr.room_id = p_room_id and pr.challenge_id = c.id
    )
  order by random() limit 1;
  if v_challenge_id is null then
    select c.id into v_challenge_id
    from public.party_challenges c where c.enabled
    order by random() limit 1;
  end if;

  insert into public.party_rounds (
    room_id, round_number, performer_id, witness_id, challenge_id,
    phase, phase_started_at, phase_ends_at
  ) values (
    p_room_id, v_next_round, v_performer_id, v_witness_id, v_challenge_id,
    'guessing', statement_timestamp(),
    statement_timestamp() + make_interval(secs => p_guess_duration_seconds)
  );
  update public.party_matches
  set turn_index = v_next_index, state_version = state_version + 1
  where room_id = p_room_id;
  update public.rooms
  set current_round = v_next_round, round_phase = 'guessing',
      phase_started_at = statement_timestamp(),
      phase_ends_at = statement_timestamp() + make_interval(secs => p_guess_duration_seconds)
  where id = p_room_id;
  return public.get_party_snapshot_v1(p_room_id);
end;
$$;

revoke all on function public.confirm_party_result_v1(uuid) from public, anon, authenticated;
revoke all on function public.dispute_party_result_v1(uuid) from public, anon, authenticated;
revoke all on function public.advance_party_round_v1(uuid, integer) from public, anon, authenticated;

grant execute on function public.confirm_party_result_v1(uuid) to authenticated;
grant execute on function public.dispute_party_result_v1(uuid) to authenticated;
grant execute on function public.advance_party_round_v1(uuid, integer) to authenticated;
