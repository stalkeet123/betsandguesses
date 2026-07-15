begin;

drop function if exists public.reset_room_to_lobby_v1(uuid);
drop function if exists public.claim_game_phase_v1(uuid, integer, text, text, integer, integer, uuid);
drop function if exists public.start_game_v1(uuid, uuid, integer, jsonb);

commit;
