-- Avoid evaluating player membership through the caller's players RLS while
-- Storage is authorizing a Party moment object.

create or replace function public.can_manage_party_moment_v1(
  p_room_id_text text,
  p_player_id_text text
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_room_id uuid;
  v_player_id uuid;
begin
  if (select auth.uid()) is null then
    return false;
  end if;

  begin
    v_room_id := p_room_id_text::uuid;
    v_player_id := p_player_id_text::uuid;
  exception
    when invalid_text_representation then
      return false;
  end;

  return exists (
    select 1
    from public.players player
    where player.room_id = v_room_id
      and player.id = v_player_id
      and player.auth_user_id = (select auth.uid())
      and player.is_connected
  );
end;
$$;

revoke all on function public.can_manage_party_moment_v1(text, text)
  from public, anon;
grant execute on function public.can_manage_party_moment_v1(text, text)
  to authenticated;

drop policy if exists "party_moments_member_upload" on storage.objects;
create policy "party_moments_member_upload"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'party-moments'
  and coalesce(array_length(storage.foldername(name), 1), 0) = 3
  and lower(storage.extension(name)) = 'jpg'
  and public.can_manage_party_moment_v1(
    (storage.foldername(name))[1],
    (storage.foldername(name))[3]
  )
);

drop policy if exists "party_moments_uploader_delete" on storage.objects;
create policy "party_moments_uploader_delete"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'party-moments'
  and coalesce(array_length(storage.foldername(name), 1), 0) = 3
  and public.can_manage_party_moment_v1(
    (storage.foldername(name))[1],
    (storage.foldername(name))[3]
  )
);
