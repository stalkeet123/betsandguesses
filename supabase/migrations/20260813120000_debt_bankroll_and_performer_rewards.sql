-- Separate competitive bank score from the legacy playable score. Published
-- clients continue to see at least 15 chips, while updated clients display the
-- real bank (including debt) and use a minimum per-round betting limit of 15.

begin;

alter table public.players
  add column if not exists bank_score integer not null default 0;

comment on column public.players.bank_score is
  'Competitive bank balance. May be negative; score remains a legacy playable balance.';

alter table public.party_scores
  drop constraint if exists party_scores_nonnegative;
alter table public.party_scores
  alter column score set default 0;

-- Preserve a live match when this migration is deployed mid-game.
update public.players player
set bank_score = player.score
from public.rooms room
where room.id = player.room_id
  and room.status = 'playing'
  and coalesce(room.game_mode, 'classic') = 'classic';

update public.players player
set bank_score = party_score.score
from public.party_scores party_score
join public.rooms room on room.id = party_score.room_id
where player.id = party_score.player_id
  and room.status = 'playing'
  and room.game_mode = 'party';

-- Patch only small, stable clauses while preserving authorization, idempotency,
-- deadline behavior, grants, and old RPC response contracts.
do $function_patch$
declare
  patch record;
  definition text;
  rewritten text;
begin
  for patch in
    select * from (values
      (
        'public.start_game_v2(uuid,integer)'::regprocedure,
        'set\s+score\s*=\s*15',
        'set score = 15, bank_score = 0',
        'bank_score = 0'
      ),
      (
        'public.reset_room_to_lobby_v1(uuid)'::regprocedure,
        'set\s+score\s*=\s*15',
        'set score = 15, bank_score = 0',
        'bank_score = 0'
      ),
      (
        'public.start_party_game_v2(uuid,integer)'::regprocedure,
        'select\s+p_room_id\s*,\s*p[.]id\s*,\s*15',
        'select p_room_id, p.id, 0',
        'select p_room_id, p.id, 0'
      ),
      (
        'public.reset_party_to_lobby_v1(uuid)'::regprocedure,
        'set\s+score\s*=\s*15',
        'set score = 15, bank_score = 0',
        'bank_score = 0'
      ),
      (
        'public.place_bet_v2(uuid,integer,integer,uuid,double precision,double precision)'::regprocedure,
        'v_total\s*[+]\s*p_chips\s*>\s*v_player[.]score',
        'v_total + p_chips > greatest(15, v_player.bank_score)',
        'greatest(15, v_player.bank_score)'
      ),
      (
        'public.place_party_bet_v1(uuid,integer,integer,uuid,double precision,double precision)'::regprocedure,
        'v_total\s*[+]\s*p_chips\s*>\s*v_score',
        'v_total + p_chips > greatest(15, v_score)',
        'greatest(15, v_score)'
      ),
      (
        'public.advance_party_round_v2(uuid,integer)'::regprocedure,
        'set\s+score\s*=\s*s[.]score',
        'set bank_score = s.score, score = greatest(15, s.score)',
        'bank_score = s.score'
      )
    ) as patches(function_id, pattern, replacement, required_fragment)
  loop
    select pg_get_functiondef(patch.function_id) into definition;
    if position(lower(patch.required_fragment) in lower(definition)) > 0 then
      continue;
    end if;
    rewritten := regexp_replace(
      definition,
      patch.pattern,
      patch.replacement,
      'gi'
    );
    if rewritten = definition then
      raise exception 'Bank-score patch anchor missing in %', patch.function_id;
    end if;
    execute rewritten;
  end loop;
end;
$function_patch$;

