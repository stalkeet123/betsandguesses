-- Party Count v2: soft, social and mostly verbal.
-- Retains only three lightweight physical benchmarks.

begin;

update public.party_challenges
set enabled = false
where enabled
  and challenge_type = 'count';

delete from public.party_challenges challenge
where challenge.challenge_type = 'count'
  and challenge.slug not like 'mvp2_count_%'
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
  ('mvp2_count_countries', 'How many countries can {player} name in 60 seconds?', 'English sovereign-country names only. No repeats, territories, or help.', 'countries', 100, array[8,16,26,40], 'count', 60, 0, true, 'count', 'higher', '{}'::text[], null, null),
  ('mvp2_count_us_states', 'How many U.S. states can {player} name in 60 seconds?', 'Current state names only. No repeats, abbreviations, territories, or help.', 'states', 50, array[8,16,25,36], 'count', 60, 0, true, 'count', 'higher', '{}'::text[], null, null),
  ('mvp2_count_us_presidents', 'How many U.S. presidents can {player} name in 60 seconds?', 'Name people who have served as president. Each person counts once, even across nonconsecutive terms. No repeats or help.', 'presidents', 50, array[4,8,14,22], 'count', 60, 0, true, 'count', 'higher', '{}'::text[], null, null),
  ('mvp2_count_world_capitals', 'How many world capital cities can {player} name in 60 seconds?', 'Current national capitals only. No repeats or help. The country name is not required.', 'capitals', 100, array[5,10,18,28], 'count', 60, 0, true, 'count', 'higher', '{}'::text[], null, null),
  ('mvp2_count_rappers', 'How many rappers can {player} name in 60 seconds?', 'Recognizable solo rappers or rap groups count. Aliases for the same act count once. No repeats or help.', 'rappers', 100, array[6,12,20,32], 'count', 60, 0, true, 'count', 'higher', '{}'::text[], null, null),
  ('mvp2_count_music_artists', 'How many music artists can {player} name in 60 seconds?', 'Recognizable solo artists or bands count. The same act counts once. No repeats or help.', 'artists', 120, array[8,16,27,42], 'count', 60, 0, true, 'count', 'higher', '{}'::text[], null, null),
  ('mvp2_count_movies', 'How many movie titles can {player} name in 60 seconds?', 'Distinct feature-film titles count. Sequels count when their full titles are stated. No repeats or help.', 'movies', 120, array[8,16,28,45], 'count', 60, 0, true, 'count', 'higher', '{}'::text[], null, null),
  ('mvp2_count_tv_series', 'How many TV series can {player} name in 60 seconds?', 'Distinct series titles count. Episodes, seasons, and alternate translations do not. No repeats or help.', 'shows', 100, array[6,13,22,35], 'count', 60, 0, true, 'count', 'higher', '{}'::text[], null, null),
  ('mvp2_count_superheroes', 'How many superheroes can {player} name in 60 seconds?', 'Recognizable named heroes count. A hero and their civilian identity are the same answer. No repeats or help.', 'heroes', 100, array[5,10,18,28], 'count', 60, 0, true, 'count', 'higher', '{}'::text[], null, null),
  ('mvp2_count_game_characters', 'How many video-game characters can {player} name in 60 seconds?', 'Recognizable named characters count. Alternate versions of one character count once. No repeats or help.', 'characters', 100, array[5,10,18,28], 'count', 60, 0, true, 'count', 'higher', '{}'::text[], null, null),
  ('mvp2_count_restaurant_chains', 'How many restaurant chains can {player} name in 60 seconds?', 'Recognizable restaurant or fast-food chains count. Regional branches of one brand count once. No repeats or help.', 'chains', 80, array[4,8,14,22], 'count', 60, 0, true, 'count', 'higher', '{}'::text[], null, null),
  ('mvp2_count_clothing_brands', 'How many clothing or shoe brands can {player} name in 60 seconds?', 'Brand names count; individual products and models do not. No repeats or help.', 'brands', 100, array[5,10,18,28], 'count', 60, 0, true, 'count', 'higher', '{}'::text[], null, null),
  ('mvp2_count_car_brands', 'How many car brands can {player} name in 60 seconds?', 'Current or historic manufacturers count. Models and sub-brands of the same manufacturer do not. No repeats or help.', 'brands', 80, array[4,8,14,22], 'count', 60, 0, true, 'count', 'higher', '{}'::text[], null, null),
  ('mvp2_count_social_apps', 'How many social-media or messaging apps can {player} name in 60 seconds?', 'Distinct public platforms count. Features inside one platform do not. No repeats or help.', 'apps', 60, array[4,8,13,20], 'count', 60, 0, true, 'count', 'higher', '{}'::text[], null, null),
  ('mvp2_count_nba_teams', 'How many NBA teams can {player} name in 60 seconds?', 'Current NBA teams only. City plus team name or an unmistakable nickname counts. No repeats or help.', 'teams', 40, array[5,10,17,24], 'count', 60, 0, true, 'count', 'higher', '{}'::text[], null, null),
  ('mvp2_count_nfl_teams', 'How many NFL teams can {player} name in 60 seconds?', 'Current NFL teams only. City plus team name or an unmistakable nickname counts. No repeats or help.', 'teams', 40, array[5,10,18,26], 'count', 60, 0, true, 'count', 'higher', '{}'::text[], null, null),
  ('mvp2_count_animals', 'How many animals can {player} name in 60 seconds?', 'Common animal names count. Breeds, fictional creatures, and adjective variations do not. No repeats or help.', 'animals', 120, array[8,16,28,45], 'count', 60, 0, true, 'count', 'higher', '{}'::text[], null, null),
  ('mvp2_count_pushups_set', 'How many clean push-ups can {player} do in one continuous set?', 'End the set at the first knee touch, clear form break, rest longer than three seconds, or 60 seconds. Stop if uncomfortable.', 'push-ups', 100, array[5,12,22,35], 'count', 60, 0, true, 'count', 'higher', array['clear floor']::text[], null, null),
  ('mvp2_count_squats_set', 'How many clean bodyweight squats can {player} do in one continuous set?', 'Each rep reaches about knee height and returns fully upright. End at a clear form break, rest longer than three seconds, or 60 seconds.', 'squats', 150, array[10,22,38,60], 'count', 60, 0, true, 'count', 'higher', array['clear floor']::text[], null, null),
  ('mvp2_count_one_leg', 'How many seconds can {player} balance on one foot?', 'Eyes stay open. End at the first floor touch, support-leg touch, step or hop out of place, or 60 seconds.', 'seconds', 60, array[8,18,32,48], 'count', 60, 0, true, 'count', 'higher', array['clear floor']::text[], null, null)
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

