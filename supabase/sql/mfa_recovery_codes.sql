create extension if not exists pgcrypto;

create table if not exists public.user_mfa_recovery_codes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  code_hash text not null,
  batch_id uuid not null,
  created_at timestamptz not null default now(),
  used_at timestamptz
);

alter table public.user_mfa_recovery_codes enable row level security;

create index if not exists user_mfa_recovery_codes_user_active_idx
  on public.user_mfa_recovery_codes (user_id, used_at, created_at desc);

drop policy if exists "Users can read own MFA recovery code status"
  on public.user_mfa_recovery_codes;
create policy "Users can read own MFA recovery code status"
  on public.user_mfa_recovery_codes
  for select
  to authenticated
  using (user_id = auth.uid());

create or replace function public.normalize_mfa_recovery_code(p_code text)
returns text
language sql
immutable
as $$
  select upper(regexp_replace(coalesce(p_code, ''), '[^a-zA-Z0-9]', '', 'g'));
$$;

create or replace function public.rotate_my_mfa_recovery_codes(p_count int default 10)
returns table(code text)
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_user_id uuid := auth.uid();
  v_count int := least(greatest(coalesce(p_count, 10), 4), 12);
  v_batch_id uuid := gen_random_uuid();
  v_clean_code text;
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  update public.user_mfa_recovery_codes
  set used_at = coalesce(used_at, now())
  where user_id = v_user_id
    and used_at is null;

  for i in 1..v_count loop
    v_clean_code := upper(encode(gen_random_bytes(5), 'hex'));

    insert into public.user_mfa_recovery_codes (
      user_id,
      code_hash,
      batch_id
    ) values (
      v_user_id,
      encode(digest(v_clean_code, 'sha256'), 'hex'),
      v_batch_id
    );

    code := substr(v_clean_code, 1, 5) || '-' || substr(v_clean_code, 6, 5);
    return next;
  end loop;
end;
$$;

create or replace function public.get_my_mfa_recovery_code_status()
returns table(
  active_count int,
  used_count int,
  last_generated_at timestamptz
)
language sql
security definer
set search_path = public
as $$
  select
    count(*) filter (where used_at is null)::int as active_count,
    count(*) filter (where used_at is not null)::int as used_count,
    max(created_at) as last_generated_at
  from public.user_mfa_recovery_codes
  where user_id = auth.uid();
$$;

create or replace function public.consume_my_mfa_recovery_code(p_code text)
returns boolean
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_user_id uuid := auth.uid();
  v_clean_code text := public.normalize_mfa_recovery_code(p_code);
  v_updated int := 0;
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  if length(v_clean_code) < 8 then
    return false;
  end if;

  update public.user_mfa_recovery_codes
  set used_at = now()
  where user_id = v_user_id
    and used_at is null
    and code_hash = encode(digest(v_clean_code, 'sha256'), 'hex');

  get diagnostics v_updated = row_count;
  return v_updated > 0;
end;
$$;

grant execute on function public.rotate_my_mfa_recovery_codes(int)
  to authenticated;
grant execute on function public.get_my_mfa_recovery_code_status()
  to authenticated;
grant execute on function public.consume_my_mfa_recovery_code(text)
  to authenticated;
