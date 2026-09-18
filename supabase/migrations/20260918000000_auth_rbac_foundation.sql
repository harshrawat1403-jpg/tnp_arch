-- Phase 3: authentication and authorization foundation. Product workflows remain
-- deliberately unavailable until their approved phases add narrowly scoped policies.

create schema if not exists private;

revoke all on schema private from public, anon, authenticated;
grant usage on schema private to authenticated;

create or replace function private.has_active_role(p_allowed_roles public.app_role[])
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles as profile
    where profile.id = (select auth.uid())
      and profile.is_active
      and profile.role = any(p_allowed_roles)
  );
$$;

revoke all on function private.has_active_role(public.app_role[]) from public, anon, authenticated;
grant execute on function private.has_active_role(public.app_role[]) to authenticated;

-- The Data API remains private by default. Explicit grants below are the only
-- browser-facing table capabilities introduced in this phase.
revoke all on all tables in schema public from public, anon, authenticated;
revoke all on all sequences in schema public from public, anon, authenticated;
revoke execute on all functions in schema public from public, anon, authenticated;

alter default privileges in schema public revoke all on tables from public, anon, authenticated;
alter default privileges in schema public revoke all on sequences from public, anon, authenticated;
alter default privileges in schema public revoke execute on functions from public, anon, authenticated;

alter table public.profiles enable row level security;
alter table public.student_roster enable row level security;
alter table public.student_profiles enable row level security;
alter table public.academic_records enable row level security;
alter table public.companies enable row level security;
alter table public.recruiters enable row level security;
alter table public.placement_drives enable row level security;
alter table public.drive_eligible_batches enable row level security;
alter table public.drive_eligibility enable row level security;
alter table public.recruiter_drive_access enable row level security;
alter table public.applications enable row level security;
alter table public.application_status_history enable row level security;
alter table public.documents enable row level security;
alter table public.announcements enable row level security;
alter table public.audit_logs enable row level security;

grant select on table public.profiles to authenticated;
grant select on table public.audit_logs to authenticated;

create policy "active users can read their own profile"
on public.profiles
for select
to authenticated
using (
  id = (select auth.uid())
  and is_active
);

create policy "super admins can read all profiles"
on public.profiles
for select
to authenticated
using (
  (select private.has_active_role(array['SUPER_ADMIN'::public.app_role]))
);

create policy "super admins can read audit logs"
on public.audit_logs
for select
to authenticated
using (
  (select private.has_active_role(array['SUPER_ADMIN'::public.app_role]))
);

comment on function private.has_active_role(public.app_role[]) is
  'Phase 3 RLS helper. It derives the active caller role from auth.uid(), never from a caller-provided user identifier.';

