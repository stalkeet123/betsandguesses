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

drop function if exists public.can_manage_party_moment_v1(text, text);
