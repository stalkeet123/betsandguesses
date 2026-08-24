begin;

create or replace function public.start_game_v4(
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
  if (select auth.uid()) is null then
    raise exception using errcode = '42501', message = 'AUTH_REQUIRED';
  end if;

  if p_duration_seconds not between 5 and 300 then
    raise exception using errcode = '22023', message = 'Invalid duration';
  end if;

  select *
  into v_room
  from public.rooms
  where id = p_room_id
  for update;

  if not found then
    raise exception using errcode = 'P0002', message = 'Room not found';
  end if;

  if coalesce(v_room.game_mode, 'classic') <> 'classic' then
    raise exception using errcode = 'P0002', message = 'Classic room not found';
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

  if v_room.status = 'playing' and v_room.current_question_id is not null then
    select coalesce(jsonb_object_agg(p.id::text, p.score), '{}'::jsonb)
    into v_scores
    from public.players p
    where p.room_id = p_room_id
      and p.is_connected;

    return jsonb_build_object(
      'room', to_jsonb(v_room),
      'question', public.public_question_json_v2(v_room.current_question_id, false),
      'scores', v_scores
    );
  end if;

  if v_room.status <> 'waiting' then
    raise exception using errcode = '40001', message = 'Room is not waiting';
  end if;

  if (
    select count(*)
    from public.players p
    where p.room_id = p_room_id
      and p.is_connected
  ) < 2 then
    raise exception using errcode = 'P0001', message = 'At least two players required';
  end if;

  if exists (
    select 1
    from public.players p
    where p.room_id = p_room_id
      and p.is_connected
      and not p.is_host
      and not p.is_ready
  ) then
    raise exception using errcode = 'P0001', message = 'All players must be ready';
  end if;

  perform public.consume_host_game_credit_v1();

  update public.rooms
  set classic_match_id = gen_random_uuid()
  where id = p_room_id
  returning * into v_room;

  v_question_id := public.pick_question_id_v3(p_room_id, v_room.category);
  if v_question_id is null then
    raise exception using errcode = 'P0002', message = 'No question available';
  end if;

  update public.players
  set score = 15
  where room_id = p_room_id
    and is_connected;

  update public.rooms
  set status = 'playing',
      current_round = 1,
      round_phase = 'question',
      current_question_id = v_question_id,
      phase_started_at = statement_timestamp(),
      phase_ends_at = statement_timestamp() + interval '1 second'
  where id = p_room_id
  returning * into v_room;

  select coalesce(jsonb_object_agg(p.id::text, p.score), '{}'::jsonb)
  into v_scores
  from public.players p
  where p.room_id = p_room_id
    and p.is_connected;

  return jsonb_build_object(
    'room', to_jsonb(v_room),
    'question', public.public_question_json_v2(v_question_id, false),
    'scores', v_scores
  );
end;
$$;

revoke all on function public.start_game_v4(uuid, integer)
  from public, anon, authenticated;
grant execute on function public.start_game_v4(uuid, integer) to authenticated;

notify pgrst, 'reload schema';

commit;