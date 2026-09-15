-- Administrator-only contract test. Synthetic rows are rolled back.
begin;
set local statement_timeout = '15s';
do $check$
declare
  v_admin text := current_user;
  v_user uuid := gen_random_uuid();
  v_room uuid := gen_random_uuid();
  v_question uuid;
  v_bet uuid;
  v_result jsonb;
  v_version integer;
begin
  select id into v_question from public.questions
  where is_active and access_tier = 'starter' order by id limit 1;
  if v_question is null then raise exception 'No starter question fixture'; end if;
  insert into auth.users(id) values (v_user);
  insert into public.rooms(
    id, code, host_id, created_by, game_mode, status, current_round,
    max_rounds, round_phase, current_question_id, state_version,
    phase_ends_at
  ) values (
    v_room, upper(left(replace(gen_random_uuid()::text, '-', ''), 6)),
    v_user::text, v_user, 'classic', 'playing', 1, 6, 'guessing',
    v_question, 0, clock_timestamp() + interval '30 seconds'
  );
  insert into public.players(
    room_id, name, device_id, auth_user_id, is_host, is_connected, score
  ) values (v_room, 'command user', v_user::text, v_user, true, true, 100);

  perform set_config('request.jwt.claim.sub', v_user::text, true);
  perform set_config('role', 'authenticated', true);
  v_result := public.submit_guess_v2(v_room, 123);
  if v_result is null then raise exception 'Open guess was rejected'; end if;
  perform set_config('role', v_admin, true);
  select state_version into v_version from public.rooms where id = v_room;
  if v_version <> 1 then raise exception 'Guess did not advance room version once'; end if;

  update public.rooms
  set round_phase = 'betting', phase_ends_at = clock_timestamp() + interval '30 seconds'
  where id = v_room;
  select state_version into v_version from public.rooms where id = v_room;
  perform set_config('role', 'authenticated', true);
  v_result := public.place_bet_v2(v_room, 2, 5, gen_random_uuid(), 0, 0);
  v_bet := (v_result->>'id')::uuid;
  if v_bet is null then raise exception 'Open bet was rejected'; end if;
  perform set_config('role', v_admin, true);
  if (select state_version from public.rooms where id = v_room) <> v_version + 1 then
    raise exception 'Bet insert did not advance room version once';
  end if;

  update public.rooms set phase_ends_at = statement_timestamp() - interval '1 second'
  where id = v_room;
  select state_version into v_version from public.rooms where id = v_room;
  perform set_config('role', 'authenticated', true);
  if public.move_bet_v2(v_bet, 1, 0, 0) is not null then
    raise exception 'Closed bet move was accepted';
  end if;
  begin
    perform public.remove_bet_v2(v_bet);
    raise exception 'Closed bet removal was accepted';
  exception when serialization_failure then null;
  end;
  perform set_config('role', v_admin, true);
  if (select state_version from public.rooms where id = v_room) <> v_version then
    raise exception 'Rejected mutation changed room version';
  end if;
  if (select slot_index from public.bets where id = v_bet) <> 2 then
    raise exception 'Rejected mutation changed bet';
  end if;
end;
$check$;
rollback;
select 'PASS: Classic commands serialize on room, close at deadline, and version once' as result;
