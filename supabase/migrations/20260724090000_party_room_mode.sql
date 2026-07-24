-- Additive room-mode foundation. Classic clients and create_room_v2 continue
-- using the existing path and every existing room defaults to classic.

alter table public.rooms
  add column if not exists game_mode text not null default 'classic';

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'rooms_game_mode_valid'
  ) then
    alter table public.rooms
      add constraint rooms_game_mode_valid
      check (game_mode in ('classic', 'party'))
      not valid;

    alter table public.rooms
      validate constraint rooms_game_mode_valid;
  end if;
end
$$;

create or replace function public.create_room_v3(
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
  v_uid uuid := (select auth.uid());
  v_room public.rooms%rowtype;
  v_game_mode text := lower(btrim(coalesce(p_game_mode, 'classic')));
begin
  if v_uid is null then
    raise exception using errcode = '28000', message = 'Authentication required';
  end if;
  if upper(p_code) !~ '^[A-Z0-9]{6}$' then
    raise exception using errcode = '22023', message = 'Invalid room code';
  end if;
  if p_max_rounds not between 5 and 12 then
    raise exception using errcode = '22023', message = 'Invalid round count';
  end if;
  if p_max_players not between 2 and 10 then
    raise exception using errcode = '22023', message = 'Invalid player limit';
  end if;
  if v_game_mode not in ('classic', 'party') then
    raise exception using errcode = '22023', message = 'Invalid game mode';
  end if;
  if (
    select count(*)
    from public.rooms r
    where r.created_by = v_uid
      and r.created_at > statement_timestamp() - interval '1 minute'
  ) >= 5 then
    raise exception using errcode = 'P0001', message = 'Room creation rate exceeded';
  end if;

  insert into public.rooms (
    code,
    host_id,
    status,
    current_round,
    max_rounds,
    max_players,
    category,
    round_phase,
    created_by,
    game_mode
  ) values (
    upper(p_code),
    v_uid::text,
    'waiting',
    0,
    p_max_rounds,
    p_max_players,
    case when v_game_mode = 'classic' then nullif(btrim(p_category), '') else null end,
    'idle',
    v_uid,
    v_game_mode
  )
  returning * into v_room;

  return to_jsonb(v_room);
end;
$$;

revoke all on function public.create_room_v3(text, integer, integer, text, text)
from public, anon, authenticated;

grant execute on function public.create_room_v3(text, integer, integer, text, text)
to authenticated;
