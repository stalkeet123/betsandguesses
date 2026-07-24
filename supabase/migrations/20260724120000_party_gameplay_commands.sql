create or replace function public.party_board_boundaries_v1(
  p_room_id uuid,
  p_round_number integer
)
returns bigint[]
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_values bigint[];
  v_candidates bigint[];
  v_result bigint[];
  v_count integer;
  v_index integer;
  v_widest_index integer;
  v_widest_gap bigint;
  v_gap bigint;
  v_step bigint;
  v_generated bigint;
  v_target numeric;
  v_candidate bigint;
begin
  select array_agg(value order by value) into v_values
  from (
    select distinct g.value::bigint
    from public.party_guesses g
    where g.room_id = p_room_id
      and g.round_number = p_round_number
      and g.is_performer_prediction = false
  ) values_query;
  v_count := coalesce(array_length(v_values, 1), 0);
  if v_count = 0 then return array[25, 50, 75, 100]::bigint[]; end if;
  if v_count = 1 then return public.game_fallback_boundaries_v2(v_values); end if;
  if v_count > 4 then
    v_result := array[v_values[1]];
    v_candidates := v_values[2:v_count - 1];
    for v_index in 1..2 loop
      v_target := v_values[1]
        + ((v_values[v_count] - v_values[1])::numeric / 3) * v_index;
      select c into v_candidate
      from unnest(v_candidates) c
      order by abs(c::numeric - v_target), c
      limit 1;
      v_result := array_append(v_result, v_candidate);
      v_candidates := array_remove(v_candidates, v_candidate);
    end loop;
    v_result := array_append(v_result, v_values[v_count]);
    select array_agg(v order by v) into v_result from unnest(v_result) v;
    return v_result;
  end if;
  v_result := v_values;
  while array_length(v_result, 1) < 4 loop
    v_widest_index := 1;
    v_widest_gap := v_result[2] - v_result[1];
    if array_length(v_result, 1) > 2 then
      for v_index in 2..array_length(v_result, 1) - 1 loop
        v_gap := v_result[v_index + 1] - v_result[v_index];
        if v_gap > v_widest_gap then
          v_widest_gap := v_gap;
          v_widest_index := v_index;
        end if;
      end loop;
    end if;
    v_step := public.game_nice_step_v2(abs(v_widest_gap));
    v_generated := round(
      (((v_result[v_widest_index] + v_result[v_widest_index + 1])::numeric / 2) / v_step)
    )::bigint * v_step;
    if v_generated = any(v_result) then
      return public.game_fallback_boundaries_v2(v_values);
    end if;
    v_result := array_append(v_result, v_generated);
    select array_agg(v order by v) into v_result from unnest(v_result) v;
  end loop;
  return v_result;
end;
$$;

