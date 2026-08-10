# Party Challenge Deck v2

The MVP deck keeps the strongest parts of betting on a friend and removes the
fitness-app feeling and long, privacy-heavy dares from v1.

## Deck shape

| Category | Count | Betting format | Typical action time |
|---|---:|---|---:|
| Verbal | 20 | Five authored numeric ranges | 60 seconds |
| Physical | 5 | Five authored numeric ranges | 60 seconds |
| Quick dare | 20 | YES / NO | 5–15 seconds |
| Precision | 15 | First / second / third / 4–5 / fail | Up to 60 seconds |

## Quick-dare contract

Every quick dare must be:

- performed by one person while bettors only observe;
- finishable in 5–15 seconds;
- objectively recordable as success or failure;
- usable without preparation, special props, accounts, or another person;
- reversible, safe, and free of public posts, messages, purchases, or private data;
- visually understandable quickly enough to make a useful camera moment.

The host may open result entry before the timer expires for binary and attempt
challenges. Count challenges retain their authoritative server deadline.

## Quick dares

| # | Slug | Prompt | Seconds |
|---:|---|---|---:|
| 1 | raise_one_eyebrow | Can {player} raise one eyebrow without raising the other? | 8 |
| 2 | alternating_winks | Can {player} wink with each eye separately? | 8 |
| 3 | double_vulcan_salute | Can {player} make the Vulcan salute with both hands at once? | 10 |
| 4 | roll_tongue | Can {player} roll their tongue into a tube? | 5 |
| 5 | tongue_touch_nose | Can {player} touch their nose with their tongue? | 5 |
| 6 | snap_both_hands | Can {player} snap their fingers clearly with both hands? | 8 |
| 7 | clear_whistle | Can {player} produce a clear whistle on command? | 5 |
| 8 | cross_leg_stand | Can {player} stand up from a cross-legged position without using their hands? | 15 |
| 9 | irish_wristwatch_three | Can {player} say “Irish wristwatch” three times fast without a mistake? | 10 |
| 10 | toy_boat_five | Can {player} say “toy boat” five times fast without a mistake? | 10 |
| 11 | unique_new_york_three | Can {player} say “unique New York” three times fast without a mistake? | 10 |
| 12 | pat_head_rub_belly | Can {player} pat their head and rub their belly at the same time? | 10 |
| 13 | problem_no_smile | Can {player} look into the camera and say “I was the problem” three times without smiling? | 10 |
| 14 | fake_cry_no_laugh | Can {player} fake-cry for 10 seconds without laughing? | 10 |
| 15 | flirty_weather | Can {player} give a flirty weather forecast without laughing? | 12 |
| 16 | villain_laugh | Can {player} hold an evil-villain laugh for eight seconds? | 8 |
| 17 | opera_happy_birthday | Can {player} sing “Happy Birthday” like an opera singer without breaking character? | 12 |
| 18 | three_kiss_sounds | Can {player} make three clearly different kissing sounds at the camera? | 8 |
| 19 | seductive_full_name | Can {player} say their full name in a seductive movie-trailer voice without laughing? | 8 |
| 20 | slow_motion_runway | Can {player} complete a slow-motion runway walk and turn without breaking character? | 12 |

## Physical cards retained

- push_ups
- squats
- jumping_jacks
- plank_seconds
- one_leg_balance_seconds

The other ten v1 physical cards and all ten v1 dares are disabled, not deleted,
so historical rounds and analytics keep valid references.

## Source of truth

- Base deck: `supabase/migrations/20260801190000_party_challenge_deck_v1.sql`
- v2 correction: `supabase/migrations/20260801213000_party_quick_dare_deck.sql`