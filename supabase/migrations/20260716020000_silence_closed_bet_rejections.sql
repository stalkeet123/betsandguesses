-- Deadline races are expected client/server timing outcomes. Preserve the
-- existing successful JSON contract while rejecting late writes without
-- reporting a PostgreSQL serialization failure.
create or replace function public.place_bet_v2(
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
  v_player public.players%rowtype;
  v_bet public.bets%rowtype;
  v_total integer;
  v_multiplier integer;
begin
  if p_slot_index not between 0 and 4 or p_chips not between 1 and 1000 then
    raise exception using errcode = '22023', message = 'Invalid bet';
  end if;

  select * into v_room
  from public.rooms
  where id = p_room_id;

  select * into v_player
  from public.players
  where room_id = p_room_id
    and auth_user_id = (select auth.uid())
    and is_connected
  limit 1;

  if v_player.id is null then
    raise exception using errcode = '42501', message = 'Room membership required';
  end if;

  -- Return an already committed action even when its response arrives after
  -- the deadline. This keeps retries idempotent and prevents duplicate chips.
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
         and v_room.phase_ends_at < statement_timestamp()) then
    return null;
  end if;

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
  )
  returning * into v_bet;

  return to_jsonb(v_bet);
end;
$$;

create or replace function public.move_bet_v2(
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
  v_bet public.bets%rowtype;
  v_room public.rooms%rowtype;
begin
  if p_slot_index not between 0 and 4 then
    raise exception using errcode = '22023', message = 'Invalid slot';
  end if;

  select b.* into v_bet
  from public.bets b
  join public.players p on p.id = b.player_id
  where b.id = p_bet_id
    and p.auth_user_id = (select auth.uid())
  for update of b;

  if not found then
    raise exception using errcode = '42501', message = 'Bet access denied';
  end if;

  select * into v_room
  from public.rooms
  where id = v_bet.room_id;

  if v_room.round_phase <> 'betting'
     or v_room.current_round <> v_bet.round_number
     or (v_room.phase_ends_at is not null
         and v_room.phase_ends_at < statement_timestamp()) then
    return null;
  end if;

  update public.bets
  set target_guess_id = null,
      slot_index = p_slot_index,
      payout_multiplier = (array[4, 3, 2, 3, 4])[p_slot_index + 1],
      position_x = case
        when p_position_x between -1000 and 2000 then p_position_x
        else null
      end,
      position_y = case
        when p_position_y between -1000 and 2000 then p_position_y
        else null
      end
  where id = p_bet_id
  returning * into v_bet;

  return to_jsonb(v_bet);
end;
$$;
