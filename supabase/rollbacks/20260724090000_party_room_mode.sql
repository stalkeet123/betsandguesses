drop function if exists public.create_room_v3(
  text,
  integer,
  integer,
  text,
  text
);

alter table public.rooms
  drop constraint if exists rooms_game_mode_valid;

alter table public.rooms
  drop column if exists game_mode;
