-- Party deck v2: replace long, privacy-heavy dares and excess fitness cards
-- with short, camera-readable, self-contained binary challenges.
-- Safe to run after the v1 deck whether or not that deck is already live.

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
  ('raise_one_eyebrow', 'Can {player} raise one eyebrow without raising the other?', 'One clear eyebrow must lift while the other stays visibly lower. One attempt; hold it for one second.', 'result', 1, null, 'binary', 8, 3, true, 'dare', 'binary', '{}'::text[]),
  ('alternating_winks', 'Can {player} wink with each eye separately?', 'Close only the left eye, reopen it, then close only the right eye. Complete both cleanly within the time.', 'result', 1, null, 'binary', 8, 3, true, 'dare', 'binary', '{}'::text[]),
  ('double_vulcan_salute', 'Can {player} make the Vulcan salute with both hands at once?', 'Both hands must show a clear split between the middle and ring fingers at the same time for one second.', 'result', 1, null, 'binary', 10, 3, true, 'dare', 'binary', '{}'::text[]),
  ('roll_tongue', 'Can {player} roll their tongue into a tube?', 'The sides of the tongue must curl upward into a visible tube and hold for one second.', 'result', 1, null, 'binary', 5, 3, true, 'dare', 'binary', '{}'::text[]),
  ('tongue_touch_nose', 'Can {player} touch their nose with their tongue?', 'The tongue must visibly touch the bottom or tip of the nose. One attempt.', 'result', 1, null, 'binary', 5, 3, true, 'dare', 'binary', '{}'::text[]),
  ('snap_both_hands', 'Can {player} snap their fingers clearly with both hands?', 'Produce one audible snap with the left hand and one with the right hand within the time.', 'result', 1, null, 'binary', 8, 3, true, 'dare', 'binary', '{}'::text[]),
  ('clear_whistle', 'Can {player} produce a clear whistle on command?', 'One clearly audible whistle must be produced before time expires.', 'result', 1, null, 'binary', 5, 3, true, 'dare', 'binary', '{}'::text[]),
  ('cross_leg_stand', 'Can {player} stand up from a cross-legged position without using their hands?', 'Start seated cross-legged on a clear, stable floor. Stand fully without hands touching the floor, body, or furniture. Skip if unsafe.', 'result', 1, null, 'binary', 15, 3, true, 'dare', 'binary', '{}'::text[]),
  ('irish_wristwatch_three', 'Can {player} say "Irish wristwatch" three times fast without a mistake?', 'Say the exact phrase three complete times in a row. Any stumble, restart, or missing word is a failure.', 'result', 1, null, 'binary', 10, 3, true, 'dare', 'binary', '{}'::text[]),
  ('toy_boat_five', 'Can {player} say "toy boat" five times fast without a mistake?', 'Say the exact phrase five complete times in a row. Any stumble, restart, or missing word is a failure.', 'result', 1, null, 'binary', 10, 3, true, 'dare', 'binary', '{}'::text[]),
  ('unique_new_york_three', 'Can {player} say "unique New York" three times fast without a mistake?', 'Say the exact phrase three complete times in a row. Any stumble, restart, or missing word is a failure.', 'result', 1, null, 'binary', 10, 3, true, 'dare', 'binary', '{}'::text[]),
  ('pat_head_rub_belly', 'Can {player} pat their head and rub their belly at the same time?', 'Keep one hand patting and the other rubbing in circles continuously for five seconds.', 'result', 1, null, 'binary', 10, 3, true, 'dare', 'binary', '{}'::text[]),
  ('problem_no_smile', 'Can {player} look into the camera and say "I was the problem" three times without smiling?', 'Face the camera and say the exact sentence three times. Smiling, laughing, hiding the face, or restarting is a failure.', 'result', 1, null, 'binary', 10, 3, true, 'dare', 'binary', '{}'::text[]),
  ('fake_cry_no_laugh', 'Can {player} fake-cry for 10 seconds without laughing?', 'Give a continuous, clearly intentional fake cry. Laughing, speaking normally, or dropping the act is a failure.', 'result', 1, null, 'binary', 10, 3, true, 'dare', 'binary', '{}'::text[]),
  ('flirty_weather', 'Can {player} give a flirty weather forecast without laughing?', 'Deliver at least one complete weather-forecast sentence directly to the camera in a deliberately flirty voice. No laughing or restart.', 'result', 1, null, 'binary', 12, 3, true, 'dare', 'binary', '{}'::text[]),
  ('villain_laugh', 'Can {player} hold an evil-villain laugh for eight seconds?', 'Maintain an intentional villain laugh continuously until time expires. Stopping, speaking, or normal laughter is a failure.', 'result', 1, null, 'binary', 8, 3, true, 'dare', 'binary', '{}'::text[]),
  ('opera_happy_birthday', 'Can {player} sing "Happy Birthday" like an opera singer without breaking character?', 'Sing at least the first two complete lines in an exaggerated opera voice. Laughing, speaking the lyrics, or restarting is a failure.', 'result', 1, null, 'binary', 12, 3, true, 'dare', 'binary', '{}'::text[]),
  ('three_kiss_sounds', 'Can {player} make three clearly different kissing sounds at the camera?', 'Make three distinct audible kissing sounds while facing the camera. Repeating the exact same sound does not count.', 'result', 1, null, 'binary', 8, 3, true, 'dare', 'binary', '{}'::text[]),
  ('seductive_full_name', 'Can {player} say their full name in a seductive movie-trailer voice without laughing?', 'Say the full name once, clearly and in character. Laughing, covering the face, or restarting is a failure.', 'result', 1, null, 'binary', 8, 3, true, 'dare', 'binary', '{}'::text[]),
  ('slow_motion_runway', 'Can {player} complete a slow-motion runway walk and turn without breaking character?', 'Take at least three slow-motion steps, make one full runway turn, and hold the final pose. Laughing or returning to normal speed is a failure.', 'result', 1, null, 'binary', 12, 3, true, 'dare', 'binary', '{}'::text[])
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

