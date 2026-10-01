-- SQLSTATE 40001 means serialization_failure to PostgreSQL/PostgREST.
-- These functions used it for ordinary game-state races (closed windows,
-- stale phases, room not waiting, etc.). Preserve function signatures,
-- messages and behavior while moving only the SQLSTATE to P0001 so old and
-- new clients remain compatible without triggering PostgREST transaction
-- retries.

do $$
declare
  v record;
  v_def text;
  v_rewritten text;
begin
  for v in
    select p.oid, n.nspname as schema_name, p.proname
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname in ('public', 'private')
      and p.prokind = 'f'
      and pg_get_functiondef(p.oid) ilike '%40001%'
  loop
    v_def := pg_get_functiondef(v.oid);
    v_rewritten := regexp_replace(
      v_def,
      E'errcode\\s*=\\s*''40001''',
      'errcode = ''P0001''',
      'gi'
    );

    if v_rewritten <> v_def then
      execute v_rewritten;
    end if;
  end loop;
end
$$;
