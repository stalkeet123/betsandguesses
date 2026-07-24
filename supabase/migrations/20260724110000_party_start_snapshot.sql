insert into public.party_challenges (
  slug,
  prompt_template,
  rules,
  answer_unit,
  max_result
) values
  (
    'push_ups',
    'How many push-ups can {player} complete in 60 seconds?',
    'Only complete reps count. Chest lowers and arms return to full extension.',
    'push-ups',
    150
  ),
  (
    'squats',
    'How many squats can {player} complete in 60 seconds?',
    'Only controlled reps that return to a full standing position count.',
    'squats',
    180
  ),
  (
    'jumping_jacks',
    'How many jumping jacks can {player} complete in 60 seconds?',
    'Hands meet overhead and feet return together for a valid rep.',
    'jumping jacks',
    220
  ),
  (
    'countries',
    'How many countries can {player} name in 60 seconds?',
    'Repeats, fictional places, and partial names do not count.',
    'countries',
    120
  ),
  (
    'movie_titles',
    'How many movie titles can {player} name in 60 seconds?',
    'Repeats and made-up titles do not count.',
    'movies',
    100
  ),
  (
    'paper_cup',
    'How many paper balls can {player} land in a cup in 60 seconds?',
    'Only paper balls that remain inside the cup count.',
    'shots',
    120
  ),
  (
    'coin_catches',
    'How many coin flips can {player} catch in 60 seconds?',
    'The coin must complete a visible flip and be caught without touching the floor.',
    'catches',
    150
  ),
  (
    'tongue_twister',
    'How many times can {player} clearly say "Red leather, yellow leather" in 60 seconds?',
    'Only complete, clearly spoken repetitions count. Stumbles do not count.',
    'repetitions',
    100
  ),
  (
    'toe_touches',
    'How many standing toe touches can {player} complete in 60 seconds?',
    'Both hands must reach the toes before standing upright. Stop immediately if there is pain.',
    'reps',
    180
  ),
  (
    'knee_raises',
    'How many alternating knee raises can {player} complete in 60 seconds?',
    'Each knee must reach waist height. Left and right knees each count as one rep.',
    'reps',
    240
  ),
  (
    'animals',
    'How many different animals can {player} name in 60 seconds?',
    'No repeats, fictional creatures, breeds, or help from the group.',
    'animals',
    150
  ),
  (
    'count_by_threes',
    'How many correct numbers can {player} say while counting backward from 100 by threes in 60 seconds?',
    'Count only correct numbers in sequence. The first mistake ends the attempt.',
    'numbers',
    34
  )
on conflict (slug) do update
set prompt_template = excluded.prompt_template,
    rules = excluded.rules,
    answer_unit = excluded.answer_unit,
    max_result = excluded.max_result,
    enabled = true;

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
  v_guesses jsonb := '[]'::jsonb;
  v_bets jsonb := '[]'::jsonb;
  v_scores jsonb := '{}'::jsonb;
  v_own_guess jsonb;
  v_show_guess_values boolean;
  v_show_guess_owners boolean;
  v_show_all_bets boolean;
  v_show_result boolean;
begin
  select * into v_room
  from public.rooms
  where id = p_room_id;

  if not found or v_room.game_mode <> 'party' then
    raise exception using errcode = 'P0002', message = 'Party room not found';
  end if;

  select * into v_me
  from public.players
  where room_id = p_room_id
    and auth_user_id = (select auth.uid())
    and is_connected = true
  order by joined_at desc
  limit 1;

  if v_me.id is null then
    raise exception using errcode = '42501', message = 'Room membership required';
  end if;

  select * into v_match
  from public.party_matches
  where room_id = p_room_id;

  if v_match.room_id is null then
    return jsonb_build_object(
      'room', to_jsonb(v_room),
      'status', 'waiting'
    );
  end if;

  select * into v_round
  from public.party_rounds
  where room_id = p_room_id
    and round_number = v_room.current_round;

  select * into v_performer
  from public.players
  where id = v_round.performer_id;

  select * into v_witness
  from public.players
  where id = v_round.witness_id;

  select * into v_challenge
  from public.party_challenges
  where id = v_round.challenge_id;

  v_show_guess_values := v_round.phase in (
    'betting', 'ready', 'action', 'resultEntry', 'resultConfirm', 'reveal'
  );
  v_show_guess_owners := v_round.phase = 'reveal';
  v_show_all_bets := v_round.phase = 'reveal';
  v_show_result := v_round.phase in ('resultConfirm', 'reveal');

  select to_jsonb(g) into v_own_guess
  from public.party_guesses g
  where g.room_id = p_room_id
    and g.round_number = v_room.current_round
    and g.player_id = v_me.id;

  if v_show_guess_values then
    select coalesce(
      jsonb_agg(
        jsonb_strip_nulls(
          jsonb_build_object(
            'id', g.id,
            'value', g.value,
            'is_performer_prediction', g.is_performer_prediction,
            'player_id', case when v_show_guess_owners then g.player_id else null end,
            'player_name', case when v_show_guess_owners then p.name else null end,
            'player_color', case when v_show_guess_owners then p.avatar_color else null end
          )
        )
        order by g.value, g.id
      ),
      '[]'::jsonb
    )
    into v_guesses
    from public.party_guesses g
    join public.players p on p.id = g.player_id
    where g.room_id = p_room_id
      and g.round_number = v_room.current_round
      and g.is_performer_prediction = false;
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', b.id,
        'slot_index', b.slot_index,
        'chips', b.chips,
        'position_x', b.position_x,
        'position_y', b.position_y,
        'player_id', case
          when v_show_all_bets or b.player_id = v_me.id then b.player_id
          else null
        end
      )
      order by b.created_at, b.id
    ) filter (where v_show_all_bets or b.player_id = v_me.id),
    '[]'::jsonb
  )
  into v_bets
  from public.party_bets b
  where b.room_id = p_room_id
    and b.round_number = v_room.current_round;

  select coalesce(jsonb_object_agg(s.player_id::text, s.score), '{}'::jsonb)
  into v_scores
  from public.party_scores s
  where s.room_id = p_room_id;

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
        'name', v_witness.name
      ) end,
      'challenge', jsonb_build_object(
        'id', v_challenge.id,
        'text', replace(v_challenge.prompt_template, '{player}', v_performer.name),
        'rules', v_challenge.rules,
        'answer_unit', v_challenge.answer_unit,
        'duration_seconds', 60,
        'max_result', v_challenge.max_result
      ),
      'submitted_guess_count', (
        select count(*)
        from public.party_guesses g
        where g.room_id = p_room_id
          and g.round_number = v_room.current_round
      ),
      'performer_ready', v_round.performer_ready_at is not null,
      'own_guess', v_own_guess,
      'guesses', v_guesses,
      'bets', v_bets,
      'proposed_result', case when v_show_result then v_round.proposed_result else null end
    ),
    'scores', v_scores
  );
