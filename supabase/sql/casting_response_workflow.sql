-- Full casting response workflow: board statuses, bulk moves, and history.
-- Safe to run multiple times in Supabase SQL Editor.

alter table public.casting_responses
  add column if not exists status text not null default 'submitted';

update public.casting_responses
set status = 'shortlist'
where status = 'viewed';

update public.casting_responses
set status = 'callback'
where status = 'invited';

do $$
begin
  if exists (
    select 1
    from pg_constraint
    where conname = 'casting_responses_status_check'
      and conrelid = 'public.casting_responses'::regclass
  ) then
    alter table public.casting_responses
      drop constraint casting_responses_status_check;
  end if;
end $$;

alter table public.casting_responses
  add constraint casting_responses_status_check
  check (
    status in (
      'submitted',
      'shortlist',
      'callback',
      'approved',
      'reserve',
      'rejected',
      'viewed',
      'invited'
    )
  );

create index if not exists casting_responses_status_idx
  on public.casting_responses (status);

create table if not exists public.casting_response_status_history (
  id uuid primary key default gen_random_uuid(),
  casting_id uuid not null references public.castings(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  old_status text,
  new_status text not null,
  actor_user_id uuid references auth.users(id) on delete set null,
  note text not null default '',
  created_at timestamptz not null default now()
);

create index if not exists casting_response_status_history_casting_idx
  on public.casting_response_status_history (casting_id, created_at desc);

create index if not exists casting_response_status_history_profile_idx
  on public.casting_response_status_history (profile_id, created_at desc);

alter table public.casting_response_status_history enable row level security;

drop policy if exists "Admins can view casting response status history"
  on public.casting_response_status_history;

create policy "Admins can view casting response status history"
  on public.casting_response_status_history
  for select
  to authenticated
  using (public.current_user_is_admin());

drop policy if exists "Admins can insert casting response status history"
  on public.casting_response_status_history;

create policy "Admins can insert casting response status history"
  on public.casting_response_status_history
  for insert
  to authenticated
  with check (public.current_user_is_admin());

create or replace function public.set_casting_response_status(
  p_casting_id uuid,
  p_profile_id uuid,
  p_status text,
  p_note text default ''
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_old_status text;
  v_new_status text := lower(btrim(coalesce(p_status, '')));
begin
  if not public.current_user_is_admin() then
    raise exception 'Only admins can update casting response status';
  end if;

  if v_new_status not in (
    'submitted',
    'shortlist',
    'callback',
    'approved',
    'reserve',
    'rejected',
    'viewed',
    'invited'
  ) then
    raise exception 'Invalid casting response status: %', p_status;
  end if;

  select status
  into v_old_status
  from public.casting_responses
  where casting_id = p_casting_id
    and profile_id = p_profile_id
  for update;

  if not found then
    raise exception 'Casting response not found';
  end if;

  if coalesce(v_old_status, '') = v_new_status then
    return;
  end if;

  update public.casting_responses
  set status = v_new_status
  where casting_id = p_casting_id
    and profile_id = p_profile_id;

  insert into public.casting_response_status_history (
    casting_id,
    profile_id,
    old_status,
    new_status,
    actor_user_id,
    note
  )
  values (
    p_casting_id,
    p_profile_id,
    v_old_status,
    v_new_status,
    auth.uid(),
    coalesce(p_note, '')
  );
end;
$$;

grant execute on function public.set_casting_response_status(uuid, uuid, text, text)
  to authenticated;
