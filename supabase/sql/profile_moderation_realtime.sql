-- Live profile moderation status and notification updates.
-- Run after push_notifications.sql.

create or replace function public.notify_profile_moderation_status()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_title text;
  v_body text;
begin
  if new.user_id is null
     or coalesce(old.status::text, '') = coalesce(new.status::text, '') then
    return new;
  end if;

  if new.status::text = 'approved' then
    v_title := 'Анкета одобрена';
    v_body := 'Ваша анкета прошла модерацию и готова к размещению.';
  elsif new.status::text = 'rejected' then
    v_title := 'Анкета отклонена';
    v_body := coalesce(
      nullif(btrim(new.moderation_comment), ''),
      'Анкета не прошла модерацию.'
    );
  else
    return new;
  end if;

  perform public.enqueue_app_notification(
    new.user_id,
    v_title,
    v_body,
    '/me',
    'profile_moderation',
    jsonb_build_object(
      'profile_id', new.id,
      'status', new.status::text
    )
  );

  return new;
end;
$$;

drop trigger if exists profile_moderation_status_notify
  on public.profiles;

create trigger profile_moderation_status_notify
after update of status on public.profiles
for each row
execute function public.notify_profile_moderation_status();

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'profiles'
  ) then
    alter publication supabase_realtime add table public.profiles;
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'app_notifications'
  ) then
    alter publication supabase_realtime add table public.app_notifications;
  end if;
end
$$;

notify pgrst, 'reload schema';
