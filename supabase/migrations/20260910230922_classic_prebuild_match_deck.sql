-- Build the complete immutable Classic question order when the game starts.
-- Round transitions only promote an already selected question.
begin;

alter table public.classic_question_serves
  add column if not exists round_number integer;

do $check$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'classic_question_serves_round_positive'
      and conrelid = 'public.classic_question_serves'::regclass
  ) then
    alter table public.classic_question_serves
      add constraint classic_question_serves_round_positive
      check (round_number is null or round_number > 0);
  end if;
end;
$check$;

-- Preserve the current round identity for games created before this rollout.
update public.classic_question_serves s
set round_number = r.current_round
from public.rooms r
where r.classic_match_id = s.match_id
  and r.current_question_id = s.question_id
  and coalesce(r.game_mode, 'classic') = 'classic'
  and r.status = 'playing'
  and r.current_round > 0
  and s.round_number is null
  and not exists (
    select 1 from public.classic_question_serves occupied
    where occupied.match_id = s.match_id
      and occupied.round_number = r.current_round
  );

create unique index if not exists classic_question_serves_match_round_unique
  on public.classic_question_serves(match_id, round_number)
  where round_number is not null;

create index if not exists classic_question_serves_room_round_idx
  on public.classic_question_serves(room_id, round_number)
  where round_number is not null;

create or replace function private.prepare_classic_match_deck_v1(
  p_room_id uuid
) returns uuid[]
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_room public.rooms%rowtype;
  v_round integer;
  v_question_id uuid;
  v_deck uuid[] := '{}'::uuid[];
begin
  select * into v_room
  from public.rooms
  where id = p_room_id
  for update;

  if not found or coalesce(v_room.game_mode, 'classic') <> 'classic' then
    raise exception using errcode = 'P0002', message = 'Classic room not found';
  end if;
  if v_room.classic_match_id is null then
    raise exception using errcode = '55000', message = 'Classic match identity required';
  end if;
  if v_room.max_rounds is null or v_room.max_rounds not between 1 and 100 then
    raise exception using errcode = '22023', message = 'Invalid Classic round count';
  end if;

  for v_round in 1..v_room.max_rounds loop
    select s.question_id into v_question_id
    from public.classic_question_serves s
    where s.match_id = v_room.classic_match_id
      and s.round_number = v_round;

    if v_question_id is null then
      v_question_id := public.pick_question_id_v3(p_room_id, v_room.category);
      if v_question_id is null then
        raise exception using errcode = 'P0002',
          message = format('No question available for Classic round %s', v_round);
      end if;
      update public.classic_question_serves
      set round_number = v_round
      where match_id = v_room.classic_match_id
        and question_id = v_question_id
        and round_number is null;
      if not found then
        raise exception using errcode = '55000',
          message = format('Classic deck row missing for round %s', v_round);
      end if;
    end if;
    v_deck := array_append(v_deck, v_question_id);
  end loop;

  return v_deck;
end;
$function$;

revoke all on function private.prepare_classic_match_deck_v1(uuid)
  from public, anon, authenticated;

