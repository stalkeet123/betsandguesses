-- Canonical Party MVP deck.
-- New rounds use exactly three authoring categories:
--   personality (choice), attempt, and count.
-- Legacy rows already referenced by a round are retained but disabled so old
-- recaps remain readable. Unreferenced legacy rows are removed.

begin;

alter table public.party_challenges
  drop constraint if exists party_challenges_category_valid,
  drop constraint if exists party_challenges_duration_valid,
  drop constraint if exists party_challenges_active_taxonomy_valid,
  drop constraint if exists party_challenges_active_items_valid;

-- Keep legacy category names readable for historical rounds. The active-deck
-- constraint below permits only the three MVP categories on enabled rows.
alter table public.party_challenges
  add constraint party_challenges_category_valid check (
    category in (
      'personality', 'attempt', 'count',
      'general', 'verbal', 'precision', 'physical', 'dare', 'skill', 'social'
    )
  );

update public.party_challenges
set duration_seconds = 0
where challenge_type = 'attempt';

alter table public.party_challenges
  add constraint party_challenges_duration_valid check (
    (challenge_type = 'attempt' and duration_seconds = 0)
    or (challenge_type <> 'attempt' and duration_seconds between 5 and 60)
  );

update public.party_challenges
set enabled = false
where enabled;

