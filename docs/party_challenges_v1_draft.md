#
> Superseded by the curated production catalog: [Party Challenge Deck v1](party_challenge_deck_v1.md).

 Party Challenge Deck v1 — Working Draft

This is a review document, not a production seed. Challenges move to SQL only
after their wording, fairness, boundaries, and real-world playability are
approved.

## Authoring contract

Every challenge must satisfy all of these:

- The performer controls the outcome; bettors cannot help or sabotage.
- The host can record one objective integer or a clear YES/NO.
- No special permission, sensor, account connection, or cloud upload is needed.
- Required objects must be ordinary and named in the prompt.
- The action is safe, legal, and understandable in one reading.
- A numeric challenge declares whether higher or lower is better.
- Repeated answers, outside help, and mid-round rule changes never count.

## MVP deck target

| Category | Target | Board | Performer reward |
|---|---:|---|---|
| Verbal | 20 | Five numeric ranges | Higher is better |
| Physical / endurance | 15 | Five numeric ranges | Higher is better |
| Precision / attempts | 15 | Five numeric ranges | Lower is better |
| Dare | 10 | YES / NO | Success bonus |

## Batch 1 — Verbal (20 candidates)

All candidates below use:

- challenge_type = count
- category = verbal
- result_direction = higher
- duration_seconds = 60

| # | Slug | Prompt | Counting rule | Unit | Max | Bet boundaries |
|---:|---|---|---|---|---:|---|
| 1 | countries_starting_a | How many countries beginning with A can {player} name in 60 seconds? | English country names only. No repeats or help. There are 11 accepted answers. | countries | 11 | 3, 5, 7, 9 |
| 2 | us_states_starting_m | How many U.S. states beginning with M can {player} name in 60 seconds? | State names only. No repeats or corrections after moving on. There are 8 accepted answers. | states | 8 | 2, 3, 5, 7 |
| 3 | south_american_countries | How many South American countries can {player} name in 60 seconds? | Sovereign countries only. No territories, repeats, or help. There are 12 accepted answers. | countries | 12 | 4, 7, 9, 11 |
| 4 | european_countries | How many European countries can {player} name in 60 seconds? | Use the game’s accepted country list. No repeats or help. | countries | 50 | 8, 14, 20, 28 |
| 5 | us_state_capitals | How many U.S. state capitals can {player} name in 60 seconds? | City names only. Each city must be a current state capital. No repeats or help. | capitals | 50 | 6, 12, 18, 25 |
| 6 | animals_starting_b | How many animals beginning with B can {player} name in 60 seconds? | Common animal names count; breeds do not. No fictional creatures, repeats, or help. | animals | 40 | 5, 9, 13, 18 |
| 7 | foods_starting_p | How many foods beginning with P can {player} name in 60 seconds? | Recognizable foods or dishes only. Brands, repeats, and the same food with a new adjective do not count. | foods | 40 | 5, 9, 13, 18 |
| 8 | jobs_starting_t | How many jobs beginning with T can {player} name in 60 seconds? | Real occupations only. Near-duplicates and job titles differing only by seniority count once. | jobs | 30 | 4, 7, 10, 14 |
| 9 | kitchen_items | How many different things found in a kitchen can {player} name in 60 seconds? | Specific physical objects only. No foods, brands, repeats, or adjective variations. | items | 50 | 8, 14, 20, 27 |
| 10 | airport_things | How many different things found at an airport can {player} name in 60 seconds? | Specific people, places, or physical objects count. Near-duplicates count once. | things | 50 | 7, 12, 18, 25 |
| 11 | one_word_movies | How many movies with one-word titles can {player} name in 60 seconds? | The official English title must be exactly one word. Sequels with numbers or subtitles do not count. | movies | 40 | 4, 7, 11, 16 |
| 12 | love_song_titles | How many songs with the word “love” in the title can {player} name in 60 seconds? | “Love” must appear as a separate word in the official title. No repeats or invented titles. | songs | 35 | 3, 6, 9, 13 |
| 13 | brands_starting_s | How many brands beginning with S can {player} name in 60 seconds? | Recognizable consumer brands only. Products owned by the same brand do not count separately. | brands | 40 | 5, 9, 13, 18 |
| 14 | rhyme_with_day | How many different words rhyming with “day” can {player} say in 60 seconds? | Standard English words only. Proper nouns, repeats, and the same word with a new prefix do not count. | words | 30 | 5, 9, 13, 18 |
| 15 | names_starting_j | How many first names beginning with J can {player} say in 60 seconds? | Established first names only. Alternate spellings of the same name count once. | names | 40 | 7, 12, 18, 25 |
| 16 | body_parts_starting_c | How many body parts beginning with C can {player} name in 60 seconds? | Standard English anatomical names only. Singular and plural forms count once. | body parts | 25 | 3, 5, 8, 11 |
| 17 | excuses_for_being_late | How many different excuses for being late can {player} invent in 60 seconds? | Each excuse needs a distinct reason. Rewording the same reason does not count. | excuses | 30 | 5, 8, 12, 16 |
| 18 | bad_first_date_lines | How many things you should never say on a first date can {player} invent in 60 seconds? | Each line must be meaningfully different and complete. Rephrases count once. | lines | 25 | 4, 7, 10, 14 |
| 19 | texting_back_excuses | How many excuses for not texting back can {player} invent in 60 seconds? | Each excuse needs a distinct reason. Rewording the same reason does not count. | excuses | 30 | 5, 8, 12, 16 |
| 20 | suspicious_searches | How many search histories that would be hard to explain can {player} invent in 60 seconds? | Each search must be complete, distinct, and safe to say aloud. Rephrases count once. | searches | 25 | 4, 7, 10, 14 |

