-- One-time acknowledgement for rejected account status requests.
-- Run after account_public_roles / casting_agent_applications SQL.

alter table public.casting_agent_applications
  add column if not exists rejection_seen_at timestamptz;

create index if not exists casting_agent_applications_rejection_seen_idx
  on public.casting_agent_applications (user_id, status, rejection_seen_at);

create or replace function public.mark_casting_agent_application_rejection_seen(
  p_application_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
set row_security = off
as $mark_casting_agent_application_rejection_seen$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  update public.casting_agent_applications
  set
    rejection_seen_at = coalesce(rejection_seen_at, now()),
    updated_at = now()
  where id = p_application_id
    and user_id = v_user_id
    and status = 'rejected';
end;
$mark_casting_agent_application_rejection_seen$;

grant execute on function public.mark_casting_agent_application_rejection_seen(uuid)
  to authenticated;
