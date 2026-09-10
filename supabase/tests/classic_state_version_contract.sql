-- Administrator-only contract test. It uses synthetic rooms and rolls every
-- row back. Run after classic_authoritative_state_versions is installed.
begin;

do $check$
declare
  v_classic_room uuid := gen_random_uuid();
  v_party_room uuid := gen_random_uuid();
  v_host uuid := gen_random_uuid();
  v_before integer;
  v_after integer;
begin
  insert into auth.users(id) values (v_host);

  insert into public.rooms(
    id, code, host_id, created_by, game_mode, status, current_round,
    max_rounds, round_phase, state_version
  ) values (
    v_classic_room, upper(left(replace(gen_random_uuid()::text, '-', ''), 6)),
    v_host::text, v_host, 'classic', 'waiting', 0, 6, 'idle', 0
  ), (
    v_party_room, upper(left(replace(gen_random_uuid()::text, '-', ''), 6)),
    v_host::text, v_host, 'party', 'waiting', 0, 6, 'idle', 41
  );
  insert into public.players(room_id, name, device_id, auth_user_id, is_host)
    values (v_classic_room, 'version host', v_host::text, v_host, true);

  select state_version into v_before from public.rooms where id = v_classic_room;
  update public.rooms
  set current_round = 1,
      round_phase = 'question',
      phase_started_at = clock_timestamp(),
      phase_ends_at = clock_timestamp() + interval '1 second'
  where id = v_classic_room;
  select state_version into v_after from public.rooms where id = v_classic_room;
  if v_after <> v_before + 1 then
    raise exception 'Classic phase mutation did not advance state_version once';
  end if;

  v_before := v_after;
  update public.players set score = 16
  where room_id = v_classic_room and is_host;
  select state_version into v_after from public.rooms where id = v_classic_room;
  if v_after <> v_before + 1 then
    raise exception 'Classic visible player mutation did not advance version';
  end if;

  v_before := v_after;
  update public.players set last_seen = clock_timestamp()
  where room_id = v_classic_room and is_host;
  select state_version into v_after from public.rooms where id = v_classic_room;
  if v_after <> v_before then
    raise exception 'Classic heartbeat unexpectedly advanced state_version';
  end if;

  update public.rooms set current_round = 1 where id = v_party_room;
  select state_version into v_after from public.rooms where id = v_party_room;
  if v_after <> 41 then
    raise exception 'Classic trigger changed a Party room version';
  end if;
end;
$check$;

rollback;
select 'PASS: Classic state versions are monotonic, heartbeat-safe, and Party-isolated' as result;
