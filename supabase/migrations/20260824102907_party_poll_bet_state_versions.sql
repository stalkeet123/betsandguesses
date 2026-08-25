-- Monotonic authoritative Party Poll bet snapshots.
BEGIN;

CREATE OR REPLACE FUNCTION public.place_party_poll_bet_v1(
  p_room_id uuid,
  p_target_player_id uuid,
  p_chips integer,
  p_client_action_id uuid,
  p_position_x double precision DEFAULT NULL::double precision,
  p_position_y double precision DEFAULT NULL::double precision
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
declare
  v_room public.rooms%rowtype;
  v_match public.party_matches%rowtype;
  v_round public.party_rounds%rowtype;
  v_me public.players%rowtype;
  v_challenge public.party_challenges%rowtype;
  v_bet public.party_bets%rowtype;

  v_target_position integer;
  v_slot_index integer;

  v_score integer := 0;
  v_limit integer := 0;
  v_total integer := 0;
begin
  if p_target_player_id is null
     or p_client_action_id is null
     then
    raise exception using
      errcode = '22023',
      message = 'INVALID_BET';
  end if;

  if (
    p_position_x is not null
    and p_position_x not between 0 and 1
  ) or (
    p_position_y is not null
    and p_position_y not between 0 and 1
  ) then
    raise exception using
      errcode = '22023',
      message = 'INVALID_BET_POSITION';
  end if;

  -- Room lock serializes command mutations for this match.
  select *
  into v_room
  from public.rooms
  where id = p_room_id
  for update;

  if not found or v_room.game_mode <> 'party' then
    raise exception using
      errcode = 'P0002',
      message = 'PARTY_ROOM_NOT_FOUND';
  end if;

  select *
  into v_me
  from public.players p
  where p.room_id = p_room_id
    and p.auth_user_id = (select auth.uid())
  order by p.joined_at desc
  limit 1;

  if v_me.id is null then
    raise exception using
      errcode = '42501',
      message = 'ROOM_MEMBERSHIP_REQUIRED';
  end if;

  select *
  into v_match
  from public.party_matches
  where room_id = p_room_id
  for update;

  if v_match.room_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'PARTY_MATCH_NOT_STARTED';
  end if;

  -- Idempotency spans rounds.
  --
  -- A delayed retry from Round N must NOT become a new bet in Round N+1.
  select *
  into v_bet
  from public.party_bets b
  where b.room_id = p_room_id
    and b.player_id = v_me.id
    and b.client_action_id = p_client_action_id
  order by b.created_at desc
  limit 1;

  if v_bet.id is not null then
    return jsonb_build_object(
      'bet',
      jsonb_build_object(
        'id', v_bet.id,
        'round_number', v_bet.round_number,
        'player_id', v_bet.player_id,
        'target_player_id',
          coalesce(
            v_bet.target_player_id,
            v_match.turn_order[v_bet.slot_index + 1]
          ),
        'chips', v_bet.chips,
        'client_action_id', v_bet.client_action_id,
        'position_x', v_bet.position_x,
        'position_y', v_bet.position_y,
        'won', v_bet.won
      ),

      'snapshot',
      public.get_party_poll_snapshot_v1(p_room_id)
    );
  end if;

  if p_chips is null or p_chips not in (5, 10, 25) then
    raise exception using
      errcode = '22023',
      message = 'INVALID_PARTY_POLL_CHIP';
  end if;

  select *
  into v_round
  from public.party_rounds
  where room_id = p_room_id
    and round_number = v_room.current_round
  for update;

  if v_round.id is null then
    raise exception using
      errcode = 'P0001',
      message = 'PARTY_ROUND_STATE_MISMATCH';
  end if;

  select *
  into v_challenge
  from public.party_challenges
  where id = v_round.challenge_id;

  if v_challenge.id is null
     or v_challenge.challenge_type <> 'poll' then
    raise exception using
      errcode = 'P0001',
      message = 'PARTY_POLL_CHALLENGE_REQUIRED';
  end if;

  if v_round.phase <> 'betting' then
    raise exception using
      errcode = 'P0001',
      message = 'BETTING_WINDOW_CLOSED';
  end if;

  if v_round.phase_ends_at is null then
    raise exception using
      errcode = 'P0001',
      message = 'BETTING_DEADLINE_MISSING';
  end if;

  if statement_timestamp() >= v_round.phase_ends_at then
    raise exception using
      errcode = 'P0001',
      message = 'BETTING_WINDOW_CLOSED';
  end if;

  -- UUID is authoritative.
  -- Slot is calculated entirely by the database.
  v_target_position :=
    array_position(
      v_match.turn_order,
      p_target_player_id
    );

  if v_target_position is null then
    raise exception using
      errcode = '22023',
      message = 'INVALID_POLL_TARGET';
  end if;

  v_slot_index := v_target_position - 1;

  if v_slot_index < 0 or v_slot_index > 7 then
    raise exception using
      errcode = '22023',
      message = 'INVALID_POLL_TARGET';
  end if;

  if exists (
    select 1
    from public.party_bets b
    where b.room_id = p_room_id
      and b.round_number = v_room.current_round
      and b.player_id = v_me.id
      and b.chips = p_chips
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'POLL_CHIP_ALREADY_USED';
  end if;

  -- Explicit zero. We do NOT rely on the legacy table default of 15.
  insert into public.party_scores (
    room_id,
    player_id,
    score
  )
  values (
    p_room_id,
    v_me.id,
    0
  )
  on conflict (room_id, player_id)
  do nothing;

  select s.score
  into v_score
  from public.party_scores s
  where s.room_id = p_room_id
    and s.player_id = v_me.id
  for update;

  v_score := coalesce(v_score, 0);

  -- Fixed round stake capacity. PROFIT never changes wager capacity.
  v_limit := 40;

  select coalesce(sum(b.chips), 0)
  into v_total
  from public.party_bets b
  where b.room_id = p_room_id
    and b.round_number = v_room.current_round
    and b.player_id = v_me.id;

  if v_total + p_chips > v_limit then
    raise exception using
      errcode = 'P0001',
      message = format(
        'INSUFFICIENT_CHIPS available=%s requested=%s',
        greatest(0, v_limit - v_total),
        p_chips
      );
  end if;

  insert into public.party_bets (
    room_id,
    round_number,
    player_id,
    slot_index,
    target_player_id,
    chips,
    client_action_id,
    position_x,
    position_y
  )
  values (
    p_room_id,
    v_room.current_round,
    v_me.id,
    v_slot_index,
    p_target_player_id,
    p_chips,
    p_client_action_id,
    p_position_x,
    p_position_y
  )
  on conflict (
    room_id,
    round_number,
    player_id,
    client_action_id
  )
  do nothing
  returning *
  into v_bet;

  -- Defensive retry path.
  if v_bet.id is null then
    select *
    into v_bet
    from public.party_bets b
    where b.room_id = p_room_id
      and b.round_number = v_room.current_round
      and b.player_id = v_me.id
      and b.client_action_id = p_client_action_id
    limit 1;
  end if;

  if v_bet.id is null then
    raise exception using
      errcode = 'P0001',
      message = 'BET_INSERT_FAILED';
  end if;

  -- A new authoritative bet must publish a strictly newer snapshot.
  update public.party_matches
  set state_version = state_version + 1
  where room_id = p_room_id;

  return jsonb_build_object(
    'bet',
    jsonb_build_object(
      'id', v_bet.id,
      'round_number', v_bet.round_number,
      'player_id', v_bet.player_id,
      'target_player_id', v_bet.target_player_id,
      'chips', v_bet.chips,
      'client_action_id', v_bet.client_action_id,
      'position_x', v_bet.position_x,
      'position_y', v_bet.position_y,
      'won', v_bet.won
    ),

    'snapshot',
    public.get_party_poll_snapshot_v1(p_room_id)
  );
end;
$function$;


create or replace function public.move_party_poll_bet_v1(
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

  -- The no-op path returns above, so this was a real move.
  update public.party_matches
  set state_version = state_version + 1
  where room_id = p_room_id;

  return public.get_party_poll_snapshot_v1(p_room_id);
end;
$$;


create or replace function public.remove_party_poll_bet_v1(
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
  v_deleted integer := 0;
begin
  if p_room_id is null or p_bet_id is null then
    raise exception using errcode = '22023', message = 'INVALID_BET_MOVE';
  end if;
  select * into v_room from public.rooms where id = p_room_id for update;
  if not found or v_room.game_mode <> 'party' then raise exception using errcode = 'P0002', message = 'PARTY_ROOM_NOT_FOUND'; end if;
  select * into v_me from public.players p where p.room_id = p_room_id and p.auth_user_id = (select auth.uid()) order by p.joined_at desc limit 1;
  if not found then raise exception using errcode = '42501', message = 'ROOM_MEMBERSHIP_REQUIRED'; end if;
  select * into v_match from public.party_matches where room_id = p_room_id for update;
  if not found then raise exception using errcode = 'P0001', message = 'PARTY_MATCH_NOT_STARTED'; end if;
  select * into v_round from public.party_rounds where room_id = p_room_id and round_number = v_room.current_round for update;
  if not found then raise exception using errcode = 'P0001', message = 'PARTY_ROUND_STATE_MISMATCH'; end if;
  select * into v_challenge from public.party_challenges where id = v_round.challenge_id;
  if not found or v_challenge.challenge_type <> 'poll' then raise exception using errcode = 'P0001', message = 'PARTY_POLL_CHALLENGE_REQUIRED'; end if;
  if v_round.phase <> 'betting' then raise exception using errcode = 'P0001', message = 'BETTING_WINDOW_CLOSED'; end if;
  if v_round.phase_ends_at is null then raise exception using errcode = 'P0001', message = 'BETTING_DEADLINE_MISSING'; end if;
  if statement_timestamp() >= v_round.phase_ends_at then raise exception using errcode = 'P0001', message = 'BETTING_WINDOW_CLOSED'; end if;
  delete from public.party_bets where id = p_bet_id and room_id = p_room_id and round_number = v_room.current_round and player_id = v_me.id;
  get diagnostics v_deleted = row_count;
  if v_deleted > 0 then
    update public.party_matches set state_version = state_version + 1 where room_id = p_room_id;
  end if;
  return public.get_party_poll_snapshot_v1(p_room_id);
end;
$$;
REVOKE ALL ON FUNCTION public.place_party_poll_bet_v1(uuid, uuid, integer, uuid, double precision, double precision) FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.place_party_poll_bet_v1(uuid, uuid, integer, uuid, double precision, double precision) TO authenticated;
REVOKE ALL ON FUNCTION public.move_party_poll_bet_v1(uuid, uuid, uuid, double precision, double precision) FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.move_party_poll_bet_v1(uuid, uuid, uuid, double precision, double precision) TO authenticated;
REVOKE ALL ON FUNCTION public.remove_party_poll_bet_v1(uuid, uuid) FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.remove_party_poll_bet_v1(uuid, uuid) TO authenticated;
NOTIFY pgrst, 'reload schema';
COMMIT;