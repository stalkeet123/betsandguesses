begin;

alter table public.rooms
  add column if not exists classic_match_id uuid;

alter table public.classic_question_serves
  add column if not exists match_id uuid,
  add column if not exists normalized_text text;

-- Existing rows, if any, are historical records. Giving each a separate safe
-- match id avoids recreating the old permanent room-level uniqueness boundary.
update public.classic_question_serves s
set normalized_text = lower(btrim(q.text_en))
from public.questions q
where q.id = s.question_id
  and s.normalized_text is null;

update public.classic_question_serves
set match_id = gen_random_uuid()
where match_id is null;

alter table public.classic_question_serves
  alter column match_id set not null,
  alter column normalized_text set not null;

alter table public.classic_question_serves
  drop constraint if exists classic_question_serves_pkey;

alter table public.classic_question_serves
  add constraint classic_question_serves_pkey
    primary key (match_id, normalized_text),
  add constraint classic_question_serves_match_question_unique
    unique (match_id, question_id);

create index if not exists classic_question_serves_host_normalized_text_idx
  on public.classic_question_serves (host_user_id, normalized_text);

create index if not exists classic_question_serves_host_served_at_idx
  on public.classic_question_serves (host_user_id, served_at);

-- Internal selector. Its room lock serializes one room; the locked owner
-- profile serializes simultaneous selections across all rooms of that host.
create or replace function public.pick_question_id_v3(
  p_room_id uuid,
  p_category text
)
returns uuid
language plpgsql
volatile
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

  v_is_premium := coalesce(v_profile.lifetime_premium, false)
    or coalesce(v_profile.premium_expires_at > statement_timestamp(), false);

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
    where q.text_en is not null
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
      where q.text_en is not null
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