-- Retain only five broad, easy-to-understand physical benchmarks.
update public.party_challenges
set enabled = true
where slug in (
  'push_ups',
  'squats',
  'jumping_jacks',
  'plank_seconds',
  'one_leg_balance_seconds'
);

-- These v1 cards are deliberately retired, not deleted. Existing round and
-- analytics references remain valid while new rounds stop drawing them.
update public.party_challenges
set enabled = false
where slug in (
  'knee_raises',
  'alternating_lunges_60',
  'mountain_climbers_60',
  'wall_pushups_60',
  'calf_raises_60',
  'chair_stands_60',
  'opposite_knee_taps_60',
  'plank_shoulder_taps_60',
  'toe_touches',
  'wall_sit_seconds',
  'last_text_dramatic_read',
  'top_emojis_story',
  'last_search_defense',
  'recreate_last_selfie',
  'silent_dance',
  'chair_proposal',
  'fake_awards_speech',
  'chorus_acapella',
  'worst_pickup_line_pitch',
  'fake_breakup_speech'
);

-- Binary quick dares may finish immediately. Count challenges still require
-- their server timer, and only the connected host can finish any action early.
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
  from public.rooms where id = p_room_id for update;
  select * into v_round
  from public.party_rounds
  where room_id = p_room_id and round_number = v_room.current_round
  for update;
  select * into v_player
  from public.players
  where room_id = p_room_id
    and auth_user_id = (select auth.uid())
    and is_connected
  order by joined_at desc
  limit 1;
  select * into v_challenge
  from public.party_challenges where id = v_round.challenge_id;

  if v_player.id is null then
    raise exception using errcode = '42501', message = 'Room membership required';
  end if;
  if v_round.phase = 'resultEntry' then
    return public.get_party_snapshot_v1(p_room_id);
  end if;
  if v_round.phase <> 'action' then
    raise exception using errcode = '40001',
      message = 'Challenge action is not active';
  end if;
  if v_round.phase_ends_at > statement_timestamp()
     and (
       v_challenge.challenge_type not in ('attempt', 'binary')
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

revoke all on function public.open_party_result_entry_v1(uuid)
from public, anon, authenticated;
grant execute on function public.open_party_result_entry_v1(uuid)
to authenticated;

do $verification$
declare
  v_quick_dares integer;
  v_retired_enabled integer;
begin
  select count(*) into v_quick_dares
  from public.party_challenges
  where enabled
    and challenge_type = 'binary'
    and category = 'dare'
    and duration_seconds between 5 and 15
    and slug in (
      'raise_one_eyebrow', 'alternating_winks', 'double_vulcan_salute',
      'roll_tongue', 'tongue_touch_nose', 'snap_both_hands',
      'clear_whistle', 'cross_leg_stand', 'irish_wristwatch_three',
      'toy_boat_five', 'unique_new_york_three', 'pat_head_rub_belly',
      'problem_no_smile', 'fake_cry_no_laugh', 'flirty_weather',
      'villain_laugh', 'opera_happy_birthday', 'three_kiss_sounds',
      'seductive_full_name', 'slow_motion_runway'
    );

  select count(*) into v_retired_enabled
  from public.party_challenges
  where enabled
    and slug in (
      'knee_raises', 'alternating_lunges_60', 'mountain_climbers_60',
      'wall_pushups_60', 'calf_raises_60', 'chair_stands_60',
      'opposite_knee_taps_60', 'plank_shoulder_taps_60',
      'toe_touches', 'wall_sit_seconds', 'last_text_dramatic_read',
      'top_emojis_story', 'last_search_defense', 'recreate_last_selfie',
      'silent_dance', 'chair_proposal', 'fake_awards_speech',
      'chorus_acapella', 'worst_pickup_line_pitch',
      'fake_breakup_speech'
    );

  if v_quick_dares <> 20 then
    raise exception 'Quick-dare deck incomplete: % of 20 enabled',
      v_quick_dares;
  end if;
  if v_retired_enabled <> 0 then
    raise exception 'Party v1 retirement incomplete: % card(s) still enabled',
      v_retired_enabled;
  end if;
end;
$verification$;