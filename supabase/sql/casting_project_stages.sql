-- Project stages for castings.

alter table public.castings
  add column if not exists project_stage text not null default 'intake';

update public.castings
set project_stage = 'intake'
where project_stage is null or btrim(project_stage) = '';

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'castings_project_stage_check'
  ) then
    alter table public.castings
      add constraint castings_project_stage_check
      check (
        project_stage in (
          'intake',
          'accepting_applications',
          'shortlist',
          'callback',
          'approval',
          'shoot',
          'completed'
        )
      );
  end if;
end;
$$;

create index if not exists castings_project_stage_created_idx
  on public.castings (project_stage, created_at desc);

create or replace function public.set_casting_project_stage(
  p_casting_id uuid,
  p_project_stage text
)
returns void
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_stage text := lower(btrim(coalesce(p_project_stage, '')));
begin
  if not public.current_user_is_admin() then
    raise exception 'Only admins can update casting project stages';
  end if;

  if v_stage not in (
    'intake',
    'accepting_applications',
    'shortlist',
    'callback',
    'approval',
    'shoot',
    'completed'
  ) then
    raise exception 'Unsupported casting project stage: %', p_project_stage;
  end if;

  update public.castings
  set project_stage = v_stage
  where id = p_casting_id;

  if not found then
    raise exception 'Casting not found';
  end if;
end;
$$;

grant execute on function public.set_casting_project_stage(uuid, text)
  to authenticated;
