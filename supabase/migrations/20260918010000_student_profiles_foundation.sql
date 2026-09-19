-- Phase 4: roster-gated student registration, self-service profile data, and
-- private resume storage. Later workflows remain default-deny.

create or replace function private.is_valid_skill_list(p_skills text[])
returns boolean
language sql
immutable
set search_path = ''
as $$
  select cardinality(p_skills) <= 20
    and coalesce(
      bool_and(
        skill = btrim(skill)
        and char_length(skill) between 1 and 80
      ),
      true
    )
  from unnest(p_skills) as skill;
$$;

revoke all on function private.is_valid_skill_list(text[]) from public, anon;
grant execute on function private.is_valid_skill_list(text[]) to authenticated;

alter table public.student_roster
  add constraint student_roster_institutional_email_normalized_check
  check (institutional_email = lower(btrim(institutional_email))) not valid;

alter table public.student_profiles
  add constraint student_profiles_phone_number_check
  check (
    phone_number is null
    or (
      phone_number = btrim(phone_number)
      and phone_number ~ '^[0-9+() -]{7,30}$'
    )
  ),
  add constraint student_profiles_portfolio_url_check
  check (
    portfolio_url is null
    or (
      portfolio_url = btrim(portfolio_url)
      and portfolio_url ~ '^https://[^[:space:]]+$'
    )
  ),
  add constraint student_profiles_skills_check
  check (private.is_valid_skill_list(skills));

create unique index documents_one_active_resume_per_owner_idx
  on public.documents (owner_id)
  where document_kind = 'RESUME' and is_archived = false;

-- The Phase 2 deferred invariant is invoked by student-facing transactions in
-- this phase. It must count every protected profile rather than the caller's
-- RLS-visible subset.
create or replace function public.enforce_exactly_one_active_super_admin()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select count(*) from public.profiles where role = 'SUPER_ADMIN' and is_active) <> 1 then
    raise exception 'Exactly one active SUPER_ADMIN profile is required'
      using errcode = '23514';
  end if;

  return null;
end;
$$;

revoke all on function public.enforce_exactly_one_active_super_admin() from public, anon, authenticated;

create or replace function public.enforce_student_roster_signup(event jsonb)
returns jsonb
language plpgsql
set search_path = ''
as $$
declare
  v_email text := lower(btrim(coalesce(event -> 'user' ->> 'email', '')));
begin
  if v_email = '' or not exists (
    select 1
    from public.student_roster as roster
    where roster.institutional_email = v_email
      and roster.is_active
      and not exists (
        select 1
        from public.student_profiles as student_profile
        where student_profile.roster_id = roster.id
      )
  ) then
    return jsonb_build_object(
      'error',
      jsonb_build_object(
        'http_code', 403,
        'message', 'Student registration is unavailable for this account.'
      )
    );
  end if;

  return '{}'::jsonb;
end;
$$;

grant usage on schema public to supabase_auth_admin;
grant select on table public.student_roster to supabase_auth_admin;
grant select on table public.student_profiles to supabase_auth_admin;
grant execute on function public.enforce_student_roster_signup(jsonb) to supabase_auth_admin;
revoke all on function public.enforce_student_roster_signup(jsonb) from public, anon, authenticated;

create policy "auth hook can inspect the protected student roster"
on public.student_roster
for select
to supabase_auth_admin
using (true);

create policy "auth hook can inspect roster consumption"
on public.student_profiles
for select
to supabase_auth_admin
using (true);

create or replace function public.complete_student_registration()
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_email text;
  v_display_name text;
  v_email_confirmed_at timestamptz;
  v_existing_role public.app_role;
  v_roster public.student_roster%rowtype;
