begin;

alter function public.game_server_time() security invoker;
revoke all on function public.game_server_time() from public;
grant execute on function public.game_server_time() to anon, authenticated;

revoke all on function public.transition_game_phase(
  uuid,
  text,
  bigint,
  integer,
  uuid,
  integer
) from public, anon, authenticated;

commit;
