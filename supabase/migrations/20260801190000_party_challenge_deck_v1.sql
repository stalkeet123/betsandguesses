-- Curated Party MVP deck: 60 challenges.
-- 20 verbal + 15 physical + 10 dare + 15 attempt.
--
-- This seed is intentionally explicit. Every prompt has authored validation,
-- result semantics, betting ranges, and ordinary-item requirements.

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
  enabled,
  category,
  result_direction,
  required_items
) values
  ('countries_starting_a', 'How many countries beginning with A can {player} name in 60 seconds?', 'English country names only. No repeats or help. There are 11 accepted answers.', 'countries', 11, array[3,5,7,9], 'count', 60, 3, true, 'verbal', 'higher', '{}'::text[]),
  ('us_states_starting_m', 'How many U.S. states beginning with M can {player} name in 60 seconds?', 'State names only. No repeats or corrections after moving on. There are 8 accepted answers.', 'states', 8, array[2,3,5,7], 'count', 60, 3, true, 'verbal', 'higher', '{}'::text[]),
  ('south_american_countries', 'How many South American countries can {player} name in 60 seconds?', 'Sovereign countries only. No territories, repeats, or help. There are 12 accepted answers.', 'countries', 12, array[4,7,9,11], 'count', 60, 3, true, 'verbal', 'higher', '{}'::text[]),
  ('us_state_capitals', 'How many U.S. state capitals can {player} name in 60 seconds?', 'City names only. Each city must be a current state capital. No repeats or help.', 'capitals', 50, array[6,12,18,25], 'count', 60, 3, true, 'verbal', 'higher', '{}'::text[]),
  ('animals_starting_b', 'How many animals beginning with B can {player} name in 60 seconds?', 'Common animal names count; breeds do not. No fictional creatures, repeats, or help.', 'animals', 40, array[5,9,13,18], 'count', 60, 3, true, 'verbal', 'higher', '{}'::text[]),
  ('foods_starting_p', 'How many foods beginning with P can {player} name in 60 seconds?', 'Recognizable foods or dishes only. Brands, repeats, and adjective variations do not count.', 'foods', 40, array[5,9,13,18], 'count', 60, 3, true, 'verbal', 'higher', '{}'::text[]),
  ('jobs_starting_t', 'How many jobs beginning with T can {player} name in 60 seconds?', 'Real occupations only. Near-duplicates and titles differing only by seniority count once.', 'jobs', 30, array[4,7,10,14], 'count', 60, 3, true, 'verbal', 'higher', '{}'::text[]),
  ('kitchen_items', 'How many different things found in a kitchen can {player} name in 60 seconds?', 'Specific physical objects only. Foods, brands, repeats, and adjective variations do not count.', 'items', 50, array[8,14,20,27], 'count', 60, 3, true, 'verbal', 'higher', '{}'::text[]),
  ('airport_things', 'How many different things found at an airport can {player} name in 60 seconds?', 'Specific people, places, or physical objects count. Near-duplicates count once.', 'things', 50, array[7,12,18,25], 'count', 60, 3, true, 'verbal', 'higher', '{}'::text[]),
  ('one_word_movies', 'How many movies with one-word titles can {player} name in 60 seconds?', 'The official English title must be exactly one word. Subtitles and invented titles do not count.', 'movies', 40, array[4,7,11,16], 'count', 60, 3, true, 'verbal', 'higher', '{}'::text[]),
  ('love_song_titles', 'How many songs with the word "love" in the title can {player} name in 60 seconds?', '"Love" must appear as a separate word in the official title. No repeats or invented titles.', 'songs', 35, array[3,6,9,13], 'count', 60, 3, true, 'verbal', 'higher', '{}'::text[]),
  ('brands_starting_s', 'How many brands beginning with S can {player} name in 60 seconds?', 'Recognizable consumer brands only. Products owned by the same brand do not count separately.', 'brands', 40, array[5,9,13,18], 'count', 60, 3, true, 'verbal', 'higher', '{}'::text[]),
  ('rhyme_with_day', 'How many different words rhyming with "day" can {player} say in 60 seconds?', 'Standard English words only. Proper nouns, repeats, and simple prefix variations do not count.', 'words', 30, array[5,9,13,18], 'count', 60, 3, true, 'verbal', 'higher', '{}'::text[]),
  ('names_starting_j', 'How many first names beginning with J can {player} say in 60 seconds?', 'Established first names only. Alternate spellings of the same name count once.', 'names', 40, array[7,12,18,25], 'count', 60, 3, true, 'verbal', 'higher', '{}'::text[]),
  ('tongue_twister', 'How many times can {player} clearly say "Red leather, yellow leather" in 60 seconds?', 'Only complete, clearly spoken repetitions count. Stumbles and partial repetitions do not count.', 'repetitions', 100, array[5,9,13,18], 'count', 60, 3, true, 'verbal', 'higher', '{}'::text[]),
  ('count_by_threes', 'How many correct numbers can {player} say while counting backward from 100 by threes in 60 seconds?', 'Count correct numbers in sequence. The first mistake or correction ends the attempt.', 'numbers', 34, array[5,10,16,24], 'count', 60, 3, true, 'verbal', 'higher', '{}'::text[]),
  ('excuses_for_being_late', 'How many different excuses for being late can {player} invent in 60 seconds?', 'Each excuse needs a distinct reason. Rewording the same reason does not count.', 'excuses', 30, array[5,8,12,16], 'count', 60, 3, true, 'verbal', 'higher', '{}'::text[]),
  ('bad_first_date_lines', 'How many things you should never say on a first date can {player} invent in 60 seconds?', 'Each line must be complete and meaningfully different. Rephrases count once.', 'lines', 25, array[4,7,10,14], 'count', 60, 3, true, 'verbal', 'higher', '{}'::text[]),
  ('texting_back_excuses', 'How many excuses for not texting back can {player} invent in 60 seconds?', 'Each excuse needs a distinct reason. Rewording the same reason does not count.', 'excuses', 30, array[5,8,12,16], 'count', 60, 3, true, 'verbal', 'higher', '{}'::text[]),
  ('suspicious_searches', 'How many search histories that would be hard to explain can {player} invent in 60 seconds?', 'Each search must be complete, distinct, and safe to say aloud. Rephrases count once.', 'searches', 25, array[4,7,10,14], 'count', 60, 3, true, 'verbal', 'higher', '{}'::text[]),

  ('push_ups', 'How many clean push-ups can {player} complete in 60 seconds?', 'Chest lowers visibly and arms return to extension. Stop immediately if there is pain.', 'push-ups', 80, array[5,10,20,30], 'count', 60, 3, true, 'physical', 'higher', '{}'::text[]),
  ('squats', 'How many clean bodyweight squats can {player} complete in 60 seconds?', 'Hips lower to roughly knee height and the performer returns to a full stand.', 'squats', 100, array[10,20,30,45], 'count', 60, 3, true, 'physical', 'higher', '{}'::text[]),
  ('jumping_jacks', 'How many jumping jacks can {player} complete in 60 seconds?', 'Hands meet overhead and feet return together for one valid rep.', 'jumping jacks', 100, array[15,30,45,60], 'count', 60, 3, true, 'physical', 'higher', '{}'::text[]),
  ('knee_raises', 'How many high knees can {player} complete in 60 seconds?', 'A knee reaching waist height counts as one. Count left and right separately.', 'knees', 150, array[20,40,65,90], 'count', 60, 3, true, 'physical', 'higher', '{}'::text[]),
  ('alternating_lunges_60', 'How many alternating lunges can {player} complete in 60 seconds?', 'The back knee lowers visibly and the performer returns to standing. Each side counts as one.', 'lunges', 70, array[6,12,20,30], 'count', 60, 3, true, 'physical', 'higher', '{}'::text[]),
  ('mountain_climbers_60', 'How many mountain climbers can {player} complete in 60 seconds?', 'A knee reaching forward under the torso counts as one. Count both sides separately.', 'reps', 140, array[12,25,40,60], 'count', 60, 3, true, 'physical', 'higher', '{}'::text[]),
  ('wall_pushups_60', 'How many clean wall push-ups can {player} complete in 60 seconds?', 'Body stays straight, chest moves toward the wall, and arms return to extension.', 'wall push-ups', 120, array[12,25,40,60], 'count', 60, 3, true, 'physical', 'higher', array['wall']::text[]),
  ('calf_raises_60', 'How many calf raises can {player} complete in 60 seconds?', 'Both heels lift clearly and return to the floor for one rep. No bouncing.', 'calf raises', 120, array[15,30,45,65], 'count', 60, 3, true, 'physical', 'higher', '{}'::text[]),
  ('chair_stands_60', 'How many times can {player} stand up from a chair in 60 seconds?', 'Start seated, reach a full stand, and sit with control. Hands cannot push off the chair.', 'stands', 60, array[5,10,16,24], 'count', 60, 3, true, 'physical', 'higher', array['chair']::text[]),
  ('opposite_knee_taps_60', 'How many opposite elbow-to-knee taps can {player} complete in 60 seconds?', 'A clear elbow-to-opposite-knee touch counts as one. Alternate sides each time.', 'taps', 120, array[12,25,40,60], 'count', 60, 3, true, 'physical', 'higher', '{}'::text[]),
  ('plank_shoulder_taps_60', 'How many plank shoulder taps can {player} complete in 60 seconds?', 'From a stable plank, each hand touching the opposite shoulder counts as one.', 'taps', 100, array[10,20,35,50], 'count', 60, 3, true, 'physical', 'higher', '{}'::text[]),
  ('toe_touches', 'How many standing toe touches can {player} complete in 60 seconds?', 'Both hands reach the toes or shoes before returning upright. No forced stretching.', 'touches', 80, array[8,15,25,38], 'count', 60, 3, true, 'physical', 'higher', '{}'::text[]),
  ('wall_sit_seconds', 'How many seconds can {player} hold a wall sit?', 'Back stays against the wall and thighs stay roughly parallel. Stop at 60 seconds or any pain.', 'seconds', 60, array[10,20,35,50], 'count', 60, 3, true, 'physical', 'higher', array['wall']::text[]),
  ('plank_seconds', 'How many seconds can {player} hold a forearm plank?', 'Keep a straight body line. The attempt ends when knees touch down or form clearly breaks.', 'seconds', 60, array[10,20,35,50], 'count', 60, 3, true, 'physical', 'higher', '{}'::text[]),
  ('one_leg_balance_seconds', 'How many seconds can {player} balance on one leg?', 'The raised foot cannot touch the floor or standing leg. Eyes stay open. Stop at 60 seconds.', 'seconds', 60, array[10,20,35,50], 'count', 60, 3, true, 'physical', 'higher', '{}'::text[]),

  ('last_text_dramatic_read', 'Can {player} read their last sent text aloud like it is the climax of a movie?', 'Read the complete last sent text with a dramatic delivery. Names may be replaced with "beep"; skipping is a failure.', 'result', 1, null, 'binary', 60, 3, true, 'dare', 'binary', array['phone']::text[]),
  ('top_emojis_story', 'Can {player} explain their three most-used emojis as one believable story?', 'Show or state the three emojis, then use all three in one complete story.', 'result', 1, null, 'binary', 60, 3, true, 'dare', 'binary', array['phone']::text[]),
  ('last_search_defense', 'Can {player} reveal their last web search and defend it like a lawyer?', 'State the real last search, then give a continuous 20-second defense. Skipping is a failure.', 'result', 1, null, 'binary', 60, 3, true, 'dare', 'binary', array['phone']::text[]),
  ('recreate_last_selfie', 'Can {player} recreate the pose from their latest selfie?', 'Show the selfie to the host and hold a recognizable recreation for three seconds.', 'result', 1, null, 'binary', 60, 3, true, 'dare', 'binary', array['phone']::text[]),
  ('silent_dance', 'Can {player} dance for 20 seconds with no music and no stopping?', 'Keep deliberately dancing for the full 20 seconds. Laughing is allowed; stopping is not.', 'result', 1, null, 'binary', 60, 3, true, 'dare', 'binary', '{}'::text[]),
  ('chair_proposal', 'Can {player} deliver a serious marriage proposal to an empty chair?', 'Give a complete 20-second proposal without abandoning the performance.', 'result', 1, null, 'binary', 60, 3, true, 'dare', 'binary', array['chair']::text[]),
  ('fake_awards_speech', 'Can {player} give a 30-second acceptance speech for "Most Questionable Decisions"?', 'Stay in character and speak continuously for 30 seconds.', 'result', 1, null, 'binary', 60, 3, true, 'dare', 'binary', '{}'::text[]),
  ('chorus_acapella', 'Can {player} sing a full chorus of any song with no music?', 'Sing one recognizable complete chorus without switching songs or stopping.', 'result', 1, null, 'binary', 60, 3, true, 'dare', 'binary', '{}'::text[]),
  ('worst_pickup_line_pitch', 'Can {player} sell their worst pickup line like a luxury product?', 'Say the pickup line, then give a continuous 20-second sales pitch for it.', 'result', 1, null, 'binary', 60, 3, true, 'dare', 'binary', '{}'::text[]),
  ('fake_breakup_speech', 'Can {player} give a dramatic breakup speech to an everyday object?', 'Choose one nearby object and deliver a continuous 20-second breakup speech to it.', 'result', 1, null, 'binary', 60, 3, true, 'dare', 'binary', array['nearby object']::text[]),

  ('bottle_flip', 'On which attempt will {player} land a bottle flip?', 'Five attempts maximum. A partially filled plastic bottle must land upright and remain standing.', 'attempt', 5, null, 'attempt', 60, 5, true, 'precision', 'lower', array['plastic bottle', 'water']::text[]),
  ('paper_ball_cup', 'On which attempt will {player} land a paper ball in a cup from six feet away?', 'Five attempts maximum. The ball must enter and remain in the cup from behind the line.', 'attempt', 5, null, 'attempt', 60, 5, true, 'precision', 'lower', array['paper', 'cup']::text[]),
  ('paper_ball_trash_backwards', 'On which attempt will {player} make a backward paper-ball shot into a trash can?', 'Five attempts maximum. Release while facing away; the ball must remain inside the bin.', 'attempt', 5, null, 'attempt', 60, 5, true, 'precision', 'lower', array['paper', 'trash can']::text[]),
  ('coin_backhand_catch', 'On which attempt will {player} flip a coin and catch it on the back of the same hand?', 'Five attempts maximum. The coin must visibly flip and rest on the hand for one second.', 'attempt', 5, null, 'attempt', 60, 5, true, 'precision', 'lower', array['coin']::text[]),
  ('pen_flip_catch', 'On which attempt will {player} flip a pen one full rotation and catch it with the same hand?', 'Five attempts maximum. The pen must rotate once and be caught before touching anything else.', 'attempt', 5, null, 'attempt', 60, 5, true, 'precision', 'lower', array['pen']::text[]),
  ('spoon_handle_catch', 'On which attempt will {player} flip a spoon and catch it by the handle?', 'Five attempts maximum. The spoon must rotate visibly and only the handle may be caught.', 'attempt', 5, null, 'attempt', 60, 5, true, 'precision', 'lower', array['spoon']::text[]),
  ('card_into_cup', 'On which attempt will {player} throw a playing card into a cup from four feet away?', 'Five attempts maximum. The card must enter and remain inside the cup.', 'attempt', 5, null, 'attempt', 60, 5, true, 'precision', 'lower', array['playing card', 'cup']::text[]),
  ('sock_basket_backwards', 'On which attempt will {player} land a rolled-up sock in a basket while facing backward?', 'Five attempts maximum. Release while facing away; the sock must remain in the basket.', 'attempt', 5, null, 'attempt', 60, 5, true, 'precision', 'lower', array['rolled-up socks', 'basket']::text[]),
  ('plastic_cup_flip', 'On which attempt will {player} flip a plastic cup and land it upright?', 'Five attempts maximum. The cup must rotate visibly and remain upright.', 'attempt', 5, null, 'attempt', 60, 5, true, 'precision', 'lower', array['plastic cup']::text[]),
  ('coaster_backhand', 'On which attempt will {player} flip a coaster from a table onto the back of their hand?', 'Five attempts maximum. The coaster must flip visibly and rest on the hand for one second.', 'attempt', 5, null, 'attempt', 60, 5, true, 'precision', 'lower', array['coaster', 'table']::text[]),
  ('coin_into_mug', 'On which attempt will {player} toss a coin into a mug from four feet away?', 'Five attempts maximum. The coin must enter and remain in a sturdy mug on a soft surface.', 'attempt', 5, null, 'attempt', 60, 5, true, 'precision', 'lower', array['coin', 'sturdy mug']::text[]),
  ('bank_shot_paper_cup', 'On which attempt will {player} bank a paper ball off a wall into a cup?', 'Five attempts maximum. The ball must touch the wall once, then remain inside the cup.', 'attempt', 5, null, 'attempt', 60, 5, true, 'precision', 'lower', array['paper', 'cup', 'clear wall']::text[]),
  ('bottle_cap_into_cup', 'On which attempt will {player} flick a bottle cap into a cup from three feet away?', 'Five attempts maximum. Flick from a table; the cap must remain inside the cup.', 'attempt', 5, null, 'attempt', 60, 5, true, 'precision', 'lower', array['bottle cap', 'cup', 'table']::text[]),
  ('shoe_flip', 'On which attempt will {player} flip a shoe and land it sole-down?', 'Five attempts maximum. The shoe must rotate visibly and come to rest sole-down on clear floor.', 'attempt', 5, null, 'attempt', 60, 5, true, 'precision', 'lower', array['shoe', 'clear floor']::text[]),
  ('three_coin_stack', 'On which attempt will {player} stack three coins using only one hand?', 'Five attempts maximum. All three coins must remain in one vertical stack for two seconds.', 'attempt', 5, null, 'attempt', 60, 5, true, 'precision', 'lower', array['three coins', 'table']::text[])
