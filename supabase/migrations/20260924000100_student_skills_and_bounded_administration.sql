-- Phase 5: normalized, governed student skills. Placement eligibility remains
-- deliberately unchanged and skill information is advisory only.

create type public.skill_verification_status as enum ('PENDING', 'VERIFIED', 'REJECTED');
create type public.skill_evidence_source_type as enum ('PROJECT_URL', 'DOCUMENT');

create table public.skills (
  id uuid primary key default gen_random_uuid(),
  display_name text not null check (char_length(btrim(display_name)) between 1 and 120),
  normalized_name text generated always as (lower(btrim(display_name))) stored,
  is_archived boolean not null default false,
  archived_at timestamptz,
  archived_by uuid references public.profiles (id) on delete restrict,
  created_by uuid references public.profiles (id) on delete restrict,
  updated_by uuid references public.profiles (id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (normalized_name),
  constraint skills_archive_check check (
    (is_archived = false and archived_at is null and archived_by is null)
    or (is_archived = true and archived_at is not null and archived_by is not null)
  )
);

create table public.student_skills (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.student_profiles (user_id) on delete restrict,
  skill_id uuid not null references public.skills (id) on delete restrict,
  proficiency_level smallint not null check (proficiency_level between 1 and 4),
  verification_status public.skill_verification_status not null default 'PENDING',
  reviewed_at timestamptz,
  reviewed_by uuid references public.profiles (id) on delete restrict,
  reviewer_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (student_id, skill_id),
  constraint student_skills_reviewer_note_check check (
    reviewer_note is null or char_length(btrim(reviewer_note)) between 1 and 2000
  ),
  constraint student_skills_review_check check (
    (verification_status = 'PENDING' and reviewed_at is null and reviewed_by is null and reviewer_note is null)
    or (verification_status = 'VERIFIED' and reviewed_at is not null and reviewed_by is not null)
    or (
      verification_status = 'REJECTED'
      and reviewed_at is not null
      and reviewed_by is not null
      and reviewer_note is not null
    )
  )
);

create table public.student_skill_evidence (
  id uuid primary key default gen_random_uuid(),
  student_skill_id uuid not null references public.student_skills (id) on delete restrict,
  title text not null check (char_length(btrim(title)) between 1 and 200),
  description text,
  source_type public.skill_evidence_source_type not null,
  project_url text,
  document_id uuid references public.documents (id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint student_skill_evidence_description_check check (
    description is null or char_length(btrim(description)) between 1 and 2000
  ),
  constraint student_skill_evidence_source_check check (
    (source_type = 'PROJECT_URL' and project_url ~ '^https://[^[:space:]]+$' and document_id is null)
    or (source_type = 'DOCUMENT' and project_url is null and document_id is not null)
  )
);

create table public.coordinator_student_scopes (
  coordinator_id uuid not null references public.profiles (id) on delete restrict,
  course text not null check (char_length(btrim(course)) between 1 and 120),
  batch_year smallint not null check (batch_year between 2000 and 2200),
  assigned_by uuid not null references public.profiles (id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (coordinator_id, course, batch_year)
);

alter table public.documents
  add constraint documents_skill_evidence_check check (
    document_kind <> 'SKILL_EVIDENCE' or (mime_type = 'application/pdf' and byte_size <= 5242880)
  );

create index student_skills_student_idx on public.student_skills (student_id);
create index student_skills_skill_status_updated_idx
  on public.student_skills (skill_id, verification_status, updated_at desc);
create index student_skills_review_queue_idx
  on public.student_skills (verification_status, updated_at, student_id);
create index student_skill_evidence_student_skill_idx
  on public.student_skill_evidence (student_skill_id);
create index coordinator_student_scopes_lookup_idx
  on public.coordinator_student_scopes (coordinator_id, course, batch_year);
create index skills_active_normalized_name_idx
  on public.skills (normalized_name)
  where is_archived = false;

create trigger skills_set_updated_at
before update on public.skills
for each row execute function public.set_updated_at();

create trigger student_skills_set_updated_at
before update on public.student_skills
for each row execute function public.set_updated_at();

create trigger student_skill_evidence_set_updated_at
before update on public.student_skill_evidence
for each row execute function public.set_updated_at();

create trigger coordinator_student_scopes_set_updated_at
before update on public.coordinator_student_scopes
for each row execute function public.set_updated_at();

create or replace function public.enforce_coordinator_student_scope_role()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if not exists (
    select 1
    from public.profiles as profile
    where profile.id = new.coordinator_id
      and profile.role = 'TNP_COORDINATOR'
      and profile.is_active
  ) then
    raise exception 'A coordinator scope requires an active TNP_COORDINATOR profile' using errcode = '23514';
  end if;

  return new;
end;
$$;

create trigger coordinator_student_scopes_require_coordinator
before insert or update of coordinator_id on public.coordinator_student_scopes
for each row execute function public.enforce_coordinator_student_scope_role();

create or replace function public.enforce_student_skill_evidence_document_ownership()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_student_id uuid;
begin
  if new.source_type = 'DOCUMENT' then
    select student_skill.student_id
    into v_student_id
    from public.student_skills as student_skill
    where student_skill.id = new.student_skill_id;

    if not found or not exists (
      select 1
      from public.documents as document
      where document.id = new.document_id
        and document.owner_id = v_student_id
        and document.document_kind = 'SKILL_EVIDENCE'
        and document.is_archived = false
    ) then
      raise exception 'Skill evidence document must be an active SKILL_EVIDENCE document owned by the student'
        using errcode = '23514';
    end if;
  end if;

  return new;
end;
$$;

create trigger student_skill_evidence_require_owned_document
before insert or update of student_skill_id, source_type, document_id on public.student_skill_evidence
for each row execute function public.enforce_student_skill_evidence_document_ownership();

-- One-way legacy import. Different normalized labels remain distinct catalog
-- entries; no synonym or semantic inference occurs here.
with normalized_legacy_skills as (
  select btrim(legacy_skill) as display_name, lower(btrim(legacy_skill)) as normalized_name
  from public.student_profiles as student_profile
  cross join lateral unnest(student_profile.skills) as legacy_skill
  where btrim(legacy_skill) <> ''
), canonical_legacy_skills as (
  select normalized_name, min(display_name) as display_name
  from normalized_legacy_skills
  group by normalized_name
)
insert into public.skills (display_name)
select canonical_legacy_skills.display_name
from canonical_legacy_skills
on conflict (normalized_name) do nothing;

with normalized_student_skills as (
  select distinct student_profile.user_id as student_id, lower(btrim(legacy_skill)) as normalized_name
  from public.student_profiles as student_profile
  cross join lateral unnest(student_profile.skills) as legacy_skill
  where btrim(legacy_skill) <> ''
)
insert into public.student_skills (student_id, skill_id, proficiency_level, verification_status)
select normalized_student_skills.student_id, skill.id, 1, 'PENDING'
from normalized_student_skills
join public.skills as skill on skill.normalized_name = normalized_student_skills.normalized_name
on conflict (student_id, skill_id) do nothing;

create or replace function private.can_review_student_skills(p_student_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles as actor
    where actor.id = (select auth.uid())
      and actor.is_active
      and actor.role in ('SUPER_ADMIN'::public.app_role, 'TNP_SECRETARY'::public.app_role)
  )
  or exists (
    select 1
    from public.profiles as actor
    join public.coordinator_student_scopes as scope on scope.coordinator_id = actor.id
    join public.student_profiles as student_profile on student_profile.user_id = p_student_id
    join public.student_roster as roster on roster.id = student_profile.roster_id
    where actor.id = (select auth.uid())
      and actor.is_active
      and actor.role = 'TNP_COORDINATOR'
      and scope.course = roster.course
      and scope.batch_year = roster.batch_year
  );
$$;

revoke all on function private.can_review_student_skills(uuid) from public, anon;
grant execute on function private.can_review_student_skills(uuid) to authenticated;

create or replace function private.require_active_student()
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := auth.uid();
begin
  if v_actor_id is null or not private.has_active_role(array['STUDENT'::public.app_role]) then
    raise exception 'Only an active student may manage student skills' using errcode = '42501';
  end if;

  return v_actor_id;
end;
$$;

revoke all on function private.require_active_student() from public, anon;

create or replace function public.save_student_skill(p_skill_id uuid, p_proficiency_level smallint)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_student_id uuid := private.require_active_student();
  v_student_skill public.student_skills%rowtype;
begin
  if p_proficiency_level is null or p_proficiency_level not between 1 and 4 then
    raise exception 'Skill proficiency must be between 1 and 4' using errcode = '23514';
  end if;

  if not exists (select 1 from public.skills where id = p_skill_id and not is_archived) then
    raise exception 'Select an active catalog skill' using errcode = '23514';
  end if;

  select * into v_student_skill
  from public.student_skills
  where student_id = v_student_id and skill_id = p_skill_id
  for update;

  if found and v_student_skill.verification_status = 'VERIFIED' then
    raise exception 'Verified skills cannot be changed by students' using errcode = '42501';
  end if;

  if found then
    update public.student_skills
    set proficiency_level = p_proficiency_level,
        verification_status = 'PENDING',
        reviewed_at = null,
        reviewed_by = null,
        reviewer_note = null
    where id = v_student_skill.id;

    insert into public.audit_logs (actor_id, action, entity_type, entity_id, before_data, after_data)
    values (
      v_student_id,
      'student.skill_resubmitted',
      'student_skill',
      v_student_skill.id,
      jsonb_build_object('verification_status', v_student_skill.verification_status, 'proficiency_level', v_student_skill.proficiency_level),
      jsonb_build_object('verification_status', 'PENDING', 'proficiency_level', p_proficiency_level)
    );
    return v_student_skill.id;
  end if;

  insert into public.student_skills (student_id, skill_id, proficiency_level)
  values (v_student_id, p_skill_id, p_proficiency_level)
  returning * into v_student_skill;

  insert into public.audit_logs (actor_id, action, entity_type, entity_id, after_data)
  values (v_student_id, 'student.skill_declared', 'student_skill', v_student_skill.id, jsonb_build_object('skill_id', p_skill_id, 'proficiency_level', p_proficiency_level));

  return v_student_skill.id;
end;
$$;

create or replace function public.add_student_skill_project_evidence(
  p_student_skill_id uuid,
  p_title text,
  p_description text,
  p_project_url text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_student_id uuid := private.require_active_student();
  v_evidence_id uuid;
begin
  if p_title is null or char_length(btrim(p_title)) not between 1 and 200
    or p_project_url is null or btrim(p_project_url) !~ '^https://[^[:space:]]+$'
    or (p_description is not null and char_length(btrim(p_description)) not between 1 and 2000) then
    raise exception 'Valid evidence title, optional description, and HTTPS project URL are required' using errcode = '23514';
  end if;

  if not exists (
    select 1 from public.student_skills
    where id = p_student_skill_id and student_id = v_student_id and verification_status = 'PENDING'
  ) then
    raise exception 'Evidence may be added only to the student''s pending skill' using errcode = '42501';
  end if;

  insert into public.student_skill_evidence (student_skill_id, title, description, source_type, project_url)
  values (p_student_skill_id, btrim(p_title), nullif(btrim(p_description), ''), 'PROJECT_URL', btrim(p_project_url))
  returning id into v_evidence_id;

  insert into public.audit_logs (actor_id, action, entity_type, entity_id, after_data)
  values (v_student_id, 'student.skill_evidence_added', 'student_skill_evidence', v_evidence_id, jsonb_build_object('source_type', 'PROJECT_URL'));
  return v_evidence_id;
end;
$$;

create or replace function public.register_student_skill_evidence_document(
  p_student_skill_id uuid,
  p_title text,
  p_description text,
  p_storage_path text,
  p_original_filename text,
  p_byte_size integer
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_student_id uuid := private.require_active_student();
  v_document_id uuid;
  v_evidence_id uuid;
begin
  if p_title is null or char_length(btrim(p_title)) not between 1 and 200
    or p_original_filename is null or char_length(btrim(p_original_filename)) not between 1 and 255
    or p_byte_size is null or p_byte_size not between 1 and 5242880
    or (p_description is not null and char_length(btrim(p_description)) not between 1 and 2000) then
    raise exception 'Valid private PDF evidence metadata is required' using errcode = '23514';
  end if;

  if not exists (
    select 1 from public.student_skills
    where id = p_student_skill_id and student_id = v_student_id and verification_status = 'PENDING'
  ) then
    raise exception 'Evidence may be added only to the student''s pending skill' using errcode = '42501';
  end if;

  if not exists (
    select 1
    from storage.objects as object
    where object.bucket_id = 'skill-evidence'
      and object.name = p_storage_path
      and object.owner_id = v_student_id::text
      and object.name ~ ('^' || v_student_id::text || '/[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}[.]pdf$')
      and object.metadata ->> 'mimetype' = 'application/pdf'
  ) then
    raise exception 'A validated owned PDF upload is required' using errcode = '23514';
  end if;

  insert into public.documents (owner_id, document_kind, storage_bucket, storage_path, original_filename, mime_type, byte_size)
  values (v_student_id, 'SKILL_EVIDENCE', 'skill-evidence', p_storage_path, btrim(p_original_filename), 'application/pdf', p_byte_size)
  returning id into v_document_id;

  insert into public.student_skill_evidence (student_skill_id, title, description, source_type, document_id)
  values (p_student_skill_id, btrim(p_title), nullif(btrim(p_description), ''), 'DOCUMENT', v_document_id)
  returning id into v_evidence_id;

  insert into public.audit_logs (actor_id, action, entity_type, entity_id, after_data)
  values (v_student_id, 'student.skill_evidence_added', 'student_skill_evidence', v_evidence_id, jsonb_build_object('source_type', 'DOCUMENT', 'document_id', v_document_id));
  return v_evidence_id;
end;
$$;

create or replace function public.review_student_skill(
  p_student_skill_id uuid,
  p_verification_status public.skill_verification_status,
  p_reviewer_note text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := auth.uid();
  v_student_skill public.student_skills%rowtype;
begin
  if p_verification_status not in ('VERIFIED', 'REJECTED') then
    raise exception 'A review must verify or reject a pending student skill' using errcode = '23514';
  end if;
  if p_verification_status = 'REJECTED' and (p_reviewer_note is null or char_length(btrim(p_reviewer_note)) not between 1 and 2000) then
    raise exception 'A rejection reason is required' using errcode = '23514';
  end if;

  select * into v_student_skill from public.student_skills where id = p_student_skill_id for update;
  if not found or v_student_skill.verification_status <> 'PENDING' then
    raise exception 'Only pending student skills may be reviewed' using errcode = '23514';
  end if;
  if v_actor_id is null or not private.can_review_student_skills(v_student_skill.student_id) then
    raise exception 'The reviewer is not authorized for this student skill' using errcode = '42501';
  end if;

  update public.student_skills
  set verification_status = p_verification_status,
      reviewed_at = now(),
      reviewed_by = v_actor_id,
      reviewer_note = nullif(btrim(p_reviewer_note), '')
  where id = p_student_skill_id;

  insert into public.audit_logs (actor_id, action, entity_type, entity_id, before_data, after_data)
  values (v_actor_id, 'student.skill_reviewed', 'student_skill', p_student_skill_id, jsonb_build_object('verification_status', 'PENDING'), jsonb_build_object('verification_status', p_verification_status, 'reviewer_note', nullif(btrim(p_reviewer_note), '')));
end;
$$;

create or replace function public.create_skill_catalog_entry(p_display_name text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := auth.uid();
  v_skill_id uuid;
begin
  if v_actor_id is null or not private.has_active_role(array['SUPER_ADMIN'::public.app_role, 'TNP_SECRETARY'::public.app_role]) then
    raise exception 'Only the TNP Secretary or Super Admin may manage the skill catalog' using errcode = '42501';
  end if;
  if p_display_name is null or char_length(btrim(p_display_name)) not between 1 and 120 then
    raise exception 'A valid skill name is required' using errcode = '23514';
  end if;

  insert into public.skills (display_name, created_by, updated_by)
  values (btrim(p_display_name), v_actor_id, v_actor_id)
  returning id into v_skill_id;

  insert into public.audit_logs (actor_id, action, entity_type, entity_id, after_data)
  values (v_actor_id, 'skill.catalog_created', 'skill', v_skill_id, jsonb_build_object('display_name', btrim(p_display_name)));
  return v_skill_id;
end;
$$;

create or replace function public.update_skill_catalog_entry(p_skill_id uuid, p_display_name text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := auth.uid();
  v_previous_name text;
begin
  if v_actor_id is null or not private.has_active_role(array['SUPER_ADMIN'::public.app_role, 'TNP_SECRETARY'::public.app_role]) then
    raise exception 'Only the TNP Secretary or Super Admin may manage the skill catalog' using errcode = '42501';
  end if;
  if p_display_name is null or char_length(btrim(p_display_name)) not between 1 and 120 then
    raise exception 'A valid skill name is required' using errcode = '23514';
  end if;

  select display_name into v_previous_name from public.skills where id = p_skill_id for update;
  if not found then
    raise exception 'Skill catalog entry was not found' using errcode = 'P0002';
  end if;
  update public.skills set display_name = btrim(p_display_name), updated_by = v_actor_id where id = p_skill_id;
  insert into public.audit_logs (actor_id, action, entity_type, entity_id, before_data, after_data)
  values (v_actor_id, 'skill.catalog_updated', 'skill', p_skill_id, jsonb_build_object('display_name', v_previous_name), jsonb_build_object('display_name', btrim(p_display_name)));
end;
$$;

create or replace function public.archive_skill_catalog_entry(p_skill_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := auth.uid();
begin
  if v_actor_id is null or not private.has_active_role(array['SUPER_ADMIN'::public.app_role, 'TNP_SECRETARY'::public.app_role]) then
    raise exception 'Only the TNP Secretary or Super Admin may manage the skill catalog' using errcode = '42501';
  end if;
  update public.skills
  set is_archived = true, archived_at = now(), archived_by = v_actor_id, updated_by = v_actor_id
  where id = p_skill_id and not is_archived;
  if not found then
    raise exception 'An active skill catalog entry is required' using errcode = 'P0002';
  end if;
  insert into public.audit_logs (actor_id, action, entity_type, entity_id, after_data)
  values (v_actor_id, 'skill.catalog_archived', 'skill', p_skill_id, jsonb_build_object('is_archived', true));
end;
$$;

create or replace function public.correct_verified_student_skill(
  p_student_skill_id uuid,
  p_proficiency_level smallint,
  p_reason text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := auth.uid();
  v_skill public.student_skills%rowtype;
begin
  if v_actor_id is null or not private.has_active_role(array['SUPER_ADMIN'::public.app_role, 'TNP_SECRETARY'::public.app_role]) then
    raise exception 'Only the TNP Secretary or Super Admin may correct verified student skills' using errcode = '42501';
  end if;
  if p_proficiency_level is null or p_proficiency_level not between 1 and 4
    or p_reason is null or char_length(btrim(p_reason)) not between 1 and 2000 then
    raise exception 'A valid proficiency and correction reason are required' using errcode = '23514';
  end if;
  select * into v_skill from public.student_skills where id = p_student_skill_id for update;
  if not found or v_skill.verification_status <> 'VERIFIED' then
    raise exception 'Only verified skills may be corrected by this operation' using errcode = '23514';
  end if;
  update public.student_skills
  set proficiency_level = p_proficiency_level, reviewed_at = now(), reviewed_by = v_actor_id, reviewer_note = btrim(p_reason)
  where id = p_student_skill_id;
  insert into public.audit_logs (actor_id, action, entity_type, entity_id, before_data, after_data)
  values (v_actor_id, 'student.verified_skill_corrected', 'student_skill', p_student_skill_id, jsonb_build_object('proficiency_level', v_skill.proficiency_level), jsonb_build_object('proficiency_level', p_proficiency_level, 'reason', btrim(p_reason)));
end;
$$;

create or replace function public.revoke_verified_student_skill(p_student_skill_id uuid, p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := auth.uid();
  v_skill public.student_skills%rowtype;
begin
  if v_actor_id is null or not private.has_active_role(array['SUPER_ADMIN'::public.app_role, 'TNP_SECRETARY'::public.app_role]) then
    raise exception 'Only the TNP Secretary or Super Admin may revoke verified student skills' using errcode = '42501';
  end if;
  if p_reason is null or char_length(btrim(p_reason)) not between 1 and 2000 then
    raise exception 'A revocation reason is required' using errcode = '23514';
  end if;
  select * into v_skill from public.student_skills where id = p_student_skill_id for update;
  if not found or v_skill.verification_status <> 'VERIFIED' then
    raise exception 'Only verified skills may be revoked by this operation' using errcode = '23514';
  end if;
  update public.student_skills
  set verification_status = 'PENDING', reviewed_at = null, reviewed_by = null, reviewer_note = null
  where id = p_student_skill_id;
  insert into public.audit_logs (actor_id, action, entity_type, entity_id, before_data, after_data)
  values (v_actor_id, 'student.verified_skill_revoked', 'student_skill', p_student_skill_id, jsonb_build_object('verification_status', 'VERIFIED'), jsonb_build_object('verification_status', 'PENDING', 'reason', btrim(p_reason)));
end;
$$;

create or replace function public.assign_coordinator_student_scope(
  p_coordinator_id uuid,
  p_course text,
  p_batch_year smallint
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := auth.uid();
begin
  if v_actor_id is null or not private.has_active_role(array['SUPER_ADMIN'::public.app_role, 'TNP_SECRETARY'::public.app_role]) then
    raise exception 'Only the TNP Secretary or Super Admin may assign coordinator scope' using errcode = '42501';
  end if;
  if p_course is null or char_length(btrim(p_course)) not between 1 and 120 or p_batch_year not between 2000 and 2200 then
    raise exception 'A valid course and batch are required' using errcode = '23514';
  end if;
  insert into public.coordinator_student_scopes (coordinator_id, course, batch_year, assigned_by)
  values (p_coordinator_id, btrim(p_course), p_batch_year, v_actor_id);
  insert into public.audit_logs (actor_id, action, entity_type, entity_id, after_data)
  values (v_actor_id, 'coordinator.student_scope_assigned', 'coordinator_student_scope', p_coordinator_id, jsonb_build_object('course', btrim(p_course), 'batch_year', p_batch_year));
end;
$$;

create or replace function public.remove_coordinator_student_scope(
  p_coordinator_id uuid,
  p_course text,
  p_batch_year smallint
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := auth.uid();
begin
  if v_actor_id is null or not private.has_active_role(array['SUPER_ADMIN'::public.app_role, 'TNP_SECRETARY'::public.app_role]) then
    raise exception 'Only the TNP Secretary or Super Admin may remove coordinator scope' using errcode = '42501';
  end if;
  delete from public.coordinator_student_scopes
  where coordinator_id = p_coordinator_id and course = btrim(p_course) and batch_year = p_batch_year;
  if not found then
    raise exception 'Coordinator scope was not found' using errcode = 'P0002';
  end if;
  insert into public.audit_logs (actor_id, action, entity_type, entity_id, after_data)
  values (v_actor_id, 'coordinator.student_scope_removed', 'coordinator_student_scope', p_coordinator_id, jsonb_build_object('course', btrim(p_course), 'batch_year', p_batch_year));
end;
$$;

-- Profile verification now depends on the authoritative relation instead of the
-- legacy text array.
create or replace function public.verify_student_profile(p_student_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := auth.uid();
  v_student_profile public.student_profiles%rowtype;
  v_display_name text;
  v_has_academic_record boolean;
  v_has_active_resume boolean;
  v_has_skill boolean;
begin
  if v_actor_id is null or not private.can_review_student_skills(p_student_id) then
    raise exception 'Only authorized TNP staff may verify a student profile within scope' using errcode = '42501';
  end if;
  select profile.display_name into v_display_name from public.profiles as profile where profile.id = p_student_id and profile.role = 'STUDENT' and profile.is_active for update;
  if not found then raise exception 'An active student profile is required' using errcode = 'P0002'; end if;
  select * into v_student_profile from public.student_profiles where user_id = p_student_id for update;
  if not found then raise exception 'An active student profile is required' using errcode = 'P0002'; end if;
  perform 1 from public.academic_records where student_id = p_student_id for update;
  v_has_academic_record := found;
  select exists (select 1 from public.documents where owner_id = p_student_id and document_kind = 'RESUME' and not is_archived) into v_has_active_resume;
  select exists (select 1 from public.student_skills where student_id = p_student_id) into v_has_skill;
  if not v_has_academic_record or char_length(btrim(v_display_name)) = 0 or v_student_profile.phone_number is null or not v_has_skill or not v_has_active_resume then
    raise exception 'The student profile is incomplete and cannot be verified' using errcode = '23514';
  end if;
  update public.student_profiles set verification_status = 'VERIFIED', verified_at = now(), verified_by = v_actor_id where user_id = p_student_id;
  update public.academic_records set verification_status = 'VERIFIED', verified_at = now(), verified_by = v_actor_id, correction_reason = null where student_id = p_student_id;
  insert into public.audit_logs (actor_id, action, entity_type, entity_id, after_data)
  values (v_actor_id, 'student.profile_verified', 'student_profile', p_student_id, jsonb_build_object('academic_verification_status', 'VERIFIED'));
end;
$$;

alter table public.skills enable row level security;
alter table public.student_skills enable row level security;
alter table public.student_skill_evidence enable row level security;
alter table public.coordinator_student_scopes enable row level security;

grant select on table public.skills, public.student_skills, public.student_skill_evidence, public.coordinator_student_scopes to authenticated;

create policy "active users can read active or owned skills"
on public.skills for select to authenticated
using (
  not is_archived
  or (select private.has_active_role(array['SUPER_ADMIN'::public.app_role, 'TNP_SECRETARY'::public.app_role]))
  or exists (
    select 1 from public.student_skills as student_skill
    where student_skill.skill_id = skills.id and student_skill.student_id = (select auth.uid())
  )
);

create policy "students and scoped staff can read student skills"
on public.student_skills for select to authenticated
using (
  student_id = (select auth.uid())
  or (select private.can_review_student_skills(student_id))
);

create policy "students and scoped staff can read skill evidence"
on public.student_skill_evidence for select to authenticated
using (
  exists (
    select 1 from public.student_skills as student_skill
    where student_skill.id = student_skill_evidence.student_skill_id
      and (
        student_skill.student_id = (select auth.uid())
        or (select private.can_review_student_skills(student_skill.student_id))
      )
  )
);

create policy "coordinators can read their scope assignments"
on public.coordinator_student_scopes for select to authenticated
using (
  coordinator_id = (select auth.uid())
  or (select private.has_active_role(array['SUPER_ADMIN'::public.app_role, 'TNP_SECRETARY'::public.app_role]))
);

create policy "scoped staff can read skill evidence document metadata"
on public.documents for select to authenticated
using (
  document_kind = 'SKILL_EVIDENCE'
  and exists (
    select 1
    from public.student_skill_evidence as evidence
    join public.student_skills as student_skill on student_skill.id = evidence.student_skill_id
    where evidence.document_id = documents.id
      and (select private.can_review_student_skills(student_skill.student_id))
  )
);

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('skill-evidence', 'skill-evidence', false, 5242880, array['application/pdf'])
on conflict (id) do update
set public = excluded.public, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

create policy "active students can upload UUID-scoped skill evidence"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'skill-evidence'
  and owner_id = (select auth.uid()::text)
  and (select private.has_active_role(array['STUDENT'::public.app_role]))
  and name ~ ('^' || (select auth.uid()::text) || '/[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}[.]pdf$')
);

create policy "students and scoped staff can read skill evidence objects"
on storage.objects for select to authenticated
using (
  bucket_id = 'skill-evidence'
  and (
    (owner_id = (select auth.uid()::text) and (select private.has_active_role(array['STUDENT'::public.app_role])))
    or exists (
      select 1
      from public.documents as document
      join public.student_skill_evidence as evidence on evidence.document_id = document.id
      join public.student_skills as student_skill on student_skill.id = evidence.student_skill_id
      where document.storage_bucket = storage.objects.bucket_id
        and document.storage_path = storage.objects.name
        and (select private.can_review_student_skills(student_skill.student_id))
    )
  )
);

create policy "students can delete only unregistered skill evidence uploads"
on storage.objects for delete to authenticated
using (
  bucket_id = 'skill-evidence'
  and owner_id = (select auth.uid()::text)
  and (select private.has_active_role(array['STUDENT'::public.app_role]))
  and not exists (
    select 1 from public.documents as document
    where document.storage_bucket = storage.objects.bucket_id and document.storage_path = storage.objects.name
  )
);

revoke all on function public.save_student_skill(uuid, smallint) from public, anon, authenticated;
revoke all on function public.add_student_skill_project_evidence(uuid, text, text, text) from public, anon, authenticated;
revoke all on function public.register_student_skill_evidence_document(uuid, text, text, text, text, integer) from public, anon, authenticated;
revoke all on function public.review_student_skill(uuid, public.skill_verification_status, text) from public, anon, authenticated;
revoke all on function public.create_skill_catalog_entry(text) from public, anon, authenticated;
revoke all on function public.update_skill_catalog_entry(uuid, text) from public, anon, authenticated;
revoke all on function public.archive_skill_catalog_entry(uuid) from public, anon, authenticated;
revoke all on function public.correct_verified_student_skill(uuid, smallint, text) from public, anon, authenticated;
revoke all on function public.revoke_verified_student_skill(uuid, text) from public, anon, authenticated;
revoke all on function public.assign_coordinator_student_scope(uuid, text, smallint) from public, anon, authenticated;
revoke all on function public.remove_coordinator_student_scope(uuid, text, smallint) from public, anon, authenticated;

grant execute on function public.save_student_skill(uuid, smallint) to authenticated;
grant execute on function public.add_student_skill_project_evidence(uuid, text, text, text) to authenticated;
grant execute on function public.register_student_skill_evidence_document(uuid, text, text, text, text, integer) to authenticated;
grant execute on function public.review_student_skill(uuid, public.skill_verification_status, text) to authenticated;
grant execute on function public.create_skill_catalog_entry(text) to authenticated;
grant execute on function public.update_skill_catalog_entry(uuid, text) to authenticated;
grant execute on function public.archive_skill_catalog_entry(uuid) to authenticated;
grant execute on function public.correct_verified_student_skill(uuid, smallint, text) to authenticated;
grant execute on function public.revoke_verified_student_skill(uuid, text) to authenticated;
grant execute on function public.assign_coordinator_student_scope(uuid, text, smallint) to authenticated;
grant execute on function public.remove_coordinator_student_scope(uuid, text, smallint) to authenticated;

revoke update (skills) on table public.student_profiles from authenticated;

comment on function public.save_student_skill(uuid, smallint) is
  'Phase 5 student-owned canonical skill declaration and rejected-skill resubmission.';
comment on function public.review_student_skill(uuid, public.skill_verification_status, text) is
  'Phase 5 scoped coordinator/office student-skill review with audit evidence.';