delete from public.party_challenges challenge
where challenge.enabled = false
  and challenge.slug not like 'mvp_%'
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
  ('mvp_personality_music_movies', 'If one had to disappear for a year, which would {player} keep?', 'Choose the one you would genuinely keep. This is hypothetical.', 'choice', 1, null, 'choice', 15, 0, true, 'personality', 'binary', '{}'::text[], 'Music', 'Movies and TV'),
  ('mvp_personality_early_late', 'Which permanent inconvenience would {player} choose?', 'Choose the option you would personally tolerate better.', 'choice', 1, null, 'choice', 15, 0, true, 'personality', 'binary', '{}'::text[], 'Always arrive 30 minutes early', 'Always arrive 10 minutes late'),
  ('mvp_personality_battery_wifi', 'Which bad day would {player} rather survive?', 'Choose the option you would personally find less painful.', 'choice', 1, null, 'choice', 15, 0, true, 'personality', 'binary', '{}'::text[], 'A phone stuck at 5% battery', 'A full day with no Wi-Fi'),
  ('mvp_personality_search_screen', 'Which reveal would {player} choose?', 'This is hypothetical. Nothing has to be shown to the group.', 'choice', 1, null, 'choice', 15, 0, true, 'personality', 'binary', '{}'::text[], 'Reveal the last five searches', 'Reveal the weekly screen-time report'),
  ('mvp_personality_socks_mosquito', 'Which tiny nightmare would {player} choose?', 'Pick the one you would rather tolerate for the stated time.', 'choice', 1, null, 'choice', 15, 0, true, 'personality', 'binary', '{}'::text[], 'Wear wet socks for two hours', 'Sleep with one mosquito in the room'),
  ('mvp_personality_meme_song', 'Which kind of fame would {player} choose?', 'Choose the life you would honestly prefer.', 'choice', 1, null, 'choice', 15, 0, true, 'personality', 'binary', '{}'::text[], 'Be famous as an embarrassing meme', 'Stay anonymous behind a hit song'),
  ('mvp_personality_whisper_shout', 'Which voice curse would {player} choose for one day?', 'Choose one. No performance is required.', 'choice', 1, null, 'choice', 15, 0, true, 'personality', 'binary', '{}'::text[], 'Only whisper', 'Only shout'),
  ('mvp_personality_caffeine_dessert', 'Which would {player} give up for a year?', 'Choose the one you could more realistically live without.', 'choice', 1, null, 'choice', 15, 0, true, 'personality', 'binary', '{}'::text[], 'Coffee and energy drinks', 'Dessert'),
  ('mvp_personality_trip_flight', 'Which travel disaster would {player} choose?', 'Pick the trip you would rather endure from start to finish.', 'choice', 1, null, 'choice', 15, 0, true, 'personality', 'binary', '{}'::text[], 'A 10-hour road trip with no music', 'A 4-hour flight beside a crying baby'),
  ('mvp_personality_hair_outfits', 'Which style gamble would {player} choose?', 'The group chooses, but the scenario stays hypothetical.', 'choice', 1, null, 'choice', 15, 0, true, 'personality', 'binary', '{}'::text[], 'Let the group choose one haircut', 'Let the group choose every outfit for a week'),
  ('mvp_personality_duck_horse', 'Which ridiculous fight would {player} choose?', 'Assume every animal is equally determined. Choose one side.', 'choice', 1, null, 'choice', 15, 0, true, 'personality', 'binary', '{}'::text[], 'One horse-sized duck', 'One hundred duck-sized horses'),
  ('mvp_personality_boss_mistake', 'Which message mistake would {player} rather make?', 'This is hypothetical. Do not send anything.', 'choice', 1, null, 'choice', 15, 0, true, 'personality', 'binary', '{}'::text[], 'Send the boss a romantic emoji', 'Call the boss Mom or Dad'),
  ('mvp_personality_listening_video', 'Which history would {player} rather project on a wall?', 'This is hypothetical. Nothing has to be opened or shown.', 'choice', 1, null, 'choice', 15, 0, true, 'personality', 'binary', '{}'::text[], 'Listening history', 'Video watch history'),
  ('mvp_personality_emoji_rules', 'Which texting rule would {player} accept for a month?', 'The rule is hypothetical and applies to every message.', 'choice', 1, null, 'choice', 15, 0, true, 'personality', 'binary', '{}'::text[], 'Use no emojis', 'Reply using only emojis'),
  ('mvp_personality_plans', 'Which friend would {player} rather make plans with?', 'Choose based on the experience, not a real person in the room.', 'choice', 1, null, 'choice', 15, 0, true, 'personality', 'binary', '{}'::text[], 'Reliable but predictable', 'Exciting but always chaotic'),
  ('mvp_personality_thoughts_laugh', 'Which life soundtrack would {player} choose?', 'Assume the effect follows you everywhere for one week.', 'choice', 1, null, 'choice', 15, 0, true, 'personality', 'binary', '{}'::text[], 'Subtitles showing every thought', 'A laugh track after every sentence'),
  ('mvp_personality_repeat_media', 'Which repeat button would {player} accept for a week?', 'The selected item is the only music or movie available for seven days.', 'choice', 1, null, 'choice', 15, 0, true, 'personality', 'binary', '{}'::text[], 'One song on repeat', 'One movie on repeat'),
  ('mvp_personality_lies', 'Which social power would {player} choose?', 'Choose the ability you would rather have permanently.', 'choice', 1, null, 'choice', 15, 0, true, 'personality', 'binary', '{}'::text[], 'Always know when someone lies', 'Always make your own lies believable'),
  ('mvp_personality_chat_photos', 'Which phone screen would {player} rather project for one minute?', 'This is hypothetical. Nothing has to be shown.', 'choice', 1, null, 'choice', 15, 0, true, 'personality', 'binary', '{}'::text[], 'The busiest group chat', 'The latest 20 camera-roll photos'),
  ('mvp_personality_contacts_photos', 'Which phone loss would {player} choose?', 'Assume there is no backup and choose the less painful loss.', 'choice', 1, null, 'choice', 15, 0, true, 'personality', 'binary', '{}'::text[], 'Lose every saved contact', 'Lose every saved photo'),

  ('mvp_attempt_cap_flip', 'On which attempt will {player} land a bottle-cap flip open-side up?', 'Five attempts maximum. Flick the cap upward from the table edge. It must rotate visibly and come to rest open-side up.', 'attempt', 5, null, 'attempt', 0, 0, true, 'attempt', 'lower', array['bottle cap', 'table']::text[], null, null),
  ('mvp_attempt_coin_edge_stop', 'On which attempt will {player} slide a coin to the perfect table edge?', 'Five attempts maximum. Release from at least one forearm length away. Part of the coin must hang past the edge without falling.', 'attempt', 5, null, 'attempt', 0, 0, true, 'attempt', 'lower', array['coin', 'table']::text[], null, null),
  ('mvp_attempt_coin_cup_catch', 'On which attempt will {player} flip a coin into a cup held in the other hand?', 'Five attempts maximum. Thumb-flip the coin above the cup rim and catch it inside the cup without it bouncing out.', 'attempt', 5, null, 'attempt', 0, 0, true, 'attempt', 'lower', array['coin', 'cup']::text[], null, null),
  ('mvp_attempt_coaster_lid', 'On which attempt will {player} land a coaster flat across a cup?', 'Five attempts maximum. Toss from one large step away. The coaster must come to rest unsupported across the cup opening.', 'attempt', 5, null, 'attempt', 0, 0, true, 'attempt', 'lower', array['coaster', 'cup']::text[], null, null),
  ('mvp_attempt_paper_bank_cup', 'On which attempt will {player} bank a paper ball off the wall into a cup?', 'Five attempts maximum. The paper ball must touch the clear wall first, then enter and remain in the cup.', 'attempt', 5, null, 'attempt', 0, 0, true, 'attempt', 'lower', array['paper', 'cup', 'clear wall']::text[], null, null),
  ('mvp_attempt_paper_bounce_cup', 'On which attempt will {player} bounce a paper ball into a cup?', 'Five attempts maximum. The paper ball must bounce exactly once on the table, then enter and remain in the cup.', 'attempt', 5, null, 'attempt', 0, 0, true, 'attempt', 'lower', array['paper', 'cup', 'table']::text[], null, null),
  ('mvp_attempt_pen_opposite_catch', 'On which attempt will {player} flip a pen from one hand and catch it with the other?', 'Five attempts maximum. The pen must make one visible full rotation and be caught cleanly before touching anything else.', 'attempt', 5, null, 'attempt', 0, 0, true, 'attempt', 'lower', array['pen']::text[], null, null),
  ('mvp_attempt_spoon_handle_catch', 'On which attempt will {player} flip a spoon and catch only the handle?', 'Five attempts maximum. The spoon must rotate visibly; the catching hand may touch only the handle before control is established.', 'attempt', 5, null, 'attempt', 0, 0, true, 'attempt', 'lower', array['spoon']::text[], null, null),
  ('mvp_attempt_bottle_flip', 'On which attempt will {player} land a bottle flip?', 'Five attempts maximum. Use a partly filled plastic bottle on a table. It must land upright and come to rest without support.', 'attempt', 5, null, 'attempt', 0, 0, true, 'attempt', 'lower', array['plastic bottle', 'water', 'table']::text[], null, null),
  ('mvp_attempt_coin_bounce_cup', 'On which attempt will {player} bounce a coin into a cup?', 'Five attempts maximum. Bounce the coin once on the table; it must enter and remain in the cup.', 'attempt', 5, null, 'attempt', 0, 0, true, 'attempt', 'lower', array['coin', 'cup', 'table']::text[], null, null),
  ('mvp_attempt_backward_bin', 'On which attempt will {player} land a backward paper-ball shot?', 'Five attempts maximum. Stand two large steps from the trash can, face away, throw over one shoulder, and leave the ball inside.', 'attempt', 5, null, 'attempt', 0, 0, true, 'attempt', 'lower', array['paper', 'trash can']::text[], null, null),
  ('mvp_attempt_spoon_bowl_landing', 'On which attempt will {player} land a spoon flip bowl-side up?', 'Five attempts maximum. Flip from the handle above the table. The spoon must make a full rotation and come to rest bowl-side up on the table.', 'attempt', 5, null, 'attempt', 0, 0, true, 'attempt', 'lower', array['spoon', 'table']::text[], null, null),
  ('mvp_attempt_pen_claw_catch', 'On which attempt will {player} make a reverse pen catch?', 'Five attempts maximum. Toss the pen above the hand, turn the palm fully downward, and catch it before it touches anything else.', 'attempt', 5, null, 'attempt', 0, 0, true, 'attempt', 'lower', array['pen']::text[], null, null),
  ('mvp_attempt_card_into_cup', 'On which attempt will {player} toss a playing card into a cup?', 'Five attempts maximum. Throw from two large steps away. The card must enter and remain in the cup.', 'attempt', 5, null, 'attempt', 0, 0, true, 'attempt', 'lower', array['playing card', 'cup']::text[], null, null),
  ('mvp_attempt_sock_basket', 'On which attempt will {player} land a sock shot in the basket?', 'Five attempts maximum. Throw one rolled-up pair from three large steps away. It must remain inside the basket.', 'attempt', 5, null, 'attempt', 0, 0, true, 'attempt', 'lower', array['rolled-up socks', 'basket']::text[], null, null),
  ('mvp_attempt_cap_flick_cup', 'On which attempt will {player} flick a bottle cap into a cup?', 'Five attempts maximum. Start the cap flat on the table, flick it with one finger, and leave it inside the cup.', 'attempt', 5, null, 'attempt', 0, 0, true, 'attempt', 'lower', array['bottle cap', 'cup', 'table']::text[], null, null),
  ('mvp_attempt_paper_ball_cup', 'On which attempt will {player} land a paper ball in a cup?', 'Five attempts maximum. Throw from two large steps away. The paper ball must enter and remain in the cup.', 'attempt', 5, null, 'attempt', 0, 0, true, 'attempt', 'lower', array['paper', 'cup']::text[], null, null),
  ('mvp_attempt_shoe_flip', 'On which attempt will {player} land a shoe flip?', 'Five attempts maximum. Flip the shoe from the toe using one hand. It must land sole-down inside the clear area.', 'attempt', 5, null, 'attempt', 0, 0, true, 'attempt', 'lower', array['shoe', 'clear floor']::text[], null, null),
  ('mvp_attempt_coin_drop_catch', 'On which attempt will {player} catch a falling coin with the same hand?', 'Five attempts maximum. Slide the coin off the table with one hand and catch it with that same hand before it reaches the floor.', 'attempt', 5, null, 'attempt', 0, 0, true, 'attempt', 'lower', array['coin', 'table']::text[], null, null),
  ('mvp_attempt_three_coin_elbow', 'On which attempt will {player} catch three coins from the elbow?', 'Five attempts maximum. Stack three coins on one elbow, drop the arm, and catch all three in that same hand before any hit the floor.', 'attempt', 5, null, 'attempt', 0, 0, true, 'attempt', 'lower', array['three coins']::text[], null, null),

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

