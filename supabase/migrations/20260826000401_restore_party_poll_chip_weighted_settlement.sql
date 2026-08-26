do $migration$
declare
  v_oid regprocedure := 'public.settle_party_poll_round_v1(uuid)'::regprocedure;
  v_def text;
  v_next text;
  v_start integer;
  v_end integer;
  v_weighted text := $weighted$
  -- Chip-weighted voting: each chip contributes its face value to the target.
  -- Multiple chips on the same target accumulate, regardless of bettor.
  WITH target_chip_totals AS (
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
  select pg_get_functiondef(v_oid) into v_def;

  -- Fresh/replayed repo chains can already be weighted because the historical
  -- legacy-compat migration existed in production but is not present locally.
  if position('sum(b.chips) AS total_chip_weight' in v_def) > 0 then
    return;
  end if;

  v_start := position('  -- Legacy/native-compatible confidence voting:' in v_def);
  v_end := position('  SELECT coalesce(min(array_position' in v_def);

  if v_start = 0 or v_end = 0 or v_end <= v_start then
    raise exception 'settle_party_poll_round_v1 voting block was neither weighted nor recognized legacy form';
  end if;

  v_next := substring(v_def from 1 for v_start - 1)
    || v_weighted
    || substring(v_def from v_end);

  execute v_next;
end;
$migration$;
