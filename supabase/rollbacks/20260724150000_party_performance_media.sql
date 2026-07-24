drop policy if exists "party_moments_member_upload" on storage.objects;
drop policy if exists "party_moments_member_read" on storage.objects;
drop policy if exists "party_moments_uploader_delete" on storage.objects;

drop function if exists public.get_party_recap_v1(uuid);
drop function if exists public.delete_party_moment_v1(uuid, uuid);
drop function if exists public.register_party_moment_v1(uuid, integer, text);
drop function if exists public.get_party_moments_v1(uuid, integer);

delete from storage.objects where bucket_id = 'party-moments';
delete from storage.buckets where id = 'party-moments';
drop table if exists public.party_round_media;

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
  select * into v_room from public.rooms where id = p_room_id for update;
  if not exists (
    select 1 from public.players p where p.room_id = p_room_id
      and p.auth_user_id = (select auth.uid()) and p.is_host and p.is_connected
  ) then
    raise exception using errcode = '42501', message = 'Host access required';
  end if;
  select * into v_round from public.party_rounds
  where room_id = p_room_id and round_number = v_room.current_round for update;
  if v_round.phase = 'action' then return public.get_party_snapshot_v1(p_room_id); end if;
  if v_round.phase <> 'ready' or v_round.performer_ready_at is null then
    raise exception using errcode = '40001', message = 'Performer is not ready';
  end if;
  update public.party_rounds
  set phase = 'action', phase_started_at = statement_timestamp(),
      phase_ends_at = statement_timestamp() + interval '60 seconds'
  where id = v_round.id;
  update public.rooms
  set round_phase = 'partyAction', phase_started_at = statement_timestamp(),
      phase_ends_at = statement_timestamp() + interval '60 seconds'
  where id = p_room_id;
  update public.party_matches set state_version = state_version + 1
  where room_id = p_room_id;
  return public.get_party_snapshot_v1(p_room_id);
end;
$$;