-- Keep the session rhythm balanced even when no props were selected:
-- Count -> Attempt -> Personality, then repeat. The guard also rejects an
-- already-used random pick whenever an unused eligible card exists.
create or replace function public.enforce_party_challenge_items_v1()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_items text[] := '{}'::text[];
  v_required text[] := '{}'::text[];
  v_category text;
  v_expected_category text;
  v_replacement uuid;
  v_already_used boolean := false;
begin
  v_expected_category := case mod(greatest(new.round_number, 1) - 1, 3)
    when 0 then 'count'
    when 1 then 'attempt'
    else 'personality'
  end;

  select coalesce(room.party_available_items, '{}'::text[])
  into v_items
  from public.rooms room
  where room.id = new.room_id
    and room.game_mode = 'party';

  select
    coalesce(challenge.required_items, '{}'::text[]),
    challenge.category
  into v_required, v_category
  from public.party_challenges challenge
  where challenge.id = new.challenge_id;

  select exists (
    select 1
    from public.party_rounds previous_round
    where previous_round.room_id = new.room_id
      and previous_round.challenge_id = new.challenge_id
      and previous_round.id is distinct from new.id
  ) into v_already_used;

  if v_required <@ v_items
     and v_category = v_expected_category
     and not v_already_used then
    return new;
  end if;

  select challenge.id
  into v_replacement
  from public.party_challenges challenge
  where challenge.enabled
    and challenge.category = v_expected_category
    and coalesce(challenge.required_items, '{}'::text[]) <@ v_items
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

  -- This branch matters only for unusually long matches that exhaust a type.
  if v_replacement is null then
    select challenge.id
    into v_replacement
    from public.party_challenges challenge
    where challenge.enabled
      and challenge.category = v_expected_category
      and coalesce(challenge.required_items, '{}'::text[]) <@ v_items
      and challenge.id <> new.challenge_id
    order by random()
    limit 1;
  end if;

  if v_replacement is null then
    select challenge.id
    into v_replacement
    from public.party_challenges challenge
    where challenge.enabled
      and coalesce(challenge.required_items, '{}'::text[]) <@ v_items
      and challenge.id <> new.challenge_id
    order by random()
    limit 1;
  end if;

  if v_replacement is null then
    raise exception using errcode = 'P0002',
      message = 'No Party challenge matches the available items';
  end if;

  new.challenge_id := v_replacement;
  return new;
