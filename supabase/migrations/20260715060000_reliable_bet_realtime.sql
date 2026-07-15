begin;

alter table public.bets
  add column if not exists position_x double precision,
  add column if not exists position_y double precision;

alter table public.bets replica identity full;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'bets'
  ) then
    alter publication supabase_realtime add table public.bets;
  end if;
end;
$$;

commit;
