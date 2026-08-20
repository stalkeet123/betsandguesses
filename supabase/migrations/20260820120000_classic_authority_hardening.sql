begin;

create or replace function public.place_bet_v2(
  p_room_id uuid,
  p_slot_index integer,
  p_chips integer,
  p_client_action_id uuid,
  p_position_x double precision default null::double precision,
  p_position_y double precision default null::double precision
)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_room public.rooms%rowtype;
  v_player public.players%rowtype;
  v_bet public.bets%rowtype;
  v_total integer;
  v_multiplier integer;
begin
  if p_slot_index not between 0 and 4 or p_chips not between 1 and 1000 then
    raise exception using errcode = '22023', message = 'Invalid bet';
  end if;

  select * into v_room from public.rooms where id = p_room_id for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'Room not found';
  end if;

  -- Serializes all distinct bet actions for this authenticated player.
  select * into v_player
  from public.players
  where room_id = p_room_id
    and auth_user_id = (select auth.uid())
    and is_connected
  limit 1
  for update;

  if v_player.id is null then
    raise exception using errcode = '42501', message = 'Room membership required';
  end if;

  -- Preserve idempotency before treating a request as a new stake.
  select * into v_bet
  from public.bets
  where client_action_id = p_client_action_id::text
    and player_id = v_player.id;
  if v_bet.id is not null then
    return to_jsonb(v_bet);
  end if;

  if v_room.status <> 'playing'
     or v_room.round_phase <> 'betting'
     or (v_room.phase_ends_at is not null
         and v_room.phase_ends_at < statement_timestamp()) then
    return null;
  end if;

  select score into v_player.score from public.players where id = v_player.id;
  select coalesce(sum(chips), 0) into v_total
  from public.bets
  where room_id = p_room_id
    and round_number = v_room.current_round
    and player_id = v_player.id;

  if v_total + p_chips > v_player.score then
    raise exception using errcode = '22003', message = 'Insufficient score';
  end if;

  v_multiplier := (array[4, 3, 2, 3, 4])[p_slot_index + 1];
  insert into public.bets (
    room_id, round_number, player_id, target_guess_id, slot_index,
    chips, payout_multiplier, client_action_id, position_x, position_y
  ) values (
    p_room_id, v_room.current_round, v_player.id, null, p_slot_index,
    p_chips, v_multiplier, p_client_action_id::text,
    case when p_position_x between -1000 and 2000 then p_position_x else null end,
    case when p_position_y between -1000 and 2000 then p_position_y else null end
  ) returning * into v_bet;

  return to_jsonb(v_bet);
end;
$function$;

create or replace function public.finish_game_v2(p_room_id uuid, p_round_number integer)
returns boolean
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_room public.rooms%rowtype;
begin
  if not public.is_room_member_v2(p_room_id) then
    raise exception using errcode = '42501', message = 'Room membership required';
  end if;

  select * into v_room
  from public.rooms
  where id = p_room_id
  for update;

  if not found then
    return false;
  end if;

  if v_room.current_round <> p_round_number
     or v_room.current_round < v_room.max_rounds
     or v_room.round_phase <> 'revealAnswer'
     or (v_room.phase_ends_at is not null
         and v_room.phase_ends_at > statement_timestamp()) then
    return false;
  end if;

  update public.rooms
  set status = 'finished', round_phase = 'idle', phase_ends_at = null
  where id = p_room_id
    and status = 'playing'
    and current_round = p_round_number
    and current_round >= max_rounds
    and round_phase = 'revealAnswer'
    and (phase_ends_at is null or phase_ends_at <= statement_timestamp());
  return found;
end;
$function$;
create or replace function public.reset_room_to_lobby_v1(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_room public.rooms%rowtype;
begin
  select * into v_room from public.rooms where id = p_room_id for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'Room not found';
  end if;

  if not exists (
    select 1 from public.players p
    where p.room_id = p_room_id
      and p.auth_user_id = (select auth.uid())
      and p.is_host is true
  ) then
    raise exception using errcode = '42501', message = 'Host access required';
  end if;

  if v_room.status <> 'finished' then
    raise exception using errcode = '40001', message = 'Game is not finished';
  end if;

  delete from public.bets where room_id = p_room_id;
  delete from public.guesses where room_id = p_room_id;
  update public.players set score = 15, is_ready = is_host where room_id = p_room_id;
  update public.rooms
  set status = 'waiting', current_round = 0, round_phase = 'idle',
      current_question_id = null, phase_started_at = null, phase_ends_at = null
  where id = p_room_id
  returning * into v_room;
  return to_jsonb(v_room);
end;
$function$;

revoke all on function public.place_bet_v2(uuid, integer, integer, uuid, double precision, double precision)
from public, anon, authenticated;
grant execute on function public.place_bet_v2(uuid, integer, integer, uuid, double precision, double precision)
to authenticated;

revoke all on function public.reset_room_to_lobby_v1(uuid)
from public, anon, authenticated;
grant execute on function public.reset_room_to_lobby_v1(uuid)
to authenticated;

notify pgrst, 'reload schema';

commit;