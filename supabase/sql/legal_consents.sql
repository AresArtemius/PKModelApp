-- Public legal document consent storage.
-- Apply in Supabase SQL Editor before relying on RPC table writes in production.

create table if not exists public.user_legal_consents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  privacy_policy_version text not null,
  terms_version text not null,
  cookie_policy_version text not null,
  processing_notice_version text not null,
  accepted_at timestamptz not null default now(),
  source text not null default 'registration',
  user_agent text not null default '',
  client_ip text not null default ''
);

create index if not exists idx_user_legal_consents_user_created
  on public.user_legal_consents(user_id, accepted_at desc);

alter table public.user_legal_consents enable row level security;

drop policy if exists "Users can view own legal consents"
  on public.user_legal_consents;
create policy "Users can view own legal consents"
  on public.user_legal_consents
  for select
  using (auth.uid() = user_id);

drop policy if exists "Users can insert own legal consents"
  on public.user_legal_consents;
create policy "Users can insert own legal consents"
  on public.user_legal_consents
  for insert
  with check (auth.uid() = user_id);

drop policy if exists "Admins can view legal consents"
  on public.user_legal_consents;
create policy "Admins can view legal consents"
  on public.user_legal_consents
  for select
  using (public.current_user_is_admin());

create or replace function public.record_user_legal_consent(
  p_privacy_policy_version text,
  p_terms_version text,
  p_cookie_policy_version text,
  p_processing_notice_version text,
  p_source text default 'registration',
  p_user_agent text default '',
  p_client_ip text default ''
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_id uuid;
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  insert into public.user_legal_consents (
    user_id,
    privacy_policy_version,
    terms_version,
    cookie_policy_version,
    processing_notice_version,
    source,
    user_agent,
    client_ip
  )
  values (
    v_user_id,
    p_privacy_policy_version,
    p_terms_version,
    p_cookie_policy_version,
    p_processing_notice_version,
    coalesce(nullif(trim(p_source), ''), 'registration'),
    coalesce(p_user_agent, ''),
    coalesce(p_client_ip, '')
  )
  returning id into v_id;

  return v_id;
end;
$$;

grant execute on function public.record_user_legal_consent(
  text,
  text,
  text,
  text,
  text,
  text,
  text
) to authenticated;