-- Host may stop a Count early when a continuous set ends or the performer
-- gives up. Non-host clients still wait for the authoritative deadline.
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
     and not v_player.is_host
     and (
       v_round.phase_ends_at is null
       or v_round.phase_ends_at > statement_timestamp()
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

revoke all on function public.open_party_result_entry_v1(uuid)
from public, anon, authenticated;
grant execute on function public.open_party_result_entry_v1(uuid)
to authenticated;

do $verification$
declare
  v_count integer;
  v_itemless integer;
  v_physical integer;
  v_bad_quiz integer;
begin
  select
    count(*),
    count(*) filter (
      where cardinality(coalesce(required_items, '{}'::text[])) = 0
    ),
    count(*) filter (
      where cardinality(coalesce(required_items, '{}'::text[])) > 0
    ),
    count(*) filter (
      where prompt_template ~* '(backward|reverse|times.table|correct steps)'
         or rules ~* '(backward|reverse|times.table|correct steps)'
    )
  into v_count, v_itemless, v_physical, v_bad_quiz
  from public.party_challenges
  where enabled
    and challenge_type = 'count';

  if v_count <> 20
     or v_itemless <> 17
     or v_physical <> 3
     or v_bad_quiz <> 0 then
    raise exception
      'Count v2 mismatch: total %, verbal %, physical %, quiz-like %',
      v_count, v_itemless, v_physical, v_bad_quiz;
  end if;
end;
$verification$;

commit;
