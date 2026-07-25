-- Party Mode supports two manual, permission-free challenge formats:
--   count  -> five authored numeric betting ranges
--   binary -> YES / NO betting, host records success or failure
-- Bettors only observe. The app does not request sensor or microphone access.

alter table public.party_challenges
  add column if not exists challenge_type text not null default 'count',
  add column if not exists duration_seconds integer not null default 60,
  add column if not exists performer_success_bonus integer not null default 3;

alter table public.party_challenges
  alter column bet_boundaries drop not null;

alter table public.party_challenges
  drop constraint if exists party_challenges_type_valid,
  drop constraint if exists party_challenges_duration_valid,
  drop constraint if exists party_challenges_performer_bonus_valid,
  drop constraint if exists party_challenges_bet_boundaries_valid;

alter table public.party_challenges
  add constraint party_challenges_type_valid
    check (challenge_type in ('count', 'binary')),
  add constraint party_challenges_duration_valid
    check (duration_seconds between 5 and 60),
  add constraint party_challenges_performer_bonus_valid
    check (performer_success_bonus between 0 and 20),
  add constraint party_challenges_bet_boundaries_valid check (
    (
      challenge_type = 'count'
      and bet_boundaries is not null
      and cardinality(bet_boundaries) = 4
      and bet_boundaries[1] >= 0
      and bet_boundaries[1] < bet_boundaries[2]
      and bet_boundaries[2] < bet_boundaries[3]
      and bet_boundaries[3] < bet_boundaries[4]
      and bet_boundaries[4] <= max_result
    )
    or (
      challenge_type = 'binary'
      and bet_boundaries is null
      and max_result = 1
    )
  );

insert into public.party_challenges (
  slug,
  prompt_template,
  rules,
  answer_unit,
  max_result,
  bet_boundaries,
  challenge_type,
  duration_seconds,
  performer_success_bonus,
  enabled
) values
  (
    'binary_tongue_twister',
    'Can {player} say "Red leather, yellow leather" three times cleanly?',
    'One attempt. All three repetitions must be complete and clearly spoken without a stumble.',
    'result',
    1,
    null,
    'binary',
    15,
    3,
    true
  ),
  (
    'binary_one_leg_balance',
    'Can {player} balance on one leg for 20 seconds?',
    'The raised foot cannot touch the floor or the standing leg. Keep eyes open and stop if there is pain.',
    'result',
    1,
    null,
    'binary',
    20,
    3,
    true
  ),
  (
    'binary_ten_pushups',
    'Can {player} complete 10 clean push-ups in 20 seconds?',
    'Only complete reps count. Chest lowers and arms return to full extension.',
    'result',
    1,
    null,
    'binary',
    20,
    3,
    true
  ),
  (
    'binary_alphabet_backwards',
    'Can {player} recite the alphabet backwards from Z to A?',
    'One attempt. Every letter must be in order, with no skipped or repeated letters.',
    'result',
    1,
    null,
    'binary',
    30,
    3,
    true
  ),
  (
    'binary_months_backwards',
    'Can {player} name all 12 months backwards from December?',
    'One attempt. Every month must be in reverse order with no skips or corrections.',
    'result',
    1,
    null,
    'binary',
    20,
    3,
    true
  ),
  (
    'binary_count_back_threes',
    'Can {player} count backward from 50 to 20 by threes?',
    'Say 50, then subtract three each time. One mistake or correction fails the attempt.',
    'result',
    1,
    null,
    'binary',
    20,
    3,
    true
  )
