-- Candidate notes for casting responses.
-- Safe to run multiple times in Supabase SQL Editor.

alter table public.casting_responses
  add column if not exists admin_note text not null default '';

create index if not exists casting_responses_admin_note_idx
  on public.casting_responses (casting_id, profile_id)
  where btrim(admin_note) <> '';

create or replace function public.set_casting_response_admin_note(
  p_casting_id uuid,
  p_profile_id uuid,
  p_admin_note text default ''
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.current_user_is_admin() then
    raise exception 'Only admins can update casting response notes';
  end if;

  update public.casting_responses
  set admin_note = btrim(coalesce(p_admin_note, ''))
  where casting_id = p_casting_id
    and profile_id = p_profile_id;

  if not found then
    raise exception 'Casting response not found';
  end if;
end;
$$;

grant execute on function public.set_casting_response_admin_note(uuid, uuid, text)
  to authenticated;
