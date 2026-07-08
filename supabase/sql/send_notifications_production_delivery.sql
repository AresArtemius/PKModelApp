-- Production delivery trigger for app_notifications.
--
-- Applies two authenticated delivery paths for the send-notifications Edge Function:
-- 1. Immediate pg_net webhook on every app_notifications insert.
-- 2. pg_cron fallback every minute to process pending/failed queue items.
--
-- Before running this SQL in production, store the service-role key in Supabase
-- Vault under the name `send_notifications_service_role_key`.
--
-- Example, run once in the SQL editor with the real service-role key:
-- select vault.create_secret(
--   'eyJ...',
--   'send_notifications_service_role_key',
--   'Authorization token for the send-notifications worker cron/webhook'
-- );

create extension if not exists pg_net;
create extension if not exists pg_cron;
create extension if not exists supabase_vault;

create or replace function public.send_notifications_worker_auth_headers()
returns jsonb
language plpgsql
security definer
set search_path = public, vault
as $$
declare
  service_role_key text;
begin
  select decrypted_secret
  into service_role_key
  from vault.decrypted_secrets
  where name = 'send_notifications_service_role_key'
  limit 1;

  if nullif(service_role_key, '') is null then
    raise exception 'Missing Vault secret: send_notifications_service_role_key';
  end if;

  return jsonb_build_object(
    'Content-Type', 'application/json',
    'Authorization', 'Bearer ' || service_role_key
  );
end;
$$;

do $$
begin
  perform public.send_notifications_worker_auth_headers();
exception
  when others then
    raise exception
      'Cannot install send-notifications delivery. Store service-role key in Supabase Vault as send_notifications_service_role_key first.';
end;
$$;

create or replace function public.invoke_send_notifications_worker()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  perform net.http_post(
    url := 'https://dherzlobdrknoajeidbz.supabase.co/functions/v1/send-notifications',
    headers := public.send_notifications_worker_auth_headers(),
    body := jsonb_build_object('record', to_jsonb(new)),
    timeout_milliseconds := 10000
  );

  return new;
exception
  when others then
    -- Notification enqueue must not fail just because the async webhook failed.
    return new;
end;
$$;

drop trigger if exists app_notifications_send_worker_after_insert
  on public.app_notifications;

create trigger app_notifications_send_worker_after_insert
after insert on public.app_notifications
for each row
execute function public.invoke_send_notifications_worker();

do $$
begin
  if exists (
    select 1
    from cron.job
    where jobname = 'send-notifications-every-minute'
  ) then
    perform cron.unschedule('send-notifications-every-minute');
  end if;
end;
$$;

select cron.schedule(
  'send-notifications-every-minute',
  '* * * * *',
  $$
  select net.http_post(
    url := 'https://dherzlobdrknoajeidbz.supabase.co/functions/v1/send-notifications',
    headers := public.send_notifications_worker_auth_headers(),
    body := '{}'::jsonb,
    timeout_milliseconds := 10000
  );
  $$
);
