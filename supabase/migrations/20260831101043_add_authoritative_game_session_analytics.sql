create table if not exists public.analytics_game_sessions (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null,
  host_user_id uuid,
  game_mode text not null,
  started_at timestamptz not null default statement_timestamp(),
  finished_at timestamptz,
  planned_rounds integer not null,
  finished_rounds integer,
  starting_player_count integer not null,
  constraint analytics_game_sessions_mode_check check (game_mode in ('classic', 'party')),
  constraint analytics_game_sessions_planned_rounds_check check (planned_rounds > 0),
  constraint analytics_game_sessions_starting_players_check check (starting_player_count >= 0),
  constraint analytics_game_sessions_finish_order_check check (finished_at is null or finished_at >= started_at)
);

create unique index if not exists analytics_game_sessions_one_open_per_room_idx
  on public.analytics_game_sessions (room_id)
  where finished_at is null;
create index if not exists analytics_game_sessions_started_at_idx
  on public.analytics_game_sessions (started_at desc);
create index if not exists analytics_game_sessions_host_started_idx
  on public.analytics_game_sessions (host_user_id, started_at desc)
  where host_user_id is not null;

alter table public.analytics_game_sessions enable row level security;
revoke all on table public.analytics_game_sessions from anon, authenticated;

create or replace function private.capture_game_session_analytics_v1()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_host_user_id uuid;
  v_player_count integer := 0;
begin
  if new.status = 'playing' and old.status is distinct from 'playing' then
    v_host_user_id := new.created_by;

    if v_host_user_id is null then
      select p.auth_user_id
      into v_host_user_id
      from public.players p
      where p.room_id = new.id
        and coalesce(p.is_host, false) = true
        and p.auth_user_id is not null
      order by p.joined_at nulls last, p.id
      limit 1;
    end if;

    select count(distinct p.device_id)::integer
    into v_player_count
    from public.players p
    where p.room_id = new.id
      and coalesce(p.is_connected, false) = true
      and p.device_id is not null;

    insert into public.analytics_game_sessions (
      room_id,
      host_user_id,
      game_mode,
      started_at,
      planned_rounds,
      starting_player_count
    ) values (
      new.id,
      v_host_user_id,
      coalesce(new.game_mode, 'classic'),
      statement_timestamp(),
      greatest(1, coalesce(new.max_rounds, 1)),
      coalesce(v_player_count, 0)
    )
    on conflict (room_id) where finished_at is null do nothing;
  end if;

  if new.status = 'finished' and old.status is distinct from 'finished' then
    update public.analytics_game_sessions s
    set finished_at = statement_timestamp(),
        finished_rounds = greatest(0, coalesce(new.current_round, 0))
    where s.id = (
      select candidate.id
      from public.analytics_game_sessions candidate
      where candidate.room_id = new.id
        and candidate.finished_at is null
      order by candidate.started_at desc
      limit 1
    );
  end if;

  return new;
end;
$$;

revoke all on function private.capture_game_session_analytics_v1() from public, anon, authenticated;

drop trigger if exists rooms_capture_game_session_analytics on public.rooms;
create trigger rooms_capture_game_session_analytics
after update of status on public.rooms
for each row
when (old.status is distinct from new.status)
execute function private.capture_game_session_analytics_v1();
