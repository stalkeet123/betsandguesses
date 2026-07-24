create or replace function public.reset_party_to_lobby_v1(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room public.rooms%rowtype;
begin
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
  if v_room.status = 'waiting' then
    return to_jsonb(v_room);
  end if;
  if v_room.status <> 'finished' then
    raise exception using errcode = '40001', message = 'Party game is still active';
  end if;

  delete from public.party_bets where room_id = p_room_id;
  delete from public.party_guesses where room_id = p_room_id;
  delete from public.party_rounds where room_id = p_room_id;
  delete from public.party_scores where room_id = p_room_id;
  delete from public.party_matches where room_id = p_room_id;

  update public.players
  set score = 15,
      is_ready = is_host
  where room_id = p_room_id;

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

revoke all on function public.reset_party_to_lobby_v1(uuid)
from public, anon, authenticated;
grant execute on function public.reset_party_to_lobby_v1(uuid)
to authenticated;
