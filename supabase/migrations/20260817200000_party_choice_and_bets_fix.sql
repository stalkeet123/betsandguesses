-- Fix party betting chip visibility and performer choice display:
-- 1. Ensure all placed bets are always visible in party snapshot during betting.
-- 2. Ensure option_a and option_b are always returned to performer and friends.

create or replace function public.get_party_snapshot_v1(p_room_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_room public.rooms%rowtype;
  v_match public.party_matches%rowtype;
  v_round public.party_rounds%rowtype;
  v_me public.players%rowtype;
  v_performer public.players%rowtype;
  v_witness public.players%rowtype;
  v_challenge public.party_challenges%rowtype;
  v_bets jsonb := '[]'::jsonb;
  v_scores jsonb := '{}'::jsonb;
  v_show_result boolean;
begin
  select * into v_room from public.rooms where id = p_room_id;
  if not found or v_room.game_mode <> 'party' then
    raise exception using errcode = 'P0002', message = 'Party room not found';
  end if;

  select * into v_me
  from public.players
  where room_id = p_room_id
    and auth_user_id = (select auth.uid())
    and is_connected
  order by joined_at desc limit 1;
  if v_me.id is null then
    raise exception using errcode = '42501', message = 'Room membership required';
  end if;

  select * into v_match from public.party_matches where room_id = p_room_id;
  if v_match.room_id is null then
    return jsonb_build_object('room', to_jsonb(v_room), 'status', 'waiting');
  end if;

  select * into v_round
  from public.party_rounds
  where room_id = p_room_id and round_number = v_room.current_round;
  select * into v_performer from public.players where id = v_round.performer_id;
  select * into v_witness from public.players where id = v_round.witness_id;
  select * into v_challenge
  from public.party_challenges where id = v_round.challenge_id;

  v_show_result :=
    v_round.phase in ('resultConfirm', 'reveal')
    or (
      v_challenge.challenge_type = 'choice'
      and v_me.id = v_round.performer_id
      and v_round.phase = 'betting'
    );

  -- All bets in the room and round are included so every player sees placed chips
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', bet.id,
        'slot_index', bet.slot_index,
        'chips', bet.chips,
        'position_x', bet.position_x,
        'position_y', bet.position_y,
        'player_id', bet.player_id
      ) order by bet.created_at, bet.id
    ),
    '[]'::jsonb
  ) into v_bets
  from public.party_bets bet
  where bet.room_id = p_room_id
    and bet.round_number = v_room.current_round;

  select coalesce(
    jsonb_object_agg(score.player_id::text, score.score), '{}'::jsonb
  ) into v_scores
  from public.party_scores score
  where score.room_id = p_room_id;

  return jsonb_build_object(
    'room', to_jsonb(v_room),
    'state_version', v_match.state_version,
    'turn_index', v_match.turn_index,
    'turn_count', cardinality(v_match.turn_order),
    'round', jsonb_build_object(
      'number', v_round.round_number,
      'phase', v_round.phase,
      'phase_started_at', v_round.phase_started_at,
      'phase_ends_at', v_round.phase_ends_at,
      'performer', jsonb_build_object(
        'id', v_performer.id,
        'name', v_performer.name,
        'avatar_color', v_performer.avatar_color
      ),
      'witness', case when v_witness.id is null then null else jsonb_build_object(
        'id', v_witness.id,
        'name', v_witness.name,
        'avatar_color', v_witness.avatar_color
      ) end,
      'challenge', jsonb_build_object(
        'id', v_challenge.id,
        'text', replace(v_challenge.prompt_template, '{player}', v_performer.name),
        'rules', v_challenge.rules,
        'answer_unit', v_challenge.answer_unit,
        'duration_seconds', v_challenge.duration_seconds,
        'max_result', v_challenge.max_result,
        'bet_boundaries', v_challenge.bet_boundaries,
        'challenge_type', v_challenge.challenge_type,
        'category', v_challenge.category,
        'result_direction', v_challenge.result_direction,
        'required_items', coalesce(v_challenge.required_items, '{}'::text[]),
        'option_a', v_challenge.option_a,
        'option_b', v_challenge.option_b,
        'performer_success_bonus', v_challenge.performer_success_bonus
      ),
      'proposed_result', case when v_show_result then v_round.proposed_result else null end,
      'result_confirmed', v_round.result_confirmed,
      'performer_ready', v_round.performer_ready,
      'bets', v_bets
    ),
    'scores', v_scores
  );
end;
$$;
