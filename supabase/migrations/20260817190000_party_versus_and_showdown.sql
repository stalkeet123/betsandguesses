-- Party Mode: Versus and Showdown Challenges.
-- Introduces 1v1 duels (versus) and full-room competitions (showdown)
-- where betting board slots correspond directly to players in the room.

begin;

alter table public.party_challenges
  drop constraint if exists party_challenges_type_valid,
  drop constraint if exists party_challenges_category_valid,
  drop constraint if exists party_challenges_duration_valid,
  drop constraint if exists party_challenges_active_taxonomy_valid,
  drop constraint if exists party_challenges_bet_boundaries_valid,
  drop constraint if exists party_challenges_type_direction_valid,
  drop constraint if exists party_challenges_choice_options_valid;

alter table public.party_challenges
  add constraint party_challenges_type_valid check (
    challenge_type in ('count', 'binary', 'attempt', 'choice', 'versus', 'showdown')
  ),
  add constraint party_challenges_category_valid check (
    category in (
      'personality', 'attempt', 'count', 'versus', 'showdown',
      'general', 'verbal', 'precision', 'physical', 'dare', 'skill', 'social'
    )
  ),
  add constraint party_challenges_duration_valid check (
    (challenge_type = 'attempt' and duration_seconds = 0)
    or (challenge_type in ('versus', 'showdown') and duration_seconds between 0 and 90)
    or (challenge_type not in ('attempt', 'versus', 'showdown') and duration_seconds between 5 and 60)
  ),
  add constraint party_challenges_type_direction_valid check (
    (challenge_type in ('binary', 'choice', 'versus') and result_direction = 'binary')
    or (challenge_type = 'attempt' and result_direction = 'lower')
    or (challenge_type in ('count', 'showdown') and result_direction in ('higher', 'lower'))
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
      challenge_type = 'showdown'
      and bet_boundaries is null
      and max_result = 7
    )
  ),
  add constraint party_challenges_choice_options_valid check (
    (
      challenge_type = 'choice'
      and nullif(btrim(option_a), '') is not null
      and nullif(btrim(option_b), '') is not null
      and option_a <> option_b
    )
    or (
      challenge_type <> 'choice'
      and option_a is null
      and option_b is null
    )
  ),
  add constraint party_challenges_active_taxonomy_valid check (
    not enabled
    or (challenge_type = 'choice' and category = 'personality')
    or (challenge_type = 'attempt' and category = 'attempt')
    or (challenge_type = 'count' and category = 'count')
    or (challenge_type = 'versus' and category = 'versus')
    or (challenge_type = 'showdown' and category = 'showdown')
  );

