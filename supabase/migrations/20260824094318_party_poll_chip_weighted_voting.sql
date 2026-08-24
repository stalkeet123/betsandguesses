-- Party Poll weighted chip voting. New migration; historical migrations stay immutable.
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

  return public.get_party_poll_snapshot_v1(p_room_id);
end;
$$;

CREATE OR REPLACE FUNCTION public.settle_party_poll_round_v1(p_room_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_room public.rooms%rowtype;
  v_match public.party_matches%rowtype;
  v_round public.party_rounds%rowtype;
  v_me public.players%rowtype;
  v_challenge public.party_challenges%rowtype;
  v_winning_player_ids uuid[] := '{}'::uuid[];
  v_proposed_slot integer := 0;
BEGIN
  SELECT * INTO v_room
  FROM public.rooms
  WHERE id = p_room_id
  FOR UPDATE;

  IF NOT FOUND OR v_room.game_mode <> 'party' THEN
    RAISE EXCEPTION USING errcode = 'P0002', message = 'PARTY_ROOM_NOT_FOUND';
  END IF;

  SELECT * INTO v_me
  FROM public.players p
  WHERE p.room_id = p_room_id
    AND p.auth_user_id = (SELECT auth.uid())
  ORDER BY p.joined_at DESC
  LIMIT 1;

  IF v_me.id IS NULL THEN
    RAISE EXCEPTION USING errcode = '42501', message = 'ROOM_MEMBERSHIP_REQUIRED';
  END IF;

  SELECT * INTO v_match
  FROM public.party_matches
  WHERE room_id = p_room_id
  FOR UPDATE;

  IF v_match.room_id IS NULL THEN
    RAISE EXCEPTION USING errcode = 'P0001', message = 'PARTY_MATCH_NOT_STARTED';
  END IF;

  SELECT * INTO v_round
  FROM public.party_rounds
  WHERE room_id = p_room_id
    AND round_number = v_room.current_round
  FOR UPDATE;

  IF v_round.id IS NULL THEN
    RAISE EXCEPTION USING errcode = 'P0001', message = 'PARTY_ROUND_STATE_MISMATCH';
  END IF;

  IF v_round.phase = 'reveal' THEN
    RETURN public.get_party_poll_snapshot_v1(p_room_id);
  END IF;

  IF v_round.phase <> 'betting' THEN
    RAISE EXCEPTION USING errcode = 'P0001', message = 'PARTY_POLL_INVALID_PHASE';
  END IF;

  IF v_round.phase_ends_at IS NULL THEN
    RAISE EXCEPTION USING errcode = 'P0001', message = 'BETTING_DEADLINE_MISSING';
  END IF;

  IF statement_timestamp() < v_round.phase_ends_at THEN
    RAISE EXCEPTION USING errcode = 'P0001', message = 'BETTING_WINDOW_OPEN';
  END IF;

  SELECT * INTO v_challenge
  FROM public.party_challenges
  WHERE id = v_round.challenge_id;

  IF v_challenge.id IS NULL OR v_challenge.challenge_type <> 'poll' THEN
    RAISE EXCEPTION USING errcode = 'P0001', message = 'PARTY_POLL_CHALLENGE_REQUIRED';
  END IF;

  WITH target_vote_totals AS (
    SELECT
      coalesce(
        b.target_player_id,
        v_match.turn_order[b.slot_index + 1]
      ) AS target_player_id,
      sum(b.chips) AS total_chip_weight
    FROM public.party_bets b
    WHERE b.room_id = p_room_id
      AND b.round_number = v_room.current_round
      AND coalesce(
        b.target_player_id,
        v_match.turn_order[b.slot_index + 1]
      ) IS NOT NULL
    GROUP BY coalesce(
      b.target_player_id,
      v_match.turn_order[b.slot_index + 1]
    )
  ),
  max_vote AS (
    SELECT max(total_chip_weight) AS max_chip_weight
    FROM target_vote_totals
  )
  SELECT coalesce(
    array_agg(totals.target_player_id ORDER BY totals.target_player_id),
    '{}'::uuid[]
  )
  INTO v_winning_player_ids
  FROM target_vote_totals totals
  CROSS JOIN max_vote winner
  WHERE totals.total_chip_weight = winner.max_chip_weight;

  SELECT coalesce(min(array_position(v_match.turn_order, winner_id) - 1), 0)
  INTO v_proposed_slot
  FROM unnest(v_winning_player_ids) AS winners(winner_id);

  UPDATE public.party_bets b
  SET won = (
    coalesce(
      b.target_player_id,
      v_match.turn_order[b.slot_index + 1]
    ) = ANY(v_winning_player_ids)
  )
  WHERE b.room_id = p_room_id
    AND b.round_number = v_room.current_round;

  UPDATE public.party_scores score_row
  SET score = score_row.score + coalesce((
    SELECT sum(
      CASE
        WHEN coalesce(
          b.target_player_id,
          v_match.turn_order[b.slot_index + 1]
        ) = ANY(v_winning_player_ids) THEN b.chips
        ELSE -b.chips
      END
    )
    FROM public.party_bets b
    WHERE b.room_id = p_room_id
      AND b.round_number = v_room.current_round
      AND b.player_id = score_row.player_id
  ), 0)
  WHERE score_row.room_id = p_room_id;

  UPDATE public.party_rounds
  SET phase = 'reveal',
      proposed_result = v_proposed_slot,
      result_submitted_by = v_me.id,
      result_confirmed_by = v_me.id,
      settled_at = statement_timestamp(),
      phase_started_at = statement_timestamp(),
      phase_ends_at = statement_timestamp() + interval '8 seconds'
  WHERE id = v_round.id;

  UPDATE public.rooms
  SET round_phase = 'partyReveal',
      phase_started_at = statement_timestamp(),
      phase_ends_at = statement_timestamp() + interval '8 seconds'
  WHERE id = p_room_id;

  UPDATE public.party_matches
  SET state_version = state_version + 1
  WHERE room_id = p_room_id;

  RETURN public.get_party_poll_snapshot_v1(p_room_id);
END;
$function$;
REVOKE ALL ON FUNCTION public.place_party_poll_bet_v1(
  uuid, uuid, integer, uuid, double precision, double precision
) FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.place_party_poll_bet_v1(
  uuid, uuid, integer, uuid, double precision, double precision
) TO authenticated;

REVOKE ALL ON FUNCTION public.move_party_poll_bet_v1(
  uuid, uuid, uuid, double precision, double precision
) FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.move_party_poll_bet_v1(
  uuid, uuid, uuid, double precision, double precision
) TO authenticated;

REVOKE ALL ON FUNCTION public.settle_party_poll_round_v1(uuid)
FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.settle_party_poll_round_v1(uuid)
TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;