on conflict (slug) do update
set prompt_template = excluded.prompt_template,
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
    required_items = excluded.required_items;

-- Retire only the known prototype rows replaced by this curated deck. Unknown
-- or developer-authored rows are deliberately left untouched.
update public.party_challenges
set enabled = false
where slug in (
  'countries',
  'movie_titles',
  'paper_cup',
  'coin_catches',
  'animals',
  'binary_tongue_twister',
  'binary_one_leg_balance',
  'binary_ten_pushups',
  'binary_alphabet_backwards',
  'binary_months_backwards',
  'binary_count_back_threes'
);

do $verification$
declare
  v_enabled_seed_count integer;
begin
  select count(*) into v_enabled_seed_count
  from public.party_challenges
  where enabled
    and slug in (
      'countries_starting_a', 'us_states_starting_m',
      'south_american_countries', 'us_state_capitals',
      'animals_starting_b', 'foods_starting_p', 'jobs_starting_t',
      'kitchen_items', 'airport_things', 'one_word_movies',
      'love_song_titles', 'brands_starting_s', 'rhyme_with_day',
      'names_starting_j', 'tongue_twister', 'count_by_threes',
      'excuses_for_being_late', 'bad_first_date_lines',
      'texting_back_excuses', 'suspicious_searches',
      'push_ups', 'squats', 'jumping_jacks', 'knee_raises',
      'alternating_lunges_60', 'mountain_climbers_60',
      'wall_pushups_60', 'calf_raises_60', 'chair_stands_60',
      'opposite_knee_taps_60', 'plank_shoulder_taps_60',
      'toe_touches', 'wall_sit_seconds', 'plank_seconds',
      'one_leg_balance_seconds', 'last_text_dramatic_read',
      'top_emojis_story', 'last_search_defense', 'recreate_last_selfie',
      'silent_dance', 'chair_proposal', 'fake_awards_speech',
      'chorus_acapella', 'worst_pickup_line_pitch',
      'fake_breakup_speech', 'bottle_flip', 'paper_ball_cup',
      'paper_ball_trash_backwards', 'coin_backhand_catch',
      'pen_flip_catch', 'spoon_handle_catch', 'card_into_cup',
      'sock_basket_backwards', 'plastic_cup_flip',
      'coaster_backhand', 'coin_into_mug', 'bank_shot_paper_cup',
      'bottle_cap_into_cup', 'shoe_flip', 'three_coin_stack'
    );

  if v_enabled_seed_count <> 60 then
    raise exception 'Party deck seed incomplete: % of 60 enabled',
      v_enabled_seed_count;
  end if;
end;
$verification$;