-- Insert 15 Versus Challenges (1v1 Duels)
insert into public.party_challenges (
  slug, prompt_template, rules, answer_unit, max_result, bet_boundaries,
  challenge_type, duration_seconds, performer_success_bonus, enabled,
  category, result_direction, required_items, option_a, option_b
) values
  ('party_versus_thumb_war', 'Who will win the 3-round Thumb War duel between {player} and {witness}?', 'Best of 3 thumb wrestling match. Host declares the victor.', 'winner', 1, null, 'versus', 30, 0, true, 'versus', 'binary', '{}'::text[], null, null),
  ('party_versus_staring_contest', 'Who will blink or laugh first in the staring contest: {player} or {witness}?', 'Sit face-to-face without smiling or blinking. First to blink or laugh loses.', 'winner', 1, null, 'versus', 45, 0, true, 'versus', 'binary', '{}'::text[], null, null),
  ('party_versus_rock_paper_scissors', 'Who will win the Best-of-5 Rock-Paper-Scissors match between {player} and {witness}?', 'Standard rock-paper-scissors, first to win 3 rounds wins.', 'winner', 1, null, 'versus', 30, 0, true, 'versus', 'binary', '{}'::text[], null, null),
  ('party_versus_wall_sit', 'Who can hold a Wall Sit longer: {player} or {witness}?', 'Back flat against the wall, thighs parallel to the ground. First to slide or stand loses.', 'winner', 1, null, 'versus', 60, 0, true, 'versus', 'binary', '{"wall"}'::text[], null, null),
  ('party_versus_flamingo_balance', 'Who can balance on one leg with eyes closed longer: {player} or {witness}?', 'Both close their eyes and lift one foot. First to drop their foot or open their eyes loses.', 'winner', 1, null, 'versus', 45, 0, true, 'versus', 'binary', '{}'::text[], null, null),
  ('party_versus_coin_spin', 'Whose spun coin will keep spinning longer: {player} or {witness}?', 'Both spin a coin simultaneously on the table. The coin that stays upright longest wins.', 'winner', 1, null, 'versus', 30, 0, true, 'versus', 'binary', '{"coin"}'::text[], null, null),
  ('party_versus_straw_drink', 'Who will finish a glass of water through a straw faster: {player} or {witness}?', 'Drink one glass of water using a straw. First empty cup wins.', 'winner', 1, null, 'versus', 30, 0, true, 'versus', 'binary', '{"cup", "water"}'::text[], null, null),
  ('party_versus_arm_wrestle', 'Who will win the arm wrestling match between {player} and {witness}?', 'Standard table arm wrestling match with elbows planted on the table.', 'winner', 1, null, 'versus', 30, 0, true, 'versus', 'binary', '{"table"}'::text[], null, null),
  ('party_versus_plank_hold', 'Who can hold a standard forearm plank longer: {player} or {witness}?', 'Standard plank position on forearms and toes. First to drop knees loses.', 'winner', 1, null, 'versus', 60, 0, true, 'versus', 'binary', '{}'::text[], null, null),
  ('party_versus_paper_plane', 'Whose paper airplane will fly further: {player} or {witness}?', 'Each builds a quick paper plane and throws from the same line.', 'winner', 1, null, 'versus', 45, 0, true, 'versus', 'binary', '{"paper"}'::text[], null, null),
  ('party_versus_clap_speed', 'Who can clap faster: {player} or {witness} in a 10-second clap duel?', '10 seconds of rapid clapping. Group judges the faster cadence.', 'winner', 1, null, 'versus', 15, 0, true, 'versus', 'binary', '{}'::text[], null, null),
  ('party_versus_whisper_challenge', 'Who can guess the secret whispered phrase faster: {player} or {witness}?', 'Host whispers a phrase to each player; fastest to say it aloud wins.', 'winner', 1, null, 'versus', 30, 0, true, 'versus', 'binary', '{}'::text[], null, null),
  ('party_versus_dice_roll', 'Who will roll a higher single die: {player} or {witness}?', 'Each rolls one die. Reroll on ties.', 'winner', 1, null, 'versus', 15, 0, true, 'versus', 'binary', '{}'::text[], null, null),
  ('party_versus_reaction_grab', 'When the Host shouts "GRAB!", who will snatch the center cup first: {player} or {witness}?', 'Both keep hands on their knees. Host calls "3-2-1.. GRAB!". First hand on the cup wins.', 'winner', 1, null, 'versus', 20, 0, true, 'versus', 'binary', '{"cup"}'::text[], null, null),
  ('party_versus_tongue_twister', 'Who can repeat the tongue twister 3 times without stumbling: {player} or {witness}?', 'Say the chosen phrase 3 times as fast as possible without error.', 'winner', 1, null, 'versus', 20, 0, true, 'versus', 'binary', '{}'::text[], null, null)
on conflict (slug) do update set
  prompt_template = excluded.prompt_template,
  rules = excluded.rules,
  challenge_type = excluded.challenge_type,
  duration_seconds = excluded.duration_seconds,
  enabled = excluded.enabled,
  category = excluded.category;

