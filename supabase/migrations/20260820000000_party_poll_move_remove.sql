-- Server-authoritative Party Poll bet move/remove commands.
-- Client target identity is a player UUID; slot_index is derived from turn_order.

begin;

create function public.move_party_poll_bet_v1(
  p_room_id uuid,
  p_bet_id uuid,
  p_target_player_id uuid,
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
  v_me public.players%rowtype;
  v_match public.party_matches%rowtype;
  v_round public.party_rounds%rowtype;
  v_challenge public.party_challenges%rowtype;
  v_bet public.party_bets%rowtype;
  v_target_position integer;
  v_slot_index integer;
  v_other_target_count integer;
begin
  if p_room_id is null
     or p_bet_id is null
     or p_target_player_id is null then
    raise exception using errcode = '22023', message = 'INVALID_BET_MOVE';
  end if;

  if (p_position_x is not null and p_position_x not between 0 and 1)
     or (p_position_y is not null and p_position_y not between 0 and 1) then
    raise exception using errcode = '22023', message = 'INVALID_BET_POSITION';
  end if;

  select *
  into v_room
  from public.rooms
  where id = p_room_id
  for update;

  if not found or v_room.game_mode <> 'party' then
    raise exception using errcode = 'P0002', message = 'PARTY_ROOM_NOT_FOUND';
  end if;

  select *
  into v_me
  from public.players p
  where p.room_id = p_room_id
    and p.auth_user_id = (select auth.uid())
  order by p.joined_at desc
  limit 1;

  if not found then
    raise exception using errcode = '42501', message = 'ROOM_MEMBERSHIP_REQUIRED';
  end if;

  select *
  into v_match
  from public.party_matches
  where room_id = p_room_id
  for update;

  if not found then
    raise exception using errcode = 'P0001', message = 'PARTY_MATCH_NOT_STARTED';
  end if;

  select *
  into v_round
  from public.party_rounds
  where room_id = p_room_id
    and round_number = v_room.current_round
  for update;

  if not found then
    raise exception using errcode = 'P0001', message = 'PARTY_ROUND_STATE_MISMATCH';
  end if;

  select *
  into v_challenge
  from public.party_challenges
  where id = v_round.challenge_id;

  if not found or v_challenge.challenge_type <> 'poll' then
    raise exception using errcode = 'P0001', message = 'PARTY_POLL_CHALLENGE_REQUIRED';
  end if;

  if v_round.phase <> 'betting' then
    raise exception using errcode = 'P0001', message = 'BETTING_WINDOW_CLOSED';
  end if;

  if v_round.phase_ends_at is null then
    raise exception using errcode = 'P0001', message = 'BETTING_DEADLINE_MISSING';
  end if;

  if statement_timestamp() >= v_round.phase_ends_at then
    raise exception using errcode = 'P0001', message = 'BETTING_WINDOW_CLOSED';
  end if;

  select *
  into v_bet
  from public.party_bets
  where room_id = p_room_id
    and round_number = v_room.current_round
    and id = p_bet_id
    and player_id = v_me.id
  for update;

  if not found then
    return public.get_party_poll_snapshot_v1(p_room_id);
  end if;

  v_target_position := array_position(v_match.turn_order, p_target_player_id);
  if v_target_position is null then
    raise exception using errcode = '22023', message = 'INVALID_POLL_TARGET';
  end if;

  v_slot_index := v_target_position - 1;
  if v_slot_index not between 0 and 7 then
    raise exception using errcode = '22023', message = 'INVALID_POLL_TARGET';
  end if;

  select count(
    distinct coalesce(
      b.target_player_id,
      v_match.turn_order[b.slot_index + 1]
    )
  )
  into v_other_target_count
  from public.party_bets b
  where b.room_id = p_room_id
    and b.round_number = v_room.current_round
    and b.player_id = v_me.id
    and b.id <> p_bet_id
    and coalesce(
      b.target_player_id,
      v_match.turn_order[b.slot_index + 1]
    ) is distinct from p_target_player_id;

  if v_other_target_count >= 2 then
    raise exception using errcode = '22023', message = 'POLL_MAX_TWO_TARGETS';
  end if;

  if v_bet.target_player_id is not distinct from p_target_player_id
     and v_bet.slot_index = v_slot_index
     and v_bet.position_x is not distinct from p_position_x
     and v_bet.position_y is not distinct from p_position_y then
    return public.get_party_poll_snapshot_v1(p_room_id);
  end if;

  update public.party_bets
  set target_player_id = p_target_player_id,
      slot_index = v_slot_index,
      position_x = p_position_x,
      position_y = p_position_y
  where id = p_bet_id
    and room_id = p_room_id
    and round_number = v_room.current_round
    and player_id = v_me.id;

  return public.get_party_poll_snapshot_v1(p_room_id);
end;
$$;

create function public.remove_party_poll_bet_v1(
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
  v_me public.players%rowtype;
  v_match public.party_matches%rowtype;
  v_round public.party_rounds%rowtype;
  v_challenge public.party_challenges%rowtype;
begin
  if p_room_id is null or p_bet_id is null then
    raise exception using errcode = '22023', message = 'INVALID_BET_MOVE';
  end if;

  select *
  into v_room
  from public.rooms
  where id = p_room_id
  for update;

  if not found or v_room.game_mode <> 'party' then
    raise exception using errcode = 'P0002', message = 'PARTY_ROOM_NOT_FOUND';
  end if;

  select *
  into v_me
  from public.players p
  where p.room_id = p_room_id
    and p.auth_user_id = (select auth.uid())
  order by p.joined_at desc
  limit 1;

  if not found then
    raise exception using errcode = '42501', message = 'ROOM_MEMBERSHIP_REQUIRED';
  end if;

  select *
  into v_match
  from public.party_matches
  where room_id = p_room_id
  for update;

  if not found then
    raise exception using errcode = 'P0001', message = 'PARTY_MATCH_NOT_STARTED';
  end if;

  select *
  into v_round
  from public.party_rounds
  where room_id = p_room_id
    and round_number = v_room.current_round
  for update;

  if not found then
    raise exception using errcode = 'P0001', message = 'PARTY_ROUND_STATE_MISMATCH';
  end if;

  select *
  into v_challenge
  from public.party_challenges
  where id = v_round.challenge_id;

  if not found or v_challenge.challenge_type <> 'poll' then
    raise exception using errcode = 'P0001', message = 'PARTY_POLL_CHALLENGE_REQUIRED';
  end if;

  if v_round.phase <> 'betting' then
    raise exception using errcode = 'P0001', message = 'BETTING_WINDOW_CLOSED';
  end if;

  if v_round.phase_ends_at is null then
    raise exception using errcode = 'P0001', message = 'BETTING_DEADLINE_MISSING';
  end if;

  if statement_timestamp() >= v_round.phase_ends_at then
    raise exception using errcode = 'P0001', message = 'BETTING_WINDOW_CLOSED';
  end if;

  delete from public.party_bets
  where id = p_bet_id
    and room_id = p_room_id
    and round_number = v_room.current_round
    and player_id = v_me.id;

  return public.get_party_poll_snapshot_v1(p_room_id);
end;
$$;

revoke all on function public.move_party_poll_bet_v1(
  uuid,
  uuid,
  uuid,
  double precision,
  double precision
) from public, anon, authenticated;

grant execute on function public.move_party_poll_bet_v1(
  uuid,
  uuid,
  uuid,
  double precision,
  double precision
) to authenticated;

revoke all on function public.remove_party_poll_bet_v1(
  uuid,
  uuid
) from public, anon, authenticated;

grant execute on function public.remove_party_poll_bet_v1(
  uuid,
  uuid
) to authenticated;

notify pgrst, 'reload schema';

commit;