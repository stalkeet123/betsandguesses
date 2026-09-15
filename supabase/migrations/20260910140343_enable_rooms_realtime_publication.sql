-- Restore the room UPDATE feed consumed by Classic and existing room listeners.
-- Preserve every existing publication member and all RLS / privilege rules.
set local lock_timeout = '5s';

do $migration$
begin
  if not exists (
    select 1 from pg_publication where pubname = 'supabase_realtime'
  ) then
    raise exception 'Expected supabase_realtime publication is missing';
  end if;

  if not exists (
    select 1 from pg_class
    where oid = 'public.rooms'::regclass and relrowsecurity
  ) then
    raise exception 'rooms RLS must remain enabled before publishing changes';
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'rooms'
  ) then
    alter publication supabase_realtime add table public.rooms;
  end if;
end;
$migration$;