-- Insert 15 Showdown Challenges (Full Room / All Active Players)
insert into public.party_challenges (
  slug, prompt_template, rules, answer_unit, max_result, bet_boundaries,
  challenge_type, duration_seconds, performer_success_bonus, enabled,
  category, result_direction, required_items, option_a, option_b
) values
  ('party_showdown_screen_time', 'Who has the HIGHEST Screen Time on their phone today?', 'Everyone opens Settings > Screen Time. The player with the highest active hours wins.', 'player', 7, null, 'showdown', 30, 0, true, 'showdown', 'higher', '{"phone"}'::text[], null, null),
  ('party_showdown_battery_lowest', 'Who has the LOWEST phone battery percentage right now?', 'Check current battery percentage on top of phone. Lowest percentage wins.', 'player', 7, null, 'showdown', 20, 0, true, 'showdown', 'lower', '{"phone"}'::text[], null, null),
  ('party_showdown_battery_highest', 'Who has the HIGHEST phone battery percentage right now?', 'Check current battery percentage on top of phone. Highest percentage wins.', 'player', 7, null, 'showdown', 20, 0, true, 'showdown', 'higher', '{"phone"}'::text[], null, null),
  ('party_showdown_unread_messages', 'Who has the MOST unread messages in WhatsApp or Messages?', 'Check badge or unread filter count in chat apps. Highest count wins.', 'player', 7, null, 'showdown', 25, 0, true, 'showdown', 'higher', '{"phone"}'::text[], null, null),
  ('party_showdown_step_count', 'Who has walked the MOST steps today on their health app?', 'Check Apple Health / Google Fit step counter. Highest step total wins.', 'player', 7, null, 'showdown', 25, 0, true, 'showdown', 'higher', '{"phone"}'::text[], null, null),
  ('party_showdown_gallery_photos', 'Who has the MOST photos and videos stored in their camera roll?', 'Check total count at the bottom of the Photos/Gallery app. Highest count wins.', 'player', 7, null, 'showdown', 25, 0, true, 'showdown', 'higher', '{"phone"}'::text[], null, null),
  ('party_showdown_alarms_count', 'Who has the MOST alarms created in their Clock app?', 'Open Clock > Alarms and count all saved alarms. Highest count wins.', 'player', 7, null, 'showdown', 25, 0, true, 'showdown', 'higher', '{"phone"}'::text[], null, null),
  ('party_showdown_internal_clock_30s', 'Who will be CLOSEST to exactly 30 seconds with their eyes closed?', 'Everyone closes eyes. Raise your hand when you believe 30 seconds have passed. Closest hand wins.', 'player', 7, null, 'showdown', 45, 0, true, 'showdown', 'higher', '{}'::text[], null, null),
  ('party_showdown_try_not_to_laugh', 'Who will be the FIRST player to laugh or smile during the funny test?', 'Host shows a 30s funny clip or joke. The first player to laugh or smile is selected as the winner of this bet.', 'player', 7, null, 'showdown', 35, 0, true, 'showdown', 'higher', '{}'::text[], null, null),
  ('party_showdown_keychain_keys', 'Who has the MOST keys on their keychain right now?', 'Count all physical keys currently attached to your keychain. Highest count wins.', 'player', 7, null, 'showdown', 25, 0, true, 'showdown', 'higher', '{}'::text[], null, null),
  ('party_showdown_wallet_cards', 'Who has the MOST physical cards in their wallet or phone case?', 'Count credit cards, ID cards, transit cards, and loyalty cards. Highest count wins.', 'player', 7, null, 'showdown', 30, 0, true, 'showdown', 'higher', '{}'::text[], null, null),
  ('party_showdown_pocket_coins', 'Who has the MOST loose coins in their pockets or bags right now?', 'Empty all pockets and count physical coins. Highest coin count wins.', 'player', 7, null, 'showdown', 30, 0, true, 'showdown', 'higher', '{"coin"}'::text[], null, null),
  ('party_showdown_instagram_followers', 'Who has the MOST followers on Instagram?', 'Open your Instagram profile and compare follower counts. Highest count wins.', 'player', 7, null, 'showdown', 25, 0, true, 'showdown', 'higher', '{"phone"}'::text[], null, null),
  ('party_showdown_oldest_receipt', 'Who has the OLDEST receipt or slip in their wallet or bag?', 'Find the oldest dated receipt in your wallet. The furthest past date wins.', 'player', 7, null, 'showdown', 35, 0, true, 'showdown', 'higher', '{}'::text[], null, null),
  ('party_showdown_installed_apps', 'Who has the MOST total apps installed on their phone?', 'Check Settings > General > About > Applications count. Highest app count wins.', 'player', 7, null, 'showdown', 30, 0, true, 'showdown', 'higher', '{"phone"}'::text[], null, null)
on conflict (slug) do update set
  prompt_template = excluded.prompt_template,
  rules = excluded.rules,
  challenge_type = excluded.challenge_type,
  duration_seconds = excluded.duration_seconds,
  enabled = excluded.enabled,
  category = excluded.category;

commit;
