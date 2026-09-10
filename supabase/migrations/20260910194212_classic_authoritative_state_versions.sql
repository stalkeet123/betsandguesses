-- Classic uses a complete room snapshot as its authoritative client state.
-- Every observable Classic mutation must therefore advance one monotonic room
-- version. Party has its own party_matches version and is deliberately excluded.
begin;

create or replace function public.bump_classic_room_state_version_v1()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if coalesce(new.game_mode, 'classic') = 'classic'
     and (
       new.status,
       new.current_round,
       new.round_phase,
       new.current_question_id,
       new.phase_started_at,
       new.phase_ends_at,
       new.classic_match_id
     ) is distinct from (
       old.status,
       old.current_round,
       old.round_phase,
       old.current_question_id,
       old.phase_started_at,
       old.phase_ends_at,
       old.classic_match_id
     ) then
    new.state_version := coalesce(old.state_version, 0) + 1;
  end if;
  return new;
end;
$function$;

create or replace function public.bump_classic_child_state_version_v1()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_room_id uuid;
begin
  v_room_id := case when tg_op = 'DELETE' then old.room_id else new.room_id end;

  update public.rooms
  set state_version = coalesce(state_version, 0) + 1
  where id = v_room_id
    and coalesce(game_mode, 'classic') = 'classic';

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$function$;

revoke all on function public.bump_classic_room_state_version_v1()
  from public, anon, authenticated;
revoke all on function public.bump_classic_child_state_version_v1()
  from public, anon, authenticated;

drop trigger if exists classic_rooms_state_version_v1 on public.rooms;
create trigger classic_rooms_state_version_v1
before update of
  status,
  current_round,
  round_phase,
  current_question_id,
  phase_started_at,
  phase_ends_at,
  classic_match_id
on public.rooms
for each row
execute function public.bump_classic_room_state_version_v1();

drop trigger if exists classic_guesses_state_version_v1 on public.guesses;
create trigger classic_guesses_state_version_v1
after insert or update or delete on public.guesses
for each row
execute function public.bump_classic_child_state_version_v1();

drop trigger if exists classic_bets_state_version_v1 on public.bets;
create trigger classic_bets_state_version_v1
after insert or update or delete on public.bets
for each row
execute function public.bump_classic_child_state_version_v1();

drop trigger if exists classic_players_state_version_v1 on public.players;
create trigger classic_players_state_version_v1
after insert or delete or update of
  name,
  avatar_color,
  score,
  bank_score,
  is_host,
  is_ready,
  is_connected
on public.players
for each row
execute function public.bump_classic_child_state_version_v1();

notify pgrst, 'reload schema';
commit;
