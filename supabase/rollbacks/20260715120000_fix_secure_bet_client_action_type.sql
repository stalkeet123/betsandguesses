begin;

create or replace function public.place_bet_v2(
  p_room_id uuid,
  p_slot_index integer,
  p_chips integer,
  p_client_action_id uuid,
  p_position_x double precision default null,
  p_position_y double precision default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
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
  select * into v_room from public.rooms where id = p_room_id;
  select * into v_player from public.players
  where room_id = p_room_id and auth_user_id = (select auth.uid()) and is_connected
  limit 1;
  if v_player.id is null then
    raise exception using errcode = '42501', message = 'Room membership required';
  end if;
  if v_room.status <> 'playing' or v_room.round_phase <> 'betting'
     or (v_room.phase_ends_at is not null and v_room.phase_ends_at < statement_timestamp()) then
    raise exception using errcode = '40001', message = 'Betting phase is closed';
  end if;

  select * into v_bet from public.bets
  where client_action_id = p_client_action_id and player_id = v_player.id;
  if v_bet.id is not null then return to_jsonb(v_bet); end if;

  select coalesce(sum(chips), 0) into v_total
  from public.bets
  where room_id = p_room_id and round_number = v_room.current_round
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
    p_chips, v_multiplier, p_client_action_id,
    case when p_position_x between -1000 and 2000 then p_position_x else null end,
    case when p_position_y between -1000 and 2000 then p_position_y else null end
  )
  returning * into v_bet;
  return to_jsonb(v_bet);
end;
$$;

revoke all on function public.place_bet_v2(
  uuid, integer, integer, uuid, double precision, double precision
) from public, anon, authenticated;
grant execute on function public.place_bet_v2(
  uuid, integer, integer, uuid, double precision, double precision
) to authenticated;

commit;
