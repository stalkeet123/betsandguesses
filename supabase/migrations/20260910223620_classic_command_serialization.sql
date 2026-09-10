-- Serialize every Classic player write behind the room row. This makes the
-- deadline/phase check and the child-row mutation one atomic decision, uses a
-- single lock order (room -> player/bet), and advances the room snapshot
-- version exactly once for each successful logical command.
begin;

create or replace function public.submit_guess_v2(
  p_room_id uuid,
  p_value bigint
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_room public.rooms%rowtype;
  v_player public.players%rowtype;
  v_guess public.guesses%rowtype;
begin
  if p_value < 0 then
    raise exception using errcode = '22023', message = 'Invalid guess';
  end if;

  select * into v_room
  from public.rooms
  where id = p_room_id
  for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'Room not found';
  end if;

  select * into v_player
  from public.players
  where room_id = p_room_id
    and auth_user_id = (select auth.uid())
    and is_connected
  limit 1;
  if v_player.id is null then
    raise exception using errcode = '42501', message = 'Room membership required';
  end if;

  select * into v_guess
  from public.guesses
  where room_id = p_room_id
    and round_number = v_room.current_round
    and player_id = v_player.id;
  if v_guess.id is not null then
    return to_jsonb(v_guess);
  end if;

  if v_room.status <> 'playing'
     or v_room.round_phase <> 'guessing'
     or v_room.current_question_id is null
     or (v_room.phase_ends_at is not null
         and v_room.phase_ends_at <= statement_timestamp()) then
    return null;
  end if;

  insert into public.guesses (
    room_id, round_number, player_id, question_id, value
  ) values (
    p_room_id, v_room.current_round, v_player.id,
    v_room.current_question_id, p_value
  )
  on conflict (room_id, round_number, player_id) do nothing
  returning * into v_guess;

  if v_guess.id is null then
    select * into v_guess
    from public.guesses
    where room_id = p_room_id
      and round_number = v_room.current_round
      and player_id = v_player.id;
    return to_jsonb(v_guess);
  end if;

  update public.rooms
  set updated_at = clock_timestamp()
  where id = p_room_id;
  return to_jsonb(v_guess);
end;
$function$;

create or replace function public.place_bet_v2(
  p_room_id uuid,
  p_slot_index integer,
  p_chips integer,
  p_client_action_id uuid,
  p_position_x double precision default null,
  p_position_y double precision default null
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_room public.rooms%rowtype;
  v_player public.players%rowtype;
  v_bet public.bets%rowtype;
  v_total integer;
  v_multiplier integer;
begin
  if p_slot_index not between 0 and 4 or p_chips not between 1 and 1000 then
    raise exception using errcode = '22023', message = 'Invalid bet';
  end if;
  select * into v_room from public.rooms where id = p_room_id for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'Room not found';
  end if;
  select * into v_player
  from public.players
  where room_id = p_room_id
    and auth_user_id = (select auth.uid())
    and is_connected
  limit 1
  for update;
  if v_player.id is null then
    raise exception using errcode = '42501', message = 'Room membership required';
  end if;
  select * into v_bet
  from public.bets
  where client_action_id = p_client_action_id::text
    and player_id = v_player.id;
  if v_bet.id is not null then
    return to_jsonb(v_bet);
  end if;
  if v_room.status <> 'playing'
     or v_room.round_phase <> 'betting'
     or (v_room.phase_ends_at is not null
         and v_room.phase_ends_at <= statement_timestamp()) then
    return null;
  end if;
  select score into v_player.score from public.players where id = v_player.id;
  select coalesce(sum(chips), 0) into v_total
  from public.bets
  where room_id = p_room_id
    and round_number = v_room.current_round
    and player_id = v_player.id;
  if v_total + p_chips > v_player.score then
    raise exception using errcode = '22003', message = 'Insufficient score';
  end if;
  v_multiplier := (array[4, 3, 2, 3, 4])[p_slot_index + 1];
  insert into public.bets (
    room_id, round_number, player_id, target_guess_id, slot_index,
    chips, payout_multiplier, client_action_id, position_x, position_y
  ) values (
    p_room_id, v_room.current_round, v_player.id, null, p_slot_index,
    p_chips, v_multiplier, p_client_action_id::text,
    case when p_position_x between -1000 and 2000 then p_position_x else null end,
    case when p_position_y between -1000 and 2000 then p_position_y else null end
  ) returning * into v_bet;
  update public.rooms
  set updated_at = clock_timestamp()
  where id = p_room_id;
  return to_jsonb(v_bet);
end;
$function$;

create or replace function public.move_bet_v2(
  p_bet_id uuid,
  p_slot_index integer,
  p_position_x double precision default null,
  p_position_y double precision default null
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_room_id uuid;
  v_room public.rooms%rowtype;
  v_bet public.bets%rowtype;
begin
  if p_slot_index not between 0 and 4 then
    raise exception using errcode = '22023', message = 'Invalid slot';
  end if;

  select b.room_id into v_room_id
  from public.bets b
  join public.players p on p.id = b.player_id
  where b.id = p_bet_id
    and p.auth_user_id = (select auth.uid());
  if v_room_id is null then
    raise exception using errcode = '42501', message = 'Bet access denied';
  end if;

  select * into v_room
  from public.rooms
  where id = v_room_id
  for update;
  select b.* into v_bet
  from public.bets b
  join public.players p on p.id = b.player_id
  where b.id = p_bet_id
    and p.auth_user_id = (select auth.uid())
  for update of b;
  if not found then
    raise exception using errcode = '42501', message = 'Bet access denied';
  end if;

  if v_room.status <> 'playing'
     or v_room.round_phase <> 'betting'
     or v_room.current_round <> v_bet.round_number
     or (v_room.phase_ends_at is not null
         and v_room.phase_ends_at <= statement_timestamp()) then
    return null;
  end if;

  update public.bets
  set target_guess_id = null,
      slot_index = p_slot_index,
      payout_multiplier = (array[4, 3, 2, 3, 4])[p_slot_index + 1],
      position_x = case
        when p_position_x between -1000 and 2000 then p_position_x else null end,
      position_y = case
        when p_position_y between -1000 and 2000 then p_position_y else null end
  where id = p_bet_id
  returning * into v_bet;
  update public.rooms
  set updated_at = clock_timestamp()
  where id = v_room_id;
  return to_jsonb(v_bet);
end;
$function$;

create or replace function public.remove_bet_v2(p_bet_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_room_id uuid;
  v_room public.rooms%rowtype;
  v_bet public.bets%rowtype;
begin
  select b.room_id into v_room_id
  from public.bets b
  join public.players p on p.id = b.player_id
  where b.id = p_bet_id
    and p.auth_user_id = (select auth.uid());
  if v_room_id is null then
    raise exception using errcode = '42501', message = 'Bet access denied';
  end if;

  select * into v_room
  from public.rooms
  where id = v_room_id
  for update;
  select b.* into v_bet
  from public.bets b
  join public.players p on p.id = b.player_id
  where b.id = p_bet_id
    and p.auth_user_id = (select auth.uid())
  for update of b;
  if not found then
    raise exception using errcode = '42501', message = 'Bet access denied';
  end if;

  if v_room.status <> 'playing'
     or v_room.round_phase <> 'betting'
     or v_room.current_round <> v_bet.round_number
     or (v_room.phase_ends_at is not null
         and v_room.phase_ends_at <= statement_timestamp()) then
    raise exception using errcode = '40001', message = 'Betting phase is closed';
  end if;
  delete from public.bets where id = p_bet_id;
  update public.rooms
  set updated_at = clock_timestamp()
  where id = v_room_id;
  return to_jsonb(v_bet);
end;
$function$;

revoke all on function public.submit_guess_v2(uuid, bigint) from public, anon;
revoke all on function public.place_bet_v2(uuid, integer, integer, uuid, double precision, double precision) from public, anon;
revoke all on function public.move_bet_v2(uuid, integer, double precision, double precision) from public, anon;
revoke all on function public.remove_bet_v2(uuid) from public, anon;
grant execute on function public.submit_guess_v2(uuid, bigint) to authenticated, service_role;
grant execute on function public.place_bet_v2(uuid, integer, integer, uuid, double precision, double precision) to authenticated, service_role;
grant execute on function public.move_bet_v2(uuid, integer, double precision, double precision) to authenticated, service_role;
grant execute on function public.remove_bet_v2(uuid) to authenticated, service_role;

notify pgrst, 'reload schema';
commit;
