-- Dedicated Party performance page media and streamlined host-controlled start.
-- Classic game tables and RPCs are intentionally untouched.

create table if not exists public.party_round_media (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.rooms(id) on delete cascade,
  round_number integer not null,
  uploader_player_id uuid not null references public.players(id) on delete cascade,
  storage_path text not null unique,
  created_at timestamptz not null default statement_timestamp(),
  constraint party_round_media_round_positive check (round_number > 0),
  constraint party_round_media_path_not_blank check (length(btrim(storage_path)) > 12)
);

create index if not exists party_round_media_room_round_idx
  on public.party_round_media(room_id, round_number, created_at);

alter table public.party_round_media enable row level security;
revoke all on table public.party_round_media from public, anon, authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'party-moments',
  'party-moments',
  false,
  4194304,
  array['image/jpeg']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "party_moments_member_upload" on storage.objects;
create policy "party_moments_member_upload"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'party-moments'
  and (storage.foldername(name))[1] is not null
  and exists (
    select 1
    from public.players player
    where player.room_id = ((storage.foldername(name))[1])::uuid
      and player.id::text = (storage.foldername(name))[3]
      and player.auth_user_id = (select auth.uid())
      and player.is_connected
  )
  and lower(storage.extension(name)) = 'jpg'
);

drop policy if exists "party_moments_member_read" on storage.objects;
create policy "party_moments_member_read"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'party-moments'
  and (storage.foldername(name))[1] is not null
  and public.is_room_member_v2(((storage.foldername(name))[1])::uuid)
);

drop policy if exists "party_moments_uploader_delete" on storage.objects;
create policy "party_moments_uploader_delete"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'party-moments'
  and (storage.foldername(name))[1] is not null
  and exists (
    select 1
    from public.players player
    where player.room_id = ((storage.foldername(name))[1])::uuid
      and player.id::text = (storage.foldername(name))[3]
      and player.auth_user_id = (select auth.uid())
      and player.is_connected
  )
);

create or replace function public.get_party_moments_v1(
  p_room_id uuid,
  p_round_number integer default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.is_room_member_v2(p_room_id) then
    raise exception using errcode = '42501', message = 'Room membership required';
  end if;

  return coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'id', media.id,
        'room_id', media.room_id,
        'round_number', media.round_number,
        'uploader_player_id', media.uploader_player_id,
        'uploader_name', player.name,
        'uploader_color', player.avatar_color,
        'storage_path', media.storage_path,
        'created_at', media.created_at
      )
      order by media.round_number, media.created_at, media.id
    )
    from public.party_round_media media
    join public.players player on player.id = media.uploader_player_id
    where media.room_id = p_room_id
      and (p_round_number is null or media.round_number = p_round_number)
  ), '[]'::jsonb);
end;
$$;

create or replace function public.register_party_moment_v1(
  p_room_id uuid,
  p_round_number integer,
  p_storage_path text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room public.rooms%rowtype;
  v_round public.party_rounds%rowtype;
  v_player public.players%rowtype;
  v_media public.party_round_media%rowtype;
begin
  select * into v_room
  from public.rooms
  where id = p_room_id;

  select * into v_player
  from public.players
  where room_id = p_room_id
    and auth_user_id = (select auth.uid())
    and is_connected = true
  order by joined_at desc
  limit 1;

  select * into v_round
  from public.party_rounds
  where room_id = p_room_id
    and round_number = p_round_number;

  if v_player.id is null then
    raise exception using errcode = '42501', message = 'Room membership required';
  end if;
  if v_room.game_mode <> 'party'
     or v_room.status <> 'playing'
     or v_room.current_round <> p_round_number
     or v_round.phase not in ('action', 'resultEntry', 'resultConfirm') then
    raise exception using errcode = '40001', message = 'Party capture is closed';
  end if;
  if p_storage_path !~ (
    '^' || p_room_id::text || '/' || p_round_number::text || '/' ||
    v_player.id::text || '/[0-9a-f-]{36}[.]jpg$'
  ) then
    raise exception using errcode = '22023', message = 'Invalid party media path';
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended(p_room_id::text || ':' || p_round_number::text, 0)
  );
  if (
    select count(*)
    from public.party_round_media
    where room_id = p_room_id and round_number = p_round_number
  ) >= 3 then
    raise exception using errcode = '23514', message = 'This round already has 3 moments';
  end if;
  if not exists (
    select 1
    from storage.objects
    where bucket_id = 'party-moments' and name = p_storage_path
  ) then
    raise exception using errcode = 'P0002', message = 'Uploaded party photo not found';
  end if;

  insert into public.party_round_media (
    room_id,
    round_number,
    uploader_player_id,
    storage_path
  )
  values (
    p_room_id,
    p_round_number,
    v_player.id,
    p_storage_path
  )
  returning * into v_media;

  return jsonb_build_object(
    'id', v_media.id,
    'room_id', v_media.room_id,
    'round_number', v_media.round_number,
    'uploader_player_id', v_media.uploader_player_id,
    'uploader_name', v_player.name,
    'uploader_color', v_player.avatar_color,
    'storage_path', v_media.storage_path,
    'created_at', v_media.created_at
  );
