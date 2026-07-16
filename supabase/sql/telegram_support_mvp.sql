-- Telegram support: FAQ, secure account linking and webhook idempotency.
-- Apply after the support_* SQL files.

create table if not exists public.support_faq (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  question text not null,
  answer text not null,
  keywords text[] not null default '{}',
  is_active boolean not null default true,
  sort_order integer not null default 100,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.telegram_support_links (
  user_id uuid primary key references auth.users(id) on delete cascade,
  telegram_chat_id bigint not null unique,
  telegram_user_id bigint,
  telegram_username text,
  linked_at timestamptz not null default now(),
  revoked_at timestamptz
);

create table if not exists public.telegram_support_link_codes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  code_hash text not null unique,
  expires_at timestamptz not null,
  consumed_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.telegram_support_updates (
  update_id bigint primary key,
  telegram_chat_id bigint,
  received_at timestamptz not null default now()
);

create table if not exists public.telegram_support_runtime_config (
  id boolean primary key default true check (id),
  db_webhook_secret text not null,
  updated_at timestamptz not null default now()
);

alter table public.telegram_support_updates
  add column if not exists telegram_chat_id bigint;
create index if not exists telegram_support_updates_chat_time_idx
  on public.telegram_support_updates (telegram_chat_id, received_at desc);

alter table public.support_faq enable row level security;
alter table public.telegram_support_links enable row level security;
alter table public.telegram_support_link_codes enable row level security;
alter table public.telegram_support_updates enable row level security;
alter table public.telegram_support_runtime_config enable row level security;

drop policy if exists "Anyone can read active support FAQ" on public.support_faq;
create policy "Anyone can read active support FAQ"
  on public.support_faq for select
  using (is_active);

drop policy if exists "Users can read own Telegram support link" on public.telegram_support_links;
create policy "Users can read own Telegram support link"
  on public.telegram_support_links for select to authenticated
  using (user_id = auth.uid());

grant select on public.support_faq to anon, authenticated;
grant select on public.telegram_support_links to authenticated;

insert into public.support_faq (slug, question, answer, keywords, sort_order)
values
  ('profile_hidden', 'Почему анкета не видна в каталоге?',
   'Анкета появляется в каталоге после успешной модерации и при активном размещении. Проверьте статус анкеты и срок размещения в разделе «Мой аккаунт».',
   array['анкета', 'каталог', 'не видна', 'размещение'], 10),
  ('moderation_time', 'Сколько длится модерация?',
   'Обычно модерация занимает до 2 рабочих дней. Если срок прошёл, напишите администратору — обращение попадёт в очередь поддержки.',
   array['модерация', 'проверка', 'сколько', 'срок'], 20),
  ('placement_payment', 'Как оплатить размещение?',
   'Откройте «Мой аккаунт» → «Тарифы», выберите анкету и срок размещения, затем нажмите «Перейти к оплате».',
   array['оплата', 'оплатить', 'тариф', 'размещение', 'юкасса'], 30),
  ('casting_response', 'Как откликнуться на кастинг?',
   'Откройте нужный кастинг, проверьте требования и нажмите кнопку отклика. Для отклика анкета должна быть заполнена и одобрена.',
   array['кастинг', 'отклик', 'откликнуться'], 40)
on conflict (slug) do update set
  question = excluded.question,
  answer = excluded.answer,
  keywords = excluded.keywords,
  sort_order = excluded.sort_order,
  updated_at = now();

create or replace function public.create_telegram_support_link_code()
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code text;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;

  delete from public.telegram_support_link_codes
  where user_id = auth.uid() and consumed_at is null;

  v_code := upper(encode(extensions.gen_random_bytes(4), 'hex'));
  insert into public.telegram_support_link_codes (user_id, code_hash, expires_at)
  values (
    auth.uid(),
    encode(extensions.digest(v_code, 'sha256'), 'hex'),
    now() + interval '10 minutes'
  );
  return v_code;
end;
$$;

create or replace function public.consume_telegram_support_link_code(
  p_code text,
  p_chat_id bigint,
  p_telegram_user_id bigint,
  p_username text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
begin
  select user_id into v_user_id
  from public.telegram_support_link_codes
  where code_hash = encode(
      extensions.digest(upper(trim(p_code)), 'sha256'),
      'hex'
    )
    and consumed_at is null and expires_at > now()
  for update;

  if v_user_id is null then return null; end if;

  delete from public.telegram_support_links
  where telegram_chat_id = p_chat_id and user_id <> v_user_id;

  insert into public.telegram_support_links (
    user_id, telegram_chat_id, telegram_user_id, telegram_username, linked_at, revoked_at
  ) values (
    v_user_id, p_chat_id, p_telegram_user_id, nullif(trim(p_username), ''), now(), null
  )
  on conflict (user_id) do update set
    telegram_chat_id = excluded.telegram_chat_id,
    telegram_user_id = excluded.telegram_user_id,
    telegram_username = excluded.telegram_username,
    linked_at = now(), revoked_at = null;

  update public.telegram_support_link_codes
  set consumed_at = now()
  where user_id = v_user_id and consumed_at is null;

  return v_user_id;
end;
$$;

create or replace function public.revoke_my_telegram_support_link()
returns void
language sql
security definer
set search_path = public
as $$
  update public.telegram_support_links
  set revoked_at = now()
  where user_id = auth.uid();
$$;

revoke all on function public.create_telegram_support_link_code() from public;
revoke all on function public.consume_telegram_support_link_code(text,bigint,bigint,text) from public;
revoke all on function public.revoke_my_telegram_support_link() from public;
grant execute on function public.create_telegram_support_link_code() to authenticated;
grant execute on function public.revoke_my_telegram_support_link() to authenticated;
grant execute on function public.consume_telegram_support_link_code(text,bigint,bigint,text) to service_role;

create or replace function public.configure_telegram_support_delivery(p_secret text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if current_setting('role', true) <> 'service_role' then
    raise exception 'Access denied';
  end if;
  if char_length(coalesce(p_secret, '')) < 32 then
    raise exception 'Invalid delivery secret';
  end if;
  insert into public.telegram_support_runtime_config (id, db_webhook_secret)
  values (true, p_secret)
  on conflict (id) do update set
    db_webhook_secret = excluded.db_webhook_secret,
    updated_at = now();
end;
$$;

revoke all on function public.configure_telegram_support_delivery(text) from public;
grant execute on function public.configure_telegram_support_delivery(text) to service_role;

create extension if not exists pg_net;

create or replace function public.deliver_support_admin_reply_to_telegram()
returns trigger
language plpgsql
security definer
set search_path = public, net
as $$
declare
  v_secret text;
begin
  if new.author_kind <> 'admin' or new.is_internal then return new; end if;
  if not exists (
    select 1 from public.support_tickets
    where id = new.ticket_id and channel = 'telegram'
  ) then return new; end if;

  select db_webhook_secret into v_secret
  from public.telegram_support_runtime_config
  where id = true;
  if v_secret is null then return new; end if;

  perform net.http_post(
    url := 'https://dherzlobdrknoajeidbz.supabase.co/functions/v1/telegram-support',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-support-webhook-secret', v_secret
    ),
    body := jsonb_build_object(
      'type', 'INSERT',
      'table', 'support_messages',
      'schema', 'public',
      'record', to_jsonb(new)
    ),
    timeout_milliseconds := 5000
  );
  return new;
end;
$$;

drop trigger if exists support_admin_reply_telegram_delivery on public.support_messages;
create trigger support_admin_reply_telegram_delivery
after insert on public.support_messages
for each row execute function public.deliver_support_admin_reply_to_telegram();
