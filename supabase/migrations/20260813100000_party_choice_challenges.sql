-- Party Choice replaces newly selected binary dares with private, two-option
-- personality decisions. Friends see and bet on A/B; the performer cannot see
-- either option until betting closes and only that performer may choose.

alter table public.party_challenges
  add column if not exists option_a text,
  add column if not exists option_b text;

alter table public.party_challenges
  drop constraint if exists party_challenges_type_valid,
  drop constraint if exists party_challenges_category_valid,
  drop constraint if exists party_challenges_type_direction_valid,
  drop constraint if exists party_challenges_bet_boundaries_valid,
  drop constraint if exists party_challenges_choice_options_valid;

alter table public.party_challenges
  add constraint party_challenges_type_valid check (
    challenge_type in ('count', 'binary', 'attempt', 'choice')
  ),
  add constraint party_challenges_category_valid check (
    category in (
      'general', 'verbal', 'precision', 'physical', 'dare', 'skill', 'social'
    )
  ),
  add constraint party_challenges_type_direction_valid check (
    (challenge_type in ('binary', 'choice') and result_direction = 'binary')
    or (challenge_type = 'attempt' and result_direction = 'lower')
    or (challenge_type = 'count' and result_direction in ('higher', 'lower'))
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
      challenge_type in ('binary', 'choice')
      and bet_boundaries is null
      and max_result = 1
    )
    or (
      challenge_type = 'attempt'
      and bet_boundaries is null
      and max_result = 5
      and result_direction = 'lower'
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
  );

comment on column public.party_challenges.option_a is
  'First private Party Choice option. Hidden from the performer while betting.';
comment on column public.party_challenges.option_b is
  'Second private Party Choice option. Hidden from the performer while betting.';

