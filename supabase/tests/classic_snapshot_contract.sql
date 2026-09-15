-- Run as an administrator after installing the migration in a test database.
-- Reads an existing member without modifying a room, player, bet, or quota.
begin;
set local statement_timeout = '10s';
do $check$
declare
  v_room uuid;
  v_user uuid;
  v_snapshot jsonb;
  v_original_role text := current_user;
begin
  select r.id, p.auth_user_id into v_room, v_user
  from public.rooms r join public.players p on p.room_id=r.id
  where r.game_mode='classic' and p.is_connected=true and p.auth_user_id is not null
  order by r.created_at desc limit 1;
  if v_room is null then raise exception 'No existing Classic member fixture'; end if;
  perform set_config('request.jwt.claim.sub',v_user::text,true);
  perform set_config('role','authenticated',true);
  v_snapshot := public.get_classic_snapshot_v1(v_room);
  if v_snapshot->'room'->>'id' <> v_room::text
     or jsonb_typeof(v_snapshot->'players') <> 'array'
     or jsonb_typeof(v_snapshot->'bets') <> 'array'
     or jsonb_typeof(v_snapshot->'guesses') <> 'array' then
    raise exception 'Snapshot shape or membership assertion failed';
  end if;
  if v_snapshot->'room'->>'round_phase' not in ('revealAnswer','scoring')
     and v_snapshot->'room'->>'status' <> 'finished'
     and (v_snapshot->'question') ? 'answer' then
    raise exception 'Answer leaked before reveal';
  end if;
  perform set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
  begin
    perform public.get_classic_snapshot_v1(v_room);
    raise exception 'Nonmember unexpectedly allowed';
  exception when insufficient_privilege then null;
  end;
  perform set_config('role',v_original_role,true);
end;
$check$;
rollback;
