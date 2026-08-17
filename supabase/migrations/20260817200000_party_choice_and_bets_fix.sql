-- Complete fix for Party mode:
-- 1. Bet RPCs: place_party_bet_v1, move_party_bet_v1, remove_party_bet_v1 (robust slot, bankroll fallback, NO is_connected checks).
-- 2. Choice Mode: submit_party_choice_v1 & begin_party_choice_v1 (performer can submit choice anytime, auto-advances to reveal).
-- 3. 1v1 / Versus: text replaces {witness}/{opponent} with real challenger name.
-- 4. Result Confirmation: confirm_party_result_v1 & dispute_party_result_v1 for all challenge types.
-- 5. get_party_snapshot_v1: returns all visible bets, full scores, and resolved challenge text.

alter table public.party_bets drop constraint if exists party_bets_slot_valid;
alter table public.party_bets add constraint party_bets_slot_valid check (slot_index between 0 and 7);

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
  v_challenge public.party_challenges%rowtype;
  v_bet public.party_bets%rowtype;
  v_total integer;
  v_score integer;
begin
  if p_chips not between 1 and 1000 or p_client_action_id is null then
    raise exception using errcode = '22023', message = 'Invalid bet';
  end if;
  if (p_position_x is not null and p_position_x not between 0 and 1)
     or (p_position_y is not null and p_position_y not between 0 and 1) then
    raise exception using errcode = '22023', message = 'Invalid bet position';
  end if;

  select * into v_room from public.rooms where id = p_room_id;
  if not found or v_room.game_mode <> 'party' then
    raise exception using errcode = 'P0002', message = 'Party room not found';
  end if;

  select * into v_player
  from public.players
  where room_id = p_room_id
    and auth_user_id = (select auth.uid())
  order by joined_at desc limit 1;

  if v_player.id is null then
    raise exception using errcode = '42501', message = 'Room membership required';
  end if;

  select * into v_round
  from public.party_rounds
  where room_id = p_room_id and round_number = v_room.current_round;
  select * into v_challenge
  from public.party_challenges where id = v_round.challenge_id;

  -- 1. Idempotency: Return existing bet if already placed
  select * into v_bet
  from public.party_bets
  where room_id = p_room_id
    and round_number = v_room.current_round
    and player_id = v_player.id
    and client_action_id = p_client_action_id;

  if v_bet.id is not null then
    return to_jsonb(v_bet);
  end if;

  -- 2. Phase check: with 10-second network grace buffer
  if v_round.phase <> 'betting'
     or (v_round.phase_ends_at is not null
         and v_round.phase_ends_at + interval '10 seconds' < statement_timestamp()) then
    return null;
  end if;

  -- 3. Performer check
  if v_player.id = v_round.performer_id and v_challenge.challenge_type not in ('showdown', 'versus') then
    raise exception using errcode = '42501', message = 'Performer cannot bet';
  end if;

  -- 4. Slot index validation
  if p_slot_index not between 0 and 7 then
    raise exception using errcode = '22023', message = 'Invalid bet slot';
  end if;

  -- 5. Score check with 15 bankroll fallback
  select score into v_score
  from public.party_scores
  where room_id = p_room_id and player_id = v_player.id
  for update;

  v_score := greatest(15, coalesce(v_score, v_player.bank_score, 15));

  select coalesce(sum(chips), 0) into v_total
  from public.party_bets
  where room_id = p_room_id
    and round_number = v_room.current_round
    and player_id = v_player.id;

  if v_total + p_chips > v_score then
    raise exception using errcode = '22003', message = 'Insufficient score';
  end if;

  -- 6. Insert / upsert the bet
  insert into public.party_bets (
    room_id, round_number, player_id, slot_index, chips,
    client_action_id, position_x, position_y
  ) values (
    p_room_id, v_room.current_round, v_player.id, p_slot_index, p_chips,
    p_client_action_id, p_position_x, p_position_y
  )
  on conflict (room_id, round_number, player_id, client_action_id) do update
    set slot_index = excluded.slot_index,
        chips = excluded.chips,
        position_x = excluded.position_x,
        position_y = excluded.position_y
  returning * into v_bet;

  update public.party_matches
  set state_version = state_version + 1
  where room_id = p_room_id;

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
  v_challenge public.party_challenges%rowtype;
  v_bet public.party_bets%rowtype;
