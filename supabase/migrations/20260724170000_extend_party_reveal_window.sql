-- Give clients enough time to return from the performance route, animate the
-- winning range and show the winners before the next Party round begins.

do $migration$
declare
  v_definition text;
  v_updated_definition text;
begin
  select pg_get_functiondef(
    'public.confirm_party_result_v1(uuid)'::regprocedure
  )
  into v_definition;

  v_updated_definition := replace(
    v_definition,
    'interval ''7 seconds''',
    'interval ''10 seconds'''
  );

  if v_updated_definition = v_definition then
    raise exception 'confirm_party_result_v1 reveal interval was not found';
  end if;

  execute v_updated_definition;
end;
$migration$;