-- Binary cards remain valid for an already-running legacy round, but can no
-- longer be selected for a new round or reroll.
update public.party_challenges
set enabled = false
where challenge_type = 'binary';

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
  required_items,
  option_a,
  option_b
) values
  (
    'choice_music_or_movies',
    'If one had to disappear for a year, which would {player} keep?',
    'Choose the one you would genuinely keep. Friends must not give hints after betting closes.',
    'choice', 1, null, 'choice', 5, 0, true, 'social', 'binary', '{}'::text[],
    'Music', 'Movies and TV'
  ),
  (
    'choice_early_or_late',
    'Which permanent inconvenience would {player} choose?',
    'Choose honestly. The decision is hypothetical and requires no real-world action.',
    'choice', 1, null, 'choice', 5, 0, true, 'social', 'binary', '{}'::text[],
    'Always arrive 30 minutes early', 'Always arrive 10 minutes late'
  ),
  (
    'choice_phone_or_wifi',
    'Which bad day would {player} rather survive?',
    'Choose the option you would personally find less painful.',
    'choice', 1, null, 'choice', 5, 0, true, 'social', 'binary', '{}'::text[],
    'A phone stuck at 5% battery', 'A full day with no Wi-Fi'
  ),
  (
    'choice_like_or_screenshot',
    'Which social-media disaster would {player} choose?',
    'This is hypothetical. Do not open or send anything on the phone.',
    'choice', 1, null, 'choice', 5, 0, true, 'social', 'binary', '{}'::text[],
    'Like an ex''s photo from 2018', 'Send a screenshot to the person in it'
  ),
  (
    'choice_searches_or_screen_time',
    'Which reveal would {player} choose?',
    'This is hypothetical. Nothing has to be shown to the group.',
    'choice', 1, null, 'choice', 5, 0, true, 'social', 'binary', '{}'::text[],
    'Read the last five searches aloud', 'Reveal the weekly screen-time report'
  ),
  (
    'choice_wet_socks_or_mosquito',
    'Which tiny nightmare would {player} choose?',
    'Pick the one you would rather tolerate for the stated time.',
    'choice', 1, null, 'choice', 5, 0, true, 'social', 'binary', '{}'::text[],
    'Wear wet socks for two hours', 'Sleep with one mosquito in the room'
  ),
  (
    'choice_meme_or_song',
    'Which kind of fame would {player} choose?',
    'Choose the life you would honestly prefer.',
    'choice', 1, null, 'choice', 5, 0, true, 'social', 'binary', '{}'::text[],
    'Be famous as an embarrassing meme', 'Stay anonymous behind a hit song'
  ),
  (
    'choice_whisper_or_shout',
    'Which voice curse would {player} choose for one day?',
    'Choose one; no performance is required.',
    'choice', 1, null, 'choice', 5, 0, true, 'social', 'binary', '{}'::text[],
    'Only whisper', 'Only shout'
  ),
  (
    'choice_coffee_or_dessert',
    'Which would {player} give up for a year?',
    'Choose the one you could more realistically live without.',
    'choice', 1, null, 'choice', 5, 0, true, 'social', 'binary', '{}'::text[],
    'Coffee and energy drinks', 'Desserts'
  ),
  (
    'choice_roadtrip_or_flight',
    'Which journey would {player} choose?',
    'Choose the trip you would rather endure.',
    'choice', 1, null, 'choice', 5, 0, true, 'social', 'binary', '{}'::text[],
    'An eight-hour road trip with no music', 'A four-hour flight beside a crying baby'
  ),
  (
    'choice_haircut_or_outfit',
    'Which loss of control would {player} choose?',
    'This is hypothetical. The group does not actually choose anything afterward.',
    'choice', 1, null, 'choice', 5, 0, true, 'social', 'binary', '{}'::text[],
    'The group chooses one haircut', 'The group chooses every outfit for a week'
  ),
  (
    'choice_duck_fight',
    'Which ridiculous fight would {player} choose?',
    'Assume the imaginary fight is unavoidable and nobody is seriously harmed.',
    'choice', 1, null, 'choice', 5, 0, true, 'social', 'binary', '{}'::text[],
    'One horse-sized duck', 'One hundred duck-sized horses'
  ),
  (
    'choice_boss_emoji_or_mom',
    'Which embarrassing mistake would {player} choose?',
    'This is hypothetical. No message or call is made.',
    'choice', 1, null, 'choice', 5, 0, true, 'social', 'binary', '{}'::text[],
    'Send the wrong heart emoji to the boss', 'Accidentally call the boss mom or dad'
  ),
  (
    'choice_wrapped_or_history',
    'Which digital profile would {player} rather reveal?',
    'This is hypothetical. Nothing has to be opened or shown.',
    'choice', 1, null, 'choice', 5, 0, true, 'social', 'binary', '{}'::text[],
    'The full music listening history', 'The full YouTube watch history'
  ),
  (
    'choice_no_emoji_or_only_emoji',
    'Which texting rule would {player} choose for a month?',
    'Pick the communication style you would rather live with.',
    'choice', 1, null, 'choice', 5, 0, true, 'social', 'binary', '{}'::text[],
    'Never use an emoji', 'Reply using only emojis'
  ),
  (
    'choice_reliable_or_exciting',
    'Which date would {player} choose?',
    'Choose based on your genuine preference; there is no correct social answer.',
    'choice', 1, null, 'choice', 5, 0, true, 'social', 'binary', '{}'::text[],
    'Very reliable but painfully boring', 'Very exciting but completely chaotic'
  ),
  (
    'choice_subtitles_or_laugh_track',
    'Which life feature would {player} choose?',
    'Choose the permanent feature you would rather have.',
    'choice', 1, null, 'choice', 5, 0, true, 'social', 'binary', '{}'::text[],
    'Visible subtitles for every thought', 'A laugh track after every joke'
  ),
  (
    'choice_one_song_or_movie',
    'Which entertainment curse would {player} choose for a week?',
    'Choose the option that would annoy you less.',
    'choice', 1, null, 'choice', 5, 0, true, 'social', 'binary', '{}'::text[],
    'Listen to one song on repeat', 'Watch one movie on repeat'
  ),
  (
    'choice_truth_or_lie',
    'Which social curse would {player} choose?',
    'Choose the curse you think you could handle better.',
    'choice', 1, null, 'choice', 5, 0, true, 'social', 'binary', '{}'::text[],
    'Always say exactly what you think', 'Believe every lie told confidently'
  ),
  (
    'choice_group_chat_or_camera_roll',
    'Which accidental leak would {player} choose?',
    'This is purely hypothetical. No private content is shown.',
    'choice', 1, null, 'choice', 5, 0, true, 'social', 'binary', '{}'::text[],
    'The group chat gets projected for one minute', 'The last 20 camera-roll photos get projected'
  )
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
    required_items = excluded.required_items,
    option_a = excluded.option_a,
    option_b = excluded.option_b;