## Batch 2 — Physical / endurance (15 candidates)

All candidates below use:

- challenge_type = count
- category = physical
- result_direction = higher
- duration_seconds = 60
- A performer may decline or stop for safety; the recorded result is the number
  of valid reps or seconds completed.

| # | Slug | Prompt | Counting rule | Unit | Max | Bet boundaries |
|---:|---|---|---|---|---:|---|
| 21 | push_ups_60 | How many clean push-ups can {player} complete in 60 seconds? | Chest lowers visibly and arms return to extension. Knees-down push-ups do not count. Stop if there is pain. | push-ups | 80 | 5, 10, 20, 30 |
| 22 | squats_60 | How many clean bodyweight squats can {player} complete in 60 seconds? | Hips lower to roughly knee height and the performer returns to a full stand. | squats | 100 | 10, 20, 30, 45 |
| 23 | jumping_jacks_60 | How many jumping jacks can {player} complete in 60 seconds? | Hands meet overhead and feet return together for one valid rep. | jumping jacks | 100 | 15, 30, 45, 60 |
| 24 | high_knees_60 | How many high knees can {player} complete in 60 seconds? | A knee reaching waist height counts as one. Count left and right separately. | knees | 150 | 20, 40, 65, 90 |
| 25 | alternating_lunges_60 | How many alternating lunges can {player} complete in 60 seconds? | The back knee lowers visibly and the performer returns to standing. Each side counts as one. | lunges | 70 | 6, 12, 20, 30 |
| 26 | mountain_climbers_60 | How many mountain climbers can {player} complete in 60 seconds? | A knee reaching forward under the torso counts as one. Count both sides separately. | reps | 140 | 12, 25, 40, 60 |
| 27 | wall_pushups_60 | How many clean wall push-ups can {player} complete in 60 seconds? | Body stays straight, chest moves toward the wall, and arms return to extension. | wall push-ups | 120 | 12, 25, 40, 60 |
| 28 | calf_raises_60 | How many calf raises can {player} complete in 60 seconds? | Both heels lift clearly and return to the floor for one rep. No bouncing. | calf raises | 120 | 15, 30, 45, 65 |
| 29 | chair_stands_60 | How many times can {player} stand up from a chair in 60 seconds? | Start seated, reach a full stand, and sit with control. Hands cannot push off the chair. | stands | 60 | 5, 10, 16, 24 |
| 30 | one_leg_hops_60 | How many one-leg hops can {player} complete in 60 seconds? | Use the same leg throughout. Each controlled takeoff and landing counts. Stop if balance feels unsafe. | hops | 120 | 12, 25, 45, 70 |
| 31 | plank_shoulder_taps_60 | How many plank shoulder taps can {player} complete in 60 seconds? | From a stable plank, each hand touching the opposite shoulder counts as one. | taps | 100 | 10, 20, 35, 50 |
| 32 | standing_toe_touches_60 | How many standing toe touches can {player} complete in 60 seconds? | Both hands reach the toes or shoes before returning upright. No forced stretching. | touches | 80 | 8, 15, 25, 38 |
| 33 | wall_sit_seconds | How many seconds can {player} hold a wall sit? | Back stays against the wall and thighs stay roughly parallel to the floor. Stop at 60 seconds or any pain. | seconds | 60 | 10, 20, 35, 50 |
| 34 | plank_seconds | How many seconds can {player} hold a forearm plank? | Keep a straight body line. The attempt ends when knees touch down or form clearly breaks. | seconds | 60 | 10, 20, 35, 50 |
| 35 | one_leg_balance_seconds | How many seconds can {player} balance on one leg? | The raised foot cannot touch the floor or standing leg. Eyes stay open. Stop at 60 seconds. | seconds | 60 | 10, 20, 35, 50 |
## Batch 3 — Dare / willingness (10 candidates)

