-- CRM statuses for agent selections.
-- Run after selections_rpc.sql / selection_rls_hard_reset.sql.

alter table public.selections
  add column if not exists status text not null default 'draft';

update public.selections
set status = 'draft'
where status is null or btrim(status) = '';

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'selections_status_check'
  ) then
    alter table public.selections
      add constraint selections_status_check
      check (
        status in (
          'draft',
          'sent_to_client',
          'client_viewed',
          'selected',
          'rejected'
        )
      );
  end if;
end;
$$;

create index if not exists selections_status_created_at_idx
  on public.selections (status, created_at desc);

drop policy if exists "Selection owners and admins can update selections"
  on public.selections;

create policy "Selection owners and admins can update selections"
  on public.selections
  for update
  to authenticated
  using (
    created_by = auth.uid()
    or public.current_user_is_admin()
  )
  with check (
    created_by = auth.uid()
    or public.current_user_is_admin()
  );

create or replace function public.set_selection_status(
  p_selection_id uuid,
  p_status text
)
returns void
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_status text := lower(btrim(coalesce(p_status, '')));
begin
  if v_status not in (
    'draft',
    'sent_to_client',
    'client_viewed',
    'selected',
    'rejected'
  ) then
    raise exception 'Unsupported selection status: %', p_status;
  end if;

  update public.selections
  set status = v_status
  where id = p_selection_id
    and (
      created_by = auth.uid()
      or public.current_user_is_admin()
    );

  if not found then
    raise exception 'Selection not found or access denied';
  end if;
end;
$$;

grant execute on function public.set_selection_status(uuid, text)
  to authenticated;

create or replace function public.mark_selection_client_viewed(
  p_selection_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
begin
  update public.selections
  set status = 'client_viewed'
  where id = p_selection_id
    and coalesce(is_public, false) = true
    and status = 'sent_to_client';
end;
$$;

grant execute on function public.mark_selection_client_viewed(uuid)
  to anon, authenticated;

notify pgrst, 'reload schema';