end;
$$;

create or replace function public.delete_party_moment_v1(
  p_room_id uuid,
  p_moment_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_player public.players%rowtype;
  v_media public.party_round_media%rowtype;
begin
  select * into v_player
  from public.players
  where room_id = p_room_id
    and auth_user_id = (select auth.uid())
    and is_connected = true
  order by joined_at desc
  limit 1;

  select * into v_media
  from public.party_round_media
  where id = p_moment_id and room_id = p_room_id
  for update;

  if v_player.id is null then
    raise exception using errcode = '42501', message = 'Room membership required';
  end if;
  if v_media.id is null then return false; end if;
  if v_media.uploader_player_id <> v_player.id and not v_player.is_host then
    raise exception using errcode = '42501', message = 'Photo ownership required';
  end if;

  delete from public.party_round_media where id = v_media.id;
  delete from storage.objects
  where bucket_id = 'party-moments' and name = v_media.storage_path;
  return true;
end;
$$;

create or replace function public.get_party_recap_v1(p_room_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.is_room_member_v2(p_room_id) then
    raise exception using errcode = '42501', message = 'Room membership required';
  end if;

  return coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'round_number', round.round_number,
        'performer_id', performer.id,
        'performer_name', performer.name,
        'challenge_text', replace(
          challenge.prompt_template,
          '{player}',
          performer.name
        ),
        'answer_unit', challenge.answer_unit,
        'result', round.proposed_result,
        'crowd_guess', (
          select ceil(
            percentile_cont(0.5) within group (order by guess.value)
          )::integer
          from public.party_guesses guess
          where guess.room_id = p_room_id
            and guess.round_number = round.round_number
            and not guess.is_performer_prediction
        ),
        'performer_guess', (
          select guess.value
          from public.party_guesses guess
          where guess.room_id = p_room_id
            and guess.round_number = round.round_number
            and guess.is_performer_prediction
          limit 1
        ),
        'closest_player_name', closest.player_name,
        'closest_guess', closest.guess_value
      )
      order by round.round_number
    )
    from public.party_rounds round
    join public.players performer on performer.id = round.performer_id
    join public.party_challenges challenge on challenge.id = round.challenge_id
    left join lateral (
      select player.name as player_name, guess.value as guess_value
      from public.party_guesses guess
      join public.players player on player.id = guess.player_id
      where guess.room_id = p_room_id
        and guess.round_number = round.round_number
        and not guess.is_performer_prediction
      order by abs(guess.value - round.proposed_result), guess.created_at
      limit 1
    ) closest on true
    where round.room_id = p_room_id
      and round.settled_at is not null
      and round.proposed_result is not null
  ), '[]'::jsonb);
end;
$$;

-- The performance page is a ready room. Only the host starts the clock; the
-- performer no longer needs a second confirmation button.
create or replace function public.start_party_action_v1(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room public.rooms%rowtype;
  v_round public.party_rounds%rowtype;
begin
  select * into v_room
  from public.rooms
  where id = p_room_id
  for update;

  if not exists (
    select 1
    from public.players player
    where player.room_id = p_room_id
      and player.auth_user_id = (select auth.uid())
      and player.is_host
      and player.is_connected
  ) then
    raise exception using errcode = '42501', message = 'Host access required';
  end if;

  select * into v_round
  from public.party_rounds
  where room_id = p_room_id and round_number = v_room.current_round
  for update;

  if v_round.phase = 'action' then
    return public.get_party_snapshot_v1(p_room_id);
  end if;
  if v_round.phase <> 'ready' then
    raise exception using errcode = '40001', message = 'Performance page is not ready';
  end if;

  update public.party_rounds
  set phase = 'action',
      performer_ready_at = coalesce(performer_ready_at, statement_timestamp()),
      phase_started_at = statement_timestamp(),
      phase_ends_at = statement_timestamp() + interval '60 seconds'
  where id = v_round.id;

  update public.rooms
  set round_phase = 'partyAction',
      phase_started_at = statement_timestamp(),
      phase_ends_at = statement_timestamp() + interval '60 seconds'
  where id = p_room_id;

  update public.party_matches
  set state_version = state_version + 1
  where room_id = p_room_id;

  return public.get_party_snapshot_v1(p_room_id);
end;
$$;

revoke all on function public.get_party_moments_v1(uuid, integer)
from public, anon;
revoke all on function public.register_party_moment_v1(uuid, integer, text)
from public, anon;
revoke all on function public.delete_party_moment_v1(uuid, uuid)
from public, anon;
revoke all on function public.get_party_recap_v1(uuid)
from public, anon;

grant execute on function public.get_party_moments_v1(uuid, integer)
to authenticated;
grant execute on function public.register_party_moment_v1(uuid, integer, text)
to authenticated;
grant execute on function public.delete_party_moment_v1(uuid, uuid)
to authenticated;
grant execute on function public.get_party_recap_v1(uuid)
to authenticated;