These are opt-in social dares. Bettors observe only; they never choose the
performer's answer or control the success condition.

All candidates below use:

- challenge_type = binary
- category = dare
- result_direction = binary
- duration_seconds = 60
- performer_success_bonus = 3

| # | Slug | Prompt | Success rule | Required |
|---:|---|---|---|---|
| 36 | last_text_dramatic_read | Can {player} read their last sent text aloud like it is the climax of a movie? | Read the complete last sent text with a clearly dramatic delivery. Personal details may be replaced with “beep,” but skipping the dare is a failure. | Their phone |
| 37 | top_emojis_story | Can {player} explain their three most-used emojis as one believable story? | Show or state the three emojis, then use all three in one complete story. | Their phone |
| 38 | last_search_defense | Can {player} reveal their last web search and defend it like a lawyer? | State the real last search, then give a continuous 20-second defense. | Their phone |
| 39 | recreate_last_selfie | Can {player} recreate the pose from their latest selfie? | Show the selfie to the host and hold a recognizable recreation for three seconds. | Their phone |
| 40 | silent_dance | Can {player} dance for 20 seconds with no music and no stopping? | Keep deliberately dancing for the full 20 seconds. Laughing is allowed; stopping is not. | Nothing |
| 41 | chair_proposal | Can {player} deliver a serious marriage proposal to an empty chair? | Give a complete 20-second proposal without abandoning the performance. | A chair |
| 42 | fake_awards_speech | Can {player} give a 30-second acceptance speech for “Most Questionable Decisions”? | Stay in character and speak continuously for 30 seconds. | Nothing |
| 43 | chorus_acapella | Can {player} sing a full chorus of any song with no music? | Sing one recognizable complete chorus without switching songs or stopping. | Nothing |
| 44 | dating_profile_roast | Can {player} roast their own dating profile for 30 seconds? | Deliver a continuous 30-second self-roast. If they have no profile, roast their flirting style instead. | Nothing |
| 45 | fake_breakup_speech | Can {player} give a dramatic breakup speech to an everyday object? | Choose one nearby object and deliver a continuous 20-second breakup speech to it. | Any nearby object |

## Batch 4 — Precision / attempts (15 mechanic drafts)

