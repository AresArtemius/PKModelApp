-- Daily support hours (Moscow) and private support screenshots.
-- Apply after telegram_support_mvp.sql.

create table if not exists public.support_service_settings (
  id boolean primary key default true check (id),
  timezone text not null default 'Europe/Moscow',
  open_hour smallint not null default 10 check (open_hour between 0 and 23),
  close_hour smallint not null default 22 check (close_hour between 1 and 24),
  response_text text not null default 'Ответим в рабочее время в порядке очереди.',
  updated_at timestamptz not null default now()
);

insert into public.support_service_settings (
  id, timezone, open_hour, close_hour, response_text
) values (
  true, 'Europe/Moscow', 10, 22,
  'Поддержка работает ежедневно с 10:00 до 22:00 по Москве.'
)
on conflict (id) do update set
  timezone = excluded.timezone,
  open_hour = excluded.open_hour,
  close_hour = excluded.close_hour,
  response_text = excluded.response_text,
  updated_at = now();

create table if not exists public.support_attachments (
  id uuid primary key default gen_random_uuid(),
  ticket_id uuid not null references public.support_tickets(id) on delete cascade,
  message_id uuid references public.support_messages(id) on delete cascade,
  uploader_id uuid references auth.users(id) on delete set null,
  source text not null check (source in ('in_app', 'telegram', 'email', 'admin')),
  storage_path text not null unique,
  original_name text not null,
  mime_type text not null,
  size_bytes bigint not null check (size_bytes between 1 and 10485760),
  created_at timestamptz not null default now()
);

create index if not exists support_attachments_ticket_idx
  on public.support_attachments (ticket_id, created_at);

alter table public.support_service_settings enable row level security;
alter table public.support_attachments enable row level security;

drop policy if exists "Everyone can read support hours" on public.support_service_settings;
create policy "Everyone can read support hours"
  on public.support_service_settings for select using (true);

drop policy if exists "Ticket participants can read support attachments" on public.support_attachments;
create policy "Ticket participants can read support attachments"
  on public.support_attachments for select to authenticated
  using (
    exists (
      select 1 from public.support_tickets t
      where t.id = ticket_id
        and (t.user_id = auth.uid() or public.current_user_is_support_staff())
    )
  );

grant select on public.support_service_settings to anon, authenticated;
grant select on public.support_attachments to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'support-attachments', 'support-attachments', false, 10485760,
  array['image/jpeg', 'image/png', 'image/webp', 'image/heic']
)
on conflict (id) do update set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Ticket participants can read support files" on storage.objects;
create policy "Ticket participants can read support files"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'support-attachments'
    and exists (
      select 1
      from public.support_attachments a
      join public.support_tickets t on t.id = a.ticket_id
      where a.storage_path = name
        and (t.user_id = auth.uid() or public.current_user_is_support_staff())
    )
  );
