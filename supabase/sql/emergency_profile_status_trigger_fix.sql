-- Emergency fix for enum profile_status moderation errors.
-- Run this whole file in Supabase SQL Editor if approving a profile returns:
-- invalid input value for enum profile_status: "".

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
    v_body := 'Ваша анкета прошла модерацию.';
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
    jsonb_build_object('profile_id', new.id, 'status', new.status::text)
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
