-- Party room prop selection. Existing clients create rooms exactly as before;
-- an empty list means only prop-free challenges are eligible.

alter table public.rooms
  add column if not exists party_available_items text[] not null default '{}'::text[];

alter table public.rooms
  drop constraint if exists rooms_party_available_items_valid;

alter table public.rooms
  add constraint rooms_party_available_items_valid check (
    cardinality(party_available_items) <= 30
    and array_position(party_available_items, null) is null
    and array_position(party_available_items, '') is null
  );

create or replace function public.configure_party_room_items_v1(
  p_room_id uuid,
  p_available_items text[] default '{}'::text[]
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
  set party_available_items = v_items
  where id = p_room_id
  returning * into v_room;

  return to_jsonb(v_room);
end;
$$;

revoke all on function public.configure_party_room_items_v1(uuid, text[])
from public, anon, authenticated;
grant execute on function public.configure_party_room_items_v1(uuid, text[])
to authenticated;

-- Central enforcement keeps start, advance and reroll compatible without
-- changing their public RPC signatures. If their random pick needs an item the
-- room does not have, replace it with an eligible unused challenge.
create or replace function public.enforce_party_challenge_items_v1()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_items text[] := '{}'::text[];
  v_required text[] := '{}'::text[];
  v_replacement uuid;
begin
  select coalesce(room.party_available_items, '{}'::text[])
  into v_items
  from public.rooms room
  where room.id = new.room_id
    and room.game_mode = 'party';

  select coalesce(challenge.required_items, '{}'::text[])
  into v_required
  from public.party_challenges challenge
  where challenge.id = new.challenge_id;

  if v_required <@ v_items then
    return new;
  end if;

  select challenge.id
  into v_replacement
  from public.party_challenges challenge
  where challenge.enabled
    and coalesce(challenge.required_items, '{}'::text[]) <@ v_items
    and challenge.id <> new.challenge_id
    and not exists (
      select 1
      from public.party_rounds previous_round
      where previous_round.room_id = new.room_id
        and previous_round.challenge_id = challenge.id
        and previous_round.id is distinct from new.id
    )
  order by random()
  limit 1;

  if v_replacement is null then
    select challenge.id
    into v_replacement
    from public.party_challenges challenge
    where challenge.enabled
      and coalesce(challenge.required_items, '{}'::text[]) <@ v_items
      and challenge.id <> new.challenge_id
    order by random()
    limit 1;
  end if;

  if v_replacement is null then
    raise exception using errcode = 'P0002',
      message = 'No Party challenge matches the available items';
  end if;

  new.challenge_id := v_replacement;
  return new;
end;
$$;

revoke all on function public.enforce_party_challenge_items_v1()
from public, anon, authenticated;

drop trigger if exists party_round_items_guard on public.party_rounds;
create trigger party_round_items_guard
before insert or update of challenge_id on public.party_rounds
for each row execute function public.enforce_party_challenge_items_v1();

do $$
begin
  if not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'rooms'
      and column_name = 'party_available_items'
  ) then
    raise exception 'Party room item setup migration is incomplete';
  end if;
  if to_regprocedure(
    'public.configure_party_room_items_v1(uuid,text[])'
  ) is null then
    raise exception 'Party room item configuration RPC is missing';
  end if;
  if not exists (
    select 1
    from pg_trigger trigger_row
    where trigger_row.tgname = 'party_round_items_guard'
      and not trigger_row.tgisinternal
  ) then
    raise exception 'Party challenge item guard trigger is missing';
  end if;
end;
$$;

-- Party uses the host-selected round count. Performer order stays fair by
-- cycling only after everyone has received one turn.
do $party_round_count$
declare
  v_definition text;
  v_rewritten text;
begin
  select pg_get_functiondef(
    'public.start_party_game_v2(uuid,integer)'::regprocedure
  ) into v_definition;

  if position(
    $old_start$      max_rounds = cardinality(v_turn_order),
      round_phase = 'betting',$old_start$
    in v_definition
  ) > 0 then
    v_rewritten := replace(
      v_definition,
      $old_start$      max_rounds = cardinality(v_turn_order),
      round_phase = 'betting',$old_start$,
      $new_start$      round_phase = 'betting',$new_start$
    );
    execute v_rewritten;
  end if;

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

  select pg_get_functiondef(
    'public.start_party_game_v2(uuid,integer)'::regprocedure
  ) into v_definition;
  if position('max_rounds = cardinality(v_turn_order)' in v_definition) > 0 then
    raise exception 'Party start still overrides the selected round count';
  end if;

  select pg_get_functiondef(
    'public.advance_party_round_v2(uuid,integer)'::regprocedure
  ) into v_definition;
  if position(
    'v_room.current_round >= v_room.max_rounds' in v_definition
  ) = 0 or position(
    'v_next_index := v_next_index % cardinality(v_match.turn_order)'
    in v_definition
  ) = 0 then
    raise exception 'Party round rotation update is incomplete';
  end if;
end;
$party_round_count$;

-- Make the newly added RPC visible immediately through PostgREST.
notify pgrst, 'reload schema';
