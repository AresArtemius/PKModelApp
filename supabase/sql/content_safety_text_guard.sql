-- First server-side guard for clearly inappropriate public/user text.
-- Apply after the client-side filter is tested in production-like flows.

create or replace function public.contains_blocked_content(p_text text)
returns boolean
language plpgsql
immutable
as $$
declare
  v_text text := lower(replace(coalesce(p_text, ''), 'ё', 'е'));
  v_token text;
begin
  if btrim(v_text) = '' then
    return false;
  end if;

  foreach v_token in array regexp_split_to_array(v_text, '[^0-9a-zа-я]+') loop
    if v_token ~ '^(х[уy][йеияю]|п[иеe]зд|бл[яьа]|(за|вы|у|по|на|от)?е[б6][аеиоуы]|(за|вы|у|по|на|от)?е[б6]л|муд[ао]к|пид[оа]р|залуп|шлюх|проститут|порно|porn|nude|fuck|dick|pussy)' then
      return true;
    end if;
  end loop;

  return false;
end;
$$;

create or replace function public.reject_blocked_text_fields()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row jsonb := to_jsonb(new);
  v_key text;
  v_value text;
begin
  foreach v_key in array TG_ARGV loop
    v_value := coalesce(v_row ->> v_key, '');
    if public.contains_blocked_content(v_value) then
      raise exception 'blocked_content:%', v_key using errcode = '22023';
    end if;
  end loop;
  return new;
end;
$$;

do $$
begin
  if to_regclass('public.profiles') is not null then
    drop trigger if exists profiles_content_safety_guard on public.profiles;
    create trigger profiles_content_safety_guard
      before insert or update on public.profiles
      for each row execute function public.reject_blocked_text_fields(
        'full_name',
        'city',
        'country',
        'resume',
        'experience',
        'skills',
        'services',
        'genres',
        'equipment'
      );
  end if;

  if to_regclass('public.selection_chat_messages') is not null then
    drop trigger if exists selection_chat_messages_content_safety_guard
      on public.selection_chat_messages;
    create trigger selection_chat_messages_content_safety_guard
      before insert or update on public.selection_chat_messages
      for each row execute function public.reject_blocked_text_fields('body');
  end if;

  if to_regclass('public.user_profiles') is not null then
    drop trigger if exists user_profiles_content_safety_guard
      on public.user_profiles;
    create trigger user_profiles_content_safety_guard
      before insert or update on public.user_profiles
      for each row execute function public.reject_blocked_text_fields(
        'full_name',
        'company_name',
        'account_tag'
      );
  end if;
end;
$$;