on conflict (slug) do update
set prompt_template = excluded.prompt_template,
    rules = excluded.rules,
    answer_unit = excluded.answer_unit,
    max_result = excluded.max_result,
    bet_boundaries = excluded.bet_boundaries,
    challenge_type = excluded.challenge_type,
    duration_seconds = excluded.duration_seconds,
    performer_success_bonus = excluded.performer_success_bonus,
    enabled = excluded.enabled;

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
  v_show_all_bets boolean;
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

  v_show_all_bets := v_round.phase = 'reveal';
  v_show_result := v_round.phase in ('resultConfirm', 'reveal');

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', bet.id,
        'slot_index', bet.slot_index,
        'chips', bet.chips,
        'position_x', bet.position_x,
        'position_y', bet.position_y,
        'player_id', case
          when v_show_all_bets or bet.player_id = v_me.id
            then bet.player_id
          else null
        end
      )
      order by bet.created_at, bet.id
    ) filter (where v_show_all_bets or bet.player_id = v_me.id),
    '[]'::jsonb
  )
  into v_bets
  from public.party_bets bet
  where bet.room_id = p_room_id
    and bet.round_number = v_room.current_round;

  select coalesce(jsonb_object_agg(score.player_id::text, score.score), '{}'::jsonb)
  into v_scores
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
        'name', v_witness.name
      ) end,
      'challenge', jsonb_build_object(
        'id', v_challenge.id,
        'text', replace(v_challenge.prompt_template, '{player}', v_performer.name),
        'rules', v_challenge.rules,
        'answer_unit', v_challenge.answer_unit,
        'duration_seconds', v_challenge.duration_seconds,
        'max_result', v_challenge.max_result,
        'bet_boundaries', coalesce(to_jsonb(v_challenge.bet_boundaries), '[]'::jsonb),
        'challenge_type', v_challenge.challenge_type,
        'performer_success_bonus', v_challenge.performer_success_bonus
      ),
      'submitted_guess_count', 0,
      'performer_ready', v_round.performer_ready_at is not null,
      'own_guess', null,
      'guesses', '[]'::jsonb,
      'bets', v_bets,
      'proposed_result', case
        when v_show_result then v_round.proposed_result else null
      end,
      'performer_bonus', case
        when v_round.phase = 'reveal' then v_round.performer_bonus else 0
      end
    ),
    'scores', v_scores
  );
end;
$$;

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
  select * into v_player
  from public.players
  where room_id = p_room_id
    and auth_user_id = (select auth.uid())
    and is_connected
  order by joined_at desc limit 1;
  select * into v_round
  from public.party_rounds
  where room_id = p_room_id and round_number = v_room.current_round;
  select * into v_challenge
  from public.party_challenges where id = v_round.challenge_id;

  if v_player.id is null then
    raise exception using errcode = '42501', message = 'Room membership required';
  end if;
  if v_player.id = v_round.performer_id then
    raise exception using errcode = '42501', message = 'Performer cannot bet';
  end if;
  if (v_challenge.challenge_type = 'binary' and p_slot_index not between 0 and 1)
     or (v_challenge.challenge_type = 'count' and p_slot_index not between 0 and 4) then
    raise exception using errcode = '22023', message = 'Invalid bet slot';
  end if;
  if v_round.phase <> 'betting'
     or (v_round.phase_ends_at is not null
         and v_round.phase_ends_at < statement_timestamp()) then
    raise exception using errcode = '40001', message = 'Betting phase is closed';
  end if;

  select score into v_score
  from public.party_scores
  where room_id = p_room_id and player_id = v_player.id
  for update;
  select coalesce(sum(chips), 0) into v_total
  from public.party_bets
  where room_id = p_room_id
    and round_number = v_room.current_round
    and player_id = v_player.id;
  if v_total + p_chips > v_score then
    raise exception using errcode = '22023', message = 'Insufficient score';
  end if;

  insert into public.party_bets (
    room_id, round_number, player_id, slot_index, chips,
    client_action_id, position_x, position_y
  ) values (
    p_room_id, v_room.current_round, v_player.id, p_slot_index, p_chips,
    p_client_action_id, p_position_x, p_position_y
  )
  on conflict (room_id, round_number, player_id, client_action_id) do nothing
  returning * into v_bet;
  if v_bet.id is null then
    select * into v_bet
    from public.party_bets
    where room_id = p_room_id
      and round_number = v_room.current_round
      and player_id = v_player.id
      and client_action_id = p_client_action_id;
  else
    update public.party_matches
    set state_version = state_version + 1 where room_id = p_room_id;
  end if;
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
    and is_connected
  order by joined_at desc limit 1;
  select * into v_round
  from public.party_rounds
  where room_id = p_room_id and round_number = v_room.current_round;
  select * into v_challenge
  from public.party_challenges where id = v_round.challenge_id;

  if v_player.id is null then
    raise exception using errcode = '42501', message = 'Room membership required';
  end if;
  if v_player.id = v_round.performer_id then
    raise exception using errcode = '42501', message = 'Performer cannot bet';
  end if;
  if (v_challenge.challenge_type = 'binary' and p_slot_index not between 0 and 1)
     or (v_challenge.challenge_type = 'count' and p_slot_index not between 0 and 4) then
    raise exception using errcode = '22023', message = 'Invalid bet slot';
  end if;
  if v_round.phase <> 'betting'
     or (v_round.phase_ends_at is not null
         and v_round.phase_ends_at < statement_timestamp()) then
    raise exception using errcode = '40001', message = 'Betting phase is closed';
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

