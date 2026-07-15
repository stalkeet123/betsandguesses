begin;

drop function if exists public.settle_game_round_v1(
  uuid,
  integer,
  uuid,
  integer,
  jsonb
);

drop trigger if exists rooms_bump_state_version on public.rooms;
drop function if exists public.bump_room_state_version();

commit;
