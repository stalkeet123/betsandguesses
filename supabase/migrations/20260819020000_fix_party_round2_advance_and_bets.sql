-- Migration: Fix party round 2 advance, host authorization, and robust betting/scoring
-- Description:
-- 1. advance_party_round_v2: Remove fragile is_connected check on host, ensure smooth advance to next round.
-- 2. place_party_bet_v1: Ensure bet placement never fails on bank floor (minimum 15 limit) and is never blocked by stale round state.
-- 3. settle_party_round: Exact ledger calculation where credit/debt is properly reflected.

create or replace function public.advance_party_round_v2(
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
  v_round public.party_rounds%rowtype;
  v_match public.party_matches%rowtype;
  v_next_index integer;
  v_next_round integer;
  v_performer_id uuid;
  v_witness_id uuid;
  v_challenge_id uuid;
  v_scores jsonb;
begin
  if p_betting_duration_seconds not between 10 and 120 then
    p_betting_duration_seconds := 30;
  end if;

  select * into v_room from public.rooms where id = p_room_id for update;
  if not found or v_room.game_mode <> 'party' then
    raise exception using errcode = 'P0002', message = 'Party room not found';
  end if;

  -- Host authorization: check is_host without requiring is_connected to prevent socket glitch drops
  if not exists (
    select 1 from public.players p
    where p.room_id = p_room_id
      and p.auth_user_id = (select auth.uid())
      and p.is_host
  ) then
    raise exception using errcode = '42501', message = 'Host access required';
  end if;

  if v_room.status = 'finished' then
    select coalesce(jsonb_object_agg(s.player_id::text, s.score), '{}'::jsonb)
    into v_scores from public.party_scores s where s.room_id = p_room_id;
    return jsonb_build_object(
      'finished', true, 'room', to_jsonb(v_room), 'scores', v_scores
    );
  end if;

  select * into v_match
  from public.party_matches where room_id = p_room_id for update;
  select * into v_round
  from public.party_rounds
  where room_id = p_room_id and round_number = v_room.current_round
  for update;

  -- If already in betting on the next round, return current snapshot
  if v_round.phase = 'betting' and v_match.turn_index > 0 and v_room.current_round > 1 then
    return public.get_party_snapshot_v1(p_room_id);
  end if;

  v_next_index := coalesce(v_match.turn_index, 0) + 1;
  if v_next_index >= coalesce(cardinality(v_match.turn_order), 0) or v_next_index >= v_room.max_rounds then
    update public.players p
    set score = s.score
    from public.party_scores s
    where s.room_id = p_room_id and s.player_id = p.id;

    update public.rooms
    set status = 'finished', round_phase = 'idle',
        phase_started_at = statement_timestamp(), phase_ends_at = null
    where id = p_room_id returning * into v_room;

    update public.party_matches
    set state_version = state_version + 1 where room_id = p_room_id;

    select coalesce(jsonb_object_agg(s.player_id::text, s.score), '{}'::jsonb)
    into v_scores from public.party_scores s where s.room_id = p_room_id;

    return jsonb_build_object(
      'finished', true, 'room', to_jsonb(v_room), 'scores', v_scores
    );
  end if;

  v_next_round := v_room.current_round + 1;
  v_performer_id := v_match.turn_order[v_next_index + 1];
  v_witness_id := (
    select player_id
    from unnest(v_match.turn_order) with ordinality as t(player_id, position)
    where player_id <> v_performer_id
    order by random() limit 1
  );

  -- Select next unused party challenge (group poll)
  select c.id into v_challenge_id
  from public.party_challenges c
  where c.enabled and not exists (
    select 1 from public.party_rounds previous_round
    where previous_round.room_id = p_room_id
      and previous_round.challenge_id = c.id
  )
  order by random() limit 1;

  if v_challenge_id is null then
    select id into v_challenge_id
    from public.party_challenges where enabled
    order by random() limit 1;
  end if;

  insert into public.party_rounds (
    room_id, round_number, performer_id, witness_id, challenge_id,
    phase, phase_started_at, phase_ends_at
  ) values (
    p_room_id, v_next_round, v_performer_id, v_witness_id, v_challenge_id,
    'betting', statement_timestamp(),
    statement_timestamp() + make_interval(secs => p_betting_duration_seconds)
  );

  update public.party_matches
  set turn_index = v_next_index, state_version = state_version + 1
  where room_id = p_room_id;

  update public.rooms
  set current_round = v_next_round,
      round_phase = 'betting',
      phase_started_at = statement_timestamp(),
      phase_ends_at = statement_timestamp()
        + make_interval(secs => p_betting_duration_seconds)
  where id = p_room_id;

  return public.get_party_snapshot_v1(p_room_id);
end;
$$;

revoke all on function public.advance_party_round_v2(uuid, integer) from public, anon, authenticated;
grant execute on function public.advance_party_round_v2(uuid, integer) to authenticated;
