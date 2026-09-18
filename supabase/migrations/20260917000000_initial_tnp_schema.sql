-- Phase 2 baseline: relational TNP schema only. Authentication flows, grants, and RLS
-- policies are deliberately deferred to Phase 3.

create extension if not exists pgcrypto;

create type public.app_role as enum (
  'SUPER_ADMIN',
  'TNP_SECRETARY',
  'TNP_COORDINATOR',
  'STUDENT',
  'RECRUITER'
);

create type public.profile_verification_status as enum ('PENDING', 'VERIFIED');
create type public.drive_type as enum ('PLACEMENT', 'INTERNSHIP');
create type public.drive_status as enum ('DRAFT', 'PUBLISHED', 'CLOSED', 'ARCHIVED');
create type public.application_status as enum (
  'APPLIED',
  'SHORTLISTED',
  'INTERVIEW',
  'SELECTED',
  'REJECTED',
  'WITHDRAWN'
);
create type public.document_kind as enum ('RESUME', 'PROFILE_IMAGE', 'PORTFOLIO_FILE');
create type public.announcement_audience as enum ('PUBLIC', 'STUDENTS', 'RECRUITERS', 'TNP_STAFF');

create table public.profiles (
  id uuid primary key references auth.users (id) on delete restrict,
  display_name text not null check (char_length(trim(display_name)) between 1 and 160),
  role public.app_role not null default 'STUDENT',
  is_active boolean not null default true,
  coordinator_slot smallint,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_coordinator_slot_check check (
    (role = 'TNP_COORDINATOR' and coordinator_slot in (1, 2))
    or (role <> 'TNP_COORDINATOR' and coordinator_slot is null)
  )
);

create table public.student_roster (
  id uuid primary key default gen_random_uuid(),
  student_identifier text not null check (char_length(trim(student_identifier)) between 1 and 80),
  institutional_email text not null check (
    institutional_email = lower(institutional_email)
    and position('@' in institutional_email) > 1
  ),
  course text not null check (char_length(trim(course)) between 1 and 120),
  batch_year smallint not null check (batch_year between 2000 and 2200),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (student_identifier),
  unique (institutional_email)
);