create or replace function public.place_bet_v2(
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
  v_player public.players%rowtype;
  v_bet public.bets%rowtype;
  v_total integer;
  v_multiplier integer;
begin
  if p_slot_index not between 0 and 4 or p_chips not between 1 and 1000 then
    raise exception using errcode = '22023', message = 'Invalid bet';
  end if;

  select * into v_room
  from public.rooms
  where id = p_room_id;

  select * into v_player
  from public.players
  where room_id = p_room_id
    and auth_user_id = (select auth.uid())
    and is_connected
  limit 1
  for update;

  if v_player.id is null then
    raise exception using errcode = '42501', message = 'Room membership required';
  end if;

  -- Return an already committed action even when its response arrives after
  -- the deadline. This keeps retries idempotent and prevents duplicate chips.
  select * into v_bet
  from public.bets
  where client_action_id = p_client_action_id::text
    and player_id = v_player.id;

  if v_bet.id is not null then
    return to_jsonb(v_bet);
  end if;

  if v_room.status <> 'playing'
     or v_room.round_phase <> 'betting'
     or (v_room.phase_ends_at is not null
         and v_room.phase_ends_at < statement_timestamp()) then
    return null;
  end if;

  select coalesce(sum(chips), 0) into v_total
  from public.bets
  where room_id = p_room_id
    and round_number = v_room.current_round
    and player_id = v_player.id;

  if v_total + p_chips > greatest(15, v_player.bank_score) then
    raise exception using errcode = '22003', message = 'Insufficient score';
  end if;

  v_multiplier := (array[4, 3, 2, 3, 4])[p_slot_index + 1];

  insert into public.bets (
    room_id, round_number, player_id, target_guess_id, slot_index,
    chips, payout_multiplier, client_action_id, position_x, position_y
  ) values (
    p_room_id, v_room.current_round, v_player.id, null, p_slot_index,
    p_chips, v_multiplier, p_client_action_id::text,
    case when p_position_x between -1000 and 2000 then p_position_x else null end,
    case when p_position_y between -1000 and 2000 then p_position_y else null end
  )
  returning * into v_bet;

  return to_jsonb(v_bet);
end;
$$;

create or replace function public.settle_game_round_v2(
  p_room_id uuid,
  p_round_number integer
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room public.rooms%rowtype;
  v_answer bigint;
  v_boundaries bigint[];
  v_winning_slot integer;
  v_winning_guess_id uuid;
  v_scores jsonb;
  v_bank_scores jsonb;
  v_payouts jsonb;
begin
  if not public.is_room_member_v2(p_room_id) then
    raise exception using errcode = '42501', message = 'Room membership required';
  end if;
  select * into v_room from public.rooms where id = p_room_id for update;
  if not found or v_room.current_round <> p_round_number then
    raise exception using errcode = '40001', message = 'Round changed';
  end if;
  if v_room.round_phase not in ('betting', 'revealAnswer') then
    raise exception using errcode = '40001', message = 'Betting phase is not active';
  end if;
  if v_room.round_phase = 'betting' and v_room.phase_ends_at is not null
     and v_room.phase_ends_at > statement_timestamp() then
    raise exception using errcode = '40001', message = 'Betting deadline not reached';
  end if;

  select q.answer into v_answer from public.questions q where q.id = v_room.current_question_id;
  if v_answer is null then
    raise exception using errcode = 'P0002', message = 'Question answer not found';
  end if;
  v_boundaries := public.game_board_boundaries_v2(p_room_id, p_round_number);
  v_winning_slot := case
    when v_answer < v_boundaries[1] then 0
    when v_answer < v_boundaries[2] then 1
    when v_answer <= v_boundaries[3] then 2
    when v_answer <= v_boundaries[4] then 3
    else 4
  end;
  select g.id into v_winning_guess_id
  from public.guesses g
  where g.room_id = p_room_id and g.round_number = p_round_number and g.value <= v_answer
  order by g.value desc, g.id
  limit 1;

  if v_room.round_phase = 'betting' then
    update public.guesses
    set is_winner = (id = v_winning_guess_id)
    where room_id = p_room_id and round_number = p_round_number;
    update public.bets
    set won = (slot_index = v_winning_slot)
    where room_id = p_room_id and round_number = p_round_number;
    with player_results as (
      select
        player.id,
        player.bank_score
          - coalesce((
              select sum(bet.chips)
              from public.bets bet
              where bet.room_id = p_room_id
                and bet.round_number = p_round_number
                and bet.player_id = player.id
            ), 0)
          + coalesce((
              select sum(
                bet.chips * (array[4, 3, 2, 3, 4])[bet.slot_index + 1]
              )
              from public.bets bet
              where bet.room_id = p_room_id
                and bet.round_number = p_round_number
                and bet.player_id = player.id
                and bet.slot_index = v_winning_slot
            ), 0) as next_bank_score
      from public.players player
      where player.room_id = p_room_id and player.is_connected
    )
    update public.players player
    set bank_score = result.next_bank_score,
        score = greatest(15, result.next_bank_score)
    from player_results result
    where player.id = result.id;
    update public.rooms
    set round_phase = 'revealAnswer', phase_started_at = statement_timestamp(),
        phase_ends_at = null
    where id = p_room_id
    returning * into v_room;
  end if;

  select coalesce(jsonb_object_agg(p.id::text, p.score), '{}'::jsonb)
  into v_scores from public.players p where p.room_id = p_room_id and p.is_connected;
  select coalesce(jsonb_object_agg(p.id::text, p.bank_score), '{}'::jsonb)
  into v_bank_scores from public.players p
  where p.room_id = p_room_id and p.is_connected;
  select coalesce(jsonb_object_agg(x.player_id::text, x.payout), '{}'::jsonb)
  into v_payouts
  from (
    select b.player_id,
      sum(b.chips * (array[4, 3, 2, 3, 4])[b.slot_index + 1])::integer as payout
    from public.bets b
    where b.room_id = p_room_id and b.round_number = p_round_number
      and b.slot_index = v_winning_slot
    group by b.player_id
  ) x;

  return jsonb_build_object(
    'status', case when v_room.round_phase = 'revealAnswer' then 'settled' else 'already_settled' end,
    'state_version', v_room.state_version,
    'answer', v_answer,
    'winning_guess_id', v_winning_guess_id,
    'winning_slot_index', v_winning_slot,
    'scores', v_scores,
    'bank_scores', v_bank_scores,
    'payouts', v_payouts,
    'phase_ends_at', v_room.phase_ends_at
  );
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

  if v_player.id is null then
    raise exception using errcode = '42501', message = 'Room membership required';
  end if;
  if v_round.phase = 'reveal' then
    return public.get_party_snapshot_v1(p_room_id);
  end if;
  if v_round.phase <> 'resultConfirm' or v_round.proposed_result is null then
    raise exception using errcode = '40001', message = 'Result confirmation is not active';
  end if;
  if v_round.phase_ends_at is null
     or v_round.phase_ends_at > statement_timestamp() then
    raise exception using errcode = '40001', message = 'Result review is still active';
  end if;

  if v_challenge.challenge_type = 'choice' then
    v_winning_slot := v_round.proposed_result;
    v_performer_bonus := 30;
  elsif v_challenge.challenge_type = 'binary' then
    v_winning_slot := v_round.proposed_result;
    v_performer_bonus := case
      when v_round.proposed_result = 1 then v_challenge.performer_success_bonus
      else 0
    end;
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
    v_performer_bonus := case
      when v_challenge.result_direction = 'lower'
        then (array[60, 45, 30, 15, 0])[v_winning_slot + 1]
      else (array[0, 15, 30, 45, 60])[v_winning_slot + 1]
    end;
  end if;

  update public.party_bets
  set won = slot_index = v_winning_slot
  where room_id = p_room_id and round_number = v_room.current_round;

  update public.party_scores score
  set score = score.score
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
              when v_challenge.challenge_type in ('binary', 'choice') then 2
              else (array[4, 3, 2, 3, 4])[bet.slot_index + 1]
            end
          )
          from public.party_bets bet
          where bet.room_id = p_room_id
            and bet.round_number = v_room.current_round
            and bet.player_id = score.player_id
            and bet.slot_index = v_winning_slot
        ), 0)
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
  set state_version = state_version + 1
  where room_id = p_room_id;

  return public.get_party_snapshot_v1(p_room_id);
