-- Attempt challenges are resolved by the first successful try (1..5), not by
-- a clock. Count challenges retain their authored timer.

begin;

alter table public.party_challenges
  drop constraint if exists party_challenges_duration_valid;

update public.party_challenges
set duration_seconds = 0
where challenge_type = 'attempt';

alter table public.party_challenges
  add constraint party_challenges_duration_valid check (
    (challenge_type = 'attempt' and duration_seconds = 0)
    or (challenge_type <> 'attempt' and duration_seconds between 5 and 60)
  );

-- Also self-heal a database that already ran the earlier draft deck.
update public.party_challenges
set enabled = false
where slug in (
  'mvp_attempt_alphabet_reverse',
  'mvp_attempt_months_reverse',
  'mvp_attempt_count_by_three',
  'mvp_attempt_number_letter',
  'mvp_attempt_five_b_countries',
  'mvp_attempt_unique_new_york',
  'mvp_attempt_finger_sequence',
  'mvp_attempt_odds_reverse',
  'mvp_attempt_opposite_fingers',
  'mvp_attempt_days_with_claps',
  'mvp_attempt_spoon_balance'
);

delete from public.party_challenges challenge
where challenge.slug in (
    'mvp_attempt_alphabet_reverse',
    'mvp_attempt_months_reverse',
    'mvp_attempt_count_by_three',
    'mvp_attempt_number_letter',
    'mvp_attempt_five_b_countries',
    'mvp_attempt_unique_new_york',
  'mvp_attempt_finger_sequence',
  'mvp_attempt_odds_reverse',
    'mvp_attempt_opposite_fingers',
    'mvp_attempt_days_with_claps',
    'mvp_attempt_spoon_balance'
  )
  and not exists (
    select 1
    from public.party_rounds round_row
    where round_row.challenge_id = challenge.id
  );

insert into public.party_challenges (
  slug, prompt_template, rules, answer_unit, max_result, bet_boundaries,
  challenge_type, duration_seconds, performer_success_bonus, enabled,
  category, result_direction, required_items, option_a, option_b
) values
  ('mvp_attempt_cap_flip', 'On which attempt will {player} land a bottle-cap flip open-side up?', 'Five attempts maximum. Flick the cap upward from the table edge. It must rotate visibly and come to rest open-side up.', 'attempt', 5, null, 'attempt', 0, 0, true, 'attempt', 'lower', array['bottle cap', 'table']::text[], null, null),
  ('mvp_attempt_coin_edge_stop', 'On which attempt will {player} slide a coin to the perfect table edge?', 'Five attempts maximum. Release from at least one forearm length away. Part of the coin must hang past the edge without falling.', 'attempt', 5, null, 'attempt', 0, 0, true, 'attempt', 'lower', array['coin', 'table']::text[], null, null),
  ('mvp_attempt_coin_cup_catch', 'On which attempt will {player} flip a coin into a cup held in the other hand?', 'Five attempts maximum. Thumb-flip the coin above the cup rim and catch it inside the cup without it bouncing out.', 'attempt', 5, null, 'attempt', 0, 0, true, 'attempt', 'lower', array['coin', 'cup']::text[], null, null),
  ('mvp_attempt_coaster_lid', 'On which attempt will {player} land a coaster flat across a cup?', 'Five attempts maximum. Toss from one large step away. The coaster must come to rest unsupported across the cup opening.', 'attempt', 5, null, 'attempt', 0, 0, true, 'attempt', 'lower', array['coaster', 'cup']::text[], null, null),
  ('mvp_attempt_paper_bank_cup', 'On which attempt will {player} bank a paper ball off the wall into a cup?', 'Five attempts maximum. The paper ball must touch the clear wall first, then enter and remain in the cup.', 'attempt', 5, null, 'attempt', 0, 0, true, 'attempt', 'lower', array['paper', 'cup', 'clear wall']::text[], null, null),
  ('mvp_attempt_paper_bounce_cup', 'On which attempt will {player} bounce a paper ball into a cup?', 'Five attempts maximum. The paper ball must bounce exactly once on the table, then enter and remain in the cup.', 'attempt', 5, null, 'attempt', 0, 0, true, 'attempt', 'lower', array['paper', 'cup', 'table']::text[], null, null),
  ('mvp_attempt_pen_opposite_catch', 'On which attempt will {player} flip a pen from one hand and catch it with the other?', 'Five attempts maximum. The pen must make one visible full rotation and be caught cleanly before touching anything else.', 'attempt', 5, null, 'attempt', 0, 0, true, 'attempt', 'lower', array['pen']::text[], null, null),
  ('mvp_attempt_spoon_handle_catch', 'On which attempt will {player} flip a spoon and catch only the handle?', 'Five attempts maximum. The spoon must rotate visibly; the catching hand may touch only the handle before control is established.', 'attempt', 5, null, 'attempt', 0, 0, true, 'attempt', 'lower', array['spoon']::text[], null, null),
  ('mvp_attempt_spoon_bowl_landing', 'On which attempt will {player} land a spoon flip bowl-side up?', 'Five attempts maximum. Flip from the handle above the table. The spoon must make a full rotation and come to rest bowl-side up on the table.', 'attempt', 5, null, 'attempt', 0, 0, true, 'attempt', 'lower', array['spoon', 'table']::text[], null, null)
on conflict (slug) do update
set
  prompt_template = excluded.prompt_template,
  rules = excluded.rules,
  answer_unit = excluded.answer_unit,
  max_result = excluded.max_result,
  bet_boundaries = excluded.bet_boundaries,
  challenge_type = excluded.challenge_type,
  duration_seconds = excluded.duration_seconds,
  performer_success_bonus = excluded.performer_success_bonus,
  enabled = excluded.enabled,
  category = excluded.category,
  result_direction = excluded.result_direction,
  required_items = excluded.required_items,
  option_a = excluded.option_a,
  option_b = excluded.option_b;