begin
  if v_user_id is null then
    raise exception 'An authenticated student is required' using errcode = '42501';
  end if;

  select
    lower(btrim(user_record.email)),
    btrim(coalesce(user_record.raw_user_meta_data ->> 'display_name', '')),
    user_record.email_confirmed_at
  into v_email, v_display_name, v_email_confirmed_at
  from auth.users as user_record
  where user_record.id = v_user_id
  for key share;

  if not found or v_email_confirmed_at is null then
    raise exception 'A verified institutional email is required' using errcode = '42501';
  end if;

  if char_length(v_display_name) not between 1 and 160 then
    raise exception 'A valid full name is required to complete registration' using errcode = '23514';
  end if;

  select profile.role
  into v_existing_role
  from public.profiles as profile
  where profile.id = v_user_id
  for update;

  if found then
    if v_existing_role <> 'STUDENT' then
      raise exception 'Only student registration is permitted by this flow' using errcode = '42501';
    end if;

    if exists (
      select 1
      from public.student_profiles as student_profile
      where student_profile.user_id = v_user_id
    ) then
      return v_user_id;
    end if;
  end if;

  select roster.*
  into v_roster
  from public.student_roster as roster
  where roster.institutional_email = v_email
    and roster.is_active
  for update;

  if not found then
    raise exception 'Student registration is unavailable for this account' using errcode = '42501';
  end if;

  if exists (
    select 1
    from public.student_profiles as student_profile
    where student_profile.roster_id = v_roster.id
  ) then
    raise exception 'This roster entry has already been used' using errcode = '23505';
  end if;

  if not exists (select 1 from public.profiles where id = v_user_id) then
    insert into public.profiles (id, display_name, role)
    values (v_user_id, v_display_name, 'STUDENT');
  end if;

  insert into public.student_profiles (user_id, roster_id)
  values (v_user_id, v_roster.id);

  insert into public.audit_logs (actor_id, action, entity_type, entity_id, after_data)
  values (
    v_user_id,
    'student.registration_completed',
    'student_profile',
    v_user_id,
    jsonb_build_object('roster_id', v_roster.id)
  );

  return v_user_id;
end;
$$;