end;
$$;

-- New RPCs keep their existing grants because CREATE OR REPLACE does not alter
-- privileges. Verify every security and compatibility invariant explicitly.
do $verification$
declare
  remaining_party_floor integer;
begin
  if pg_get_functiondef(
    'public.place_bet_v2(uuid,integer,integer,uuid,double precision,double precision)'::regprocedure
  ) not ilike '%greatest(15, v_player.bank_score)%' then
    raise exception 'Classic minimum betting limit is missing';
  end if;
  if pg_get_functiondef(
    'public.place_bet_v2(uuid,integer,integer,uuid,double precision,double precision)'::regprocedure
  ) not ilike '%for update%' then
    raise exception 'Classic place-bet does not serialize each player budget';
  end if;
  if pg_get_functiondef(
    'public.place_party_bet_v1(uuid,integer,integer,uuid,double precision,double precision)'::regprocedure
  ) not ilike '%greatest(15, v_score)%' then
    raise exception 'Party minimum betting limit is missing';
  end if;
  if pg_get_functiondef(
    'public.settle_game_round_v2(uuid,integer)'::regprocedure
  ) not ilike '%bank_scores%' then
    raise exception 'Classic settlement does not expose bank scores';
  end if;
  if pg_get_functiondef(
    'public.confirm_party_result_v1(uuid)'::regprocedure
  ) not ilike '%v_performer_bonus := 30%' then
    raise exception 'Choice performer reward is not 30';
  end if;
  if pg_get_functiondef(
    'public.submit_party_choice_v1(uuid,integer)'::regprocedure
  ) not ilike '%v_player.id <> v_round.performer_id%' then
    raise exception 'Choice is not performer-only';
  end if;
  if pg_get_functiondef(
    'public.begin_party_choice_v1(uuid)'::regprocedure
  ) not ilike '%phase_ends_at = null%' then
    raise exception 'Choice entry can still expire before an answer';
  end if;
  select count(*) into remaining_party_floor
  from pg_constraint
  where conrelid = 'public.party_scores'::regclass
    and contype = 'c'
    and regexp_replace(pg_get_constraintdef(oid), '[[:space:]]', '', 'g')
      ilike '%score>=0%';
  if remaining_party_floor <> 0 then
    raise exception 'Party score still has a nonnegative constraint';
  end if;
end;
$verification$;

notify pgrst, 'reload schema';

commit;