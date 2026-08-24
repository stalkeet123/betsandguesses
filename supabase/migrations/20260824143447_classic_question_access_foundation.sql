begin;

-- M5B will curate the exact Starter Mix. Until then every existing Classic
-- question remains premium and the old selectors are intentionally unchanged.
alter table public.questions
  add column if not exists access_tier text;

update public.questions
set access_tier = 'premium'
where access_tier is null;

alter table public.questions
  alter column access_tier set default 'premium';

alter table public.questions
  alter column access_tier set not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'questions_access_tier_valid'
      and conrelid = 'public.questions'::regclass
  ) then
    alter table public.questions
      add constraint questions_access_tier_valid
      check (access_tier in ('starter', 'premium')) not valid;

    alter table public.questions
      validate constraint questions_access_tier_valid;
  end if;
end;
$$;

create index if not exists questions_access_tier_category_idx
  on public.questions (access_tier, category);

-- This records selection, not guesses. It is private server state owned by
-- future authoritative Classic start/claim functions.
create table if not exists public.classic_question_serves (
  room_id uuid not null references public.rooms(id) on delete cascade,
  host_user_id uuid not null references auth.users(id),
  question_id uuid not null references public.questions(id),
  served_at timestamptz not null default statement_timestamp(),
  primary key (room_id, question_id)
);

create index if not exists classic_question_serves_host_question_idx
  on public.classic_question_serves (host_user_id, question_id);

create index if not exists classic_question_serves_host_served_at_idx
  on public.classic_question_serves (host_user_id, served_at);

alter table public.classic_question_serves enable row level security;
revoke all on table public.classic_question_serves
  from public, anon, authenticated;

-- Internal future selector. It resolves the entitlement owner from the room,
-- never from the caller or an RPC argument. Future phase commands still hold
-- the room lock; this lock makes direct internal use defensive as well.
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
  v_is_premium boolean := false;
  v_question_id uuid;
begin
  select *
  into v_room
  from public.rooms
  where id = p_room_id
  for update;

  if not found or coalesce(v_room.game_mode, 'classic') <> 'classic' then
    return null;
  end if;

  -- `created_by` is the canonical room-owner account. Older rooms can fall
  -- back only to the authenticated account attached to their host player.
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

  select
    coalesce(mp.lifetime_premium, false)
    or coalesce(mp.premium_expires_at > statement_timestamp(), false)
  into v_is_premium
  from public.monetization_profiles mp
  where mp.user_id = v_host_user_id;

  v_is_premium := coalesce(v_is_premium, false);

  if v_is_premium then
    -- Premium gets the full library. Category behavior exactly matches V2:
    -- null, blank, and Mixed mean all categories.
    select q.id
    into v_question_id
    from public.questions q
    where (
        p_category is null
        or btrim(p_category) = ''
        or lower(btrim(p_category)) = 'mixed'
        or q.category = p_category
      )
      and not exists (
        select 1
        from public.classic_question_serves same_room
        where same_room.room_id = p_room_id
          and same_room.question_id = q.id
      )
      and not exists (
        select 1
        from public.classic_question_serves host_history
        where host_history.host_user_id = v_host_user_id
          and host_history.question_id = q.id
      )
    order by random()
    limit 1;

    if v_question_id is null then
      select q.id
      into v_question_id
      from public.questions q
      where (
          p_category is null
          or btrim(p_category) = ''
          or lower(btrim(p_category)) = 'mixed'
          or q.category = p_category
        )
        and not exists (
          select 1
          from public.classic_question_serves same_room
          where same_room.room_id = p_room_id
            and same_room.question_id = q.id
        )
      order by random()
      limit 1;
    end if;
  else
    -- Free stays Starter Mix even if an old/stale room contains a category.
    select q.id
    into v_question_id
    from public.questions q
    where q.access_tier = 'starter'
      and not exists (
        select 1
        from public.classic_question_serves same_room
        where same_room.room_id = p_room_id
          and same_room.question_id = q.id
      )
      and not exists (
        select 1
        from public.classic_question_serves host_history
        where host_history.host_user_id = v_host_user_id
          and host_history.question_id = q.id
      )
    order by random()
    limit 1;

    if v_question_id is null then
      select q.id
      into v_question_id
      from public.questions q
      where q.access_tier = 'starter'
        and not exists (
          select 1
          from public.classic_question_serves same_room
          where same_room.room_id = p_room_id
            and same_room.question_id = q.id
        )
      order by random()
      limit 1;
    end if;
  end if;

  if v_question_id is null then
    return null;
  end if;

  insert into public.classic_question_serves (
    room_id,
    host_user_id,
    question_id
  ) values (
    p_room_id,
    v_host_user_id,
    v_question_id
  );

  return v_question_id;
end;
$$;

revoke all on function public.pick_question_id_v3(uuid, text)
  from public, anon, authenticated;

notify pgrst, 'reload schema';

commit;
