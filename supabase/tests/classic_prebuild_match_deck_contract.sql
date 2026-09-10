-- Administrator-only contract test. All fixtures are rolled back.
begin;
set local statement_timeout = '20s';
do $check$
declare
  v_admin text := current_user;
  v_host uuid := gen_random_uuid();
  v_guest uuid := gen_random_uuid();
  v_room uuid := gen_random_uuid();
  v_payload jsonb;
  v_match uuid;
  v_deck uuid[];
  v_before uuid[];
  v_count integer;
begin
  insert into auth.users(id) values (v_host), (v_guest);
  insert into public.monetization_profiles(user_id) values (v_host);
  insert into public.rooms(
    id, code, host_id, created_by, game_mode, status,
    current_round, max_rounds, round_phase
  ) values (
    v_room, upper(left(replace(gen_random_uuid()::text, '-', ''), 6)),
    v_host::text, v_host, 'classic', 'waiting', 0, 4, 'idle'
  );
  insert into public.players(
    room_id, name, device_id, auth_user_id, is_host, is_ready, is_connected
  ) values
    (v_room, 'deck host', v_host::text, v_host, true, true, true),
    (v_room, 'deck guest', v_guest::text, v_guest, false, true, true);

  perform set_config('request.jwt.claim.sub', v_host::text, true);
  perform set_config('role', 'authenticated', true);
  v_payload := public.start_game_v4(v_room, 20);
  v_match := (v_payload->'room'->>'classic_match_id')::uuid;
  if v_match is null then raise exception 'Match id missing'; end if;

  perform set_config('role', v_admin, true);
  select array_agg(s.question_id order by s.round_number), count(*)
  into v_deck, v_count
  from public.classic_question_serves s
  where s.match_id = v_match and s.round_number is not null;
  if v_count <> 4 or cardinality(v_deck) <> 4 then
    raise exception 'Complete four-round deck was not created: %', v_count;
  end if;
  if (select count(distinct x) from unnest(v_deck) x) <> 4 then
    raise exception 'Deck contains duplicate question ids';
  end if;
  if v_payload->'room'->>'current_question_id' is distinct from v_deck[1]::text
     or v_payload->'question'->>'id' is distinct from v_deck[1]::text
     or (v_payload->'question') ? 'answer' then
    raise exception 'Round one did not use the prepared answer-free deck row';
  end if;

  v_before := v_deck;
  update public.rooms
  set round_phase = 'revealAnswer',
      phase_ends_at = statement_timestamp() - interval '1 second'
  where id = v_room;
  perform set_config('request.jwt.claim.sub', v_guest::text, true);
  perform set_config('role', 'authenticated', true);
  v_payload := public.prepare_next_classic_round_v1(v_room, 1, 1);
  if v_payload->'room'->>'current_question_id' is distinct from v_before[2]::text
     or v_payload->'question'->>'id' is distinct from v_before[2]::text
     or (v_payload->'question') ? 'answer' then
    raise exception 'Round two did not promote the prepared deck row';
  end if;

  perform set_config('role', v_admin, true);
  select array_agg(s.question_id order by s.round_number), count(*)
  into v_deck, v_count
  from public.classic_question_serves s
  where s.match_id = v_match and s.round_number is not null;
  if v_count <> 4 or v_deck is distinct from v_before then
    raise exception 'Round transition mutated or extended the prepared deck';
  end if;
  if (select free_host_games_used from public.monetization_profiles
      where user_id = v_host) <> 1 then
    raise exception 'Deck construction changed host credit semantics';
  end if;
end;
$check$;
rollback;
select 'PASS: full Classic deck is built once and transitions only promote it' as result;