create table public.student_profiles (
  user_id uuid primary key references public.profiles (id) on delete restrict,
  roster_id uuid not null unique references public.student_roster (id) on delete restrict,
  phone_number text,
  portfolio_url text,
  skills text[] not null default '{}',
  verification_status public.profile_verification_status not null default 'PENDING',
  verified_at timestamptz,
  verified_by uuid references public.profiles (id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint student_profiles_verification_check check (
    (verification_status = 'PENDING' and verified_at is null and verified_by is null)
    or (verification_status = 'VERIFIED' and verified_at is not null and verified_by is not null)
  )
);

create table public.academic_records (
  student_id uuid primary key references public.student_profiles (user_id) on delete restrict,
  course text not null check (char_length(trim(course)) between 1 and 120),
  batch_year smallint not null check (batch_year between 2000 and 2200),
  cgpa numeric(4, 2) not null check (cgpa between 0 and 10),
  active_backlog_count smallint not null default 0 check (active_backlog_count between 0 and 50),
  verification_status public.profile_verification_status not null default 'PENDING',
  verified_at timestamptz,
  verified_by uuid references public.profiles (id) on delete restrict,
  correction_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint academic_records_verification_check check (
    (verification_status = 'PENDING' and verified_at is null and verified_by is null)
    or (verification_status = 'VERIFIED' and verified_at is not null and verified_by is not null)
  ),
  constraint academic_records_correction_reason_check check (
    correction_reason is null or char_length(trim(correction_reason)) between 1 and 2000
  )
);

create table public.companies (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(trim(name)) between 1 and 160),
  normalized_name text generated always as (lower(trim(name))) stored,
  website_url text,
  description text,
  is_archived boolean not null default false,
  archived_at timestamptz,
  archived_by uuid references public.profiles (id) on delete restrict,
  created_by uuid references public.profiles (id) on delete restrict,
  updated_by uuid references public.profiles (id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (normalized_name),
  constraint companies_archive_check check (
    (is_archived = false and archived_at is null and archived_by is null)
    or (is_archived = true and archived_at is not null and archived_by is not null)
  )
);

create table public.recruiters (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies (id) on delete restrict,
  user_id uuid unique references public.profiles (id) on delete restrict,
  full_name text not null check (char_length(trim(full_name)) between 1 and 160),
  email text not null check (email = lower(email) and position('@' in email) > 1),
  phone_number text,
  invitation_expires_at timestamptz,
  is_archived boolean not null default false,
  archived_at timestamptz,
  archived_by uuid references public.profiles (id) on delete restrict,
  created_by uuid references public.profiles (id) on delete restrict,
  updated_by uuid references public.profiles (id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (email),
  constraint recruiters_invitation_check check (
    invitation_expires_at is null or invitation_expires_at > created_at
  ),
  constraint recruiters_archive_check check (
    (is_archived = false and archived_at is null and archived_by is null)
    or (is_archived = true and archived_at is not null and archived_by is not null)
  )
);

create table public.placement_drives (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies (id) on delete restrict,
  title text not null check (char_length(trim(title)) between 1 and 200),
  drive_type public.drive_type not null,
  description text not null check (char_length(trim(description)) between 1 and 10000),
  package_lpa numeric(10, 2) check (package_lpa is null or package_lpa >= 0),
  stipend_monthly numeric(10, 2) check (stipend_monthly is null or stipend_monthly >= 0),
  compensation_details text,
  location text,
  application_deadline timestamptz not null,
  status public.drive_status not null default 'DRAFT',
  published_at timestamptz,
  closed_at timestamptz,
  archived_at timestamptz,
  archived_by uuid references public.profiles (id) on delete restrict,
  created_by uuid references public.profiles (id) on delete restrict,
  updated_by uuid references public.profiles (id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint placement_drives_status_timestamp_check check (
    (status = 'DRAFT' and published_at is null and closed_at is null and archived_at is null)
    or (status = 'PUBLISHED' and published_at is not null and closed_at is null and archived_at is null)
    or (status = 'CLOSED' and published_at is not null and closed_at is not null and archived_at is null)
    or (status = 'ARCHIVED' and archived_at is not null and archived_by is not null)
  ),
  constraint placement_drives_deadline_check check (application_deadline > created_at)
);

create table public.drive_eligible_batches (
  drive_id uuid not null references public.placement_drives (id) on delete restrict,
  course text not null check (char_length(trim(course)) between 1 and 120),
  batch_year smallint not null check (batch_year between 2000 and 2200),
  created_at timestamptz not null default now(),
  primary key (drive_id, course, batch_year)
);

create table public.drive_eligibility (
  drive_id uuid primary key references public.placement_drives (id) on delete restrict,
  minimum_cgpa numeric(4, 2) not null default 0 check (minimum_cgpa between 0 and 10),
  maximum_active_backlogs smallint not null default 0 check (maximum_active_backlogs between 0 and 50),
  exclude_previously_selected_placement boolean not null default false,
  informational_requirements text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.recruiter_drive_access (
  recruiter_id uuid not null references public.recruiters (id) on delete restrict,
  drive_id uuid not null references public.placement_drives (id) on delete restrict,
  can_view_applicants boolean not null default false,
  can_view_resumes boolean not null default false,
  expires_at timestamptz,
  granted_by uuid references public.profiles (id) on delete restrict,
  created_at timestamptz not null default now(),
  primary key (recruiter_id, drive_id),
  constraint recruiter_drive_access_resume_check check (
    can_view_resumes = false or can_view_applicants = true
  )
);

create table public.applications (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.student_profiles (user_id) on delete restrict,
  drive_id uuid not null references public.placement_drives (id) on delete restrict,
  submitted_by uuid not null references public.profiles (id) on delete restrict,
  current_status public.application_status not null default 'APPLIED',
  terminal_previous_status public.application_status,
  submitted_at timestamptz not null default now(),
  withdrawn_at timestamptz,
  terminal_correction_count integer not null default 0 check (terminal_correction_count >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (student_id, drive_id),
  constraint applications_submitter_check check (submitted_by = student_id),
  constraint applications_terminal_status_check check (
    (
      current_status in ('SELECTED', 'REJECTED', 'WITHDRAWN')
      and terminal_previous_status in ('APPLIED', 'SHORTLISTED', 'INTERVIEW')
    )
    or (
      current_status not in ('SELECTED', 'REJECTED', 'WITHDRAWN')
      and terminal_previous_status is null
    )
  ),
  constraint applications_withdrawn_timestamp_check check (
    (current_status = 'WITHDRAWN' and withdrawn_at is not null)
    or (current_status <> 'WITHDRAWN' and withdrawn_at is null)
  )
);

create table public.application_status_history (
  id uuid primary key default gen_random_uuid(),
  application_id uuid not null references public.applications (id) on delete restrict,
  previous_status public.application_status,
  next_status public.application_status not null,
  changed_by uuid not null references public.profiles (id) on delete restrict,
  reason text,
  is_terminal_correction boolean not null default false,
  created_at timestamptz not null default now(),
  constraint application_status_history_reason_check check (
    reason is null or char_length(trim(reason)) between 1 and 2000
  ),
  constraint application_status_history_transition_check check (
    (previous_status is null and next_status = 'APPLIED' and is_terminal_correction = false)
    or (
      is_terminal_correction = false
      and (
        (previous_status = 'APPLIED' and next_status in ('SHORTLISTED', 'REJECTED', 'WITHDRAWN'))
        or (previous_status = 'SHORTLISTED' and next_status in ('INTERVIEW', 'REJECTED'))
        or (previous_status = 'INTERVIEW' and next_status in ('SELECTED', 'REJECTED'))
      )
    )
    or (
      is_terminal_correction = true
      and previous_status in ('SELECTED', 'REJECTED', 'WITHDRAWN')
      and next_status in ('APPLIED', 'SHORTLISTED', 'INTERVIEW')
    )
  )
);

create table public.documents (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles (id) on delete restrict,
  document_kind public.document_kind not null,
  storage_bucket text not null check (char_length(trim(storage_bucket)) between 1 and 80),
  storage_path text not null check (char_length(trim(storage_path)) between 1 and 1000),
  original_filename text not null check (char_length(trim(original_filename)) between 1 and 255),
  mime_type text not null check (char_length(trim(mime_type)) between 1 and 120),
  byte_size integer not null check (byte_size > 0),
  is_archived boolean not null default false,
  archived_at timestamptz,
  archived_by uuid references public.profiles (id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (storage_bucket, storage_path),
  constraint documents_resume_check check (
    document_kind <> 'RESUME' or (mime_type = 'application/pdf' and byte_size <= 5242880)
  ),
  constraint documents_profile_image_check check (
    document_kind <> 'PROFILE_IMAGE'
    or (mime_type in ('image/jpeg', 'image/png', 'image/webp') and byte_size <= 5242880)
  ),
  constraint documents_portfolio_file_check check (
    document_kind <> 'PORTFOLIO_FILE' or byte_size <= 10485760
  ),
  constraint documents_archive_check check (
    (is_archived = false and archived_at is null and archived_by is null)
    or (is_archived = true and archived_at is not null and archived_by is not null)
  )
);

create table public.announcements (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(trim(title)) between 1 and 200),
  body text not null check (char_length(trim(body)) between 1 and 20000),
  audience public.announcement_audience not null,
  publish_at timestamptz not null default now(),
  expires_at timestamptz,
  is_archived boolean not null default false,
  archived_at timestamptz,
  archived_by uuid references public.profiles (id) on delete restrict,
  created_by uuid references public.profiles (id) on delete restrict,
  updated_by uuid references public.profiles (id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint announcements_expiry_check check (expires_at is null or expires_at > publish_at),
  constraint announcements_archive_check check (
    (is_archived = false and archived_at is null and archived_by is null)
    or (is_archived = true and archived_at is not null and archived_by is not null)
  )
);

create table public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid not null references public.profiles (id) on delete restrict,
  action text not null check (char_length(trim(action)) between 1 and 120),
  entity_type text not null check (char_length(trim(entity_type)) between 1 and 120),
  entity_id uuid not null,
  before_data jsonb,
  after_data jsonb,
  correlation_id uuid,
  created_at timestamptz not null default now(),
  constraint audit_logs_metadata_check check (
    (before_data is null or jsonb_typeof(before_data) = 'object')
    and (after_data is null or jsonb_typeof(after_data) = 'object')
  )
);

create unique index profiles_one_active_super_admin_idx
  on public.profiles (role)
  where role = 'SUPER_ADMIN' and is_active;

create unique index profiles_one_active_tnp_secretary_idx
  on public.profiles (role)
  where role = 'TNP_SECRETARY' and is_active;

create unique index profiles_active_coordinator_slot_idx
  on public.profiles (coordinator_slot)
  where role = 'TNP_COORDINATOR' and is_active;

create index student_roster_active_course_batch_idx
  on public.student_roster (course, batch_year)
  where is_active;

create index academic_records_course_batch_verification_idx
  on public.academic_records (course, batch_year, verification_status);

create index recruiters_company_active_idx
  on public.recruiters (company_id)
  where is_archived = false;

create index placement_drives_company_idx on public.placement_drives (company_id);

create index placement_drives_published_deadline_idx
  on public.placement_drives (application_deadline)
  where status = 'PUBLISHED';

create index drive_eligible_batches_course_batch_idx
  on public.drive_eligible_batches (course, batch_year, drive_id);

create index recruiter_drive_access_active_idx
  on public.recruiter_drive_access (recruiter_id, expires_at, drive_id);

create index applications_student_created_idx
  on public.applications (student_id, created_at desc);

create index applications_drive_status_idx
  on public.applications (drive_id, current_status);

create index application_status_history_application_created_idx
  on public.application_status_history (application_id, created_at);

create index documents_owner_kind_active_idx
  on public.documents (owner_id, document_kind)
  where is_archived = false;

create index announcements_audience_publish_idx
  on public.announcements (audience, publish_at desc)
  where is_archived = false;

create index audit_logs_entity_created_idx
  on public.audit_logs (entity_type, entity_id, created_at desc);

create index audit_logs_actor_created_idx
  on public.audit_logs (actor_id, created_at desc);

comment on index public.drive_eligible_batches_course_batch_idx is
  'Finds published-drive candidates for a student course and batch without scanning every drive.';
comment on index public.placement_drives_published_deadline_idx is
  'Supports the common published-drive listing ordered or filtered by application deadline.';
comment on index public.applications_drive_status_idx is
  'Supports paginated applicant queues for a drive filtered by current pipeline status.';
comment on index public.announcements_audience_publish_idx is
  'Supports audience-specific announcement feeds without scanning archived notices.';
comment on index public.audit_logs_entity_created_idx is
  'Supports targeted audit investigation in reverse chronological order.';

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.enforce_exactly_one_active_super_admin()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if (select count(*) from public.profiles where role = 'SUPER_ADMIN' and is_active) <> 1 then
    raise exception 'Exactly one active SUPER_ADMIN profile is required'
      using errcode = '23514';
  end if;

  return null;
end;
$$;

create constraint trigger profiles_require_exactly_one_active_super_admin
after insert or update of role, is_active or delete on public.profiles
deferrable initially deferred
for each row
execute function public.enforce_exactly_one_active_super_admin();

create or replace function public.enforce_student_profile_role()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if not exists (
    select 1 from public.profiles where id = new.user_id and role = 'STUDENT'
  ) then
    raise exception 'A student profile requires a STUDENT profile role' using errcode = '23514';
  end if;

  return new;
end;
$$;

create trigger student_profiles_require_student_role
before insert or update of user_id on public.student_profiles
for each row execute function public.enforce_student_profile_role();

create or replace function public.enforce_academic_record_roster_alignment()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_roster public.student_roster%rowtype;
begin
  select roster.* into v_roster
  from public.student_profiles as student_profile
  join public.student_roster as roster on roster.id = student_profile.roster_id
  where student_profile.user_id = new.student_id;

  if not found or new.course <> v_roster.course or new.batch_year <> v_roster.batch_year then
    raise exception 'Academic course and batch must match the linked student roster entry'
      using errcode = '23514';
  end if;

  return new;
end;
$$;

create trigger academic_records_require_roster_alignment
before insert or update of student_id, course, batch_year on public.academic_records
for each row execute function public.enforce_academic_record_roster_alignment();

create or replace function public.enforce_recruiter_profile_role()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.user_id is not null and not exists (
    select 1 from public.profiles where id = new.user_id and role = 'RECRUITER'
  ) then
    raise exception 'A recruiter user link requires a RECRUITER profile role' using errcode = '23514';
  end if;

  return new;
end;
$$;

create trigger recruiters_require_recruiter_role
before insert or update of user_id on public.recruiters
for each row execute function public.enforce_recruiter_profile_role();

create or replace function public.enforce_drive_lifecycle()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if tg_op = 'INSERT' and new.status <> 'DRAFT' then
    raise exception 'A placement drive must be created in DRAFT status' using errcode = '23514';
  end if;

  if tg_op = 'UPDATE' and new.status <> old.status then
    if not (
      (old.status = 'DRAFT' and new.status = 'PUBLISHED')
      or (old.status = 'PUBLISHED' and new.status = 'CLOSED')
      or (old.status = 'CLOSED' and new.status = 'ARCHIVED')
    ) then
      raise exception 'Invalid placement drive transition from % to %', old.status, new.status
        using errcode = '23514';
    end if;
  end if;

  return new;
end;
$$;

create trigger placement_drives_enforce_lifecycle
before insert or update of status on public.placement_drives
for each row execute function public.enforce_drive_lifecycle();

create or replace function public.prevent_direct_application_status_mutation()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if current_setting('app.application_transition', true) is distinct from 'true' then
    raise exception 'Use transition_application_status for application status changes'
      using errcode = '23514';
  end if;

  return new;
end;
$$;

create trigger applications_require_transition_function
before update of current_status on public.applications
for each row execute function public.prevent_direct_application_status_mutation();

create or replace function public.record_application_submission()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  insert into public.application_status_history (
    application_id,
    previous_status,
    next_status,
    changed_by,
    reason,
    is_terminal_correction
  )
  values (new.id, null, 'APPLIED', new.submitted_by, null, false);

  insert into public.audit_logs (
    actor_id,
    action,
    entity_type,
    entity_id,
    after_data
  )
  values (
    new.submitted_by,
    'application.created',
    'application',
    new.id,
    jsonb_build_object('current_status', 'APPLIED', 'drive_id', new.drive_id)
  );

  return new;
end;
$$;

create trigger applications_record_submission
after insert on public.applications
for each row execute function public.record_application_submission();

create or replace function public.prevent_history_or_audit_mutation()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  raise exception '% rows are append-only', tg_table_name using errcode = '23514';
end;
$$;

create trigger application_status_history_is_append_only
before update or delete on public.application_status_history
for each row execute function public.prevent_history_or_audit_mutation();

create trigger audit_logs_are_append_only
before update or delete on public.audit_logs
for each row execute function public.prevent_history_or_audit_mutation();

create or replace function public.transition_application_status(
  p_application_id uuid,
  p_actor_id uuid,
  p_next_status public.application_status,
  p_reason text default null,
  p_is_terminal_correction boolean default false
)
returns void
language plpgsql
set search_path = public
as $$
declare
  v_application public.applications%rowtype;
  v_is_valid_normal_transition boolean;
begin
  if p_actor_id is null then
    raise exception 'An application status transition requires an actor' using errcode = '23502';
  end if;

  select * into v_application
  from public.applications
  where id = p_application_id
  for update;

  if not found then
    raise exception 'Application % does not exist', p_application_id using errcode = 'P0002';
  end if;

  if p_is_terminal_correction then
    if p_reason is null or char_length(trim(p_reason)) not between 1 and 2000 then
      raise exception 'A terminal correction requires a reason' using errcode = '23514';
    end if;

    if v_application.current_status not in ('SELECTED', 'REJECTED', 'WITHDRAWN')
      or v_application.terminal_previous_status is null
      or p_next_status <> v_application.terminal_previous_status then
      raise exception 'A terminal correction must restore the immediate previous non-terminal status'
        using errcode = '23514';
    end if;

    perform set_config('app.application_transition', 'true', true);

    update public.applications
    set
      current_status = p_next_status,
      terminal_previous_status = null,
      withdrawn_at = null,
      terminal_correction_count = terminal_correction_count + 1
    where id = p_application_id;
  else
    v_is_valid_normal_transition :=
      (v_application.current_status = 'APPLIED' and p_next_status in ('SHORTLISTED', 'REJECTED', 'WITHDRAWN'))
      or (v_application.current_status = 'SHORTLISTED' and p_next_status in ('INTERVIEW', 'REJECTED'))
      or (v_application.current_status = 'INTERVIEW' and p_next_status in ('SELECTED', 'REJECTED'));

    if not v_is_valid_normal_transition then
      raise exception 'Invalid application status transition from % to %',
        v_application.current_status, p_next_status using errcode = '23514';
    end if;

    perform set_config('app.application_transition', 'true', true);

    update public.applications
    set
      current_status = p_next_status,
      terminal_previous_status = case
        when p_next_status in ('SELECTED', 'REJECTED', 'WITHDRAWN') then v_application.current_status
        else null
      end,
      withdrawn_at = case when p_next_status = 'WITHDRAWN' then now() else null end
    where id = p_application_id;
  end if;

  insert into public.application_status_history (
    application_id,
    previous_status,
    next_status,
    changed_by,
    reason,
    is_terminal_correction
  )
  values (
    p_application_id,
    v_application.current_status,
    p_next_status,
    p_actor_id,
    p_reason,
    p_is_terminal_correction
  );

  insert into public.audit_logs (
    actor_id,
    action,
    entity_type,
    entity_id,
    before_data,
    after_data
  )
  values (
    p_actor_id,
    case when p_is_terminal_correction then 'application.terminal_correction' else 'application.status_changed' end,
    'application',
    p_application_id,
    jsonb_build_object('current_status', v_application.current_status),
    jsonb_build_object('current_status', p_next_status)
  );

  perform set_config('app.application_transition', 'false', true);
end;
$$;

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

create trigger student_roster_set_updated_at
before update on public.student_roster
for each row execute function public.set_updated_at();

create trigger student_profiles_set_updated_at
before update on public.student_profiles
for each row execute function public.set_updated_at();

create trigger academic_records_set_updated_at
before update on public.academic_records
for each row execute function public.set_updated_at();

create trigger companies_set_updated_at
before update on public.companies
for each row execute function public.set_updated_at();

create trigger recruiters_set_updated_at
before update on public.recruiters
for each row execute function public.set_updated_at();

create trigger placement_drives_set_updated_at
before update on public.placement_drives
for each row execute function public.set_updated_at();

create trigger drive_eligibility_set_updated_at
before update on public.drive_eligibility
for each row execute function public.set_updated_at();

create trigger applications_set_updated_at
before update on public.applications
for each row execute function public.set_updated_at();

create trigger documents_set_updated_at
before update on public.documents
for each row execute function public.set_updated_at();

create trigger announcements_set_updated_at
before update on public.announcements
for each row execute function public.set_updated_at();

comment on function public.transition_application_status is
  'Phase 2 domain primitive. It enforces fixed transitions/history/audit only; Phase 3 must restrict execution by authenticated role and scope.';
