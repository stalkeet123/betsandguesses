-- Poll-only Party Mode v1.
--
-- This migration is intentionally additive: it does not remove or revoke the
-- legacy Party RPCs yet. Flutter can be migrated to these functions first,
-- validated, and only then can the legacy surface be retired safely.

begin;

-- Poll supports up to eight player slots. Party score is a net profit/loss
-- ledger: 0 means the player still has the base 15-chip credit.
alter table public.party_bets
  drop constraint if exists party_bets_slot_valid;

alter table public.party_bets
  add constraint party_bets_slot_valid check (slot_index between 0 and 7);

alter table public.party_scores
  drop constraint if exists party_scores_nonnegative;

alter table public.party_scores
  alter column score set default 0;

-- Minimal authoritative Poll snapshot. During betting, only the caller's bets
-- are exposed. During reveal, every bet and winning flag becomes visible.
create or replace function public.get_party_poll_snapshot_v1(p_room_id uuid)
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
  v_challenge public.party_challenges%rowtype;
  v_players jsonb := '[]'::jsonb;
  v_bets jsonb := '[]'::jsonb;
  v_scores jsonb := '{}'::jsonb;
  v_winning_slots jsonb := '[]'::jsonb;
  v_score integer := 0;
  v_limit integer := 15;
  v_total integer := 0;
begin
  select * into v_room
  from public.rooms
  where id = p_room_id;

  if not found or v_room.game_mode <> 'party' then
    raise exception using errcode = 'P0002', message = 'PARTY_ROOM_NOT_FOUND';
  end if;

  select * into v_me
  from public.players p
  where p.room_id = p_room_id
    and p.auth_user_id = (select auth.uid())
  order by p.joined_at desc
  limit 1;

  if v_me.id is null then
    raise exception using errcode = '42501', message = 'ROOM_MEMBERSHIP_REQUIRED';
  end if;

  select * into v_match
  from public.party_matches
  where room_id = p_room_id;

  if v_match.room_id is null then
    return jsonb_build_object(
      'poll_only', true,
      'status', 'waiting',
      'room', to_jsonb(v_room),
      'me', jsonb_build_object(
        'player_id', v_me.id,
        'score', 0,
        'bet_limit', 15,
        'bet_total', 0,
        'available_chips', 15
      )
    );
  end if;

  select * into v_round
  from public.party_rounds
  where room_id = p_room_id
    and round_number = v_room.current_round;

  if v_round.id is null then
    raise exception using errcode = 'P0001', message = 'PARTY_ROUND_STATE_MISMATCH';
  end if;

  if v_round.phase not in ('betting', 'reveal') then
    raise exception using errcode = 'P0001', message = 'PARTY_POLL_INVALID_PHASE';
  end if;

  select * into v_challenge
  from public.party_challenges
  where id = v_round.challenge_id;

  if v_challenge.id is null or v_challenge.challenge_type <> 'poll' then
    raise exception using errcode = 'P0001', message = 'PARTY_POLL_CHALLENGE_REQUIRED';
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'slot_index', ordered.position - 1,
        'id', p.id,
        'name', p.name,
        'avatar_color', p.avatar_color
      )
      order by ordered.position
    ),
    '[]'::jsonb
  )
  into v_players
  from unnest(v_match.turn_order) with ordinality
    as ordered(player_id, position)
  join public.players p on p.id = ordered.player_id;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', b.id,
        'round_number', b.round_number,
        'slot_index', b.slot_index,
        'chips', b.chips,
        'position_x', b.position_x,
        'position_y', b.position_y,
        'player_id', b.player_id,
        'won', case when v_round.phase = 'reveal' then b.won else null end
      )
      order by b.created_at, b.id
    ) filter (
      where v_round.phase = 'reveal' or b.player_id = v_me.id
    ),
    '[]'::jsonb
  )
  into v_bets
  from public.party_bets b
  where b.room_id = p_room_id
    and b.round_number = v_room.current_round;

  select coalesce(jsonb_object_agg(s.player_id::text, s.score), '{}'::jsonb)
  into v_scores
  from public.party_scores s
  where s.room_id = p_room_id;

  select coalesce(s.score, 0)
  into v_score
  from public.party_scores s
  where s.room_id = p_room_id
    and s.player_id = v_me.id;

  v_score := coalesce(v_score, 0);
  v_limit := greatest(0, 15 + v_score);

  select coalesce(sum(b.chips), 0)
  into v_total
  from public.party_bets b
  where b.room_id = p_room_id
    and b.round_number = v_room.current_round
    and b.player_id = v_me.id;

  if v_round.phase = 'reveal' then
    select coalesce(jsonb_agg(w.slot_index order by w.slot_index), '[]'::jsonb)
    into v_winning_slots
    from (
      select distinct b.slot_index
      from public.party_bets b
      where b.room_id = p_room_id
        and b.round_number = v_room.current_round
        and b.won is true
    ) w;
  end if;

  return jsonb_build_object(
    'poll_only', true,
    'status', v_room.status,
    'room', to_jsonb(v_room),
    'state_version', v_match.state_version,
    'round', jsonb_build_object(
      'number', v_round.round_number,
      'phase', v_round.phase,
      'phase_started_at', v_round.phase_started_at,
      'phase_ends_at', v_round.phase_ends_at,
      'question', jsonb_build_object(
        'id', v_challenge.id,
        'text', v_challenge.prompt_template,
        'rules', v_challenge.rules
      ),
      'players', v_players,
      'bets', v_bets,
      'winning_slots', v_winning_slots
    ),
    'scores', v_scores,
    'me', jsonb_build_object(
      'player_id', v_me.id,
      'score', v_score,
      'bet_limit', v_limit,
      'bet_total', v_total,
      'available_chips', greatest(0, v_limit - v_total)
    )
  );
