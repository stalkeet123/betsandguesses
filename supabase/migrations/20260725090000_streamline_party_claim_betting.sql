-- Party Mode v2 removes the shared guessing phase. Each challenge owns four
-- authored boundaries, spectators bet immediately, and only the performer
-- records a private claim while betting is open. Classic Mode is untouched.

alter table public.party_challenges
  add column if not exists bet_boundaries integer[]
  not null default array[25, 50, 75, 100];

update public.party_challenges
set bet_boundaries = case slug
  when 'push_ups' then array[5, 12, 20, 30]
  when 'squats' then array[10, 25, 40, 60]
  when 'jumping_jacks' then array[15, 35, 55, 80]
  when 'countries' then array[8, 15, 23, 32]
  when 'movie_titles' then array[6, 12, 20, 30]
  when 'paper_cup' then array[1, 3, 6, 10]
  when 'coin_catches' then array[5, 12, 20, 30]
  when 'tongue_twister' then array[2, 5, 8, 12]
  when 'toe_touches' then array[10, 20, 30, 45]
  when 'knee_raises' then array[15, 30, 50, 75]
  when 'animals' then array[10, 20, 30, 40]
  when 'count_by_threes' then array[5, 10, 20, 28]
  else bet_boundaries
end;

alter table public.party_challenges
  drop constraint if exists party_challenges_bet_boundaries_valid;

alter table public.party_challenges
  add constraint party_challenges_bet_boundaries_valid check (
    cardinality(bet_boundaries) = 4
    and bet_boundaries[1] >= 0
    and bet_boundaries[1] < bet_boundaries[2]
    and bet_boundaries[2] < bet_boundaries[3]
    and bet_boundaries[3] < bet_boundaries[4]
    and bet_boundaries[4] <= max_result
  );

alter table public.party_rounds
  add column if not exists performer_bonus integer not null default 0;

alter table public.party_rounds
  drop constraint if exists party_rounds_performer_bonus_valid;

alter table public.party_rounds
  add constraint party_rounds_performer_bonus_valid
  check (performer_bonus between 0 and 1000);

create or replace function public.party_board_boundaries_v1(
  p_room_id uuid,
  p_round_number integer
)
returns bigint[]
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    array(
      select boundary::bigint
      from unnest(challenge.bet_boundaries) with ordinality
        as authored(boundary, position)
      order by position
    ),
    array[25, 50, 75, 100]::bigint[]
  )
  from public.party_rounds round
  join public.party_challenges challenge on challenge.id = round.challenge_id
  where round.room_id = p_room_id
    and round.round_number = p_round_number
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
  v_bets jsonb := '[]'::jsonb;
  v_scores jsonb := '{}'::jsonb;
  v_own_guess jsonb;
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
    and is_connected = true
  order by joined_at desc
  limit 1;
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

  -- A claim is private to its performer until the recap.
  if v_me.id = v_round.performer_id then
    select to_jsonb(g) into v_own_guess
    from public.party_guesses g
    where g.room_id = p_room_id
      and g.round_number = v_room.current_round
      and g.player_id = v_me.id
      and g.is_performer_prediction;
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', b.id,
        'slot_index', b.slot_index,
        'chips', b.chips,
        'position_x', b.position_x,
        'position_y', b.position_y,
        'player_id', case
          when v_show_all_bets or b.player_id = v_me.id then b.player_id
          else null
        end
      )
      order by b.created_at, b.id
    ) filter (where v_show_all_bets or b.player_id = v_me.id),
    '[]'::jsonb
  )
  into v_bets
  from public.party_bets b
  where b.room_id = p_room_id and b.round_number = v_room.current_round;

  select coalesce(jsonb_object_agg(s.player_id::text, s.score), '{}'::jsonb)
  into v_scores
  from public.party_scores s
  where s.room_id = p_room_id;

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
        'duration_seconds', 60,
        'max_result', v_challenge.max_result,
        'bet_boundaries', to_jsonb(v_challenge.bet_boundaries)
      ),
      'submitted_guess_count', case when v_own_guess is null then 0 else 1 end,
      'performer_ready', v_round.performer_ready_at is not null,
      'own_guess', v_own_guess,
      'guesses', '[]'::jsonb,
      'bets', v_bets,
      'proposed_result', case when v_show_result then v_round.proposed_result else null end,
      'performer_bonus', case when v_round.phase = 'reveal'
        then v_round.performer_bonus else 0 end
    ),
    'scores', v_scores
  );
