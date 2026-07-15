begin;

create or replace function public.start_game_v1(
  p_room_id uuid,
  p_current_question_id uuid,
  p_duration_seconds integer,
  p_scores jsonb
)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_room public.rooms%rowtype;
begin
  if p_duration_seconds is null or p_duration_seconds < 1 then
    raise exception using errcode = '22023', message = 'Invalid duration';
  end if;

  if p_scores is null or jsonb_typeof(p_scores) <> 'object' then
    raise exception using errcode = '22023', message = 'Scores must be an object';
  end if;

  select *
  into v_room
  from public.rooms
  where id = p_room_id
  for update;

  if not found then
    raise exception using errcode = 'P0002', message = 'Room not found';
  end if;

  if v_room.status <> 'waiting' then
    raise exception using errcode = '40001', message = 'Room is not waiting';
  end if;

  if not exists (
    select 1 from public.questions where id = p_current_question_id
  ) then
    raise exception using errcode = '22023', message = 'Question not found';
  end if;

  if exists (
    select 1
    from jsonb_each_text(p_scores) as score_entry(player_id, score_value)
    where score_entry.score_value !~ '^-?[0-9]+$'
       or not exists (
         select 1
         from public.players
         where room_id = p_room_id
           and is_connected = true
           and id::text = score_entry.player_id
       )
  ) then
    raise exception using errcode = '22023', message = 'Invalid score payload';
  end if;

  if (select count(*) from jsonb_object_keys(p_scores)) <>
     (select count(*) from public.players where room_id = p_room_id and is_connected = true) then
    raise exception using errcode = '22023', message = 'Incomplete score payload';
  end if;

  update public.players as player
  set score = greatest(15, score_entry.score_value::integer)
  from jsonb_each_text(p_scores) as score_entry(player_id, score_value)
  where player.room_id = p_room_id
    and player.is_connected = true
    and player.id::text = score_entry.player_id;

  update public.rooms
  set status = 'playing',
      current_round = 1,
      round_phase = 'guessing',
      current_question_id = p_current_question_id,
      phase_started_at = statement_timestamp(),
      phase_ends_at = statement_timestamp() + make_interval(secs => p_duration_seconds)
  where id = p_room_id
  returning * into v_room;

  return to_jsonb(v_room);
end;
$$;

create or replace function public.claim_game_phase_v1(
  p_room_id uuid,
  p_round_number integer,
  p_expected_phase text,
  p_next_phase text,
  p_duration_seconds integer default null,
  p_next_round integer default null,
  p_current_question_id uuid default null
)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_room public.rooms%rowtype;
  v_effective_round integer;
begin
  if p_duration_seconds is not null and p_duration_seconds < 1 then
    raise exception using errcode = '22023', message = 'Invalid duration';
  end if;

  if not (
    (p_expected_phase = 'question' and p_next_phase = 'guessing') or
    (p_expected_phase = 'guessing' and p_next_phase = 'betting') or
    (p_expected_phase = 'revealAnswer' and p_next_phase = 'question')
  ) then
    raise exception using errcode = '22023', message = 'Invalid phase transition';
  end if;

  if p_expected_phase = 'revealAnswer' and
     (p_next_round is null or p_next_round <> p_round_number + 1) then
    raise exception using errcode = '22023', message = 'Invalid next round';
  end if;

  if p_expected_phase <> 'revealAnswer' and
     p_next_round is not null and p_next_round <> p_round_number then
    raise exception using errcode = '22023', message = 'Unexpected round change';
  end if;

  v_effective_round := coalesce(p_next_round, p_round_number);

  update public.rooms
  set current_round = v_effective_round,
      round_phase = p_next_phase,
      current_question_id = coalesce(p_current_question_id, current_question_id),
      phase_started_at = statement_timestamp(),
      phase_ends_at = case
        when p_duration_seconds is null then null
        else statement_timestamp() + make_interval(secs => p_duration_seconds)
      end
  where id = p_room_id
    and current_round = p_round_number
    and round_phase = p_expected_phase
    and status = 'playing'
  returning * into v_room;

  if not found then
    return null;
  end if;

  return to_jsonb(v_room);
end;
$$;

create or replace function public.reset_room_to_lobby_v1(p_room_id uuid)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_room public.rooms%rowtype;
begin
  select *
  into v_room
  from public.rooms
  where id = p_room_id
  for update;

  if not found then
    raise exception using errcode = 'P0002', message = 'Room not found';
  end if;

  delete from public.bets where room_id = p_room_id;
  delete from public.guesses where room_id = p_room_id;

  update public.rooms
  set status = 'waiting',
      current_round = 0,
      round_phase = 'idle',
      current_question_id = null,
      phase_started_at = null,
      phase_ends_at = null
  where id = p_room_id
  returning * into v_room;

  return to_jsonb(v_room);
end;
$$;

revoke all on function public.start_game_v1(uuid, uuid, integer, jsonb) from public;
revoke all on function public.claim_game_phase_v1(uuid, integer, text, text, integer, integer, uuid) from public;
revoke all on function public.reset_room_to_lobby_v1(uuid) from public;

grant execute on function public.start_game_v1(uuid, uuid, integer, jsonb) to anon, authenticated;
grant execute on function public.claim_game_phase_v1(uuid, integer, text, text, integer, integer, uuid) to anon, authenticated;
grant execute on function public.reset_room_to_lobby_v1(uuid) to anon, authenticated;

commit;
