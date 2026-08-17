-- Keep rerolled Party challenges on the same 30-second betting window used by
-- fresh and advanced rounds. The reroll RPC owns its deadline internally, so
-- the Flutter duration argument cannot update this branch.
do $migration$
declare
  v_function regprocedure :=
    to_regprocedure('public.reroll_party_challenge_v1(uuid)');
  v_definition text;
  v_rewritten text;
begin
  if v_function is null then
    raise exception 'reroll_party_challenge_v1(uuid) is missing';
  end if;

  select pg_get_functiondef(v_function) into v_definition;
  v_rewritten := replace(
    v_definition,
    'interval ''20 seconds''',
    'interval ''30 seconds'''
  );

  if v_rewritten = v_definition then
    if v_definition not like '%interval ''30 seconds''%' then
      raise exception 'Could not update Party reroll betting duration';
    end if;
  else
    execute v_rewritten;
  end if;
end;
$migration$;

do $verification$
declare
  v_definition text;
begin
  select pg_get_functiondef(
    'public.reroll_party_challenge_v1(uuid)'::regprocedure
  ) into v_definition;

  if v_definition not like '%interval ''30 seconds''%'
     or v_definition like '%interval ''20 seconds''%' then
    raise exception 'Party reroll betting duration verification failed';
  end if;
end;
$verification$;