end;
$$;

create or replace function public.submit_party_claim_v1(
  p_room_id uuid,
  p_value integer
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
  v_guess public.party_guesses%rowtype;
  v_max_result integer;
begin
  select * into v_room from public.rooms where id = p_room_id;
  select * into v_player
  from public.players
  where room_id = p_room_id
    and auth_user_id = (select auth.uid())
    and is_connected = true
  order by joined_at desc limit 1;
  select * into v_round
  from public.party_rounds
  where room_id = p_room_id and round_number = v_room.current_round;
  select max_result into v_max_result
  from public.party_challenges where id = v_round.challenge_id;

  if v_player.id is null then
    raise exception using errcode = '42501', message = 'Room membership required';
  end if;
  if v_player.id <> v_round.performer_id then
    raise exception using errcode = '42501', message = 'Only the performer can submit a claim';
  end if;
  if v_room.game_mode <> 'party' or v_room.status <> 'playing'
     or v_round.phase <> 'betting'
     or (v_round.phase_ends_at is not null
         and v_round.phase_ends_at < statement_timestamp()) then
    raise exception using errcode = '40001', message = 'Claim entry is closed';
  end if;
  if p_value < 0 or p_value > v_max_result then
    raise exception using errcode = '22023', message = 'Invalid claim';
  end if;

  insert into public.party_guesses (
    room_id, round_number, player_id, value, is_performer_prediction
  ) values (
    p_room_id, v_room.current_round, v_player.id, p_value, true
  )
  on conflict (room_id, round_number, player_id) do nothing
  returning * into v_guess;

  if v_guess.id is null then
    select * into v_guess
    from public.party_guesses
    where room_id = p_room_id
      and round_number = v_room.current_round
      and player_id = v_player.id;
  else
    update public.party_matches
    set state_version = state_version + 1
    where room_id = p_room_id;
  end if;
  return to_jsonb(v_guess);
end;
$$;

create or replace function public.start_party_game_v2(
  p_room_id uuid,
  p_betting_duration_seconds integer default 20
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room public.rooms%rowtype;
  v_turn_order uuid[];
  v_performer_id uuid;
  v_witness_id uuid;
  v_challenge_id uuid;
begin
  if p_betting_duration_seconds not between 15 and 90 then
    raise exception using errcode = '22023', message = 'Invalid betting duration';
  end if;
  select * into v_room from public.rooms where id = p_room_id for update;
  if not found or v_room.game_mode <> 'party' then
    raise exception using errcode = 'P0002', message = 'Party room not found';
  end if;
  if not exists (
    select 1 from public.players p
    where p.room_id = p_room_id
      and p.auth_user_id = (select auth.uid())
      and p.is_host and p.is_connected
  ) then
    raise exception using errcode = '42501', message = 'Host access required';
  end if;
  if v_room.status = 'playing'
     and exists (select 1 from public.party_matches m where m.room_id = p_room_id) then
    return public.get_party_snapshot_v1(p_room_id);
  end if;
  if v_room.status <> 'waiting' then
    raise exception using errcode = '40001', message = 'Room is not waiting';
  end if;
  if (
    select count(*) from public.players p
    where p.room_id = p_room_id and p.is_connected
  ) < 3 then
    raise exception using errcode = 'P0001', message = 'Party Mode requires at least three players';
  end if;
  if exists (
    select 1 from public.players p
    where p.room_id = p_room_id and p.is_connected
      and not p.is_host and not p.is_ready
  ) then
    raise exception using errcode = 'P0001', message = 'All players must be ready';
  end if;

  select array_agg(p.id order by random())
  into v_turn_order
  from public.players p
  where p.room_id = p_room_id and p.is_connected;
  v_performer_id := v_turn_order[1];
  v_witness_id := (
    select player_id
    from unnest(v_turn_order) with ordinality as t(player_id, position)
    where player_id <> v_performer_id
    order by position limit 1
  );
  select id into v_challenge_id
  from public.party_challenges
  where enabled
  order by random() limit 1;
  if v_challenge_id is null then
    raise exception using errcode = 'P0002', message = 'No Party challenge available';
  end if;

  insert into public.party_matches (room_id, turn_order, turn_index, state_version)
  values (p_room_id, v_turn_order, 0, 1);
  insert into public.party_scores (room_id, player_id, score)
  select p_room_id, p.id, 15
  from public.players p
  where p.room_id = p_room_id and p.is_connected;
  insert into public.party_rounds (
    room_id, round_number, performer_id, witness_id, challenge_id,
    phase, phase_started_at, phase_ends_at
  ) values (
    p_room_id, 1, v_performer_id, v_witness_id, v_challenge_id,
    'betting', statement_timestamp(),
    statement_timestamp() + make_interval(secs => p_betting_duration_seconds)
  );
  update public.rooms
  set status = 'playing',
      current_round = 1,
      max_rounds = cardinality(v_turn_order),
      round_phase = 'betting',
      current_question_id = null,
      phase_started_at = statement_timestamp(),
      phase_ends_at = statement_timestamp()
        + make_interval(secs => p_betting_duration_seconds)
  where id = p_room_id;
  return public.get_party_snapshot_v1(p_room_id);
end;
$$;

create or replace function public.advance_party_round_v2(
  p_room_id uuid,
  p_betting_duration_seconds integer default 20
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
  if p_betting_duration_seconds not between 15 and 90 then
    raise exception using errcode = '22023', message = 'Invalid betting duration';
  end if;
  select * into v_room from public.rooms where id = p_room_id for update;
  if not exists (
    select 1 from public.players p
    where p.room_id = p_room_id
      and p.auth_user_id = (select auth.uid())
      and p.is_host and p.is_connected
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
  if v_round.phase = 'betting' and v_match.turn_index > 0 then
    return public.get_party_snapshot_v1(p_room_id);
  end if;
  if v_round.phase <> 'reveal' or v_round.settled_at is null
     or (v_round.phase_ends_at is not null
         and v_round.phase_ends_at > statement_timestamp()) then
    raise exception using errcode = '40001', message = 'Reveal is still active';
  end if;

  v_next_index := v_match.turn_index + 1;
  if v_next_index >= cardinality(v_match.turn_order) then
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
    order by position limit 1
  );
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
  v_performer_bonus := (array[0, 2, 4, 7, 10])[v_winning_slot + 1];

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
            bet.chips * (array[4, 3, 2, 3, 4])[bet.slot_index + 1]
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
        'crowd_guess', (
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
        ),
        'performer_guess', (
          select guess.value
          from public.party_guesses guess
          where guess.room_id = p_room_id
            and guess.round_number = round.round_number
            and guess.is_performer_prediction
          limit 1
        ),
        'closest_player_name', null,
        'closest_guess', null,
        'performer_bonus', round.performer_bonus
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
revoke all on function public.start_party_game_v2(uuid, integer)
from public, anon, authenticated;
revoke all on function public.advance_party_round_v2(uuid, integer)
from public, anon, authenticated;

grant execute on function public.submit_party_claim_v1(uuid, integer)
to authenticated;
grant execute on function public.start_party_game_v2(uuid, integer)
to authenticated;
grant execute on function public.advance_party_round_v2(uuid, integer)
to authenticated;
