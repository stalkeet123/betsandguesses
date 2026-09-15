-- Administrator-only contract test. All identities, rooms and serve history
-- are synthetic and rolled back. No existing user's JWT or room is used.
begin;
set local statement_timeout = '15s';
do $check$
declare
  v_host uuid := gen_random_uuid();
  v_guest uuid := gen_random_uuid();
  v_outsider uuid := gen_random_uuid();
  v_room uuid := gen_random_uuid();
  v_match uuid := gen_random_uuid();
  v_first_question uuid;
  v_prepared_question uuid;
  v_row jsonb;
  v_payload jsonb;
  v_snapshot jsonb;
  v_count integer;
  v_before_start timestamptz;
  v_admin text := current_user;
begin
  insert into auth.users(id) values (v_host), (v_guest), (v_outsider);
  insert into public.monetization_profiles(user_id) values (v_host);
  select id into v_first_question from public.questions
    where is_active and access_tier = 'starter' and btrim(text_en) <> ''
    order by id limit 1;
  if v_first_question is null then raise exception 'No starter question fixture'; end if;
  insert into public.rooms(
    id, code, host_id, created_by, game_mode, status, current_round,
    max_rounds, round_phase, current_question_id, classic_match_id, phase_ends_at
  ) values (
    v_room, upper(left(replace(gen_random_uuid()::text, '-', ''), 6)),
    v_host::text, v_host, 'classic', 'playing', 1, 6, 'revealAnswer',
    v_first_question, v_match, clock_timestamp() + interval '30 seconds'
  );
  insert into public.players(room_id, name, device_id, auth_user_id, is_host)
    values (v_room, 'contract host', v_host::text, v_host, true),
           (v_room, 'contract guest', v_guest::text, v_guest, false);
  insert into public.classic_question_serves(
    room_id, host_user_id, question_id, match_id, normalized_text
  ) select v_room, v_host, id, v_match, lower(btrim(text_en))
    from public.questions where id = v_first_question;

  perform set_config('request.jwt.claim.sub', v_guest::text, true);
  perform set_config('role', 'authenticated', true);
  -- Non-host membership is sufficient for failover, but deadlines still apply.
  v_row := public.claim_game_phase_v1(v_room, 1, 'revealAnswer', 'question', 1, 2, null);
  if v_row is not null then raise exception 'Early claim was accepted'; end if;

  perform set_config('role', v_admin, true);
  select count(*) into v_count from public.classic_question_serves where match_id = v_match;
  if v_count <> 1 then raise exception 'Early claim consumed a question'; end if;
  update public.rooms set phase_ends_at = clock_timestamp() - interval '1 second' where id = v_room;
  perform set_config('role', 'authenticated', true);

  -- Old clients must also publish a prepared question during the transition.
  v_row := public.claim_game_phase_v1(v_room, 1, 'revealAnswer', 'question', 1, 2, null);
  v_prepared_question := (v_row->>'current_question_id')::uuid;
  if v_row is null or v_prepared_question is null
     or v_row->>'round_phase' <> 'question'
     or (v_row->>'current_round')::integer <> 2
     or v_prepared_question = v_first_question then
    raise exception 'Transition published without its next question';
  end if;
  if (v_row->>'phase_ends_at')::timestamptz -
     (v_row->>'phase_started_at')::timestamptz <> interval '1 second' then
    raise exception 'Transition duration was lost during preparation';
  end if;
  v_snapshot := public.get_classic_snapshot_v1(v_room);
  if v_snapshot->'question'->>'id' is distinct from v_prepared_question::text
     or (v_snapshot->'question') ? 'answer' then
    raise exception 'Prepared snapshot is inconsistent or leaks the answer';
  end if;
  -- A losing retry must not select another question or reset the deadline.
  if public.claim_game_phase_v1(v_room, 1, 'revealAnswer', 'question', 1, 2, null) is not null
     or public.prepare_next_classic_round_v1(v_room, 1, 1) is not null then
    raise exception 'Duplicate next-round claim was accepted';
  end if;
  perform set_config('role', v_admin, true);
  select count(*) into v_count from public.classic_question_serves where match_id = v_match;
  if v_count <> 2 then raise exception 'Duplicate claim consumed another question'; end if;

  -- Expire only this synthetic room instead of sleeping.
  update public.rooms set phase_ends_at = clock_timestamp() - interval '1 second' where id = v_room;
  perform set_config('role', 'authenticated', true);
  v_payload := public.claim_next_question_v3(v_room, 2, 20);
  if v_payload->'question'->>'id' is distinct from v_prepared_question::text
     or v_payload->'room'->>'round_phase' <> 'guessing'
     or (v_payload->'question') ? 'answer' then
    raise exception 'Guessing did not reuse the prepared question safely';
  end if;
  if public.claim_next_question_v3(v_room, 2, 20) is not null then
    raise exception 'Duplicate guessing claim restarted the round';
  end if;

  -- Exercise the new RPC as well as the backwards-compatible entry point.
  perform set_config('role', v_admin, true);
  update public.rooms set round_phase = 'revealAnswer' where id = v_room;
  update public.rooms set phase_ends_at = clock_timestamp() - interval '1 second' where id = v_room;
  perform set_config('role', 'authenticated', true);
  v_payload := public.prepare_next_classic_round_v1(v_room, 2, 1);
  if v_payload is null
     or v_payload->'room'->>'round_phase' <> 'question'
     or (v_payload->'room'->>'current_round')::integer <> 3
     or v_payload->'question'->>'id' is null
     or v_payload->'question'->>'id' is distinct from v_payload->'room'->>'current_question_id'
     or v_payload->'question'->>'id' = v_prepared_question::text
     or (v_payload->'question') ? 'answer' then
    raise exception 'New RPC did not return one prepared, answer-free round';
  end if;
  perform set_config('request.jwt.claim.sub', v_outsider::text, true);
  begin
    perform public.prepare_next_classic_round_v1(v_room, 3, 1);
    raise exception 'Nonmember was allowed to prepare a question';
  exception when insufficient_privilege then null;
  end;
  perform set_config('role', v_admin, true);
  if has_function_privilege('anon', 'public.prepare_next_classic_round_v1(uuid,integer,integer)', 'EXECUTE') then
    raise exception 'Anonymous role has execute access';
  end if;
  select count(*) into v_count from public.classic_question_serves where match_id = v_match;
  if v_count <> 3 then raise exception 'Unexpected question serve count'; end if;
  if (select free_host_games_used from public.monetization_profiles where user_id = v_host) <> 0 then
    raise exception 'Round preparation consumed a host game credit';
  end if;
  -- Initial game start also prepares before starting the one-second clock.
  v_room := gen_random_uuid();
  insert into public.rooms(id, code, host_id, created_by, max_rounds)
    values (v_room, upper(left(replace(gen_random_uuid()::text, '-', ''), 6)),
            v_host::text, v_host, 6);
  insert into public.players(room_id, name, device_id, auth_user_id, is_host, is_ready)
    values (v_room, 'contract host', v_host::text, v_host, true, true),
           (v_room, 'contract guest', v_guest::text, v_guest, false, true);
  perform set_config('request.jwt.claim.sub', v_host::text, true);
  perform set_config('role', 'authenticated', true);
  v_before_start := clock_timestamp();
  v_payload := public.start_game_v4(v_room, 20);
  if v_payload->'question'->>'id' is null
     or v_payload->'question'->>'id' is distinct from v_payload->'room'->>'current_question_id'
     or v_payload->'room'->>'round_phase' <> 'question'
     or (v_payload->'room'->>'phase_started_at')::timestamptz < v_before_start
     or (v_payload->'room'->>'phase_ends_at')::timestamptz -
        (v_payload->'room'->>'phase_started_at')::timestamptz <> interval '1 second'
     or (v_payload->'question') ? 'answer' then
    raise exception 'Initial round did not prepare before starting its clock';
  end if;
  v_snapshot := public.start_game_v4(v_room, 20);
  if v_snapshot->'question'->>'id' is distinct from v_payload->'question'->>'id' then
    raise exception 'Duplicate game start selected another question';
  end if;
  perform set_config('role', v_admin, true);
  if (select free_host_games_used from public.monetization_profiles where user_id = v_host) <> 1 then
    raise exception 'Duplicate game start consumed another credit';
  end if;
end;
$check$;
rollback;
select 'PASS: prepared question, deadlines, retries, snapshot, failover membership, answer privacy, quota; fixtures rolled back' as result;
