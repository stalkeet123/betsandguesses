begin;

create or replace function public.start_game_v2(
  p_room_id uuid,
  p_duration_seconds integer
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room public.rooms%rowtype;
  v_question_id uuid;
  v_scores jsonb;
begin
  if p_duration_seconds not between 5 and 300 then
    raise exception using errcode = '22023', message = 'Invalid duration';
  end if;
  select * into v_room from public.rooms where id = p_room_id for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'Room not found';
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
  if v_room.status <> 'waiting' then
    raise exception using errcode = '40001', message = 'Room is not waiting';
  end if;
  if (select count(*) from public.players p where p.room_id = p_room_id and p.is_connected) < 2 then
    raise exception using errcode = 'P0001', message = 'At least two players required';
  end if;
  if exists (
    select 1 from public.players p
    where p.room_id = p_room_id and p.is_connected and not p.is_host and not p.is_ready
  ) then
    raise exception using errcode = 'P0001', message = 'All players must be ready';
  end if;

  v_question_id := public.pick_question_id_v2(p_room_id, v_room.category);
  if v_question_id is null then
    raise exception using errcode = 'P0002', message = 'No question available';
  end if;

  update public.players set score = 15 where room_id = p_room_id and is_connected;
  update public.rooms
  set status = 'playing', current_round = 1, round_phase = 'question',
      current_question_id = v_question_id,
      phase_started_at = statement_timestamp(),
      phase_ends_at = statement_timestamp() + interval '3 seconds'
  where id = p_room_id
  returning * into v_room;

  select coalesce(jsonb_object_agg(p.id::text, p.score), '{}'::jsonb)
  into v_scores from public.players p where p.room_id = p_room_id and p.is_connected;

  return jsonb_build_object(
    'room', to_jsonb(v_room),
    'question', public.public_question_json_v2(v_question_id, false),
    'scores', v_scores
  );
end;
$$;

create or replace function public.claim_next_question_v2(
  p_room_id uuid,
  p_round_number integer,
  p_duration_seconds integer
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room public.rooms%rowtype;
  v_question_id uuid;
begin
  if not public.is_room_member_v2(p_room_id) then
    raise exception using errcode = '42501', message = 'Room membership required';
  end if;
  if p_duration_seconds not between 5 and 300 then
    raise exception using errcode = '22023', message = 'Invalid duration';
  end if;
  select * into v_room from public.rooms where id = p_room_id for update;
  if not found or v_room.status <> 'playing' or v_room.current_round <> p_round_number
     or v_room.round_phase <> 'question' then
    return null;
  end if;
  if v_room.phase_ends_at is not null and v_room.phase_ends_at > statement_timestamp() then
    return null;
  end if;

  v_question_id := v_room.current_question_id;
  if v_question_id is null then
    v_question_id := public.pick_question_id_v2(p_room_id, v_room.category);
  end if;
  if v_question_id is null then
    raise exception using errcode = 'P0002', message = 'No question available';
  end if;

  update public.rooms
  set round_phase = 'guessing', current_question_id = v_question_id,
      phase_started_at = statement_timestamp(),
      phase_ends_at = statement_timestamp() + make_interval(secs => p_duration_seconds)
  where id = p_room_id
  returning * into v_room;

  return jsonb_build_object(
    'room', to_jsonb(v_room),
    'question', public.public_question_json_v2(v_question_id, false)
  );
end;
$$;

revoke all on function public.start_game_v2(uuid, integer)
  from public, anon, authenticated;
revoke all on function public.claim_next_question_v2(uuid, integer, integer)
  from public, anon, authenticated;
grant execute on function public.start_game_v2(uuid, integer) to authenticated;
grant execute on function public.claim_next_question_v2(uuid, integer, integer)
  to authenticated;

commit;
