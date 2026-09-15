do $migration$
declare
  v_place_oid regprocedure := 'public.place_party_poll_bet_v1(uuid,uuid,integer,uuid,double precision,double precision)'::regprocedure;
  v_move_oid regprocedure := 'public.move_party_poll_bet_v1(uuid,uuid,uuid,double precision,double precision)'::regprocedure;
  v_snapshot_oid regprocedure := 'public.get_party_poll_snapshot_v1(uuid)'::regprocedure;
  v_settle_oid regprocedure := 'public.settle_party_poll_round_v1(uuid)'::regprocedure;
  v_def text;
  v_next text;
  v_start integer;
  v_end integer;
  v_weighted text := $weighted$
  -- Chip-weighted voting: each chip contributes its face value to the target.
  -- Multiple chips on the same target accumulate, regardless of bettor.
  WITH target_chip_totals AS (
    SELECT
      coalesce(b.target_player_id, v_match.turn_order[b.slot_index + 1]) AS target_player_id,
      sum(b.chips) AS total_chip_weight
    FROM public.party_bets b
    WHERE b.room_id = p_room_id
      AND b.round_number = v_room.current_round
      AND coalesce(b.target_player_id, v_match.turn_order[b.slot_index + 1]) IS NOT NULL
    GROUP BY coalesce(b.target_player_id, v_match.turn_order[b.slot_index + 1])
  ),
  max_weight AS (
    SELECT max(total_chip_weight) AS max_chip_weight
    FROM target_chip_totals
  )
  SELECT coalesce(
    array_agg(totals.target_player_id ORDER BY totals.target_player_id),
    '{}'::uuid[]
  )
  INTO v_winning_player_ids
  FROM target_chip_totals totals
  CROSS JOIN max_weight winner
  WHERE totals.total_chip_weight = winner.max_chip_weight;

$weighted$;
begin
  select pg_get_functiondef(v_place_oid) into v_def;
  v_next := replace(v_def, 'if p_chips is null or p_chips not in (5, 10, 25) then', 'if p_chips is null or p_chips not in (5, 10, 20) then');
  v_next := replace(v_next, 'if v_other_target_count >= 2 then', 'if v_other_target_count >= 3 then');
  v_next := replace(v_next, 'POLL_MAX_TWO_TARGETS', 'POLL_MAX_THREE_TARGETS');
  v_next := replace(v_next, 'v_limit := 40;', 'v_limit := 35;');
  if v_next <> v_def then execute v_next; end if;

  select pg_get_functiondef(v_move_oid) into v_def;
  v_next := replace(v_def, 'if v_other_target_count >= 2 then', 'if v_other_target_count >= 3 then');
  v_next := replace(v_next, 'POLL_MAX_TWO_TARGETS', 'POLL_MAX_THREE_TARGETS');
  if v_next <> v_def then execute v_next; end if;

  select pg_get_functiondef(v_snapshot_oid) into v_def;
  v_next := replace(v_def, 'v_limit integer := 40;', 'v_limit integer := 35;');
  v_next := replace(v_next, 'v_limit := 40;', 'v_limit := 35;');
  if v_next <> v_def then execute v_next; end if;

  select pg_get_functiondef(v_settle_oid) into v_def;
  if position('  -- Legacy/native-compatible confidence voting:' in v_def) > 0 then
    v_start := position('  -- Legacy/native-compatible confidence voting:' in v_def);
    v_end := position('  SELECT coalesce(min(array_position' in v_def);
    if v_end = 0 or v_end <= v_start then
      raise exception 'settle_party_poll_round_v1 legacy block end marker not found';
    end if;
    v_next := substring(v_def from 1 for v_start - 1) || v_weighted || substring(v_def from v_end);
    execute v_next;
  elsif position('  -- Chip-weighted voting:' in v_def) = 0 then
    raise exception 'settle_party_poll_round_v1 is in an unknown voting state';
  end if;

  update public.party_challenges
  set rules = 'Use each of your 5, 10, and 20 chips at most once across up to three players. Chip value is voting weight; the highest total chip weight wins.'
  where enabled = true and challenge_type = 'poll';
end;
$migration$;