end;
$$;

revoke all on function public.enforce_party_challenge_items_v1()
from public, anon, authenticated;

drop trigger if exists party_round_items_guard on public.party_rounds;
create trigger party_round_items_guard
before insert or update of challenge_id on public.party_rounds
for each row execute function public.enforce_party_challenge_items_v1();

alter table public.party_challenges
  add constraint party_challenges_active_taxonomy_valid check (
    not enabled
    or (challenge_type = 'choice' and category = 'personality')
    or (challenge_type = 'attempt' and category = 'attempt')
    or (challenge_type = 'count' and category = 'count')
  ),
  add constraint party_challenges_active_items_valid check (
    not enabled
    or coalesce(required_items, '{}'::text[]) <@ array[
      'phone', 'chair', 'paper', 'cup', 'plastic cup', 'sturdy mug',
      'plastic bottle', 'water', 'coin', 'three coins', 'pen', 'spoon',
      'playing card', 'rolled-up socks', 'basket', 'trash can', 'table',
      'wall', 'clear wall', 'clear floor', 'coaster', 'bottle cap', 'shoe'
    ]::text[]
  );

do $verification$
declare
  v_total integer;
  v_personality integer;
  v_attempt integer;
  v_count integer;
  v_itemless integer;
  v_bad_prompts integer;
begin
  select
    count(*),
    count(*) filter (
      where challenge_type = 'choice' and category = 'personality'
    ),
    count(*) filter (
      where challenge_type = 'attempt' and category = 'attempt'
    ),
    count(*) filter (
      where challenge_type = 'count' and category = 'count'
    ),
    count(*) filter (
      where cardinality(coalesce(required_items, '{}'::text[])) = 0
    )
  into v_total, v_personality, v_attempt, v_count, v_itemless
  from public.party_challenges
  where enabled;

  select count(*) - count(distinct prompt_template)
  into v_bad_prompts
  from public.party_challenges
  where enabled;

  if v_total <> 60
     or v_personality <> 20
     or v_attempt <> 20
     or v_count <> 20 then
    raise exception
      'Party MVP deck mismatch: total %, personality %, attempt %, count %',
      v_total, v_personality, v_attempt, v_count;
  end if;

  if v_itemless < 28 then
    raise exception
      'Party MVP needs at least 28 itemless cards, found %', v_itemless;
  end if;

  if v_bad_prompts <> 0 then
    raise exception 'Party MVP contains % duplicate prompts', v_bad_prompts;
  end if;
end;
$verification$;

commit;