end;
$$;

create or replace function public.start_party_game_v1(
  p_room_id uuid,
  p_guess_duration_seconds integer default 30
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room public.rooms%rowtype;
  v_turn_order uuid[];
  v_performer_id uuid;
  v_witness_id uuid;
  v_challenge_id uuid;
begin
  if p_guess_duration_seconds not between 15 and 90 then
    raise exception using errcode = '22023', message = 'Invalid guess duration';
  end if;

  select * into v_room
  from public.rooms
  where id = p_room_id
  for update;

  if not found or v_room.game_mode <> 'party' then
    raise exception using errcode = 'P0002', message = 'Party room not found';
  end if;
  if not exists (
    select 1
    from public.players p
    where p.room_id = p_room_id
      and p.auth_user_id = (select auth.uid())
      and p.is_host = true
      and p.is_connected = true
  ) then
    raise exception using errcode = '42501', message = 'Host access required';
  end if;
  if v_room.status = 'playing'
     and exists (
       select 1 from public.party_matches m where m.room_id = p_room_id
     ) then
    return public.get_party_snapshot_v1(p_room_id);
  end if;
  if v_room.status <> 'waiting' then
    raise exception using errcode = '40001', message = 'Room is not waiting';
  end if;
  if (
    select count(*)
    from public.players p
    where p.room_id = p_room_id and p.is_connected = true
  ) < 3 then
    raise exception using errcode = 'P0001', message = 'Party Mode requires at least three players';
  end if;
  if exists (
    select 1
    from public.players p
    where p.room_id = p_room_id
      and p.is_connected = true
      and p.is_host = false
      and p.is_ready = false
  ) then
    raise exception using errcode = 'P0001', message = 'All players must be ready';
  end if;

  select array_agg(p.id order by random())
  into v_turn_order
  from public.players p
  where p.room_id = p_room_id
    and p.is_connected = true;

  v_performer_id := v_turn_order[1];
  v_witness_id := (
    select player_id
    from unnest(v_turn_order) with ordinality as t(player_id, position)
    where player_id <> v_performer_id
    order by position
    limit 1
  );

  select c.id into v_challenge_id
  from public.party_challenges c
  where c.enabled = true
  order by random()
  limit 1;

  if v_challenge_id is null then
    raise exception using errcode = 'P0002', message = 'No Party challenge available';
  end if;

  insert into public.party_matches (
    room_id,
    turn_order,
    turn_index,
    state_version
  ) values (
    p_room_id,
    v_turn_order,
    0,
    1
  );

  insert into public.party_scores (room_id, player_id, score)
  select p_room_id, p.id, 15
  from public.players p
  where p.room_id = p_room_id
    and p.is_connected = true;

  insert into public.party_rounds (
    room_id,
    round_number,
    performer_id,
    witness_id,
    challenge_id,
    phase,
    phase_started_at,
    phase_ends_at
  ) values (
    p_room_id,
    1,
    v_performer_id,
    v_witness_id,
    v_challenge_id,
    'guessing',
    statement_timestamp(),
    statement_timestamp() + make_interval(secs => p_guess_duration_seconds)
  );

  update public.rooms
  set status = 'playing',
      current_round = 1,
      max_rounds = cardinality(v_turn_order),
      round_phase = 'guessing',
      current_question_id = null,
      phase_started_at = statement_timestamp(),
      phase_ends_at = statement_timestamp() + make_interval(secs => p_guess_duration_seconds)
  where id = p_room_id;

  return public.get_party_snapshot_v1(p_room_id);
end;
$$;

revoke all on function public.get_party_snapshot_v1(uuid)
from public, anon, authenticated;
revoke all on function public.start_party_game_v1(uuid, integer)
from public, anon, authenticated;

grant execute on function public.get_party_snapshot_v1(uuid)
to authenticated;
grant execute on function public.start_party_game_v1(uuid, integer)
to authenticated;