create or replace function public.save_student_academic_record(
  p_cgpa numeric,
  p_active_backlog_count smallint
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_roster public.student_roster%rowtype;
  v_existing_record public.academic_records%rowtype;
  v_action text;
begin
  if v_user_id is null
    or not private.has_active_role(array['STUDENT'::public.app_role]) then
    raise exception 'Only an active student may submit academic data' using errcode = '42501';
  end if;

  if p_cgpa is null or p_cgpa < 0 or p_cgpa > 10
    or p_active_backlog_count is null or p_active_backlog_count < 0 or p_active_backlog_count > 50 then
    raise exception 'Academic values are outside the permitted range' using errcode = '23514';
  end if;

  select roster.*
  into v_roster
  from public.student_profiles as student_profile
  join public.student_roster as roster on roster.id = student_profile.roster_id
  where student_profile.user_id = v_user_id
  for key share of student_profile, roster;

  if not found then
    raise exception 'A linked student roster entry is required' using errcode = '23514';
  end if;

  select academic_record.*
  into v_existing_record
  from public.academic_records as academic_record
  where academic_record.student_id = v_user_id
  for update;

  if found and v_existing_record.verification_status = 'VERIFIED' then
    raise exception 'Verified academic data cannot be changed by a student' using errcode = '42501';
  end if;

  if found then
    update public.academic_records
    set cgpa = p_cgpa, active_backlog_count = p_active_backlog_count
    where student_id = v_user_id;
    v_action := 'student.academic_updated';
  else
    insert into public.academic_records (
      student_id,
      course,
      batch_year,
      cgpa,
      active_backlog_count
    )
    values (
      v_user_id,
      v_roster.course,
      v_roster.batch_year,
      p_cgpa,
      p_active_backlog_count
    );
    v_action := 'student.academic_submitted';
  end if;

  insert into public.audit_logs (actor_id, action, entity_type, entity_id, after_data)
  values (
    v_user_id,
    v_action,
    'academic_record',
    v_user_id,
    jsonb_build_object('verification_status', 'PENDING')
  );
end;
$$;

create or replace function public.replace_student_resume(
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
  v_user_id uuid := auth.uid();
  v_object_owner_id text;
  v_object_metadata jsonb;
  v_object_size integer;
  v_document_id uuid;
begin
  if v_user_id is null
    or not private.has_active_role(array['STUDENT'::public.app_role]) then
    raise exception 'Only an active student may upload a resume' using errcode = '42501';
  end if;

  if p_storage_path is null
    or p_storage_path !~ (
      '^' || v_user_id::text ||
      '/[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}[.]pdf$'
    )
    or p_original_filename is null
    or p_original_filename <> btrim(p_original_filename)
    or char_length(p_original_filename) not between 1 and 255
    or p_original_filename ~ '[\\/]' then
    raise exception 'Invalid resume metadata' using errcode = '23514';
  end if;

  select object.owner_id, object.metadata
  into v_object_owner_id, v_object_metadata
  from storage.objects as object
  where object.bucket_id = 'resumes'
    and object.name = p_storage_path
    and object.is_delete_marker = false
  for update;

  if not found
    or v_object_owner_id <> v_user_id::text
    or coalesce(v_object_metadata ->> 'mimetype', '') <> 'application/pdf'
    or coalesce(v_object_metadata ->> 'size', '') !~ '^[0-9]+$' then
    raise exception 'The uploaded resume object is invalid' using errcode = '23514';
  end if;

  v_object_size := (v_object_metadata ->> 'size')::integer;

  if p_byte_size is null
    or p_byte_size <> v_object_size
    or p_byte_size < 1
    or p_byte_size > 5242880 then
    raise exception 'The uploaded resume size is invalid' using errcode = '23514';
  end if;

  update public.documents
  set is_archived = true, archived_at = now(), archived_by = v_user_id
  where owner_id = v_user_id
    and document_kind = 'RESUME'
    and is_archived = false;

  insert into public.documents (
    owner_id,
    document_kind,
    storage_bucket,
    storage_path,
    original_filename,
    mime_type,
    byte_size
  )
  values (
    v_user_id,
    'RESUME',
    'resumes',
    p_storage_path,
    p_original_filename,
    'application/pdf',
    p_byte_size
  )
  returning id into v_document_id;

  insert into public.audit_logs (actor_id, action, entity_type, entity_id, after_data)
  values (
    v_user_id,
    'student.resume_replaced',
    'document',
    v_document_id,
    jsonb_build_object('document_kind', 'RESUME')
  );

  return v_document_id;
end;
$$;

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
begin
  if v_actor_id is null
    or not private.has_active_role(
      array[
        'SUPER_ADMIN'::public.app_role,
        'TNP_SECRETARY'::public.app_role,
        'TNP_COORDINATOR'::public.app_role
      ]
    ) then
    raise exception 'Only authorized TNP staff may verify a student profile' using errcode = '42501';
  end if;

  select profile.display_name
  into v_display_name
  from public.profiles as profile
  where profile.id = p_student_id
    and profile.role = 'STUDENT'
    and profile.is_active
  for update;

  if not found then
    raise exception 'An active student profile is required' using errcode = 'P0002';
  end if;

  select student_profile.*
  into v_student_profile
  from public.student_profiles as student_profile
  where student_profile.user_id = p_student_id
  for update;

  if not found then
    raise exception 'An active student profile is required' using errcode = 'P0002';
  end if;

  perform 1
  from public.academic_records as academic_record
  where academic_record.student_id = p_student_id
  for update;

  v_has_academic_record := found;

  select exists (
    select 1
    from public.documents as document
    where document.owner_id = p_student_id
      and document.document_kind = 'RESUME'
      and document.is_archived = false
  ) into v_has_active_resume;

  if not v_has_academic_record
    or char_length(btrim(v_display_name)) = 0
    or v_student_profile.phone_number is null
    or cardinality(v_student_profile.skills) = 0
    or not v_has_active_resume then
    raise exception 'The student profile is incomplete and cannot be verified' using errcode = '23514';
  end if;

  update public.student_profiles
  set
    verification_status = 'VERIFIED',
    verified_at = now(),
    verified_by = v_actor_id
  where user_id = p_student_id;

  update public.academic_records
  set
    verification_status = 'VERIFIED',
    verified_at = now(),
    verified_by = v_actor_id,
    correction_reason = null
  where student_id = p_student_id;

  insert into public.audit_logs (actor_id, action, entity_type, entity_id, after_data)
  values (
    v_actor_id,
    'student.profile_verified',
    'student_profile',
    p_student_id,
    jsonb_build_object('academic_verification_status', 'VERIFIED')
  );
end;
$$;

create or replace function public.correct_verified_academic_record(
  p_student_id uuid,
  p_cgpa numeric,
  p_active_backlog_count smallint,
  p_correction_reason text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := auth.uid();
  v_academic_record public.academic_records%rowtype;
begin
  if v_actor_id is null
    or not private.has_active_role(
      array['SUPER_ADMIN'::public.app_role, 'TNP_SECRETARY'::public.app_role]
    ) then
    raise exception 'Only the TNP Secretary or Super Admin may correct verified academic data'
      using errcode = '42501';
  end if;

  if p_cgpa is null or p_cgpa < 0 or p_cgpa > 10
    or p_active_backlog_count is null or p_active_backlog_count < 0 or p_active_backlog_count > 50
    or p_correction_reason is null or char_length(btrim(p_correction_reason)) not between 1 and 2000 then
    raise exception 'Valid corrected academic values and a reason are required' using errcode = '23514';
  end if;

  select academic_record.*
  into v_academic_record
  from public.academic_records as academic_record
  where academic_record.student_id = p_student_id
  for update;

  if not found or v_academic_record.verification_status <> 'VERIFIED' then
    raise exception 'Only verified academic data may be corrected by this operation' using errcode = '23514';
  end if;

  update public.academic_records
  set
    cgpa = p_cgpa,
    active_backlog_count = p_active_backlog_count,
    verified_at = now(),
    verified_by = v_actor_id,
    correction_reason = btrim(p_correction_reason)
  where student_id = p_student_id;

  insert into public.audit_logs (actor_id, action, entity_type, entity_id, before_data, after_data)
  values (
    v_actor_id,
    'student.verified_academic_corrected',
    'academic_record',
    p_student_id,
    jsonb_build_object(
      'cgpa', v_academic_record.cgpa,
      'active_backlog_count', v_academic_record.active_backlog_count
    ),
    jsonb_build_object('cgpa', p_cgpa, 'active_backlog_count', p_active_backlog_count)
  );
end;
$$;

revoke all on function public.complete_student_registration() from public, anon, authenticated;
revoke all on function public.save_student_academic_record(numeric, smallint) from public, anon, authenticated;
revoke all on function public.replace_student_resume(text, text, integer) from public, anon, authenticated;
revoke all on function public.verify_student_profile(uuid) from public, anon, authenticated;
revoke all on function public.correct_verified_academic_record(uuid, numeric, smallint, text)
  from public, anon, authenticated;

grant execute on function public.complete_student_registration() to authenticated;
grant execute on function public.save_student_academic_record(numeric, smallint) to authenticated;
grant execute on function public.replace_student_resume(text, text, integer) to authenticated;
grant execute on function public.verify_student_profile(uuid) to authenticated;
grant execute on function public.correct_verified_academic_record(uuid, numeric, smallint, text)
  to authenticated;

grant update (display_name) on table public.profiles to authenticated;
grant select on table public.student_roster to authenticated;
grant select, update (phone_number, portfolio_url, skills) on table public.student_profiles to authenticated;
grant select on table public.academic_records to authenticated;
grant select on table public.documents to authenticated;

create policy "active students can update their own display name"
on public.profiles
for update
to authenticated
using (
  id = (select auth.uid())
  and is_active
  and role = 'STUDENT'
)
with check (
  id = (select auth.uid())
  and is_active
  and role = 'STUDENT'
);

create policy "active students can read their own student profile"
on public.student_profiles
for select
to authenticated
using (
  user_id = (select auth.uid())
  and (select private.has_active_role(array['STUDENT'::public.app_role]))
);

create policy "active students can read their own roster facts"
on public.student_roster
for select
to authenticated
using (
  (select private.has_active_role(array['STUDENT'::public.app_role]))
  and exists (
    select 1
    from public.student_profiles as student_profile
    where student_profile.roster_id = student_roster.id
      and student_profile.user_id = (select auth.uid())
  )
);

create policy "active students can update permitted personal fields"
on public.student_profiles
for update
to authenticated
using (
  user_id = (select auth.uid())
  and (select private.has_active_role(array['STUDENT'::public.app_role]))
)
with check (
  user_id = (select auth.uid())
  and (select private.has_active_role(array['STUDENT'::public.app_role]))
);

create policy "active students can read their own academic record"
on public.academic_records
for select
to authenticated
using (
  student_id = (select auth.uid())
  and (select private.has_active_role(array['STUDENT'::public.app_role]))
);

create policy "active students can read their own document metadata"
on public.documents
for select
to authenticated
using (
  owner_id = (select auth.uid())
  and (select private.has_active_role(array['STUDENT'::public.app_role]))
);

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('resumes', 'resumes', false, 5242880, array['application/pdf'])
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

grant select, insert, delete on table storage.objects to authenticated;

create policy "active students can upload UUID-scoped resumes"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'resumes'
  and owner_id = (select auth.uid()::text)
  and (select private.has_active_role(array['STUDENT'::public.app_role]))
  and name ~ (
    '^' || (select auth.uid()::text) ||
    '/[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}[.]pdf$'
  )
);

create policy "active students can read their own resumes"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'resumes'
  and owner_id = (select auth.uid()::text)
  and (select private.has_active_role(array['STUDENT'::public.app_role]))
  and name like (select auth.uid()::text) || '/%'
);

create policy "active students can delete only unregistered resume uploads"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'resumes'
  and owner_id = (select auth.uid()::text)
  and (select private.has_active_role(array['STUDENT'::public.app_role]))
  and not exists (
    select 1
    from public.documents as document
    where document.storage_bucket = storage.objects.bucket_id
      and document.storage_path = storage.objects.name
  )
);

comment on function public.complete_student_registration() is
  'Phase 4 roster-gated student provisioning. It derives identity and role from verified Auth state only.';
comment on function public.save_student_academic_record(numeric, smallint) is
  'Phase 4 student academic submission. Roster course/batch are server-derived and verified rows are immutable to students.';
comment on function public.replace_student_resume(text, text, integer) is
  'Phase 4 private resume metadata registration. It archives the prior active metadata after validating a UUID-scoped object.';
