-- Complete Poll-Only Party Mode Architecture

begin;

-- 1. Drop constraints first so existing dirty rows do not block execution
alter table public.party_challenges
  drop constraint if exists party_challenges_type_valid,
  drop constraint if exists party_challenges_category_valid,
  drop constraint if exists party_challenges_active_taxonomy_valid,
  drop constraint if exists party_challenges_type_direction_valid,
  drop constraint if exists party_challenges_bet_boundaries_valid;

-- 2. Normalize and disable all non-poll challenges; enable Poll only
update public.party_challenges
set enabled = false
where challenge_type is null or challenge_type <> 'poll';

update public.party_challenges
set enabled = true,
    category = 'poll',
    result_direction = 'higher',
    max_result = 7,
    duration_seconds = 30,
    bet_boundaries = null
where challenge_type = 'poll';

-- 3. Re-add clean constraints supporting Poll
alter table public.party_challenges
  add constraint party_challenges_type_valid check (
    challenge_type in ('count', 'binary', 'attempt', 'choice', 'versus', 'showdown', 'poll')
  ),
  add constraint party_challenges_category_valid check (
    category in (
      'personality', 'attempt', 'count', 'versus', 'showdown',
      'general', 'verbal', 'precision', 'physical', 'dare', 'skill', 'social', 'poll'
    )
  ),
  add constraint party_challenges_type_direction_valid check (
    (challenge_type in ('binary', 'choice', 'versus') and result_direction = 'binary')
    or (challenge_type = 'attempt' and result_direction = 'lower')
    or (challenge_type in ('count', 'showdown', 'poll') and result_direction in ('higher', 'lower'))
  ),
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
      challenge_type in ('binary', 'choice', 'versus')
      and bet_boundaries is null
      and max_result = 1
    )
    or (
      challenge_type = 'attempt'
      and bet_boundaries is null
      and max_result = 5
      and result_direction = 'lower'
    )
    or (
      challenge_type in ('showdown', 'poll')
      and bet_boundaries is null
      and max_result = 7
    )
  ),
  add constraint party_challenges_active_taxonomy_valid check (
    not enabled
    or (challenge_type = 'poll' and category = 'poll')
    or (challenge_type = 'choice' and category = 'personality')
    or (challenge_type = 'attempt' and category = 'attempt')
    or (challenge_type = 'count' and category = 'count')
    or (challenge_type = 'versus' and category = 'versus')
    or (challenge_type = 'showdown' and category = 'showdown')
  );

-- 4. Upsert 20 English Poll Challenges (Strictly valid underscore slugs)
insert into public.party_challenges (
  slug, challenge_type, category, rules, prompt_template, answer_unit, max_result,
  duration_seconds, bet_boundaries, performer_success_bonus, enabled
) values
('poll_1', 'poll', 'poll', 'Majority Rules', 'Who is most likely to text their ex tonight?', 'player', 7, 30, null, 15, true),
('poll_2', 'poll', 'poll', 'Majority Rules', 'Who dies first in a zombie apocalypse?', 'player', 7, 30, null, 15, true),
('poll_3', 'poll', 'poll', 'Majority Rules', 'Who cannot survive 24 hours without gossiping?', 'player', 7, 30, null, 15, true),
('poll_4', 'poll', 'poll', 'Majority Rules', 'Who has the worst road rage while driving?', 'player', 7, 30, null, 15, true),
('poll_5', 'poll', 'poll', 'Majority Rules', 'Who secretly has a crush on a friend''s partner?', 'player', 7, 30, null, 15, true),
('poll_6', 'poll', 'poll', 'Majority Rules', 'Who performs a full concert in the shower?', 'player', 7, 30, null, 15, true),
('poll_7', 'poll', 'poll', 'Majority Rules', 'Who takes the longest time getting ready for a party?', 'player', 7, 30, null, 15, true),
('poll_8', 'poll', 'poll', 'Majority Rules', 'Who is most likely to be a secret billionaire?', 'player', 7, 30, null, 15, true),
('poll_9', 'poll', 'poll', 'Majority Rules', 'Who has the purest and most innocent soul in the room?', 'player', 7, 30, null, 15, true),
('poll_10', 'poll', 'poll', 'Majority Rules', 'Who runs away first when a fight breaks out?', 'player', 7, 30, null, 15, true),
('poll_11', 'poll', 'poll', 'Majority Rules', 'Who spends the most money on completely useless things?', 'player', 7, 30, null, 15, true),
('poll_12', 'poll', 'poll', 'Majority Rules', 'Who would accidentally join a cult without realizing it?', 'player', 7, 30, null, 15, true),
('poll_13', 'poll', 'poll', 'Majority Rules', 'Who is the worst at keeping secrets?', 'player', 7, 30, null, 15, true),
('poll_14', 'poll', 'poll', 'Majority Rules', 'Who is most likely to become internet famous for something embarrassing?', 'player', 7, 30, null, 15, true),
('poll_15', 'poll', 'poll', 'Majority Rules', 'Who checks themselves out in every mirror they pass?', 'player', 7, 30, null, 15, true),
('poll_16', 'poll', 'poll', 'Majority Rules', 'Who would survive the longest on a deserted island?', 'player', 7, 30, null, 15, true),
('poll_17', 'poll', 'poll', 'Majority Rules', 'Who is most likely to show up an hour late with iced coffee?', 'player', 7, 30, null, 15, true),
('poll_18', 'poll', 'poll', 'Majority Rules', 'Who has the weirdest search history right now?', 'player', 7, 30, null, 15, true),
('poll_19', 'poll', 'poll', 'Majority Rules', 'Who is the master of dramatic overreactions?', 'player', 7, 30, null, 15, true),
('poll_20', 'poll', 'poll', 'Majority Rules', 'Who would marry for money without hesitation?', 'player', 7, 30, null, 15, true)
on conflict (slug) do update
set prompt_template = excluded.prompt_template,
    rules = excluded.rules,
    enabled = true;

