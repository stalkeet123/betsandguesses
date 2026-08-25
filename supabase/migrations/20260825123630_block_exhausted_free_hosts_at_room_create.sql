begin;

-- Production already contains this function version. This forward migration
-- records the live create-time host quota gate in repository history.
create or replace function public.create_room_v4(
  p_code text,
  p_max_rounds integer,
  p_max_players integer,
  p_category text default null,
  p_game_mode text default 'classic'
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile public.monetization_profiles%rowtype;
  v_is_premium boolean;
  v_game_mode text := lower(btrim(coalesce(p_game_mode, 'classic')));
  v_category text := nullif(btrim(p_category), '');
begin
  if (select auth.uid()) is null then
    raise exception using errcode = '28000', message = 'Authentication required';
  end if;

  insert into public.monetization_profiles (user_id)
  values ((select auth.uid()))
  on conflict (user_id) do nothing;

  select *
  into v_profile
  from public.monetization_profiles
  where user_id = (select auth.uid());

  v_is_premium := v_profile.lifetime_premium
    or coalesce(v_profile.premium_expires_at > statement_timestamp(), false);

  if not v_is_premium then
    if v_profile.free_host_games_used >= 3 then
      raise exception using
        errcode = 'P0001',
        message = 'FREE_HOST_LIMIT_REACHED';
    end if;

    if p_max_rounds > 6 then
      raise exception using errcode = 'P0001', message = 'PREMIUM_ROUNDS_REQUIRED';
    end if;

    if p_max_players > 4 then
      raise exception using errcode = 'P0001', message = 'PREMIUM_PLAYERS_REQUIRED';
    end if;

    if v_game_mode = 'classic'
       and v_category is not null
       and lower(v_category) <> 'mixed' then
      raise exception using errcode = 'P0001', message = 'PREMIUM_CATEGORY_REQUIRED';
    end if;
  end if;

  return public.create_room_v3(
    p_code,
    p_max_rounds,
    p_max_players,
    p_category,
    p_game_mode
  );
end;
$$;

revoke all on function public.create_room_v4(text, integer, integer, text, text)
  from public, anon, authenticated;
grant execute on function public.create_room_v4(text, integer, integer, text, text)
  to authenticated;

notify pgrst, 'reload schema';

commit;