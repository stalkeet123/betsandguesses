begin;
create table public.monetization_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  free_host_games_used integer not null default 0 check (free_host_games_used >= 0),
  premium_expires_at timestamptz,
  lifetime_premium boolean not null default false,
  revenuecat_checked_at timestamptz,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp()
);
alter table public.monetization_profiles enable row level security;
create policy "read own monetization profile" on public.monetization_profiles for select to authenticated using ((select auth.uid()) = user_id);
create or replace function public.get_monetization_status_v1()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare p public.monetization_profiles%rowtype; begin
  if (select auth.uid()) is null then raise exception using errcode='42501', message='AUTH_REQUIRED'; end if;
  insert into public.monetization_profiles(user_id) values ((select auth.uid())) on conflict (user_id) do nothing;
  select * into p from public.monetization_profiles where user_id=(select auth.uid());
  return jsonb_build_object('is_premium', p.lifetime_premium or coalesce(p.premium_expires_at > statement_timestamp(), false), 'is_lifetime', p.lifetime_premium, 'premium_expires_at', p.premium_expires_at, 'free_host_games_used', p.free_host_games_used, 'free_host_games_remaining', greatest(0, 3-p.free_host_games_used));
end; $$;
revoke all on function public.get_monetization_status_v1() from public, anon, authenticated;
grant execute on function public.get_monetization_status_v1() to authenticated;
notify pgrst, 'reload schema';
commit;