-- 5. Exclusive Poll Challenge Rotation Trigger
create or replace function public.enforce_party_challenge_items_v1()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_category text;
  v_type text;
  v_replacement uuid;
  v_already_used boolean := false;
begin
  select challenge.category, challenge.challenge_type
  into v_category, v_type
  from public.party_challenges challenge
  where challenge.id = new.challenge_id;

  select exists (
    select 1
    from public.party_rounds previous_round
    where previous_round.room_id = new.room_id
      and previous_round.challenge_id = new.challenge_id
      and previous_round.id is distinct from new.id
  ) into v_already_used;

  if v_type = 'poll' and not v_already_used then
    return new;
  end if;

  -- Pick unused poll challenge
  select challenge.id
  into v_replacement
  from public.party_challenges challenge
  where challenge.enabled
    and challenge.challenge_type = 'poll'
    and challenge.id <> new.challenge_id
    and not exists (
      select 1
      from public.party_rounds previous_round
      where previous_round.room_id = new.room_id
        and previous_round.challenge_id = challenge.id
        and previous_round.id is distinct from new.id
    )
  order by random()
  limit 1;

  -- Fallback to any enabled poll challenge
  if v_replacement is null then
    select challenge.id
    into v_replacement
    from public.party_challenges challenge
    where challenge.enabled
      and challenge.challenge_type = 'poll'
      and challenge.id <> new.challenge_id
    order by random()
    limit 1;
  end if;

  if v_replacement is null then
    select challenge.id
    into v_replacement
    from public.party_challenges challenge
    where challenge.enabled
      and challenge.challenge_type = 'poll'
    order by random()
    limit 1;
  end if;

  if v_replacement is null then
    raise exception using errcode = 'P0002',
      message = 'No Party poll challenges found';
  end if;

  new.challenge_id := v_replacement;
  return new;
end;
$$;

revoke all on function public.enforce_party_challenge_items_v1() from public, anon, authenticated;

drop trigger if exists party_round_items_guard on public.party_rounds;
create trigger party_round_items_guard
before insert or update of challenge_id on public.party_rounds
for each row execute function public.enforce_party_challenge_items_v1();

