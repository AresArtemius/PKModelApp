-- Admin-only cleanup for the combined action audit journal.
-- Run once in production to enable the "clear audit log" button.

create or replace function public.clear_action_audit_logs()
returns jsonb
language plpgsql
security definer
set search_path = public
as $clear_action_audit_logs$
declare
  v_profile_count integer := 0;
  v_admin_count integer := 0;
begin
  if not public.current_user_is_admin() then
    raise exception 'Only admins can clear action audit logs'
      using errcode = '42501';
  end if;

  delete from public.profile_action_logs;
  get diagnostics v_profile_count = row_count;

  delete from public.admin_action_logs;
  get diagnostics v_admin_count = row_count;

  return jsonb_build_object(
    'profile_action_logs_deleted', v_profile_count,
    'admin_action_logs_deleted', v_admin_count
  );
end;
$clear_action_audit_logs$;

revoke all on function public.clear_action_audit_logs() from public;
grant execute on function public.clear_action_audit_logs() to authenticated;
