alter table public.questions
  add column if not exists is_active boolean not null default true;

create index if not exists questions_active_tier_category_idx
  on public.questions (is_active, access_tier, category)
  where text_en is not null;

create or replace function public.get_question_categories_v2()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(category order by lower(category)), '[]'::jsonb)
  from (
    select distinct btrim(q.category) as category
    from public.questions q
    where q.is_active = true
      and q.category is not null
      and btrim(q.category) <> ''
  ) categories;
$$;

create or replace function public.pick_question_id_v2(
  p_room_id uuid,
  p_category text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_question_id uuid;
begin
  select q.id
  into v_question_id
  from public.questions q
  where q.is_active = true
    and (
      p_category is null
      or btrim(p_category) = ''
      or lower(btrim(p_category)) = 'mixed'
      or q.category = p_category
    )
    and not exists (
      select 1
      from public.guesses g
      where g.room_id = p_room_id
        and g.question_id = q.id
    )
  order by random()
  limit 1;

  if v_question_id is null then
    select q.id
    into v_question_id
    from public.questions q
    where q.is_active = true
      and (
        p_category is null
        or btrim(p_category) = ''
        or lower(btrim(p_category)) = 'mixed'
        or q.category = p_category
      )
    order by random()
    limit 1;
  end if;

  return v_question_id;
end;
$$;

create or replace function public.pick_question_id_v3(
  p_room_id uuid,
  p_category text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room public.rooms%rowtype;
  v_host_user_id uuid;
  v_profile public.monetization_profiles%rowtype;
  v_is_premium boolean := false;
  v_question_id uuid;
  v_normalized_text text;
begin
  select *
  into v_room
  from public.rooms
  where id = p_room_id
  for update;

  if not found or coalesce(v_room.game_mode, 'classic') <> 'classic' then
    return null;
  end if;

  v_host_user_id := v_room.created_by;
  if v_host_user_id is null then
    select p.auth_user_id
    into v_host_user_id
    from public.players p
    where p.room_id = p_room_id
      and coalesce(p.is_host, false) = true
      and p.auth_user_id is not null
    order by p.joined_at nulls last, p.id
    limit 1;
  end if;

  if v_host_user_id is null then
    return null;
  end if;

  insert into public.monetization_profiles (user_id)
  values (v_host_user_id)
  on conflict (user_id) do nothing;

  select *
  into v_profile
  from public.monetization_profiles
  where user_id = v_host_user_id
  for update;

  v_is_premium := private.is_effective_premium_v1(v_host_user_id);

  if v_room.classic_match_id is null then
    update public.rooms
    set classic_match_id = gen_random_uuid()
    where id = p_room_id
    returning * into v_room;
  end if;

  with candidates as (
    select distinct on (lower(btrim(q.text_en)))
      q.id,
      lower(btrim(q.text_en)) as normalized_text
    from public.questions q
    where q.is_active = true
      and q.text_en is not null
      and btrim(q.text_en) <> ''
      and (
        (not v_is_premium and q.access_tier = 'starter')
        or (
          v_is_premium
          and (
            p_category is null
            or btrim(p_category) = ''
            or lower(btrim(p_category)) = 'mixed'
            or q.category = p_category
          )
        )
      )
    order by lower(btrim(q.text_en)), q.id
  )
  select c.id, c.normalized_text
  into v_question_id, v_normalized_text
  from candidates c
  where not exists (
      select 1
      from public.classic_question_serves host_history
      where host_history.host_user_id = v_host_user_id
        and host_history.normalized_text = c.normalized_text
    )
    and not exists (
      select 1
      from public.classic_question_serves same_match
      where same_match.match_id = v_room.classic_match_id
        and same_match.normalized_text = c.normalized_text
    )
  order by random()
  limit 1;

  if v_question_id is null then
    with candidates as (
      select distinct on (lower(btrim(q.text_en)))
        q.id,
        lower(btrim(q.text_en)) as normalized_text
      from public.questions q
      where q.is_active = true
        and q.text_en is not null
        and btrim(q.text_en) <> ''
        and (
          (not v_is_premium and q.access_tier = 'starter')
          or (
            v_is_premium
            and (
              p_category is null
              or btrim(p_category) = ''
              or lower(btrim(p_category)) = 'mixed'
              or q.category = p_category
            )
          )
        )
      order by lower(btrim(q.text_en)), q.id
    )
    select c.id, c.normalized_text
    into v_question_id, v_normalized_text
    from candidates c
    where not exists (
        select 1
        from public.classic_question_serves same_match
        where same_match.match_id = v_room.classic_match_id
          and same_match.normalized_text = c.normalized_text
      )
    order by random()
    limit 1;
  end if;

  if v_question_id is null then
    return null;
  end if;

  insert into public.classic_question_serves (
    room_id,
    match_id,
    host_user_id,
    question_id,
    normalized_text
  ) values (
    p_room_id,
    v_room.classic_match_id,
    v_host_user_id,
    v_question_id,
    v_normalized_text
  );

  return v_question_id;
end;
$$;