-- 6. Place Bet Function for Party Mode (with 2-person limit on Poll & Performer allowed to bet)
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

  select * into v_bet
  from public.party_bets
  where room_id = p_room_id
    and round_number = v_room.current_round
    and player_id = v_player.id
    and client_action_id = p_client_action_id;

  if v_bet.id is not null then
    return to_jsonb(v_bet);
  end if;

  if v_round.phase <> 'betting'
     or (v_round.phase_ends_at is not null
         and v_round.phase_ends_at + interval '10 seconds' < statement_timestamp()) then
    return null;
  end if;

  if v_player.id = v_round.performer_id and v_challenge.challenge_type not in ('showdown', 'versus', 'poll') then
    raise exception using errcode = '42501', message = 'Performer cannot bet';
  end if;

  if p_slot_index not between 0 and 7 then
    raise exception using errcode = '22023', message = 'Invalid bet slot';
  end if;

  if v_challenge.challenge_type = 'poll' then
    if (
      select count(distinct slot_index)
      from public.party_bets
      where room_id = p_room_id
        and round_number = v_room.current_round
        and player_id = v_player.id
        and slot_index <> p_slot_index
    ) >= 2 then
      raise exception using errcode = '22023', message = 'Poll mode allows betting on at most 2 people';
    end if;
  end if;

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

  insert into public.party_bets (
    room_id, round_number, player_id, slot_index, chips,
    client_action_id, position_x, position_y
  ) values (
    p_room_id, v_room.current_round, v_player.id, p_slot_index, p_chips,
    p_client_action_id, p_position_x, p_position_y
  )
  on conflict (room_id, round_number, player_id, client_action_id) do update
  set chips = excluded.chips,
      slot_index = excluded.slot_index,
      position_x = excluded.position_x,
      position_y = excluded.position_y
  returning * into v_bet;

  return to_jsonb(v_bet);
end;
$$;

revoke all on function public.place_party_bet_v1(uuid, integer, integer, uuid, double precision, double precision) from public, anon, authenticated;
grant execute on function public.place_party_bet_v1(uuid, integer, integer, uuid, double precision, double precision) to authenticated;

-- 7. Settle Poll with Confidence Voting (1 target = 2 votes, 2 targets = 1 vote each)
create or replace function public.begin_party_poll_v1(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room public.rooms%rowtype;
  v_match public.party_matches%rowtype;
  v_round public.party_rounds%rowtype;
  v_winning_slots int[];
begin
  select * into v_room from public.rooms where id = p_room_id;
  if not found or v_room.game_mode <> 'party' then
    raise exception using errcode = 'P0002', message = 'Party room not found';
  end if;

  select * into v_round
  from public.party_rounds
  where room_id = p_room_id and round_number = v_room.current_round;

  if v_round.phase <> 'betting' then
    raise exception using errcode = 'P0003', message = 'Round is not in betting phase';
  end if;

  with player_slot_counts as (
    select player_id, count(distinct slot_index) as num_slots
    from public.party_bets
    where room_id = p_room_id and round_number = v_room.current_round
    group by player_id
  ),
  player_weighted_votes as (
    select distinct
      pb.player_id,
      pb.slot_index,
      case
        when psc.num_slots = 1 then 2
        else 1
      end as vote_weight
    from public.party_bets pb
    join player_slot_counts psc on psc.player_id = pb.player_id
    where pb.room_id = p_room_id and pb.round_number = v_room.current_round
  ),
  slot_vote_totals as (
    select slot_index, sum(vote_weight) as total_votes
    from player_weighted_votes
    group by slot_index
  ),
  max_vote as (
    select max(total_votes) as max_v from slot_vote_totals
  )
  select coalesce(array_agg(slot_index), '{}'::int[]) into v_winning_slots
  from slot_vote_totals, max_vote
  where total_votes = max_v;

  update public.party_bets
  set won = (slot_index = any(v_winning_slots))
  where room_id = p_room_id and round_number = v_room.current_round;

  update public.party_scores ps
  set score = ps.score + (
    coalesce((
      select sum(bet.chips * 2)
      from public.party_bets bet
      where bet.room_id = p_room_id
        and bet.round_number = v_room.current_round
        and bet.player_id = ps.player_id
        and bet.slot_index = any(v_winning_slots)
    ), 0)
    -
    coalesce((
      select sum(bet.chips)
      from public.party_bets bet
      where bet.room_id = p_room_id
        and bet.round_number = v_room.current_round
        and bet.player_id = ps.player_id
    ), 0)
  )
  where ps.room_id = p_room_id;

  update public.party_rounds
  set phase = 'reveal',
      proposed_result = v_winning_slots[1],
      result_submitted_by = coalesce(result_submitted_by, v_round.performer_id),
      settled_at = statement_timestamp(),
      result_confirmed_by = coalesce(v_round.performer_id, (select id from public.players where room_id = p_room_id limit 1)),
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

revoke all on function public.begin_party_poll_v1(uuid) from public, anon, authenticated;
grant execute on function public.begin_party_poll_v1(uuid) to authenticated;

notify pgrst, 'reload schema';

commit;
