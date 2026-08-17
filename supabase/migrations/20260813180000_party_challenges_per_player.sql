-- Party length is selected per performer, not as an arbitrary round count.
-- The actual round total is fixed only when the game starts, using the
-- authoritative connected-player turn order. Classic room behavior and all
-- existing RPC signatures remain unchanged.

alter table public.rooms
  add column if not exists party_challenges_per_player integer not null default 1;

alter table public.rooms
  drop constraint if exists rooms_party_challenges_per_player_valid;

alter table public.rooms
  add constraint rooms_party_challenges_per_player_valid check (
    party_challenges_per_player between 1 and 4
  );

create or replace function public.configure_party_room_v2(
  p_room_id uuid,
  p_available_items text[] default '{}'::text[],
  p_challenges_per_player integer default 1
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room public.rooms%rowtype;
  v_items text[];
begin
  if p_challenges_per_player not between 1 and 4 then
    raise exception using errcode = '22023',
      message = 'Challenges per player must be between 1 and 4';
  end if;

  select * into v_room
  from public.rooms
  where id = p_room_id
  for update;

  if not found or v_room.game_mode <> 'party' then
    raise exception using errcode = 'P0002', message = 'Party room not found';
  end if;
  if v_room.status <> 'waiting' then
    raise exception using errcode = '40001', message = 'Party setup is closed';
  end if;
  if not exists (
    select 1
    from public.players player
    where player.room_id = p_room_id
      and player.auth_user_id = (select auth.uid())
      and player.is_host
      and player.is_connected
  ) then
    raise exception using errcode = '42501', message = 'Host access required';
  end if;

  select coalesce(array_agg(item order by item), '{}'::text[])
  into v_items
  from (
    select distinct lower(btrim(raw_item)) as item
    from unnest(coalesce(p_available_items, '{}'::text[])) raw_item
    where btrim(raw_item) <> ''
  ) normalized;

  if cardinality(v_items) > 30 then
    raise exception using errcode = '22023', message = 'Too many Party items';
  end if;

  update public.rooms
  set party_available_items = v_items,
      party_challenges_per_player = p_challenges_per_player
  where id = p_room_id
  returning * into v_room;

  return to_jsonb(v_room);
end;
$$;

revoke all on function public.configure_party_room_v2(uuid, text[], integer)
from public, anon, authenticated;
grant execute on function public.configure_party_room_v2(uuid, text[], integer)
to authenticated;

create or replace function public.plan_party_rounds_per_player_v1()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_player_count integer;
begin
  if new.game_mode <> 'party'
     or new.status <> 'playing'
     or old.status = 'playing' then
    return new;
  end if;

  select cardinality(match_row.turn_order)
  into v_player_count
  from public.party_matches match_row
  where match_row.room_id = new.id;

  if coalesce(v_player_count, 0) < 3 then
    raise exception using errcode = 'P0001',
      message = 'Party turn order is incomplete';
  end if;

  new.max_rounds := v_player_count * new.party_challenges_per_player;
  return new;
end;
$$;

revoke all on function public.plan_party_rounds_per_player_v1()
from public, anon, authenticated;

drop trigger if exists party_round_plan_guard on public.rooms;
create trigger party_round_plan_guard
before update of status on public.rooms
for each row execute function public.plan_party_rounds_per_player_v1();

-- Multiple challenges per player require the existing shuffled turn order to
-- wrap until max_rounds is reached. Patch older installations in place while
-- preserving every other validation and reward rule in the live RPC.
do $party_rotation$
declare
  v_definition text;
  v_rewritten text;
begin
  select pg_get_functiondef(
    'public.advance_party_round_v2(uuid,integer)'::regprocedure
  ) into v_definition;
  v_rewritten := v_definition;

  if position(
    $old_finish$  v_next_index := v_match.turn_index + 1;
  if v_next_index >= cardinality(v_match.turn_order) then$old_finish$
    in v_rewritten
  ) > 0 then
    v_rewritten := replace(
      v_rewritten,
      $old_finish$  v_next_index := v_match.turn_index + 1;
  if v_next_index >= cardinality(v_match.turn_order) then$old_finish$,
      $new_finish$  v_next_index := v_match.turn_index + 1;
  if v_room.current_round >= v_room.max_rounds then$new_finish$
    );
  end if;

  if position(
    $old_rotation$  v_next_round := v_room.current_round + 1;
  v_performer_id := v_match.turn_order[v_next_index + 1];$old_rotation$
    in v_rewritten
  ) > 0 then
    v_rewritten := replace(
      v_rewritten,
      $old_rotation$  v_next_round := v_room.current_round + 1;
  v_performer_id := v_match.turn_order[v_next_index + 1];$old_rotation$,
      $new_rotation$  v_next_index := v_next_index % cardinality(v_match.turn_order);
  v_next_round := v_room.current_round + 1;
  v_performer_id := v_match.turn_order[v_next_index + 1];$new_rotation$
    );
  end if;

  if v_rewritten <> v_definition then
    execute v_rewritten;
  end if;
end;
$party_rotation$;

do $verification$
declare
  v_definition text;
begin
  if to_regprocedure(
    'public.configure_party_room_v2(uuid,text[],integer)'
  ) is null then
    raise exception 'Party per-player setup RPC is missing';
  end if;
  if not exists (
    select 1
    from pg_trigger trigger_row
    where trigger_row.tgname = 'party_round_plan_guard'
      and not trigger_row.tgisinternal
  ) then
    raise exception 'Party round plan trigger is missing';
  end if;

  select pg_get_functiondef(
    'public.advance_party_round_v2(uuid,integer)'::regprocedure
  ) into v_definition;
  if position('v_room.current_round >= v_room.max_rounds' in v_definition) = 0
     or position(
       'v_next_index := v_next_index % cardinality(v_match.turn_order)'
       in v_definition
     ) = 0 then
    raise exception 'Party performer rotation is not safe for multiple cycles';
  end if;
end;
$verification$;

notify pgrst, 'reload schema';
