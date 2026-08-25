begin;

create or replace function private.is_effective_premium_v1(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select coalesce(
    (
      select coalesce(m.lifetime_premium, false)
        or coalesce(m.premium_expires_at > statement_timestamp(), false)
      from public.monetization_profiles m
      where m.user_id = p_user_id
    ),
    false
  );
$function$;

create or replace function public.get_monetization_status_v1()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  p public.monetization_profiles%rowtype;
  v_is_premium boolean := false;
begin
  if (select auth.uid()) is null then
    raise exception using errcode = '42501', message = 'AUTH_REQUIRED';
  end if;

  insert into public.monetization_profiles(user_id)
  values ((select auth.uid()))
  on conflict (user_id) do nothing;

  select *
  into p
  from public.monetization_profiles
  where user_id = (select auth.uid());

  v_is_premium := coalesce(p.lifetime_premium, false)
    or coalesce(p.premium_expires_at > statement_timestamp(), false);

  return jsonb_build_object(
    'is_premium', v_is_premium,
    'is_lifetime', p.lifetime_premium,
    'premium_expires_at', p.premium_expires_at,
    'free_host_games_used', p.free_host_games_used,
    'free_host_games_remaining', greatest(0, 3 - p.free_host_games_used)
  );
end;
$function$;

drop function if exists public.set_debug_premium_override_v1(boolean);
drop function if exists public.set_debug_free_host_games_used_v1(integer);
drop table if exists private.debug_monetization_testers;

commit;
