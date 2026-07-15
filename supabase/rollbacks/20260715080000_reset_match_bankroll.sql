begin;

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

revoke all on function public.reset_room_to_lobby_v1(uuid) from public;
grant execute on function public.reset_room_to_lobby_v1(uuid) to anon, authenticated;

commit;