begin
  if (p_position_x is not null and p_position_x not between 0 and 1)
     or (p_position_y is not null and p_position_y not between 0 and 1) then
    raise exception using errcode = '22023', message = 'Invalid bet position';
  end if;

  select * into v_room from public.rooms where id = p_room_id;
  select * into v_player
  from public.players
  where room_id = p_room_id
    and auth_user_id = (select auth.uid())
  order by joined_at desc limit 1;

  if v_player.id is null then
    raise exception using errcode = '42501', message = 'Room membership required';
  end if;

  select * into v_round
  from public.party_rounds
  where room_id = p_room_id and round_number = v_room.current_round;
  select * into v_challenge
  from public.party_challenges where id = v_round.challenge_id;

  if v_round.phase <> 'betting'
     or (v_round.phase_ends_at is not null
         and v_round.phase_ends_at + interval '10 seconds' < statement_timestamp()) then
    return null;
  end if;

  if p_slot_index not between 0 and 7 then
    raise exception using errcode = '22023', message = 'Invalid bet slot';
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

  update public.party_matches
  set state_version = state_version + 1 where room_id = p_room_id;
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
  select * into v_player
  from public.players
  where room_id = p_room_id
    and auth_user_id = (select auth.uid())
  order by joined_at desc limit 1;

  if v_player.id is null then
    raise exception using errcode = '42501', message = 'Room membership required';
  end if;

  select * into v_round
  from public.party_rounds
  where room_id = p_room_id and round_number = v_room.current_round;

  if v_round.phase <> 'betting'
     or (v_round.phase_ends_at is not null
         and v_round.phase_ends_at + interval '10 seconds' < statement_timestamp()) then
    return null;
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

  update public.party_matches
  set state_version = state_version + 1 where room_id = p_room_id;
  return to_jsonb(v_bet);
end;
$$;

