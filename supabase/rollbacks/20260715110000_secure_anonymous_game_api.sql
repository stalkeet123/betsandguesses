begin;

drop policy if exists game_room_messages_read_v2 on realtime.messages;
drop policy if exists game_room_messages_send_v2 on realtime.messages;
create policy game_room_messages_read_rollback on realtime.messages
for select to authenticated using (true);
create policy game_room_messages_send_rollback on realtime.messages
for insert to authenticated with check (true);

drop policy if exists rooms_member_read_v2 on public.rooms;
drop policy if exists players_member_read_v2 on public.players;
drop policy if exists guesses_phase_read_v2 on public.guesses;
drop policy if exists bets_member_read_v2 on public.bets;

create policy rooms_legacy_all on public.rooms for all to anon, authenticated
using (true) with check (true);
create policy players_legacy_all on public.players for all to anon, authenticated
using (true) with check (true);
create policy guesses_legacy_all on public.guesses for all to anon, authenticated
using (true) with check (true);
create policy bets_legacy_all on public.bets for all to anon, authenticated
using (true) with check (true);
create policy questions_legacy_read on public.questions for select to anon, authenticated
using (true);
create policy question_ratings_legacy_all on public.question_ratings for all to anon, authenticated
using (true) with check (true);

grant select, insert, update, delete on public.rooms, public.players,
  public.guesses, public.bets, public.question_ratings to anon, authenticated;
grant select on public.questions to anon, authenticated;

grant execute on function public.start_game_v1(uuid, uuid, integer, jsonb) to anon, authenticated;
grant execute on function public.settle_game_round_v1(uuid, integer, uuid, integer, jsonb) to anon, authenticated;
grant execute on function public.claim_game_phase_v1(uuid, integer, text, text, integer, integer, uuid) to anon, authenticated;
grant execute on function public.reset_room_to_lobby_v1(uuid) to anon, authenticated;
grant execute on function public.game_server_time() to anon, authenticated;

drop function if exists public.finish_game_v2(uuid, integer);
drop function if exists public.settle_game_round_v2(uuid, integer);
drop function if exists public.game_board_boundaries_v2(uuid, integer);
drop function if exists public.game_fallback_boundaries_v2(bigint[]);
drop function if exists public.game_nice_step_v2(bigint);
drop function if exists public.remove_bet_v2(uuid);
drop function if exists public.move_bet_v2(uuid, integer, double precision, double precision);
drop function if exists public.place_bet_v2(uuid, integer, integer, uuid, double precision, double precision);
drop function if exists public.submit_guess_v2(uuid, bigint);
drop function if exists public.claim_next_question_v2(uuid, integer, integer);
drop function if exists public.start_game_v2(uuid, integer);
drop function if exists public.get_current_question_v2(uuid);
drop function if exists public.get_question_categories_v2();
drop function if exists public.set_player_connected_v2(uuid, boolean);
drop function if exists public.set_player_ready_v2(uuid, boolean);
drop function if exists public.join_room_v2(uuid, text, text, text);
drop function if exists public.find_room_by_code_v2(text);
drop function if exists public.create_room_v2(text, integer, integer, text);
drop function if exists public.pick_question_id_v2(uuid, text);
drop function if exists public.public_question_json_v2(uuid, boolean);
drop function if exists public.can_access_room_topic_v2(text);
drop function if exists public.is_room_member_v2(uuid);

commit;