update public.party_challenges
set rules =
  'Five attempts maximum. Use a partly filled plastic bottle on a table. It must land upright and come to rest without support.'
where slug = 'mvp_attempt_bottle_flip';

create or replace function public.start_party_action_v1(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room public.rooms%rowtype;
  v_round public.party_rounds%rowtype;
  v_challenge public.party_challenges%rowtype;
  v_started_at timestamptz := statement_timestamp();
  v_ends_at timestamptz;
begin
  select * into v_room
  from public.rooms
  where id = p_room_id
  for update;

  if not exists (
    select 1
    from public.players player
    where player.room_id = p_room_id
      and player.auth_user_id = (select auth.uid())
      and player.is_host
      and player.is_connected
  ) then
    raise exception using errcode = '42501',
      message = 'Host access required';
  end if;

  select * into v_round
  from public.party_rounds
  where room_id = p_room_id
    and round_number = v_room.current_round
  for update;

  if v_round.phase = 'action' then
    return public.get_party_snapshot_v1(p_room_id);
  end if;
  if v_round.phase <> 'ready' then
    raise exception using errcode = '40001',
      message = 'Performance page is not ready';
  end if;

  select * into v_challenge
  from public.party_challenges
  where id = v_round.challenge_id;

  v_ends_at := case
    when v_challenge.challenge_type = 'attempt' then null
    else v_started_at
      + make_interval(secs => v_challenge.duration_seconds)
  end;

  update public.party_rounds
  set phase = 'action',
      performer_ready_at = coalesce(performer_ready_at, v_started_at),
      phase_started_at = v_started_at,
      phase_ends_at = v_ends_at
  where id = v_round.id;

  update public.rooms
  set round_phase = 'partyAction',
      phase_started_at = v_started_at,
      phase_ends_at = v_ends_at
  where id = p_room_id;

  update public.party_matches
  set state_version = state_version + 1
  where room_id = p_room_id;

  return public.get_party_snapshot_v1(p_room_id);
end;
$$;

-- An untimed Attempt must still be closed only by the host. A null deadline
-- must never turn into permission for any spectator to advance the phase.
create or replace function public.open_party_result_entry_v1(p_room_id uuid)
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
  select * into v_room
  from public.rooms
  where id = p_room_id
  for update;

  select * into v_round
  from public.party_rounds
  where room_id = p_room_id
    and round_number = v_room.current_round
  for update;

  select * into v_player
  from public.players
  where room_id = p_room_id
    and auth_user_id = (select auth.uid())
    and is_connected
  order by joined_at desc
  limit 1;

  select * into v_challenge
  from public.party_challenges
  where id = v_round.challenge_id;

  if v_player.id is null then
    raise exception using errcode = '42501',
      message = 'Room membership required';
  end if;
  if v_round.phase = 'resultEntry' then
    return public.get_party_snapshot_v1(p_room_id);
  end if;
  if v_round.phase <> 'action' then
    raise exception using errcode = '40001',
      message = 'Challenge action is not active';
  end if;

  if v_challenge.challenge_type = 'attempt'
     and not v_player.is_host then
    raise exception using errcode = '42501',
      message = 'Only the host can finish an Attempt';
  end if;

  if v_challenge.challenge_type <> 'attempt'
     and v_round.phase_ends_at > statement_timestamp()
     and (
       v_challenge.challenge_type <> 'binary'
       or not v_player.is_host
     ) then
    raise exception using errcode = '40001',
      message = 'Challenge is still active';
  end if;

  update public.party_rounds
  set phase = 'resultEntry',
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

revoke all on function public.start_party_action_v1(uuid)
from public, anon, authenticated;
revoke all on function public.open_party_result_entry_v1(uuid)
from public, anon, authenticated;
grant execute on function public.start_party_action_v1(uuid)
to authenticated;
grant execute on function public.open_party_result_entry_v1(uuid)
to authenticated;

do $verification$
declare
  v_start_definition text;
  v_finish_definition text;
  v_enabled_attempts integer;
  v_itemless_attempts integer;
  v_timed_attempt_text integer;
begin
  select pg_get_functiondef(
    'public.start_party_action_v1(uuid)'::regprocedure
  ) into v_start_definition;
  select pg_get_functiondef(
    'public.open_party_result_entry_v1(uuid)'::regprocedure
  ) into v_finish_definition;

  if v_start_definition not ilike
     '%challenge_type = ''attempt'' then null%' then
    raise exception 'Attempt action still creates a deadline';
  end if;

  if v_finish_definition not ilike
     '%Only the host can finish an Attempt%' then
    raise exception 'Untimed Attempt host guard is missing';
  end if;

  select
    count(*),
    count(*) filter (
      where cardinality(coalesce(required_items, '{}'::text[])) = 0
    ),
    count(*) filter (
      where prompt_template ~* '\m(seconds?|minutes?|timer)\M'
         or rules ~* '\m(seconds?|minutes?|timer)\M'
    )
  into v_enabled_attempts, v_itemless_attempts, v_timed_attempt_text
  from public.party_challenges
  where enabled
    and challenge_type = 'attempt';

  if v_enabled_attempts <> 20
     or v_itemless_attempts <> 0
     or v_timed_attempt_text <> 0
     or exists (
       select 1
       from public.party_challenges
       where enabled
         and challenge_type = 'attempt'
         and duration_seconds <> 0
     ) then
    raise exception
      'Attempt deck mismatch: enabled %, itemless %, timed text %',
      v_enabled_attempts, v_itemless_attempts, v_timed_attempt_text;
  end if;
end;
$verification$;

commit;
