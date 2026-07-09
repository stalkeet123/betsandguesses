alter table public.rooms
  add column if not exists max_players integer not null default 4,
  add column if not exists category text,
  add column if not exists current_question_id uuid references public.questions(id);

alter table public.players
  add column if not exists device_id text,
  add column if not exists last_seen timestamptz not null default now();

update public.players
set device_id = id::text
where device_id is null or device_id = '';

alter table public.players
  alter column device_id set not null;

with ranked_players as (
  select
    id,
    is_host,
    row_number() over (
      partition by room_id, lower(trim(name))
      order by is_host desc, joined_at desc
    ) as rank_in_name
  from public.players
  where is_connected = true
)
update public.players
set is_connected = false
where id in (
  select id
  from ranked_players
  where rank_in_name > 1 and is_host = false
);

create unique index if not exists players_room_device_unique
  on public.players(room_id, device_id);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'rooms_max_players_range'
  ) then
    alter table public.rooms
      add constraint rooms_max_players_range
      check (max_players between 2 and 10)
      not valid;

    alter table public.rooms
      validate constraint rooms_max_players_range;
  end if;
end $$;