These are the most camera-friendly challenges, but they should not be seeded
yet. They require an attempt-specific result state:

- Bets should read FIRST TRY / SECOND / THIRD / 4–5 / DOESN’T LAND.
- The host records the successful attempt number or FAILED.
- The performer receives more chips for succeeding earlier.
- Required items must be shown before betting.
- If an item is unavailable, the host must be able to reroll before bets open.

| # | Slug | Prompt | Valid success | Required | Max attempts |
|---:|---|---|---|---|---:|
| 46 | bottle_flip | On which attempt will {player} land a bottle flip? | A partially filled plastic bottle lands upright and remains standing. | Plastic bottle with water | 5 |
| 47 | paper_ball_cup | On which attempt will {player} land a paper ball in a cup from six feet away? | The ball enters and remains in the cup; the throw starts behind the marked line. | Paper and cup | 5 |
| 48 | paper_ball_trash_backwards | On which attempt will {player} make a backward paper-ball shot into a trash can? | Throw while facing away; the ball remains inside the bin. | Paper and trash can | 5 |
| 49 | coin_backhand_catch | On which attempt will {player} flip a coin and catch it on the back of the same hand? | The coin completes a visible flip and rests on the back of the hand for one second. | Coin | 5 |
| 50 | pen_flip_catch | On which attempt will {player} flip a pen one full rotation and catch it with the same hand? | The pen visibly rotates once and is caught before touching anything else. | Pen | 5 |
| 51 | spoon_handle_catch | On which attempt will {player} flip a spoon and catch it by the handle? | The spoon completes a visible rotation and only the handle is caught. | Spoon | 5 |
| 52 | card_into_cup | On which attempt will {player} throw a playing card into a cup from four feet away? | The card enters and remains inside the cup. | Playing card and cup | 5 |
| 53 | sock_basket_backwards | On which attempt will {player} land a rolled-up sock in a basket while facing backward? | The sock is released while facing away and remains in the basket. | Pair of socks and basket | 5 |
| 54 | plastic_cup_flip | On which attempt will {player} flip a plastic cup and land it upright? | The cup completes a visible rotation and remains upright. | Empty plastic cup | 5 |
| 55 | coaster_backhand | On which attempt will {player} flip a coaster from the table onto the back of their hand? | The coaster completes a visible flip and rests on the hand for one second. | Coaster and table | 5 |
| 56 | keys_into_mug | On which attempt will {player} toss their keys into a mug from four feet away? | The keys enter and remain in the mug. Use a soft landing surface under the mug. | Keys and sturdy mug | 5 |
| 57 | bank_shot_paper_cup | On which attempt will {player} bank a paper ball off a wall into a cup? | The ball touches the wall once, then enters and remains in the cup. | Paper, cup, clear wall | 5 |
| 58 | bottle_cap_into_cup | On which attempt will {player} flick a bottle cap into a cup from three feet away? | The cap is flicked from the table and remains inside the cup. | Bottle cap, cup, table | 5 |
| 59 | shoe_flip | On which attempt will {player} flip a shoe and land it sole-down? | The shoe completes a visible rotation and comes to rest sole-down. | One shoe, clear floor | 5 |
| 60 | three_coin_stack | On which attempt will {player} stack three coins using only one hand? | All three coins remain in one vertical stack for two seconds. Reset after each failed attempt. | Three coins, table | 5 |
## Review notes

- Challenges 1–16 are the dependable core.
- Challenges 17–20 carry more personality and create better clips, but need one
  real group test to calibrate boundaries.
- The category must not control the UI. challenge_type controls numeric versus
  YES/NO; result_direction controls the performer bonus. This keeps future
  categories from creating new screens.
- Precision challenges still need an explicit no-success convention before they
  are seeded. Do not hide failure behind an unexplained maximum number.
- High-consequence dares such as texting an ex, posting publicly, spending money,
  revealing private messages, or contacting a stranger belong in an optional
  opt-in pack, not the base MVP deck.