-- Private chat media storage for PK ModelApp.
-- Run this whole file in Supabase SQL Editor after deploying the app.
-- New chat uploads use storage://chat-media/<user_id>/chats/<chat_id>/...
-- Existing legacy chat URLs in profile-media remain readable for compatibility.

insert into storage.buckets (id, name, public)
values ('chat-media', 'chat-media', false)
on conflict (id) do update
set public = false;

drop policy if exists "chat_media_participant_read" on storage.objects;
create policy "chat_media_participant_read"
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'chat-media'
    and (storage.foldername(name))[2] = 'chats'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or exists (
        select 1
        from public.selection_chats sc
        where sc.id::text = (storage.foldername(name))[3]
          and auth.uid() in (sc.model_user_id, sc.agent_user_id)
      )
    )
  );

drop policy if exists "chat_media_participant_insert" on storage.objects;
create policy "chat_media_participant_insert"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'chat-media'
    and (storage.foldername(name))[1] = auth.uid()::text
    and (storage.foldername(name))[2] = 'chats'
    and exists (
      select 1
      from public.selection_chats sc
      where sc.id::text = (storage.foldername(name))[3]
        and auth.uid() in (sc.model_user_id, sc.agent_user_id)
    )
  );

drop policy if exists "chat_media_owner_update" on storage.objects;
create policy "chat_media_owner_update"
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'chat-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'chat-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "chat_media_owner_delete" on storage.objects;
create policy "chat_media_owner_delete"
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'chat-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