create or replace function public.start_game_v4(
  p_room_id uuid,
  p_duration_seconds integer
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_room public.rooms%rowtype;
  v_question_id uuid;
  v_scores jsonb;
  v_started_at timestamptz;
begin
  if (select auth.uid()) is null then
    raise exception using errcode = '42501', message = 'AUTH_REQUIRED';
  end if;
  if p_duration_seconds not between 5 and 300 then
    raise exception using errcode = '22023', message = 'Invalid duration';
  end if;
  select * into v_room from public.rooms where id = p_room_id for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'Room not found';
  end if;
  if coalesce(v_room.game_mode, 'classic') <> 'classic' then
    raise exception using errcode = 'P0002', message = 'Classic room not found';
  end if;
  if not exists (
    select 1 from public.players p
    where p.room_id = p_room_id
      and p.auth_user_id = (select auth.uid())
      and p.is_host = true
      and p.is_connected = true
  ) then
    raise exception using errcode = '42501', message = 'Host access required';
  end if;
  if v_room.status = 'playing' and v_room.current_question_id is not null then
    select coalesce(jsonb_object_agg(p.id::text, p.score), '{}'::jsonb)
    into v_scores from public.players p
    where p.room_id = p_room_id and p.is_connected;
    return jsonb_build_object(
      'room', to_jsonb(v_room),
      'question', public.public_question_json_v2(v_room.current_question_id, false),
      'scores', v_scores
    );
  end if;
  if v_room.status <> 'waiting' then
    raise exception using errcode = '40001', message = 'Room is not waiting';
  end if;
  if (select count(*) from public.players p
      where p.room_id = p_room_id and p.is_connected) < 2 then
    raise exception using errcode = 'P0001', message = 'At least two players required';
  end if;
  if exists (
    select 1 from public.players p
    where p.room_id = p_room_id
      and p.is_connected and not p.is_host and not p.is_ready
  ) then
    raise exception using errcode = 'P0001', message = 'All players must be ready';
  end if;

  perform public.consume_host_game_credit_v1();
  update public.rooms
  set classic_match_id = gen_random_uuid()
  where id = p_room_id
  returning * into v_room;

  perform private.prepare_classic_match_deck_v1(p_room_id);
  select s.question_id into v_question_id
  from public.classic_question_serves s
  where s.match_id = v_room.classic_match_id and s.round_number = 1;
  if v_question_id is null then
    raise exception using errcode = '55000', message = 'Classic deck round 1 missing';
  end if;

  update public.players set score = 15
  where room_id = p_room_id and is_connected;
  v_started_at := clock_timestamp();
  update public.rooms
  set status = 'playing',
      current_round = 1,
      round_phase = 'question',
      current_question_id = v_question_id,
      phase_started_at = v_started_at,
      phase_ends_at = v_started_at + interval '1 second'
  where id = p_room_id
  returning * into v_room;
  select coalesce(jsonb_object_agg(p.id::text, p.score), '{}'::jsonb)
  into v_scores from public.players p
  where p.room_id = p_room_id and p.is_connected;
  return jsonb_build_object(
    'room', to_jsonb(v_room),
    'question', public.public_question_json_v2(v_question_id, false),
    'scores', v_scores
  );
end;
$function$;

create or replace function public.claim_game_phase_v1(
  p_room_id uuid,
  p_round_number integer,
  p_expected_phase text,
  p_next_phase text,
  p_duration_seconds integer default null,
  p_next_round integer default null,
  p_current_question_id uuid default null
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_room public.rooms%rowtype;
  v_question_id uuid;
  v_started_at timestamptz;
begin
  if not public.is_room_member_v2(p_room_id) then
    raise exception using errcode = '42501', message = 'Room membership required';
  end if;
  if p_duration_seconds is not null and p_duration_seconds not between 1 and 300 then
    raise exception using errcode = '22023', message = 'Invalid duration';
  end if;
  if p_round_number is null or p_round_number < 1
     or p_expected_phase is null or p_next_phase is null then
    raise exception using errcode = '22023', message = 'Invalid phase claim';
  end if;
  if not (
    (p_expected_phase = 'guessing' and p_next_phase = 'betting') or
    (p_expected_phase = 'revealAnswer' and p_next_phase = 'question')
  ) then
    raise exception using errcode = '22023', message = 'Invalid phase transition';
  end if;
  if p_current_question_id is not null then
    raise exception using errcode = '22023', message = 'Client question selection is disabled';
  end if;
  if (p_expected_phase = 'revealAnswer' and
      (p_next_round is null or p_next_round <> p_round_number + 1))
     or (p_expected_phase = 'guessing' and
         p_next_round is not null and p_next_round <> p_round_number) then
    raise exception using errcode = '22023', message = 'Invalid next round';
  end if;

  select * into v_room from public.rooms where id = p_room_id for update;
  if not found or v_room.game_mode <> 'classic'
     or v_room.status <> 'playing'
     or v_room.current_round <> p_round_number
     or v_room.round_phase <> p_expected_phase
     or (v_room.phase_ends_at is not null and
         v_room.phase_ends_at > clock_timestamp()) then
    return null;
  end if;

  v_question_id := v_room.current_question_id;
  if p_next_phase = 'question' then
    if p_next_round > v_room.max_rounds then return null; end if;
    select s.question_id into v_question_id
    from public.classic_question_serves s
    where s.match_id = v_room.classic_match_id
      and s.round_number = p_next_round;

    -- Compatibility for matches that were already running during rollout.
    if v_question_id is null then
      v_question_id := public.pick_question_id_v3(p_room_id, v_room.category);
      if v_question_id is not null then
        update public.classic_question_serves
        set round_number = p_next_round
        where match_id = v_room.classic_match_id
          and question_id = v_question_id
          and round_number is null;
      end if;
    end if;
    if v_question_id is null then
      raise exception using errcode = 'P0002', message = 'Classic deck question missing';
    end if;
  end if;

  v_started_at := clock_timestamp();
  update public.rooms
  set current_round = coalesce(p_next_round, p_round_number),
      round_phase = p_next_phase,
      current_question_id = v_question_id,
      phase_started_at = v_started_at,
      phase_ends_at = case when p_duration_seconds is null then null
        else v_started_at + make_interval(secs => p_duration_seconds) end
  where id = p_room_id
  returning * into v_room;
  return to_jsonb(v_room);
end;
$function$;

revoke all on function public.start_game_v4(uuid, integer) from public, anon;
revoke all on function public.claim_game_phase_v1(
  uuid, integer, text, text, integer, integer, uuid
) from public, anon;
grant execute on function public.start_game_v4(uuid, integer)
  to authenticated, service_role;
grant execute on function public.claim_game_phase_v1(
  uuid, integer, text, text, integer, integer, uuid
) to authenticated, service_role;

notify pgrst, 'reload schema';
commit;
