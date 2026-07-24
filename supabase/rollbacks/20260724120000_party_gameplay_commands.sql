drop function if exists public.submit_party_result_v1(uuid, integer);
drop function if exists public.open_party_result_entry_v1(uuid);
drop function if exists public.start_party_action_v1(uuid);
drop function if exists public.mark_party_performer_ready_v1(uuid);
drop function if exists public.begin_party_ready_v1(uuid);
drop function if exists public.place_party_bet_v1(uuid, integer, integer, uuid, double precision, double precision);
drop function if exists public.advance_party_to_betting_v1(uuid, integer);
drop function if exists public.submit_party_guess_v1(uuid, integer);
drop function if exists public.party_board_boundaries_v1(uuid, integer);

drop function if exists public.remove_party_bet_v1(uuid, uuid);
drop function if exists public.move_party_bet_v1(uuid, uuid, integer, double precision, double precision);
