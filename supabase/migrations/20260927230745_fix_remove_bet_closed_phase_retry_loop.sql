create or replace function public.remove_bet_v2(p_bet_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_room_id uuid;
  v_room public.rooms%rowtype;
  v_bet public.bets%rowtype;
begin
  select b.room_id
  into v_room_id
  from public.bets b
  join public.players p on p.id = b.player_id
  where b.id = p_bet_id
    and p.auth_user_id = (select auth.uid());

  if v_room_id is null then
    raise exception using errcode = '42501', message = 'Bet access denied';
  end if;

  select *
  into v_room
  from public.rooms
  where id = v_room_id
  for update;

  select b.*
  into v_bet
  from public.bets b
  join public.players p on p.id = b.player_id
  where b.id = p_bet_id
    and p.auth_user_id = (select auth.uid())
  for update of b;

  if not found then
    raise exception using errcode = '42501', message = 'Bet access denied';
  end if;

  if v_room.status <> 'playing'
     or v_room.round_phase <> 'betting'
     or v_room.current_round <> v_bet.round_number
     or (
       v_room.phase_ends_at is not null
       and v_room.phase_ends_at <= statement_timestamp()
     ) then
    -- SQLSTATE 40001 is reserved for serialization failures. Using the
    -- default P0001 keeps this a normal business-state error.
    raise exception 'Betting phase is closed';
  end if;

  delete from public.bets
  where id = p_bet_id;

  update public.rooms
  set updated_at = clock_timestamp()
  where id = v_room_id;

  return to_jsonb(v_bet);
end;
$function$;