end;
$$;

-- Starts a Poll match directly in betting. No guessing/ready/action/result
-- phases are created. The room's configured max_rounds is preserved.
create or replace function public.start_party_poll_v1(
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
  v_turn_order uuid[];
  v_active_count integer;
  v_performer_id uuid;
  v_witness_id uuid;
  v_challenge_id uuid;
begin
  if p_betting_duration_seconds not between 10 and 120 then
    raise exception using errcode = '22023', message = 'INVALID_BETTING_DURATION';
  end if;

  select * into v_room
  from public.rooms
  where id = p_room_id
  for update;

  if not found or v_room.game_mode <> 'party' then
    raise exception using errcode = 'P0002', message = 'PARTY_ROOM_NOT_FOUND';
  end if;

  if not exists (
    select 1
    from public.players p
    where p.room_id = p_room_id
      and p.auth_user_id = (select auth.uid())
      and p.is_host = true
  ) then
    raise exception using errcode = '42501', message = 'HOST_ACCESS_REQUIRED';
  end if;

  if v_room.status = 'playing'
     and exists (
       select 1 from public.party_matches m where m.room_id = p_room_id
     ) then
    return public.get_party_poll_snapshot_v1(p_room_id);
  end if;

  if v_room.status <> 'waiting' then
    raise exception using errcode = '40001', message = 'ROOM_NOT_WAITING';
  end if;

  if not exists (
    select 1
    from public.party_challenges c
    where c.enabled = true
      and c.challenge_type = 'poll'
  ) then
    raise exception using errcode = 'P0002', message = 'NO_POLL_CHALLENGE_AVAILABLE';
  end if;

  if exists (
    select 1
    from public.players p
    where p.room_id = p_room_id
      and (p.is_connected = true or p.auth_user_id = (select auth.uid()))
      and p.is_host = false
      and p.is_ready = false
  ) then
    raise exception using errcode = 'P0001', message = 'ALL_PLAYERS_MUST_BE_READY';
  end if;

  select array_agg(p.id order by random())
  into v_turn_order
  from public.players p
  where p.room_id = p_room_id
    and (p.is_connected = true or p.auth_user_id = (select auth.uid()));

  v_active_count := coalesce(cardinality(v_turn_order), 0);

  if v_active_count < 3 then
    raise exception using errcode = 'P0001', message = 'PARTY_REQUIRES_THREE_PLAYERS';
  end if;

  if v_active_count > 8 then
    raise exception using errcode = '22023', message = 'PARTY_POLL_SUPPORTS_MAX_EIGHT_PLAYERS';
  end if;

  v_performer_id := v_turn_order[1];
  v_witness_id := v_turn_order[2];

  select c.id into v_challenge_id
  from public.party_challenges c
  where c.enabled = true
    and c.challenge_type = 'poll'
  order by random()
  limit 1;

  -- A waiting room may still contain stale Party rows after an interrupted
  -- reset. Starting a new match is the safe boundary to clear them.
  delete from public.party_bets where room_id = p_room_id;
  delete from public.party_guesses where room_id = p_room_id;
  delete from public.party_rounds where room_id = p_room_id;
  delete from public.party_scores where room_id = p_room_id;
  delete from public.party_matches where room_id = p_room_id;

  update public.players p
  set score = 0,
      bank_score = 0
  where p.room_id = p_room_id
    and p.id = any(v_turn_order);

  insert into public.party_matches (
    room_id,
    turn_order,
    turn_index,
    state_version
  ) values (
    p_room_id,
    v_turn_order,
    0,
    1
  );

  insert into public.party_scores (room_id, player_id, score)
  select p_room_id, player_id, 0
  from unnest(v_turn_order) as active_players(player_id);

  insert into public.party_rounds (
    room_id,
    round_number,
    performer_id,
    witness_id,
    challenge_id,
    phase,
    phase_started_at,
    phase_ends_at
  ) values (
    p_room_id,
    1,
    v_performer_id,
    v_witness_id,
    v_challenge_id,
    'betting',
    statement_timestamp(),
    statement_timestamp() + make_interval(secs => p_betting_duration_seconds)
  );

  update public.rooms
  set status = 'playing',
      current_round = 1,
      max_rounds = greatest(1, coalesce(v_room.max_rounds, v_active_count)),
      round_phase = 'betting',
      current_question_id = null,
      phase_started_at = statement_timestamp(),
      phase_ends_at = statement_timestamp()
        + make_interval(secs => p_betting_duration_seconds)
  where id = p_room_id;

  return public.get_party_poll_snapshot_v1(p_room_id);
end;
$$;

-- Safe, idempotent Poll bet placement. Round, score and phase are all derived
-- from locked database state; the client never chooses them.
create or replace function public.place_party_poll_bet_v1(
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
  v_match public.party_matches%rowtype;
  v_round public.party_rounds%rowtype;
  v_me public.players%rowtype;
  v_challenge public.party_challenges%rowtype;
  v_bet public.party_bets%rowtype;
  v_score integer := 0;
  v_limit integer := 0;
  v_total integer := 0;
begin
  if p_client_action_id is null or p_chips not between 1 and 1000 then
    raise exception using errcode = '22023', message = 'INVALID_BET';
  end if;

  if (p_position_x is not null and p_position_x not between 0 and 1)
     or (p_position_y is not null and p_position_y not between 0 and 1) then
    raise exception using errcode = '22023', message = 'INVALID_BET_POSITION';
  end if;

  select * into v_room
  from public.rooms
  where id = p_room_id
  for update;

  if not found or v_room.game_mode <> 'party' then
    raise exception using errcode = 'P0002', message = 'PARTY_ROOM_NOT_FOUND';
  end if;

  select * into v_me
  from public.players p
  where p.room_id = p_room_id
    and p.auth_user_id = (select auth.uid())
  order by p.joined_at desc
  limit 1;

  if v_me.id is null then
    raise exception using errcode = '42501', message = 'ROOM_MEMBERSHIP_REQUIRED';
  end if;

  -- Retry safety spans rounds too: a delayed retry from round N must never
  -- become a fresh bet in round N+1.
  select * into v_bet
  from public.party_bets b
  where b.room_id = p_room_id
    and b.player_id = v_me.id
    and b.client_action_id = p_client_action_id
  order by b.created_at desc
  limit 1;

  if v_bet.id is not null then
    return jsonb_build_object(
      'bet', to_jsonb(v_bet),
      'snapshot', public.get_party_poll_snapshot_v1(p_room_id)
    );
  end if;

  select * into v_match
  from public.party_matches
  where room_id = p_room_id
  for update;

  if v_match.room_id is null then
    raise exception using errcode = 'P0001', message = 'PARTY_MATCH_NOT_STARTED';
  end if;

  select * into v_round
  from public.party_rounds
  where room_id = p_room_id
    and round_number = v_room.current_round
  for update;

  if v_round.id is null then
    raise exception using errcode = 'P0001', message = 'PARTY_ROUND_STATE_MISMATCH';
  end if;

  select * into v_challenge
  from public.party_challenges
  where id = v_round.challenge_id;

  if v_challenge.id is null or v_challenge.challenge_type <> 'poll' then
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

  if p_slot_index < 0
     or p_slot_index >= cardinality(v_match.turn_order)
     or p_slot_index > 7 then
    raise exception using errcode = '22023', message = 'INVALID_POLL_TARGET';
  end if;

  if (
    select count(distinct b.slot_index)
    from public.party_bets b
    where b.room_id = p_room_id
      and b.round_number = v_room.current_round
      and b.player_id = v_me.id
      and b.slot_index <> p_slot_index
  ) >= 2 then
    raise exception using errcode = '22023', message = 'POLL_MAX_TWO_TARGETS';
  end if;

  insert into public.party_scores (room_id, player_id, score)
  values (p_room_id, v_me.id, 0)
  on conflict (room_id, player_id) do nothing;

  select s.score into v_score
  from public.party_scores s
  where s.room_id = p_room_id
    and s.player_id = v_me.id
  for update;

  v_score := coalesce(v_score, 0);
  v_limit := greatest(0, 15 + v_score);

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
    chips,
    client_action_id,
    position_x,
    position_y
  ) values (
    p_room_id,
    v_room.current_round,
    v_me.id,
    p_slot_index,
    p_chips,
    p_client_action_id,
    p_position_x,
    p_position_y
  )
  on conflict (room_id, round_number, player_id, client_action_id) do update
  set slot_index = excluded.slot_index,
      chips = excluded.chips,
      position_x = excluded.position_x,
      position_y = excluded.position_y
  returning * into v_bet;

  return jsonb_build_object(
    'bet', to_jsonb(v_bet),
    'snapshot', public.get_party_poll_snapshot_v1(p_room_id)
  );
end;
$$;

-- Deterministic settlement. Any room member may call it after the server-side
-- deadline. Row locks make concurrent callers settle the round at most once.
create or replace function public.settle_party_poll_round_v1(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room public.rooms%rowtype;
  v_round public.party_rounds%rowtype;
  v_me public.players%rowtype;
  v_challenge public.party_challenges%rowtype;
  v_winning_slots integer[] := '{}'::integer[];
begin
  select * into v_room
  from public.rooms
  where id = p_room_id
  for update;

  if not found or v_room.game_mode <> 'party' then
    raise exception using errcode = 'P0002', message = 'PARTY_ROOM_NOT_FOUND';
  end if;

  select * into v_me
  from public.players p
  where p.room_id = p_room_id
    and p.auth_user_id = (select auth.uid())
  order by p.joined_at desc
  limit 1;

  if v_me.id is null then
    raise exception using errcode = '42501', message = 'ROOM_MEMBERSHIP_REQUIRED';
  end if;

  select * into v_round
  from public.party_rounds
  where room_id = p_room_id
    and round_number = v_room.current_round
  for update;

  if v_round.id is null then
    raise exception using errcode = 'P0001', message = 'PARTY_ROUND_STATE_MISMATCH';
  end if;

  if v_round.phase = 'reveal' then
    return public.get_party_poll_snapshot_v1(p_room_id);
  end if;

  if v_round.phase <> 'betting' then
    raise exception using errcode = 'P0001', message = 'PARTY_POLL_INVALID_PHASE';
  end if;

  if v_round.phase_ends_at is null then
    raise exception using errcode = 'P0001', message = 'BETTING_DEADLINE_MISSING';
  end if;

  if statement_timestamp() < v_round.phase_ends_at then
    raise exception using errcode = 'P0001', message = 'BETTING_WINDOW_OPEN';
  end if;

  select * into v_challenge
  from public.party_challenges
  where id = v_round.challenge_id;

  if v_challenge.id is null or v_challenge.challenge_type <> 'poll' then
    raise exception using errcode = 'P0001', message = 'PARTY_POLL_CHALLENGE_REQUIRED';
  end if;

  with player_slot_counts as (
    select b.player_id, count(distinct b.slot_index) as num_slots
    from public.party_bets b
    where b.room_id = p_room_id
      and b.round_number = v_room.current_round
    group by b.player_id
  ),
  player_weighted_votes as (
    select distinct
      b.player_id,
      b.slot_index,
      case when counts.num_slots = 1 then 2 else 1 end as vote_weight
    from public.party_bets b
    join player_slot_counts counts on counts.player_id = b.player_id
    where b.room_id = p_room_id
      and b.round_number = v_room.current_round
  ),
  slot_vote_totals as (
    select slot_index, sum(vote_weight) as total_votes
    from player_weighted_votes
    group by slot_index
  ),
  max_vote as (
    select max(total_votes) as max_votes
    from slot_vote_totals
  )
  select coalesce(array_agg(totals.slot_index order by totals.slot_index), '{}'::integer[])
  into v_winning_slots
  from slot_vote_totals totals
  cross join max_vote winner
  where totals.total_votes = winner.max_votes;

  update public.party_bets b
  set won = (b.slot_index = any(v_winning_slots))
  where b.room_id = p_room_id
    and b.round_number = v_room.current_round;

  update public.party_scores score_row
  set score = score_row.score + coalesce((
    select sum(
      case
        when b.slot_index = any(v_winning_slots) then b.chips
        else -b.chips
      end
    )
    from public.party_bets b
    where b.room_id = p_room_id
      and b.round_number = v_room.current_round
      and b.player_id = score_row.player_id
  ), 0)
  where score_row.room_id = p_room_id;

  update public.party_rounds
  set phase = 'reveal',
      proposed_result = coalesce(v_winning_slots[1], 0),
      result_submitted_by = v_me.id,
      result_confirmed_by = v_me.id,
      settled_at = statement_timestamp(),
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

  return public.get_party_poll_snapshot_v1(p_room_id);
end;
$$;

-- Advances only from reveal to the next betting round. Any room member may
-- trigger the deterministic transition after the reveal deadline. A duplicate
-- call that arrives after another client already advanced is a harmless no-op.
create or replace function public.advance_party_poll_round_v1(
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
  v_match public.party_matches%rowtype;
  v_round public.party_rounds%rowtype;
  v_me public.players%rowtype;
  v_next_round integer;
  v_next_index integer;
  v_performer_id uuid;
  v_witness_id uuid;
  v_challenge_id uuid;
  v_scores jsonb := '{}'::jsonb;
begin
  if p_betting_duration_seconds not between 10 and 120 then
    raise exception using errcode = '22023', message = 'INVALID_BETTING_DURATION';
  end if;

  select * into v_room
  from public.rooms
  where id = p_room_id
  for update;

  if not found or v_room.game_mode <> 'party' then
    raise exception using errcode = 'P0002', message = 'PARTY_ROOM_NOT_FOUND';
  end if;

  select * into v_me
  from public.players p
  where p.room_id = p_room_id
    and p.auth_user_id = (select auth.uid())
  order by p.joined_at desc
  limit 1;

  if v_me.id is null then
    raise exception using errcode = '42501', message = 'ROOM_MEMBERSHIP_REQUIRED';
  end if;

  if v_room.status = 'finished' then
    select coalesce(jsonb_object_agg(s.player_id::text, s.score), '{}'::jsonb)
    into v_scores
    from public.party_scores s
    where s.room_id = p_room_id;

    return jsonb_build_object(
      'finished', true,
      'room', to_jsonb(v_room),
      'scores', v_scores
    );
  end if;

  select * into v_match
  from public.party_matches
  where room_id = p_room_id
  for update;

  if v_match.room_id is null or cardinality(v_match.turn_order) = 0 then
    raise exception using errcode = 'P0001', message = 'PARTY_MATCH_NOT_STARTED';
  end if;

  select * into v_round
  from public.party_rounds
  where room_id = p_room_id
    and round_number = v_room.current_round
  for update;

  if v_round.id is null then
    raise exception using errcode = 'P0001', message = 'PARTY_ROUND_STATE_MISMATCH';
  end if;

  if v_round.phase = 'betting' then
    return public.get_party_poll_snapshot_v1(p_room_id);
  end if;

  if v_round.phase <> 'reveal' then
    raise exception using errcode = 'P0001', message = 'PARTY_POLL_INVALID_PHASE';
  end if;

  if v_round.phase_ends_at is null then
    raise exception using errcode = 'P0001', message = 'REVEAL_DEADLINE_MISSING';
  end if;

  if statement_timestamp() < v_round.phase_ends_at then
    raise exception using errcode = 'P0001', message = 'REVEAL_WINDOW_OPEN';
  end if;

  if v_room.current_round >= greatest(1, coalesce(v_room.max_rounds, 1)) then
    update public.players p
    set score = s.score,
        bank_score = s.score
    from public.party_scores s
    where s.room_id = p_room_id
      and s.player_id = p.id;

    update public.rooms
    set status = 'finished',
        round_phase = 'idle',
        phase_started_at = statement_timestamp(),
        phase_ends_at = null
    where id = p_room_id
    returning * into v_room;

    update public.party_matches
    set state_version = state_version + 1
    where room_id = p_room_id;

    select coalesce(jsonb_object_agg(s.player_id::text, s.score), '{}'::jsonb)
    into v_scores
    from public.party_scores s
    where s.room_id = p_room_id;

    return jsonb_build_object(
      'finished', true,
      'room', to_jsonb(v_room),
      'scores', v_scores
    );
  end if;

  v_next_round := v_room.current_round + 1;
  v_next_index := mod(
    coalesce(v_match.turn_index, 0) + 1,
    cardinality(v_match.turn_order)
  );
  v_performer_id := v_match.turn_order[v_next_index + 1];

  select ordered.player_id
  into v_witness_id
  from unnest(v_match.turn_order) with ordinality
    as ordered(player_id, position)
  where ordered.player_id <> v_performer_id
  order by ordered.position
  limit 1;

  select c.id into v_challenge_id
  from public.party_challenges c
  where c.enabled = true
    and c.challenge_type = 'poll'
    and not exists (
      select 1
      from public.party_rounds previous_round
      where previous_round.room_id = p_room_id
        and previous_round.challenge_id = c.id
    )
  order by random()
  limit 1;

  if v_challenge_id is null then
    select c.id into v_challenge_id
    from public.party_challenges c
    where c.enabled = true
      and c.challenge_type = 'poll'
    order by random()
    limit 1;
  end if;

  if v_challenge_id is null then
    raise exception using errcode = 'P0002', message = 'NO_POLL_CHALLENGE_AVAILABLE';
  end if;

  insert into public.party_rounds (
    room_id,
    round_number,
    performer_id,
    witness_id,
    challenge_id,
    phase,
    phase_started_at,
    phase_ends_at
  ) values (
    p_room_id,
    v_next_round,
    v_performer_id,
    v_witness_id,
    v_challenge_id,
    'betting',
    statement_timestamp(),
    statement_timestamp() + make_interval(secs => p_betting_duration_seconds)
  );

  update public.party_matches
  set turn_index = v_next_index,
      state_version = state_version + 1
  where room_id = p_room_id;

  update public.rooms
  set current_round = v_next_round,
      round_phase = 'betting',
      phase_started_at = statement_timestamp(),
      phase_ends_at = statement_timestamp()
        + make_interval(secs => p_betting_duration_seconds)
  where id = p_room_id;

  return public.get_party_poll_snapshot_v1(p_room_id);
end;
$$;

revoke all on function public.get_party_poll_snapshot_v1(uuid)
from public, anon, authenticated;
revoke all on function public.start_party_poll_v1(uuid, integer)
from public, anon, authenticated;
revoke all on function public.place_party_poll_bet_v1(
  uuid, integer, integer, uuid, double precision, double precision
) from public, anon, authenticated;
revoke all on function public.settle_party_poll_round_v1(uuid)
from public, anon, authenticated;
revoke all on function public.advance_party_poll_round_v1(uuid, integer)
from public, anon, authenticated;

grant execute on function public.get_party_poll_snapshot_v1(uuid)
to authenticated;
grant execute on function public.start_party_poll_v1(uuid, integer)
to authenticated;
grant execute on function public.place_party_poll_bet_v1(
  uuid, integer, integer, uuid, double precision, double precision
) to authenticated;
grant execute on function public.settle_party_poll_round_v1(uuid)
to authenticated;
grant execute on function public.advance_party_poll_round_v1(uuid, integer)
to authenticated;

notify pgrst, 'reload schema';

commit;