create or replace function public.start_party_action_v1(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room public.rooms%rowtype;
  v_round public.party_rounds%rowtype;
  v_duration integer;
begin
  select * into v_room from public.rooms where id = p_room_id for update;
  if not exists (
    select 1 from public.players player
    where player.room_id = p_room_id
      and player.auth_user_id = (select auth.uid())
      and player.is_host
      and player.is_connected
  ) then
    raise exception using errcode = '42501', message = 'Host access required';
  end if;
  select * into v_round
  from public.party_rounds
  where room_id = p_room_id and round_number = v_room.current_round
  for update;
  if v_round.phase = 'action' then
    return public.get_party_snapshot_v1(p_room_id);
  end if;
  if v_round.phase <> 'ready' then
    raise exception using errcode = '40001', message = 'Performance page is not ready';
  end if;
  select duration_seconds into v_duration
  from public.party_challenges where id = v_round.challenge_id;

  update public.party_rounds
  set phase = 'action',
      performer_ready_at = coalesce(performer_ready_at, statement_timestamp()),
      phase_started_at = statement_timestamp(),
      phase_ends_at = statement_timestamp() + make_interval(secs => v_duration)
  where id = v_round.id;
  update public.rooms
  set round_phase = 'partyAction',
      phase_started_at = statement_timestamp(),
      phase_ends_at = statement_timestamp() + make_interval(secs => v_duration)
  where id = p_room_id;
  update public.party_matches
  set state_version = state_version + 1 where room_id = p_room_id;
  return public.get_party_snapshot_v1(p_room_id);
end;
$$;

create or replace function public.submit_party_result_v1(
  p_room_id uuid,
  p_result integer
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room public.rooms%rowtype;
  v_round public.party_rounds%rowtype;
  v_host public.players%rowtype;
  v_challenge public.party_challenges%rowtype;
begin
  select * into v_room from public.rooms where id = p_room_id for update;
  select * into v_host
  from public.players
  where room_id = p_room_id
    and auth_user_id = (select auth.uid())
    and is_host and is_connected
  limit 1;
  if v_host.id is null then
    raise exception using errcode = '42501', message = 'Host access required';
  end if;
  select * into v_round
  from public.party_rounds
  where room_id = p_room_id and round_number = v_room.current_round
  for update;
  select * into v_challenge
  from public.party_challenges where id = v_round.challenge_id;

  if v_round.phase = 'resultConfirm' and v_round.proposed_result = p_result then
    return public.get_party_snapshot_v1(p_room_id);
  end if;
  if v_round.phase <> 'resultEntry' then
    raise exception using errcode = '40001', message = 'Result entry is not active';
  end if;
  if (v_challenge.challenge_type = 'binary' and p_result not between 0 and 1)
     or (v_challenge.challenge_type = 'count'
         and (p_result < 0 or p_result > v_challenge.max_result)) then
    raise exception using errcode = '22023', message = 'Invalid result';
  end if;

  update public.party_rounds
  set phase = 'resultConfirm',
      proposed_result = p_result,
      result_submitted_by = v_host.id,
      phase_started_at = statement_timestamp()
  where id = v_round.id;
  update public.rooms
  set round_phase = 'partyResultConfirm',
      phase_started_at = statement_timestamp()
  where id = p_room_id;
  update public.party_matches
  set state_version = state_version + 1 where room_id = p_room_id;
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
  v_host_id uuid;
  v_required_confirmer uuid;
  v_boundaries bigint[];
  v_winning_slot integer;
  v_performer_bonus integer;
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
    and is_connected
  order by joined_at desc limit 1;
  select * into v_challenge
  from public.party_challenges where id = v_round.challenge_id;
  select id into v_host_id
  from public.players
  where room_id = p_room_id and is_host and is_connected
  order by joined_at limit 1;

  if v_player.id is null then
    raise exception using errcode = '42501', message = 'Room membership required';
  end if;
  if v_round.phase = 'reveal' then
    return public.get_party_snapshot_v1(p_room_id);
  end if;
  if v_round.phase <> 'resultConfirm' or v_round.proposed_result is null then
    raise exception using errcode = '40001', message = 'Result confirmation is not active';
  end if;
  v_required_confirmer := case
    when v_round.performer_id = v_host_id then v_round.witness_id
    else v_round.performer_id
  end;
  if v_player.id <> v_required_confirmer then
    raise exception using errcode = '42501', message = 'Result confirmer access required';
  end if;

  if v_challenge.challenge_type = 'binary' then
    v_winning_slot := v_round.proposed_result;
    v_performer_bonus := case
      when v_round.proposed_result = 1
        then v_challenge.performer_success_bonus
      else 0
    end;
  else
    v_boundaries := public.party_board_boundaries_v1(
      p_room_id, v_room.current_round
    );
    v_winning_slot := case
      when v_round.proposed_result < v_boundaries[1] then 0
      when v_round.proposed_result < v_boundaries[2] then 1
      when v_round.proposed_result <= v_boundaries[3] then 2
      when v_round.proposed_result <= v_boundaries[4] then 3
      else 4
    end;
    v_performer_bonus := (array[0, 1, 2, 3, 5])[v_winning_slot + 1];
  end if;

  update public.party_bets
  set won = slot_index = v_winning_slot
  where room_id = p_room_id and round_number = v_room.current_round;

  update public.party_scores score
  set score = greatest(
    15,
    score.score
      - coalesce((
          select sum(bet.chips)
          from public.party_bets bet
          where bet.room_id = p_room_id
            and bet.round_number = v_room.current_round
            and bet.player_id = score.player_id
        ), 0)
      + coalesce((
          select sum(
            bet.chips * case
              when v_challenge.challenge_type = 'binary' then 2
              else (array[4, 3, 2, 3, 4])[bet.slot_index + 1]
            end
          )
          from public.party_bets bet
          where bet.room_id = p_room_id
            and bet.round_number = v_room.current_round
            and bet.player_id = score.player_id
            and bet.slot_index = v_winning_slot
        ), 0)
  )
  where score.room_id = p_room_id
    and score.player_id <> v_round.performer_id;

  update public.party_scores
  set score = score + v_performer_bonus
  where room_id = p_room_id and player_id = v_round.performer_id;

  update public.party_rounds
  set phase = 'reveal',
      performer_bonus = v_performer_bonus,
      result_confirmed_by = v_player.id,
      settled_at = statement_timestamp(),
      phase_started_at = statement_timestamp(),
      phase_ends_at = statement_timestamp() + interval '7 seconds'
  where id = v_round.id and settled_at is null;
  update public.rooms
  set round_phase = 'revealAnswer',
      phase_started_at = statement_timestamp(),
      phase_ends_at = statement_timestamp() + interval '7 seconds'
  where id = p_room_id;
  update public.party_matches
  set state_version = state_version + 1 where room_id = p_room_id;
  return public.get_party_snapshot_v1(p_room_id);
end;
$$;

create or replace function public.get_party_recap_v1(p_room_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.is_room_member_v2(p_room_id) then
    raise exception using errcode = '42501', message = 'Room membership required';
  end if;

  return coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'round_number', round.round_number,
        'performer_id', performer.id,
        'performer_name', performer.name,
        'challenge_text', replace(
          challenge.prompt_template, '{player}', performer.name
        ),
        'answer_unit', challenge.answer_unit,
        'result', round.proposed_result,
        'crowd_guess', case
          when challenge.challenge_type = 'binary' then (
            select round(
              100.0 * coalesce(sum(bet.chips) filter (where bet.slot_index = 1), 0)
              / nullif(sum(bet.chips), 0)
            )::integer
            from public.party_bets bet
            where bet.room_id = p_room_id
              and bet.round_number = round.round_number
          )
          else (
            select round(
              sum(
                bet.chips * case bet.slot_index
                  when 0 then challenge.bet_boundaries[1] / 2.0
                  when 1 then (
                    challenge.bet_boundaries[1] + challenge.bet_boundaries[2]
                  ) / 2.0
                  when 2 then (
                    challenge.bet_boundaries[2] + challenge.bet_boundaries[3]
                  ) / 2.0
                  when 3 then (
                    challenge.bet_boundaries[3] + challenge.bet_boundaries[4]
                  ) / 2.0
                  else challenge.bet_boundaries[4]
                    + greatest(
                        1,
                        challenge.bet_boundaries[4] - challenge.bet_boundaries[3]
                      ) / 2.0
                end
              ) / nullif(sum(bet.chips), 0)
            )::integer
            from public.party_bets bet
            where bet.room_id = p_room_id
              and bet.round_number = round.round_number
          )
        end,
        'performer_guess', null,
        'closest_player_name', null,
        'closest_guess', null,
        'performer_bonus', round.performer_bonus,
        'challenge_type', challenge.challenge_type,
        'duration_seconds', challenge.duration_seconds
      )
      order by round.round_number
    )
    from public.party_rounds round
    join public.players performer on performer.id = round.performer_id
    join public.party_challenges challenge on challenge.id = round.challenge_id
    where round.room_id = p_room_id
      and round.settled_at is not null
      and round.proposed_result is not null
  ), '[]'::jsonb);
end;
$$;

revoke all on function public.submit_party_claim_v1(uuid, integer)
from public, anon, authenticated;