-- Rebuild the private snapshot explicitly so option privacy does not depend on
-- a client convention. The performer receives null options while betting.
create or replace function public.get_party_snapshot_v1(p_room_id uuid)
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
  v_performer public.players%rowtype;
  v_witness public.players%rowtype;
  v_challenge public.party_challenges%rowtype;
  v_bets jsonb := '[]'::jsonb;
  v_scores jsonb := '{}'::jsonb;
  v_show_all_bets boolean;
  v_show_result boolean;
  v_hide_choice_options boolean;
begin
  select * into v_room from public.rooms where id = p_room_id;
  if not found or v_room.game_mode <> 'party' then
    raise exception using errcode = 'P0002', message = 'Party room not found';
  end if;

  select * into v_me
  from public.players
  where room_id = p_room_id
    and auth_user_id = (select auth.uid())
    and is_connected
  order by joined_at desc limit 1;
  if v_me.id is null then
    raise exception using errcode = '42501', message = 'Room membership required';
  end if;

  select * into v_match from public.party_matches where room_id = p_room_id;
  if v_match.room_id is null then
    return jsonb_build_object('room', to_jsonb(v_room), 'status', 'waiting');
  end if;

  select * into v_round
  from public.party_rounds
  where room_id = p_room_id and round_number = v_room.current_round;
  select * into v_performer from public.players where id = v_round.performer_id;
  select * into v_witness from public.players where id = v_round.witness_id;
  select * into v_challenge
  from public.party_challenges where id = v_round.challenge_id;

  v_show_all_bets := v_round.phase = 'reveal';
  v_show_result := v_round.phase in ('resultConfirm', 'reveal');
  v_hide_choice_options :=
    v_challenge.challenge_type = 'choice'
    and v_me.id = v_round.performer_id
    and v_round.phase = 'betting';

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', bet.id,
        'slot_index', bet.slot_index,
        'chips', bet.chips,
        'position_x', bet.position_x,
        'position_y', bet.position_y,
        'player_id', case
          when v_show_all_bets or bet.player_id = v_me.id then bet.player_id
          else null
        end
      ) order by bet.created_at, bet.id
    ) filter (where v_show_all_bets or bet.player_id = v_me.id),
    '[]'::jsonb
  ) into v_bets
  from public.party_bets bet
  where bet.room_id = p_room_id
    and bet.round_number = v_room.current_round;

  select coalesce(
    jsonb_object_agg(score.player_id::text, score.score), '{}'::jsonb
  ) into v_scores
  from public.party_scores score
  where score.room_id = p_room_id;

  return jsonb_build_object(
    'room', to_jsonb(v_room),
    'state_version', v_match.state_version,
    'turn_index', v_match.turn_index,
    'turn_count', cardinality(v_match.turn_order),
    'round', jsonb_build_object(
      'number', v_round.round_number,
      'phase', v_round.phase,
      'phase_started_at', v_round.phase_started_at,
      'phase_ends_at', v_round.phase_ends_at,
      'performer', jsonb_build_object(
        'id', v_performer.id,
        'name', v_performer.name,
        'avatar_color', v_performer.avatar_color
      ),
      'witness', case when v_witness.id is null then null else jsonb_build_object(
        'id', v_witness.id,
        'name', v_witness.name,
        'avatar_color', v_witness.avatar_color
      ) end,
      'challenge', jsonb_build_object(
        'id', v_challenge.id,
        'text', replace(v_challenge.prompt_template, '{player}', v_performer.name),
        'rules', v_challenge.rules,
        'answer_unit', v_challenge.answer_unit,
        'duration_seconds', v_challenge.duration_seconds,
        'max_result', v_challenge.max_result,
        'bet_boundaries', coalesce(to_jsonb(v_challenge.bet_boundaries), '[]'::jsonb),
        'challenge_type', v_challenge.challenge_type,
        'category', v_challenge.category,
        'result_direction', v_challenge.result_direction,
        'required_items', coalesce(to_jsonb(v_challenge.required_items), '[]'::jsonb),
        'option_a', case when v_hide_choice_options then null else v_challenge.option_a end,
        'option_b', case when v_hide_choice_options then null else v_challenge.option_b end,
        'performer_success_bonus', v_challenge.performer_success_bonus
      ),
      'submitted_guess_count', 0,
      'performer_ready', v_round.performer_ready_at is not null,
      'own_guess', null,
      'guesses', '[]'::jsonb,
      'bets', v_bets,
      'proposed_result', case
        when v_show_result then v_round.proposed_result else null
      end,
      'performer_bonus', case
        when v_round.phase = 'reveal' then v_round.performer_bonus else 0
      end
    ),
    'scores', v_scores
  );
