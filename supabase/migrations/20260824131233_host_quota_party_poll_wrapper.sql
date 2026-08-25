begin;

-- The canonical Party Poll runtime starts through start_party_poll_v1. This
-- wrapper adds only host-credit serialization; V1 remains the gameplay owner.
create or replace function public.start_party_poll_v2(
  p_room_id uuid,
  p_betting_duration_seconds integer default 30
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room public.rooms%rowtype;
begin
  if (select auth.uid()) is null then
    raise exception using errcode = '42501', message = 'AUTH_REQUIRED';
  end if;

  select *
  into v_room
  from public.rooms
  where id = p_room_id
  for update;

  if not found or v_room.game_mode <> 'party' then
    raise exception using errcode = 'P0002', message = 'PARTY_ROOM_NOT_FOUND';
  end if;

  -- Match the canonical Poll host check exactly. A host whose presence row is
  -- temporarily stale is still permitted to start the room.
  if not exists (
    select 1
    from public.players p
    where p.room_id = p_room_id
      and p.auth_user_id = (select auth.uid())
      and coalesce(p.is_host, false) = true
  ) then
    raise exception using errcode = '42501', message = 'HOST_ACCESS_REQUIRED';
  end if;

  if v_room.status = 'playing'
     and exists (
       select 1
       from public.party_matches m
       where m.room_id = p_room_id
     ) then
    return public.get_party_poll_snapshot_v1(p_room_id);
  end if;

  if v_room.status <> 'waiting' then
    raise exception using errcode = '40001', message = 'ROOM_NOT_WAITING';
  end if;

  -- This and the V1 call share one PostgreSQL transaction. If V1 rejects any
  -- validation or write, the profile increment is rolled back as well.
  perform public.consume_host_game_credit_v1();
  return public.start_party_poll_v1(p_room_id, p_betting_duration_seconds);
end;
$$;

revoke all on function public.start_party_poll_v2(uuid, integer)
  from public, anon, authenticated;
grant execute on function public.start_party_poll_v2(uuid, integer)
  to authenticated;

notify pgrst, 'reload schema';

commit;
