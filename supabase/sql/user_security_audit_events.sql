create table if not exists public.user_security_audit_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  event_type text not null,
  event_label text not null default '',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table public.user_security_audit_events enable row level security;

create index if not exists user_security_audit_events_user_created_idx
  on public.user_security_audit_events (user_id, created_at desc);

create index if not exists user_security_audit_events_type_created_idx
  on public.user_security_audit_events (event_type, created_at desc);

drop policy if exists "Users can read own security audit events"
  on public.user_security_audit_events;
create policy "Users can read own security audit events"
  on public.user_security_audit_events
  for select
  to authenticated
  using (user_id = auth.uid());

drop policy if exists "Users can insert own security audit events"
  on public.user_security_audit_events;
create policy "Users can insert own security audit events"
  on public.user_security_audit_events
  for insert
  to authenticated
  with check (user_id = auth.uid());

drop policy if exists "Admins can read security audit events"
  on public.user_security_audit_events;
create policy "Admins can read security audit events"
  on public.user_security_audit_events
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.user_roles ur
      where ur.user_id = auth.uid()
        and ur.role = 'admin'
    )
  );