create or replace function public.submit_party_guess_v1(
  p_room_id uuid,
  p_value integer
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room public.rooms%rowtype;
  v_round public.party_rounds%rowtype;
  v_player public.players%rowtype;
  v_guess public.party_guesses%rowtype;
  v_max_result integer;
begin
  select * into v_room from public.rooms where id = p_room_id;
  select * into v_player from public.players
  where room_id = p_room_id
    and auth_user_id = (select auth.uid())
    and is_connected = true
  order by joined_at desc limit 1;
  select * into v_round from public.party_rounds
  where room_id = p_room_id and round_number = v_room.current_round;
  select c.max_result into v_max_result
  from public.party_challenges c where c.id = v_round.challenge_id;
  if v_player.id is null then
    raise exception using errcode = '42501', message = 'Room membership required';
  end if;
  if v_room.game_mode <> 'party' or v_room.status <> 'playing'
     or v_round.phase <> 'guessing'
     or (v_round.phase_ends_at is not null and v_round.phase_ends_at < statement_timestamp()) then
    raise exception using errcode = '40001', message = 'Guessing phase is closed';
  end if;
  if p_value < 0 or p_value > v_max_result then
    raise exception using errcode = '22023', message = 'Invalid guess';
  end if;
  insert into public.party_guesses (
    room_id, round_number, player_id, value, is_performer_prediction
  ) values (
    p_room_id, v_room.current_round, v_player.id, p_value,
    v_player.id = v_round.performer_id
  )
  on conflict (room_id, round_number, player_id) do nothing
  returning * into v_guess;
  if v_guess.id is null then
    select * into v_guess from public.party_guesses
    where room_id = p_room_id and round_number = v_room.current_round
      and player_id = v_player.id;
  else
    update public.party_matches
    set state_version = state_version + 1
    where room_id = p_room_id;
  end if;
  return to_jsonb(v_guess);
end;
$$;

create or replace function public.advance_party_to_betting_v1(
  p_room_id uuid,
  p_duration_seconds integer default 45
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room public.rooms%rowtype;
  v_round public.party_rounds%rowtype;
begin
  if p_duration_seconds not between 15 and 90 then
    raise exception using errcode = '22023', message = 'Invalid betting duration';
  end if;
  if not public.is_room_member_v2(p_room_id) then
    raise exception using errcode = '42501', message = 'Room membership required';
  end if;
  select * into v_room from public.rooms where id = p_room_id for update;
  select * into v_round from public.party_rounds
  where room_id = p_room_id and round_number = v_room.current_round for update;
  if v_round.phase = 'betting' then return public.get_party_snapshot_v1(p_room_id); end if;
  if v_round.phase <> 'guessing'
     or (v_round.phase_ends_at is not null and v_round.phase_ends_at > statement_timestamp()) then
    raise exception using errcode = '40001', message = 'Guessing is still active';
  end if;
  update public.party_rounds
  set phase = 'betting', phase_started_at = statement_timestamp(),
      phase_ends_at = statement_timestamp() + make_interval(secs => p_duration_seconds)
  where id = v_round.id;
  update public.rooms
  set round_phase = 'betting', phase_started_at = statement_timestamp(),
      phase_ends_at = statement_timestamp() + make_interval(secs => p_duration_seconds)
  where id = p_room_id;
  update public.party_matches set state_version = state_version + 1
  where room_id = p_room_id;
  return public.get_party_snapshot_v1(p_room_id);
end;
$$;

create or replace function public.place_party_bet_v1(
  p_room_id uuid,
  p_slot_index integer,
  p_chips integer,
  p_client_action_id uuid,
  p_position_x double precision default null,
  p_position_y double precision default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room public.rooms%rowtype;
  v_round public.party_rounds%rowtype;
  v_player public.players%rowtype;
  v_bet public.party_bets%rowtype;
  v_total integer;
  v_score integer;
begin
  if p_slot_index not between 0 and 4 or p_chips not between 1 and 1000
     or p_client_action_id is null then
    raise exception using errcode = '22023', message = 'Invalid bet';
  end if;
  if (p_position_x is not null and p_position_x not between 0 and 1)
     or (p_position_y is not null and p_position_y not between 0 and 1) then
    raise exception using errcode = '22023', message = 'Invalid bet position';
  end if;
  select * into v_room from public.rooms where id = p_room_id;
  select * into v_player from public.players
  where room_id = p_room_id and auth_user_id = (select auth.uid())
    and is_connected = true order by joined_at desc limit 1;
  select * into v_round from public.party_rounds
  where room_id = p_room_id and round_number = v_room.current_round;
  if v_player.id is null then
    raise exception using errcode = '42501', message = 'Room membership required';
  end if;
  if v_player.id = v_round.performer_id then
    raise exception using errcode = '42501', message = 'Performer cannot bet';
  end if;
  if v_round.phase <> 'betting'
     or (v_round.phase_ends_at is not null and v_round.phase_ends_at < statement_timestamp()) then
    raise exception using errcode = '40001', message = 'Betting phase is closed';
  end if;
  select score into v_score from public.party_scores
  where room_id = p_room_id and player_id = v_player.id
  for update;
  select coalesce(sum(chips), 0) into v_total from public.party_bets
  where room_id = p_room_id and round_number = v_room.current_round
    and player_id = v_player.id;
  if v_total + p_chips > v_score then
    raise exception using errcode = '22023', message = 'Insufficient score';
  end if;
  insert into public.party_bets (
    room_id, round_number, player_id, slot_index, chips,
    client_action_id, position_x, position_y
  ) values (
    p_room_id, v_room.current_round, v_player.id, p_slot_index, p_chips,
    p_client_action_id, p_position_x, p_position_y
  )
  on conflict (room_id, round_number, player_id, client_action_id) do nothing
  returning * into v_bet;
  if v_bet.id is null then
    select * into v_bet from public.party_bets
    where room_id = p_room_id and round_number = v_room.current_round
      and player_id = v_player.id and client_action_id = p_client_action_id;
  else
    update public.party_matches set state_version = state_version + 1
    where room_id = p_room_id;
  end if;
  return to_jsonb(v_bet);
end;
$$;

create or replace function public.move_party_bet_v1(
  p_room_id uuid,
  p_bet_id uuid,
  p_slot_index integer,
  p_position_x double precision default null,
  p_position_y double precision default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room public.rooms%rowtype;
  v_round public.party_rounds%rowtype;
  v_player public.players%rowtype;
  v_bet public.party_bets%rowtype;
begin
  if p_slot_index not between 0 and 4 then
    raise exception using errcode = '22023', message = 'Invalid bet slot';
  end if;
  if (p_position_x is not null and p_position_x not between 0 and 1)
     or (p_position_y is not null and p_position_y not between 0 and 1) then
    raise exception using errcode = '22023', message = 'Invalid bet position';
  end if;
  select * into v_room from public.rooms where id = p_room_id;
  select * into v_player from public.players
  where room_id = p_room_id and auth_user_id = (select auth.uid())
    and is_connected = true order by joined_at desc limit 1;
  select * into v_round from public.party_rounds
  where room_id = p_room_id and round_number = v_room.current_round;
  if v_player.id is null then
    raise exception using errcode = '42501', message = 'Room membership required';
  end if;
  if v_round.phase <> 'betting'
     or (v_round.phase_ends_at is not null and v_round.phase_ends_at < statement_timestamp()) then
    raise exception using errcode = '40001', message = 'Betting phase is closed';
  end if;
  update public.party_bets
  set slot_index = p_slot_index,
      position_x = p_position_x,
      position_y = p_position_y
  where id = p_bet_id
    and room_id = p_room_id
    and round_number = v_room.current_round
    and player_id = v_player.id
  returning * into v_bet;
  if v_bet.id is null then
    raise exception using errcode = '42501', message = 'Bet ownership required';
  end if;
  update public.party_matches set state_version = state_version + 1
  where room_id = p_room_id;
  return to_jsonb(v_bet);
end;
$$;

create or replace function public.remove_party_bet_v1(
  p_room_id uuid,
  p_bet_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room public.rooms%rowtype;
  v_round public.party_rounds%rowtype;
  v_player public.players%rowtype;
  v_bet public.party_bets%rowtype;
begin
  select * into v_room from public.rooms where id = p_room_id;
  select * into v_player from public.players
  where room_id = p_room_id and auth_user_id = (select auth.uid())
    and is_connected = true order by joined_at desc limit 1;
  select * into v_round from public.party_rounds
  where room_id = p_room_id and round_number = v_room.current_round;
  if v_player.id is null then
    raise exception using errcode = '42501', message = 'Room membership required';
  end if;
  if v_round.phase <> 'betting'
     or (v_round.phase_ends_at is not null and v_round.phase_ends_at < statement_timestamp()) then
    raise exception using errcode = '40001', message = 'Betting phase is closed';
  end if;
  delete from public.party_bets
  where id = p_bet_id
    and room_id = p_room_id
    and round_number = v_room.current_round
    and player_id = v_player.id
  returning * into v_bet;
  if v_bet.id is null then
    raise exception using errcode = '42501', message = 'Bet ownership required';
  end if;
  update public.party_matches set state_version = state_version + 1
  where room_id = p_room_id;
  return to_jsonb(v_bet);
end;
$$;

create or replace function public.begin_party_ready_v1(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room public.rooms%rowtype;
  v_round public.party_rounds%rowtype;
begin
  if not public.is_room_member_v2(p_room_id) then
    raise exception using errcode = '42501', message = 'Room membership required';
  end if;
  select * into v_room from public.rooms where id = p_room_id for update;
  select * into v_round from public.party_rounds
  where room_id = p_room_id and round_number = v_room.current_round for update;
  if v_round.phase = 'ready' then return public.get_party_snapshot_v1(p_room_id); end if;
  if v_round.phase <> 'betting'
     or (v_round.phase_ends_at is not null and v_round.phase_ends_at > statement_timestamp()) then
    raise exception using errcode = '40001', message = 'Betting is still active';
  end if;
  update public.party_rounds
  set phase = 'ready', phase_started_at = statement_timestamp(), phase_ends_at = null
  where id = v_round.id;
  update public.rooms
  set round_phase = 'partyReady', phase_started_at = statement_timestamp(), phase_ends_at = null
  where id = p_room_id;
  update public.party_matches set state_version = state_version + 1
  where room_id = p_room_id;
  return public.get_party_snapshot_v1(p_room_id);
end;
$$;

create or replace function public.mark_party_performer_ready_v1(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room public.rooms%rowtype;
  v_round public.party_rounds%rowtype;
  v_player public.players%rowtype;
begin
  select * into v_room from public.rooms where id = p_room_id;
  select * into v_round from public.party_rounds
  where room_id = p_room_id and round_number = v_room.current_round for update;
  select * into v_player from public.players
  where room_id = p_room_id and auth_user_id = (select auth.uid())
    and is_connected = true order by joined_at desc limit 1;
  if v_player.id is null or v_player.id <> v_round.performer_id then
    raise exception using errcode = '42501', message = 'Performer access required';
  end if;
  if v_round.phase <> 'ready' then
    raise exception using errcode = '40001', message = 'Ready phase is not active';
  end if;
  if v_round.performer_ready_at is not null then
    return public.get_party_snapshot_v1(p_room_id);
  end if;
  update public.party_rounds set performer_ready_at = statement_timestamp()
  where id = v_round.id;
  update public.party_matches set state_version = state_version + 1
  where room_id = p_room_id;
  return public.get_party_snapshot_v1(p_room_id);
end;
$$;

create or replace function public.start_party_action_v1(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room public.rooms%rowtype;
  v_round public.party_rounds%rowtype;
begin
  select * into v_room from public.rooms where id = p_room_id for update;
  if not exists (
    select 1 from public.players p where p.room_id = p_room_id
      and p.auth_user_id = (select auth.uid()) and p.is_host and p.is_connected
  ) then
    raise exception using errcode = '42501', message = 'Host access required';
  end if;
  select * into v_round from public.party_rounds
  where room_id = p_room_id and round_number = v_room.current_round for update;
  if v_round.phase = 'action' then return public.get_party_snapshot_v1(p_room_id); end if;
  if v_round.phase <> 'ready' or v_round.performer_ready_at is null then
    raise exception using errcode = '40001', message = 'Performer is not ready';
  end if;
  update public.party_rounds
  set phase = 'action', phase_started_at = statement_timestamp(),
      phase_ends_at = statement_timestamp() + interval '60 seconds'
  where id = v_round.id;
  update public.rooms
  set round_phase = 'partyAction', phase_started_at = statement_timestamp(),
      phase_ends_at = statement_timestamp() + interval '60 seconds'
  where id = p_room_id;
  update public.party_matches set state_version = state_version + 1
  where room_id = p_room_id;
  return public.get_party_snapshot_v1(p_room_id);
end;
$$;

create or replace function public.open_party_result_entry_v1(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room public.rooms%rowtype;
  v_round public.party_rounds%rowtype;
begin
  if not public.is_room_member_v2(p_room_id) then
    raise exception using errcode = '42501', message = 'Room membership required';
  end if;
  select * into v_room from public.rooms where id = p_room_id for update;
  select * into v_round from public.party_rounds
  where room_id = p_room_id and round_number = v_room.current_round for update;
  if v_round.phase = 'resultEntry' then return public.get_party_snapshot_v1(p_room_id); end if;
  if v_round.phase <> 'action' or v_round.phase_ends_at > statement_timestamp() then
    raise exception using errcode = '40001', message = 'Challenge is still active';
  end if;
  update public.party_rounds
  set phase = 'resultEntry', phase_started_at = statement_timestamp(), phase_ends_at = null
  where id = v_round.id;
  update public.rooms
  set round_phase = 'partyResultEntry', phase_started_at = statement_timestamp(), phase_ends_at = null
  where id = p_room_id;
  update public.party_matches set state_version = state_version + 1
  where room_id = p_room_id;
  return public.get_party_snapshot_v1(p_room_id);
end;
$$;

create or replace function public.submit_party_result_v1(
  p_room_id uuid,
  p_result integer
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room public.rooms%rowtype;
  v_round public.party_rounds%rowtype;
  v_host public.players%rowtype;
  v_max_result integer;
begin
  select * into v_room from public.rooms where id = p_room_id for update;
  select * into v_host from public.players
  where room_id = p_room_id and auth_user_id = (select auth.uid())
    and is_host and is_connected limit 1;
  if v_host.id is null then
    raise exception using errcode = '42501', message = 'Host access required';
  end if;
  select * into v_round from public.party_rounds
  where room_id = p_room_id and round_number = v_room.current_round for update;
  select max_result into v_max_result from public.party_challenges
  where id = v_round.challenge_id;
  if v_round.phase = 'resultConfirm' and v_round.proposed_result = p_result then
    return public.get_party_snapshot_v1(p_room_id);
  end if;
  if v_round.phase <> 'resultEntry' then
    raise exception using errcode = '40001', message = 'Result entry is not active';
  end if;
  if p_result < 0 or p_result > v_max_result then
    raise exception using errcode = '22023', message = 'Invalid result';
  end if;
  update public.party_rounds
  set phase = 'resultConfirm', proposed_result = p_result,
      result_submitted_by = v_host.id, phase_started_at = statement_timestamp()
  where id = v_round.id;
  update public.rooms
  set round_phase = 'partyResultConfirm', phase_started_at = statement_timestamp()
  where id = p_room_id;
  update public.party_matches set state_version = state_version + 1
  where room_id = p_room_id;
  return public.get_party_snapshot_v1(p_room_id);
end;
$$;

revoke all on function public.party_board_boundaries_v1(uuid, integer) from public, anon, authenticated;
revoke all on function public.submit_party_guess_v1(uuid, integer) from public, anon, authenticated;
revoke all on function public.advance_party_to_betting_v1(uuid, integer) from public, anon, authenticated;
revoke all on function public.place_party_bet_v1(uuid, integer, integer, uuid, double precision, double precision) from public, anon, authenticated;
revoke all on function public.move_party_bet_v1(uuid, uuid, integer, double precision, double precision) from public, anon, authenticated;
revoke all on function public.remove_party_bet_v1(uuid, uuid) from public, anon, authenticated;
revoke all on function public.begin_party_ready_v1(uuid) from public, anon, authenticated;
revoke all on function public.mark_party_performer_ready_v1(uuid) from public, anon, authenticated;
revoke all on function public.start_party_action_v1(uuid) from public, anon, authenticated;
revoke all on function public.open_party_result_entry_v1(uuid) from public, anon, authenticated;
revoke all on function public.submit_party_result_v1(uuid, integer) from public, anon, authenticated;

grant execute on function public.submit_party_guess_v1(uuid, integer) to authenticated;
grant execute on function public.advance_party_to_betting_v1(uuid, integer) to authenticated;
grant execute on function public.place_party_bet_v1(uuid, integer, integer, uuid, double precision, double precision) to authenticated;
grant execute on function public.move_party_bet_v1(uuid, uuid, integer, double precision, double precision) to authenticated;
grant execute on function public.remove_party_bet_v1(uuid, uuid) to authenticated;
grant execute on function public.begin_party_ready_v1(uuid) to authenticated;
grant execute on function public.mark_party_performer_ready_v1(uuid) to authenticated;
grant execute on function public.start_party_action_v1(uuid) to authenticated;
grant execute on function public.open_party_result_entry_v1(uuid) to authenticated;
grant execute on function public.submit_party_result_v1(uuid, integer) to authenticated;
