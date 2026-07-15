begin;

alter function public.game_server_time() security definer;
grant execute on function public.game_server_time() to public;

grant execute on function public.transition_game_phase(
  uuid,
  text,
  bigint,
  integer,
  uuid,
  integer
) to public;

commit;
