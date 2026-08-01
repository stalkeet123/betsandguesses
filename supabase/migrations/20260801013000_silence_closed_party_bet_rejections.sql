-- Closed betting is an expected client/server deadline race. Rewrite only the
-- known 40001 branch in every live Classic and Party bet RPC, preserving each
-- function's existing validation, ownership rules, grants and return contract.
do $migration$
declare
  v_function regprocedure;
  v_definition text;
  v_rewritten text;
begin
  foreach v_function in array array[
    'public.place_bet_v2(uuid,integer,integer,uuid,double precision,double precision)'::regprocedure,
    'public.move_bet_v2(uuid,integer,double precision,double precision)'::regprocedure,
    'public.remove_bet_v2(uuid)'::regprocedure,
    'public.place_party_bet_v1(uuid,integer,integer,uuid,double precision,double precision)'::regprocedure,
    'public.move_party_bet_v1(uuid,uuid,integer,double precision,double precision)'::regprocedure,
    'public.remove_party_bet_v1(uuid,uuid)'::regprocedure
  ]
  loop
    select pg_get_functiondef(v_function) into v_definition;
    v_rewritten := replace(
      v_definition,
      'raise exception using errcode = ''40001'', message = ''Betting phase is closed'';',
      'return null;'
    );

    if v_rewritten <> v_definition then
      execute v_rewritten;
    end if;
  end loop;
end;
$migration$;

-- Fail the migration if any targeted RPC can still emit the noisy error.
do $verification$
declare
  v_remaining integer;
begin
  select count(*) into v_remaining
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname in (
      'place_bet_v2',
      'move_bet_v2',
      'remove_bet_v2',
      'place_party_bet_v1',
      'move_party_bet_v1',
      'remove_party_bet_v1'
    )
    and pg_get_functiondef(p.oid) ilike '%Betting phase is closed%';

  if v_remaining <> 0 then
    raise exception 'Closed-bet hardening incomplete for % function(s)',
      v_remaining;
  end if;
end;
$verification$;