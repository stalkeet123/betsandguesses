drop table if exists public.party_scores;
drop table if exists public.party_bets;
drop table if exists public.party_guesses;
drop table if exists public.party_rounds;
drop trigger if exists party_matches_notify_room_state
on public.party_matches;
drop table if exists public.party_matches;
drop table if exists public.party_challenges;
drop function if exists public.notify_party_room_state_v1();