end;
$$;

-- Choice uses the same two-slot bet storage as legacy binary, while retaining
-- all validation and idempotency behavior in the deployed bet RPCs.
do $bet_rpc_patch$
declare
  v_function regprocedure;
  v_definition text;
  v_rewritten text;
begin
  foreach v_function in array array[
    'public.place_party_bet_v1(uuid,integer,integer,uuid,double precision,double precision)'::regprocedure,
    'public.move_party_bet_v1(uuid,uuid,integer,double precision,double precision)'::regprocedure
  ] loop
    select pg_get_functiondef(v_function) into v_definition;
    v_rewritten := replace(
      v_definition,
      'v_challenge.challenge_type = ''binary''',
      'v_challenge.challenge_type in (''binary'', ''choice'')'
    );
    if v_rewritten <> v_definition then
      execute v_rewritten;
    end if;
  end loop;
end;
$bet_rpc_patch$;

-- Any room member may advance an expired betting window, preserving the
-- existing staggered fallback. Only Choice rounds may enter this branch.
create or replace function public.begin_party_choice_v1(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room public.rooms%rowtype;
  v_round public.party_rounds%rowtype;
  v_challenge public.party_challenges%rowtype;
begin
  if not public.is_room_member_v2(p_room_id) then
    raise exception using errcode = '42501', message = 'Room membership required';
  end if;
  select * into v_room from public.rooms where id = p_room_id for update;
  select * into v_round
  from public.party_rounds
  where room_id = p_room_id and round_number = v_room.current_round
  for update;
  select * into v_challenge
  from public.party_challenges where id = v_round.challenge_id;

  if v_round.phase = 'resultEntry'
     and v_challenge.challenge_type = 'choice' then
    return public.get_party_snapshot_v1(p_room_id);
  end if;
  if v_challenge.challenge_type <> 'choice' then
    raise exception using errcode = '22023', message = 'Choice challenge required';
  end if;
  if v_round.phase <> 'betting'
     or (v_round.phase_ends_at is not null
         and v_round.phase_ends_at > statement_timestamp()) then
    raise exception using errcode = '40001', message = 'Betting is still active';
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

-- Only the selected performer can submit the subjective answer. Neither host
-- status nor possession of the room code is sufficient.
create or replace function public.submit_party_choice_v1(
  p_room_id uuid,
  p_choice integer
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
begin
  if p_choice not between 0 and 1 then
    raise exception using errcode = '22023', message = 'Invalid choice';
  end if;
  select * into v_room from public.rooms where id = p_room_id for update;
  select * into v_round
  from public.party_rounds
  where room_id = p_room_id and round_number = v_room.current_round
  for update;
  select * into v_player
  from public.players
  where room_id = p_room_id
    and auth_user_id = (select auth.uid())
    and is_connected
  order by joined_at desc limit 1;
  select * into v_challenge
  from public.party_challenges where id = v_round.challenge_id;

  if v_player.id is null or v_player.id <> v_round.performer_id then
    raise exception using errcode = '42501', message = 'Performer access required';
  end if;
  if v_challenge.challenge_type <> 'choice' then
    raise exception using errcode = '22023', message = 'Choice challenge required';
  end if;
  if v_round.phase in ('resultConfirm', 'reveal')
     and v_round.proposed_result = p_choice then
    return public.get_party_snapshot_v1(p_room_id);
  end if;
  if v_round.phase <> 'resultEntry' then
    raise exception using errcode = '40001', message = 'Choice entry is not active';
  end if;

  update public.party_rounds
  set phase = 'resultConfirm',
      proposed_result = p_choice,
      result_submitted_by = v_player.id,
      phase_started_at = statement_timestamp(),
      phase_ends_at = statement_timestamp() + interval '3 seconds'
  where id = v_round.id;
  update public.rooms
  set round_phase = 'partyResultConfirm',
      phase_started_at = statement_timestamp(),
      phase_ends_at = statement_timestamp() + interval '3 seconds'
  where id = p_room_id;
  update public.party_matches
  set state_version = state_version + 1
  where room_id = p_room_id;

  return public.get_party_snapshot_v1(p_room_id);
end;
$$;

-- Objective count/attempt results still belong to the host. Choice is rejected
-- here so the dedicated performer-only RPC cannot be bypassed.
create or replace function public.submit_party_result_v1(
  p_room_id uuid,
  p_result integer
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room public.rooms%rowtype;
  v_round public.party_rounds%rowtype;
  v_host public.players%rowtype;
  v_challenge public.party_challenges%rowtype;
begin
  select * into v_room from public.rooms where id = p_room_id for update;
  select * into v_host
  from public.players
  where room_id = p_room_id
    and auth_user_id = (select auth.uid())
    and is_host and is_connected
  limit 1;
  if v_host.id is null then
    raise exception using errcode = '42501', message = 'Host access required';
  end if;

  select * into v_round
  from public.party_rounds
  where room_id = p_room_id and round_number = v_room.current_round
  for update;
  select * into v_challenge
  from public.party_challenges where id = v_round.challenge_id;

  if v_challenge.challenge_type = 'choice' then
    raise exception using errcode = '42501', message = 'Performer choice required';
  end if;
  if v_round.phase = 'resultConfirm' and v_round.proposed_result = p_result then
    return public.get_party_snapshot_v1(p_room_id);
  end if;
  if v_round.phase <> 'resultEntry' then
    raise exception using errcode = '40001', message = 'Result entry is not active';
  end if;
  if (v_challenge.challenge_type = 'binary' and p_result not between 0 and 1)
     or (v_challenge.challenge_type = 'attempt' and p_result not between 0 and 5)
     or (v_challenge.challenge_type = 'count'
         and (p_result < 0 or p_result > v_challenge.max_result)) then
    raise exception using errcode = '22023', message = 'Invalid result';
  end if;

  update public.party_rounds
  set phase = 'resultConfirm',
      proposed_result = p_result,
      result_submitted_by = v_host.id,
      phase_started_at = statement_timestamp(),
      phase_ends_at = statement_timestamp() + interval '5 seconds'
  where id = v_round.id;
  update public.rooms
  set round_phase = 'partyResultConfirm',
      phase_started_at = statement_timestamp(),
      phase_ends_at = statement_timestamp() + interval '5 seconds'
  where id = p_room_id;
  update public.party_matches
  set state_version = state_version + 1
  where room_id = p_room_id;

  return public.get_party_snapshot_v1(p_room_id);
end;
$$;
create or replace function public.confirm_party_result_v1(p_room_id uuid)
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
  v_boundaries bigint[];
  v_winning_slot integer;
  v_performer_bonus integer;
begin
  select * into v_room from public.rooms where id = p_room_id for update;
  select * into v_round
  from public.party_rounds
  where room_id = p_room_id and round_number = v_room.current_round
  for update;
  select * into v_player
  from public.players
  where room_id = p_room_id
    and auth_user_id = (select auth.uid())
    and is_connected
  order by joined_at desc limit 1;
  select * into v_challenge
  from public.party_challenges where id = v_round.challenge_id;

  if v_player.id is null then
    raise exception using errcode = '42501', message = 'Room membership required';
  end if;
  if v_round.phase = 'reveal' then
    return public.get_party_snapshot_v1(p_room_id);
  end if;
  if v_round.phase <> 'resultConfirm' or v_round.proposed_result is null then
    raise exception using errcode = '40001', message = 'Result confirmation is not active';
  end if;
  if v_round.phase_ends_at is null
     or v_round.phase_ends_at > statement_timestamp() then
    raise exception using errcode = '40001', message = 'Result review is still active';
  end if;

  if v_challenge.challenge_type = 'choice' then
    v_winning_slot := v_round.proposed_result;
    v_performer_bonus := 0;
  elsif v_challenge.challenge_type = 'binary' then
    v_winning_slot := v_round.proposed_result;
    v_performer_bonus := case
      when v_round.proposed_result = 1 then v_challenge.performer_success_bonus
      else 0
    end;
  elsif v_challenge.challenge_type = 'attempt' then
    v_winning_slot := case v_round.proposed_result
      when 1 then 0 when 2 then 1 when 3 then 2
      when 4 then 3 when 5 then 3 else 4
    end;
    v_performer_bonus := case v_round.proposed_result
      when 1 then 5 when 2 then 3 when 3 then 2
      when 4 then 1 when 5 then 1 else 0
    end;
  else
    v_boundaries := public.party_board_boundaries_v1(
      p_room_id, v_room.current_round
    );
    v_winning_slot := case
      when v_round.proposed_result < v_boundaries[1] then 0
      when v_round.proposed_result < v_boundaries[2] then 1
      when v_round.proposed_result <= v_boundaries[3] then 2
      when v_round.proposed_result <= v_boundaries[4] then 3
      else 4
    end;
    v_performer_bonus := case
      when v_challenge.result_direction = 'lower'
        then (array[5, 3, 2, 1, 0])[v_winning_slot + 1]
      else (array[0, 1, 2, 3, 5])[v_winning_slot + 1]
    end;
  end if;

  update public.party_bets
  set won = slot_index = v_winning_slot
  where room_id = p_room_id and round_number = v_room.current_round;

  update public.party_scores score
  set score = greatest(
    15,
    score.score
      - coalesce((
          select sum(bet.chips)
          from public.party_bets bet
          where bet.room_id = p_room_id
            and bet.round_number = v_room.current_round
            and bet.player_id = score.player_id
        ), 0)
      + coalesce((
          select sum(
            bet.chips * case
              when v_challenge.challenge_type in ('binary', 'choice') then 2
              else (array[4, 3, 2, 3, 4])[bet.slot_index + 1]
            end
          )
          from public.party_bets bet
          where bet.room_id = p_room_id
            and bet.round_number = v_room.current_round
            and bet.player_id = score.player_id
            and bet.slot_index = v_winning_slot
        ), 0)
  )
  where score.room_id = p_room_id
    and score.player_id <> v_round.performer_id;

  update public.party_scores
  set score = score + v_performer_bonus
  where room_id = p_room_id and player_id = v_round.performer_id;

  update public.party_rounds
  set phase = 'reveal',
      performer_bonus = v_performer_bonus,
      result_confirmed_by = v_player.id,
      settled_at = statement_timestamp(),
      phase_started_at = statement_timestamp(),
      phase_ends_at = statement_timestamp() + interval '7 seconds'
  where id = v_round.id and settled_at is null;
  update public.rooms
  set round_phase = 'revealAnswer',
      phase_started_at = statement_timestamp(),
      phase_ends_at = statement_timestamp() + interval '7 seconds'
  where id = p_room_id;
  update public.party_matches
  set state_version = state_version + 1
  where room_id = p_room_id;

  return public.get_party_snapshot_v1(p_room_id);
end;
$$;

create or replace function public.dispute_party_result_v1(p_room_id uuid)
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
  select * into v_room from public.rooms where id = p_room_id for update;
  select * into v_round
  from public.party_rounds
  where room_id = p_room_id and round_number = v_room.current_round
  for update;
  select * into v_player
  from public.players
  where room_id = p_room_id
    and auth_user_id = (select auth.uid())
    and is_connected
  order by joined_at desc limit 1;
  select * into v_challenge
  from public.party_challenges where id = v_round.challenge_id;

  if v_player.id is null then
    raise exception using errcode = '42501', message = 'Room membership required';
  end if;
  if v_challenge.challenge_type = 'choice' then
    raise exception using errcode = '42501', message = 'A performer choice cannot be disputed';
  end if;
  if v_round.phase = 'resultEntry' and v_round.proposed_result is null then
    return public.get_party_snapshot_v1(p_room_id);
  end if;
  if v_round.phase <> 'resultConfirm' or v_round.settled_at is not null then
    raise exception using errcode = '40001', message = 'Result cannot be disputed';
  end if;
  if v_round.phase_ends_at is null
     or v_round.phase_ends_at <= statement_timestamp() then
    raise exception using errcode = '40001', message = 'Result review is closed';
  end if;

  update public.party_rounds
  set phase = 'resultEntry',
      proposed_result = null,
      result_submitted_by = null,
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

create or replace function public.get_party_recap_v1(p_room_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.is_room_member_v2(p_room_id) then
    raise exception using errcode = '42501', message = 'Room membership required';
  end if;

  return coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'round_number', round_row.round_number,
        'performer_id', performer.id,
        'performer_name', performer.name,
        'challenge_text', replace(
          challenge.prompt_template, '{player}', performer.name
        ),
        'answer_unit', challenge.answer_unit,
        'result', round_row.proposed_result,
        'crowd_guess', case
          when challenge.challenge_type = 'choice' then (
            select round(
              100.0 * coalesce(sum(bet.chips) filter (
                where bet.slot_index = round_row.proposed_result
              ), 0) / nullif(sum(bet.chips), 0)
            )::integer
            from public.party_bets bet
            where bet.room_id = p_room_id
              and bet.round_number = round_row.round_number
          )
          when challenge.challenge_type = 'binary' then (
            select round(
              100.0 * coalesce(sum(bet.chips) filter (
                where bet.slot_index = 1
              ), 0) / nullif(sum(bet.chips), 0)
            )::integer
            from public.party_bets bet
            where bet.room_id = p_room_id
              and bet.round_number = round_row.round_number
          )
          when challenge.challenge_type = 'attempt' then null
          else (
            select round(
              sum(
                bet.chips * case bet.slot_index
                  when 0 then challenge.bet_boundaries[1] / 2.0
                  when 1 then (
                    challenge.bet_boundaries[1] + challenge.bet_boundaries[2]
                  ) / 2.0
                  when 2 then (
                    challenge.bet_boundaries[2] + challenge.bet_boundaries[3]
                  ) / 2.0
                  when 3 then (
                    challenge.bet_boundaries[3] + challenge.bet_boundaries[4]
                  ) / 2.0
                  else challenge.bet_boundaries[4]
                    + greatest(
                        1,
                        challenge.bet_boundaries[4] - challenge.bet_boundaries[3]
                      ) / 2.0
                end
              ) / nullif(sum(bet.chips), 0)
            )::integer
            from public.party_bets bet
            where bet.room_id = p_room_id
              and bet.round_number = round_row.round_number
          )
        end,
        'performer_guess', null,
        'closest_player_name', null,
        'closest_guess', null,
        'performer_bonus', round_row.performer_bonus,
        'challenge_type', challenge.challenge_type,
        'duration_seconds', challenge.duration_seconds,
        'option_a', challenge.option_a,
        'option_b', challenge.option_b
      ) order by round_row.round_number
    )
    from public.party_rounds round_row
    join public.players performer on performer.id = round_row.performer_id
    join public.party_challenges challenge on challenge.id = round_row.challenge_id
    where round_row.room_id = p_room_id
      and round_row.settled_at is not null
      and round_row.proposed_result is not null
  ), '[]'::jsonb);