create or replace function public.start_game_v4(
  p_room_id uuid,
  p_duration_seconds integer
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room public.rooms%rowtype;
  v_question_id uuid;
  v_scores jsonb;
begin
  if (select auth.uid()) is null then
    raise exception using errcode = '42501', message = 'AUTH_REQUIRED';
  end if;

  if p_duration_seconds not between 5 and 300 then
    raise exception using errcode = '22023', message = 'Invalid duration';
  end if;

  select *
  into v_room
  from public.rooms
  where id = p_room_id
  for update;

  if not found then
    raise exception using errcode = 'P0002', message = 'Room not found';
  end if;

  if coalesce(v_room.game_mode, 'classic') <> 'classic' then
    raise exception using errcode = 'P0002', message = 'Classic room not found';
  end if;

  if not exists (
    select 1
    from public.players p
    where p.room_id = p_room_id
      and p.auth_user_id = (select auth.uid())
      and p.is_host = true
      and p.is_connected = true
  ) then
    raise exception using errcode = '42501', message = 'Host access required';
  end if;

  if v_room.status = 'playing' and v_room.current_question_id is not null then
    select coalesce(jsonb_object_agg(p.id::text, p.score), '{}'::jsonb)
    into v_scores
    from public.players p
    where p.room_id = p_room_id
      and p.is_connected;

    return jsonb_build_object(
      'room', to_jsonb(v_room),
      'question', public.public_question_json_v2(v_room.current_question_id, false),
      'scores', v_scores
    );
  end if;

  if v_room.status <> 'waiting' then
    raise exception using errcode = '40001', message = 'Room is not waiting';
  end if;

  if (
    select count(*)
    from public.players p
    where p.room_id = p_room_id
      and p.is_connected
  ) < 2 then
    raise exception using errcode = 'P0001', message = 'At least two players required';
  end if;

  if exists (
    select 1
    from public.players p
    where p.room_id = p_room_id
      and p.is_connected
      and not p.is_host
      and not p.is_ready
  ) then
    raise exception using errcode = 'P0001', message = 'All players must be ready';
  end if;

  perform public.consume_host_game_credit_v1();

  update public.rooms
  set classic_match_id = gen_random_uuid()
  where id = p_room_id
  returning * into v_room;

  v_question_id := public.pick_question_id_v3(p_room_id, v_room.category);
  if v_question_id is null then
    raise exception using errcode = 'P0002', message = 'No question available';
  end if;

  update public.players
  set score = 15
  where room_id = p_room_id
    and is_connected;

  update public.rooms
  set status = 'playing',
      current_round = 1,
      round_phase = 'question',
      current_question_id = v_question_id,
      phase_started_at = statement_timestamp(),
      phase_ends_at = statement_timestamp() + interval '3 seconds'
  where id = p_room_id
  returning * into v_room;

  select coalesce(jsonb_object_agg(p.id::text, p.score), '{}'::jsonb)
  into v_scores
  from public.players p
  where p.room_id = p_room_id
    and p.is_connected;

  return jsonb_build_object(
    'room', to_jsonb(v_room),
    'question', public.public_question_json_v2(v_question_id, false),
    'scores', v_scores
  );
end;
$$;

create or replace function public.claim_next_question_v3(
  p_room_id uuid,
  p_round_number integer,
  p_duration_seconds integer
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room public.rooms%rowtype;
  v_question_id uuid;
  v_host_user_id uuid;
  v_normalized_text text;
begin
  if not public.is_room_member_v2(p_room_id) then
    raise exception using errcode = '42501', message = 'Room membership required';
  end if;

  if p_duration_seconds not between 5 and 300 then
    raise exception using errcode = '22023', message = 'Invalid duration';
  end if;

  select *
  into v_room
  from public.rooms
  where id = p_room_id
  for update;

  if not found
     or coalesce(v_room.game_mode, 'classic') <> 'classic'
     or v_room.status <> 'playing'
     or v_room.current_round <> p_round_number
     or v_room.round_phase <> 'question' then
    return null;
  end if;

  if v_room.phase_ends_at is not null
     and v_room.phase_ends_at > statement_timestamp() then
    return null;
  end if;

  if v_room.classic_match_id is null then
    update public.rooms
    set classic_match_id = gen_random_uuid()
    where id = p_room_id
    returning * into v_room;
  end if;

  if v_room.current_question_id is not null then
    -- A legacy match may have begun before this ledger existed. Record the
    -- existing question defensively without changing the V2 idempotent result.
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

    if v_host_user_id is not null then
      insert into public.monetization_profiles (user_id)
      values (v_host_user_id)
      on conflict (user_id) do nothing;

      perform 1
      from public.monetization_profiles
      where user_id = v_host_user_id
      for update;

      select lower(btrim(q.text_en))
      into v_normalized_text
      from public.questions q
      where q.id = v_room.current_question_id;

      if v_normalized_text is not null then
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
          v_room.current_question_id,
          v_normalized_text
        ) on conflict do nothing;
      end if;
    end if;

    v_question_id := v_room.current_question_id;
  else
    v_question_id := public.pick_question_id_v3(p_room_id, v_room.category);
  end if;
  if v_question_id is null then
    raise exception using errcode = 'P0002', message = 'No question available';
  end if;

  update public.rooms
  set round_phase = 'guessing',
      current_question_id = v_question_id,
      phase_started_at = statement_timestamp(),
      phase_ends_at = statement_timestamp() + make_interval(secs => p_duration_seconds)
  where id = p_room_id
  returning * into v_room;

  return jsonb_build_object(
    'room', to_jsonb(v_room),
    'question', public.public_question_json_v2(v_question_id, false)
  );
end;
$$;

revoke all on function public.pick_question_id_v3(uuid, text)
  from public, anon, authenticated;

revoke all on function public.start_game_v4(uuid, integer)
  from public, anon, authenticated;
grant execute on function public.start_game_v4(uuid, integer)
  to authenticated;

revoke all on function public.claim_next_question_v3(uuid, integer, integer)
  from public, anon, authenticated;
grant execute on function public.claim_next_question_v3(uuid, integer, integer)
  to authenticated;

notify pgrst, 'reload schema';

commit;