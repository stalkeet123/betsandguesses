begin;

create or replace function public.bump_party_poll_sync_v1()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_room_id uuid;
begin
  v_room_id := coalesce(new.room_id, old.room_id);

  if v_room_id is null then
    return coalesce(new, old);
  end if;

  update public.rooms
  set updated_at = clock_timestamp()
  where id = v_room_id
    and game_mode = 'party';

  update public.party_matches
  set state_version = coalesce(state_version, 0) + 1
  where room_id = v_room_id;

  return coalesce(new, old);
end;
$function$;

revoke all on function public.bump_party_poll_sync_v1()
from public, anon, authenticated;

drop trigger if exists party_poll_bets_sync_v1
on public.party_bets;

create trigger party_poll_bets_sync_v1
after insert or delete or update of
  target_player_id,
  slot_index,
  position_x,
  position_y,
  chips
on public.party_bets
for each row
execute function public.bump_party_poll_sync_v1();

commit;