-- Choice Mode Functions:
create or replace function public.submit_party_choice_v1(
  p_room_id uuid,
  p_choice integer
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
  v_challenge public.party_challenges%rowtype;
  v_betting_closed boolean;
begin
  if p_choice not between 0 and 1 then
    raise exception using errcode = '22023', message = 'Invalid choice';
  end if;

  select * into v_room from public.rooms where id = p_room_id for update;
  select * into v_round
  from public.party_rounds
  where room_id = p_room_id and round_number = v_room.current_round
  for update;

  select * into v_player
  from public.players
  where room_id = p_room_id
    and auth_user_id = (select auth.uid())
  order by joined_at desc limit 1;

  select * into v_challenge
  from public.party_challenges where id = v_round.challenge_id;

  if v_player.id is null or v_player.id <> v_round.performer_id then
    raise exception using errcode = '42501', message = 'Performer access required';
  end if;

  if v_round.phase = 'reveal' and v_round.proposed_result = p_choice then
    return public.get_party_snapshot_v1(p_room_id);
  end if;

  update public.party_rounds
  set proposed_result = p_choice,
      result_submitted_by = v_player.id
  where id = v_round.id;

  update public.party_matches
  set state_version = state_version + 1
  where room_id = p_room_id;

  -- If betting timer has elapsed, settle immediately into reveal
  v_betting_closed :=
    v_round.phase_ends_at is not null
    and v_round.phase_ends_at <= statement_timestamp();

  if v_betting_closed then
    return public.begin_party_choice_v1(p_room_id);
  end if;

  return public.get_party_snapshot_v1(p_room_id);
end;
$$;

create or replace function public.begin_party_choice_v1(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room public.rooms%rowtype;
  v_round public.party_rounds%rowtype;
  v_challenge public.party_challenges%rowtype;
  v_winning_slot integer;
  v_performer_bonus integer := 30;
begin
  select * into v_room from public.rooms where id = p_room_id for update;
  select * into v_round
  from public.party_rounds
  where room_id = p_room_id and round_number = v_room.current_round
  for update;
  select * into v_challenge from public.party_challenges where id = v_round.challenge_id;

  if v_round.phase = 'reveal' then
    return public.get_party_snapshot_v1(p_room_id);
  end if;

  -- Stay on betting phase if performer hasn't answered yet
  if v_round.proposed_result is null then
    return public.get_party_snapshot_v1(p_room_id);
  end if;

  v_winning_slot := v_round.proposed_result;

  -- Settle bets directly:
  update public.party_bets
  set won = (slot_index = v_winning_slot)
  where room_id = p_room_id and round_number = v_room.current_round;

  -- Payouts for winners (2x for 2-option choice board)
  update public.party_scores ps
  set score = ps.score + (
    coalesce((
      select sum(bet.chips * 2)
      from public.party_bets bet
      where bet.room_id = p_room_id
        and bet.round_number = v_room.current_round
        and bet.player_id = ps.player_id
        and bet.slot_index = v_winning_slot
    ), 0)
    -
    coalesce((
      select sum(bet.chips)
      from public.party_bets bet
      where bet.room_id = p_room_id
        and bet.round_number = v_room.current_round
        and bet.player_id = ps.player_id
    ), 0)
  ) + case when ps.player_id = v_round.performer_id then v_performer_bonus else 0 end
  where ps.room_id = p_room_id;

  update public.party_rounds
  set phase = 'reveal',
      performer_bonus = v_performer_bonus,
      phase_started_at = statement_timestamp(),
      phase_ends_at = statement_timestamp() + interval '8 seconds'
  where id = v_round.id;

  update public.rooms
  set round_phase = 'partyReveal',
      phase_started_at = statement_timestamp(),
      phase_ends_at = statement_timestamp() + interval '8 seconds'
  where id = p_room_id;

  update public.party_matches
  set state_version = state_version + 1
  where room_id = p_room_id;

  return public.get_party_snapshot_v1(p_room_id);
end;
$$;

-- Result Confirmation & Dispute Functions:
create or replace function public.dispute_party_result_v1(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room public.rooms%rowtype;
  v_round public.party_rounds%rowtype;
  v_player public.players%rowtype;
  v_challenge public.party_challenges%rowtype;
begin
  select * into v_room from public.rooms where id = p_room_id for update;
  select * into v_round
  from public.party_rounds
  where room_id = p_room_id and round_number = v_room.current_round
  for update;

  select * into v_player
  from public.players
  where room_id = p_room_id
    and auth_user_id = (select auth.uid())
  order by joined_at desc limit 1;

  select * into v_challenge
  from public.party_challenges where id = v_round.challenge_id;

  if v_player.id is null then
    raise exception using errcode = '42501', message = 'Room membership required';
  end if;

  if v_challenge.challenge_type = 'choice' then
    raise exception using errcode = '42501', message = 'Performer choice cannot be disputed';
  end if;

  if v_round.phase = 'resultEntry' and v_round.proposed_result is null then
    return public.get_party_snapshot_v1(p_room_id);
  end if;

  -- Revert to result entry so host can re-enter
  update public.party_rounds
  set phase = 'resultEntry',
      proposed_result = null,
      result_submitted_by = null,
      phase_started_at = statement_timestamp(),
      phase_ends_at = null
  where id = v_round.id;

  update public.rooms
  set round_phase = 'partyResultEntry',
      phase_started_at = statement_timestamp(),
      phase_ends_at = null
  where id = p_room_id;

  update public.party_matches
  set state_version = state_version + 1
  where room_id = p_room_id;

  return public.get_party_snapshot_v1(p_room_id);
end;
$$;

create or replace function public.confirm_party_result_v1(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room public.rooms%rowtype;
  v_round public.party_rounds%rowtype;
  v_player public.players%rowtype;
  v_challenge public.party_challenges%rowtype;
  v_match public.party_matches%rowtype;
  v_boundaries bigint[];
  v_winning_slot integer;
  v_performer_bonus integer := 0;
begin
  select * into v_room from public.rooms where id = p_room_id for update;
  select * into v_round
  from public.party_rounds
  where room_id = p_room_id and round_number = v_room.current_round
  for update;

  select * into v_match from public.party_matches where room_id = p_room_id;
  select * into v_challenge from public.party_challenges where id = v_round.challenge_id;

  if v_round.phase = 'reveal' then
    return public.get_party_snapshot_v1(p_room_id);
  end if;

  if v_round.proposed_result is null then
    raise exception using errcode = '40001', message = 'No result entered yet';
  end if;

  -- Determine winning slot and performer bonus by challenge type
  if v_challenge.challenge_type in ('choice', 'versus') then
    v_winning_slot := v_round.proposed_result;
    v_performer_bonus := 30;
  elsif v_challenge.challenge_type = 'binary' then
    v_winning_slot := v_round.proposed_result;
    v_performer_bonus := case
      when v_round.proposed_result = 1 then coalesce(v_challenge.performer_success_bonus, 30)
      else 0
    end;
  elsif v_challenge.challenge_type = 'showdown' then
    v_winning_slot := v_round.proposed_result;
    v_performer_bonus := 30;
  elsif v_challenge.challenge_type = 'attempt' then
    v_winning_slot := case v_round.proposed_result
      when 1 then 0 when 2 then 1 when 3 then 2
      when 4 then 3 when 5 then 3 else 4
    end;
    v_performer_bonus := case v_round.proposed_result
      when 1 then 60 when 2 then 45 when 3 then 30
      when 4 then 15 when 5 then 15 else 0
    end;
  else
    v_boundaries := public.party_board_boundaries_v1(p_room_id, v_room.current_round);
    v_winning_slot := case
      when v_round.proposed_result < v_boundaries[1] then 0
      when v_round.proposed_result < v_boundaries[2] then 1
      when v_round.proposed_result <= v_boundaries[3] then 2
      when v_round.proposed_result <= v_boundaries[4] then 3
      else 4
    end;
    v_performer_bonus := case
      when v_challenge.result_direction = 'lower'
        then (array[60, 45, 30, 15, 0])[v_winning_slot + 1]
      else (array[0, 15, 30, 45, 60])[v_winning_slot + 1]
    end;
  end if;

  -- Mark winning bets
  update public.party_bets
  set won = (slot_index = v_winning_slot)
  where room_id = p_room_id and round_number = v_room.current_round;

  -- Calculate payouts
  update public.party_scores ps
  set score = ps.score + (
    coalesce((
      select sum(
        bet.chips * case
          when v_challenge.challenge_type in ('binary', 'choice', 'versus') then 2
          when v_challenge.challenge_type = 'showdown' then greatest(2, cardinality(v_match.turn_order))
          else (array[4, 3, 2, 3, 4])[bet.slot_index + 1]
        end
      )
      from public.party_bets bet
      where bet.room_id = p_room_id
        and bet.round_number = v_room.current_round
        and bet.player_id = ps.player_id
        and bet.slot_index = v_winning_slot
    ), 0)
    -
    coalesce((
      select sum(bet.chips)
      from public.party_bets bet
      where bet.room_id = p_room_id
        and bet.round_number = v_room.current_round
        and bet.player_id = ps.player_id
    ), 0)
  ) + case when ps.player_id = v_round.performer_id then v_performer_bonus else 0 end
  where ps.room_id = p_room_id;

  update public.party_rounds
  set phase = 'reveal',
      performer_bonus = v_performer_bonus,
      phase_started_at = statement_timestamp(),
      phase_ends_at = statement_timestamp() + interval '8 seconds'
  where id = v_round.id;

  update public.rooms
  set round_phase = 'partyReveal',
      phase_started_at = statement_timestamp(),
      phase_ends_at = statement_timestamp() + interval '8 seconds'
  where id = p_room_id;

  update public.party_matches
  set state_version = state_version + 1
  where room_id = p_room_id;

  return public.get_party_snapshot_v1(p_room_id);
end;
$$;

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
  v_prompt_text text;
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

  -- Replace {player} with performer name and {witness}/{opponent} with opponent name
  v_prompt_text := replace(
    replace(
      replace(v_challenge.prompt_template, '{player}', coalesce(v_performer.name, 'Player')),
      '{witness}', coalesce(v_witness.name, 'Opponent')
    ),
    '{opponent}', coalesce(v_witness.name, 'Opponent')
  );

  -- All bets in the room and round are returned with player_id unconditionally
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
        'text', v_prompt_text,
        'rules', v_challenge.rules,
        'answer_unit', v_challenge.answer_unit,
        'duration_seconds', v_challenge.duration_seconds,
        'max_result', v_challenge.max_result,
        'bet_boundaries', coalesce(to_jsonb(v_challenge.bet_boundaries), '[]'::jsonb),
        'challenge_type', v_challenge.challenge_type,
        'category', v_challenge.category,
        'result_direction', v_challenge.result_direction,
        'required_items', coalesce(to_jsonb(v_challenge.required_items), '[]'::jsonb),
        'option_a', v_challenge.option_a,
        'option_b', v_challenge.option_b,
        'performer_success_bonus', v_challenge.performer_success_bonus
      ),
      'submitted_guess_count', 0,
      'performer_ready', v_round.performer_ready_at is not null,
      'own_guess', null,
      'guesses', '[]'::jsonb,
      'bets', v_bets,
      'proposed_result', case when v_show_result then v_round.proposed_result else null end,
      'performer_bonus', case when v_round.phase = 'reveal' then v_round.performer_bonus else 0 end
    ),
    'scores', v_scores
  );
end;
$$;