end;
$$;

revoke all on function public.begin_party_choice_v1(uuid)
from public, anon, authenticated;
revoke all on function public.submit_party_choice_v1(uuid, integer)
from public, anon, authenticated;
grant execute on function public.begin_party_choice_v1(uuid)
to authenticated;
grant execute on function public.submit_party_choice_v1(uuid, integer)
to authenticated;

do $verification$
declare
  v_enabled_binary integer;
  v_enabled_choice integer;
begin
  select count(*) into v_enabled_binary
  from public.party_challenges
  where enabled and challenge_type = 'binary';
  select count(*) into v_enabled_choice
  from public.party_challenges
  where enabled and challenge_type = 'choice';

  if v_enabled_binary <> 0 then
    raise exception 'Enabled binary Party challenges remain: %', v_enabled_binary;
  end if;
  if v_enabled_choice < 20 then
    raise exception 'Expected at least 20 enabled Choice challenges, found %',
      v_enabled_choice;
  end if;
  if pg_get_functiondef(
    'public.get_party_snapshot_v1(uuid)'::regprocedure
  ) not ilike '%v_hide_choice_options%' then
    raise exception 'Choice option privacy is missing from the Party snapshot';
  end if;
  if pg_get_functiondef(
    'public.submit_party_result_v1(uuid,integer)'::regprocedure
  ) not ilike '%Performer choice required%' then
    raise exception 'Host result RPC can still submit a Choice';
  end if;
  if pg_get_functiondef(
    'public.place_party_bet_v1(uuid,integer,integer,uuid,double precision,double precision)'::regprocedure
  ) not ilike '%challenge_type in (''binary'', ''choice'')%' then
    raise exception 'Party place-bet RPC does not accept Choice slots';
  end if;
  if pg_get_functiondef(
    'public.move_party_bet_v1(uuid,uuid,integer,double precision,double precision)'::regprocedure
  ) not ilike '%challenge_type in (''binary'', ''choice'')%' then
    raise exception 'Party move-bet RPC does not accept Choice slots';
  end if;
end;
$verification$;

notify pgrst, 'reload schema';
