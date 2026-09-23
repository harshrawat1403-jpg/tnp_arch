begin;
select plan(37);

insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data)
values
  (
    '21000000-0000-0000-0000-000000000001',
    'super-admin@example.test',
    now(),
    '{"display_name":"Technical Secretary"}'
  ),
  (
    '21000000-0000-0000-0000-000000000002',
    'coordinator@example.test',
    now(),
    '{"display_name":"Coordinator"}'
  ),
  (
    '21000000-0000-0000-0000-000000000003',
    'secretary@example.test',
    now(),
    '{"display_name":"TNP Secretary"}'
  ),
  (
    '21000000-0000-0000-0000-000000000004',
    'new.student@example.test',
    now(),
    '{"display_name":"New Student"}'
  ),
  (
    '21000000-0000-0000-0000-000000000005',
    'existing.student@example.test',
    now(),
    '{"display_name":"Existing Student"}'
  );

insert into public.profiles (id, display_name, role, coordinator_slot)
values
  ('21000000-0000-0000-0000-000000000001', 'Technical Secretary', 'SUPER_ADMIN', null),
  ('21000000-0000-0000-0000-000000000002', 'Coordinator', 'TNP_COORDINATOR', 1),
  ('21000000-0000-0000-0000-000000000003', 'TNP Secretary', 'TNP_SECRETARY', null),
  ('21000000-0000-0000-0000-000000000005', 'Existing Student', 'STUDENT', null);

insert into public.student_roster (id, student_identifier, institutional_email, course, batch_year, is_active)
values
  (
    '22000000-0000-0000-0000-000000000001',
    'STU-NEW',
    'new.student@example.test',
    'BARCH',
    2027,
    true
  ),
  (
    '22000000-0000-0000-0000-000000000002',
    'STU-EXISTING',
    'existing.student@example.test',
    'BARCH',
    2027,
    true
  ),
  (
    '22000000-0000-0000-0000-000000000003',
    'STU-INACTIVE',
    'inactive.student@example.test',
    'BARCH',
    2027,
    false
  );

insert into public.student_profiles (user_id, roster_id)
values ('21000000-0000-0000-0000-000000000005', '22000000-0000-0000-0000-000000000002');

select is(
  public.enforce_student_roster_signup(
    jsonb_build_object('user', jsonb_build_object('email', ' NEW.STUDENT@EXAMPLE.TEST '))
  ),
  '{}'::jsonb,
  'the auth hook accepts an active unconsumed roster email after documented normalization'
);
select is(
  public.enforce_student_roster_signup(
    jsonb_build_object('user', jsonb_build_object('email', 'non-roster@example.test'))
  ) -> 'error' ->> 'http_code',
  '403',
  'the auth hook blocks a non-roster email before Auth user creation'
);
select is(
  public.enforce_student_roster_signup(
    jsonb_build_object('user', jsonb_build_object('email', 'inactive.student@example.test'))
  ) -> 'error' ->> 'http_code',
  '403',
  'the auth hook blocks an inactive roster entry'
);
select is(
  public.enforce_student_roster_signup(
    jsonb_build_object('user', jsonb_build_object('email', 'existing.student@example.test'))
  ) -> 'error' ->> 'http_code',
  '403',
  'the auth hook blocks a consumed roster entry'
);

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '21000000-0000-0000-0000-000000000004', true);

select is(
  (select count(*)::integer from public.profiles where role = 'SUPER_ADMIN'),
  0,
  'a prospective student cannot see the protected Super Admin profile through RLS'
);

select lives_ok(
  $$select public.complete_student_registration()$$,
  'a verified roster-matched user can complete student-only registration'
);
reset role;
select is(
  (select role::text from public.profiles where id = '21000000-0000-0000-0000-000000000004'),
  'STUDENT',
  'registration creates only a STUDENT profile'
);
select is(
  (select roster_id::text from public.student_profiles where user_id = '21000000-0000-0000-0000-000000000004'),
  '22000000-0000-0000-0000-000000000001',
  'registration consumes the matching roster entry exactly once'
);
select is(
  (
    select count(*)::integer
    from public.audit_logs
    where action = 'student.registration_completed'
      and actor_id = '21000000-0000-0000-0000-000000000004'
  ),
  1,
  'registration creates an audit record'
);
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '21000000-0000-0000-0000-000000000004', true);
select throws_ok(
  $$update public.profiles set role = 'SUPER_ADMIN' where id = '21000000-0000-0000-0000-000000000004'$$,
  '42501',
  null,
  'a student cannot self-escalate their role through direct access'
);
select is(
  (select count(*)::integer from public.profiles),
  1,
  'a student can read only their own account profile'
);
select is(
  (select count(*)::integer from public.student_profiles),
  1,
  'a student can read only their own student profile'
);
select is(
  (
    select count(*)::integer
    from public.student_profiles
    where user_id = '21000000-0000-0000-0000-000000000005'
  ),
  0,
  'a student cannot read another student profile'
);
select lives_ok(
  $$update public.student_profiles
    set phone_number = '+91 98765 43210', portfolio_url = 'https://portfolio.example.test'
    where user_id = '21000000-0000-0000-0000-000000000004'$$,
  'a student can update permitted personal fields'
);
select throws_ok(
  $$update public.student_profiles set skills = array['AutoCAD'] where user_id = '21000000-0000-0000-0000-000000000004'$$,
  '42501',
  null,
  'a student cannot write the legacy skills array after the normalized cutover'
);
select throws_ok(
  $$update public.student_profiles
    set verification_status = 'VERIFIED'
    where user_id = '21000000-0000-0000-0000-000000000004'$$,
  '42501',
  null,
  'a student cannot set their own verification state'
);
select lives_ok(
  $$select public.save_student_academic_record(8.25, 0::smallint)$$,
  'a student can submit initial roster-aligned academic data'
);
select is(
  (select cgpa::text from public.academic_records where student_id = '21000000-0000-0000-0000-000000000004'),
  '8.25',
  'the academic record stores the submitted CGPA'
);
select throws_ok(
  $$update public.academic_records set cgpa = 9.00 where student_id = '21000000-0000-0000-0000-000000000004'$$,
  '42501',
  null,
  'a student cannot directly mutate protected academic fields'
);
select lives_ok(
  $$insert into storage.objects (bucket_id, name, owner_id, metadata)
    values (
      'resumes',
      '21000000-0000-0000-0000-000000000004/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa.pdf',
      '21000000-0000-0000-0000-000000000004',
      jsonb_build_object('mimetype', 'application/pdf', 'size', 9)
    )$$,
  'a student can upload a PDF object to their UUID-scoped resume path'
);
select lives_ok(
  $$select public.replace_student_resume(
    '21000000-0000-0000-0000-000000000004/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa.pdf',
    'resume.pdf',
    9
  )$$,
  'a student can register a validated owned resume object'
);
select is(
  (
    select count(*)::integer
    from public.documents
    where owner_id = '21000000-0000-0000-0000-000000000004'
      and document_kind = 'RESUME'
      and is_archived = false
  ),
  1,
  'one active resume metadata record exists after registration'
);
select lives_ok(
  $$insert into storage.objects (bucket_id, name, owner_id, metadata)
    values (
      'resumes',
      '21000000-0000-0000-0000-000000000004/bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb.pdf',
      '21000000-0000-0000-0000-000000000004',
      jsonb_build_object('mimetype', 'application/pdf', 'size', 10)
    )$$,
  'a student can prepare a replacement under a new immutable UUID path'
);
select lives_ok(
  $$select public.replace_student_resume(
    '21000000-0000-0000-0000-000000000004/bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb.pdf',
    'updated-resume.pdf',
    10
  )$$,
  'a student can replace a resume through the lifecycle procedure'
);
select is(
  (
    select count(*)::integer
    from public.documents
    where owner_id = '21000000-0000-0000-0000-000000000004'
      and document_kind = 'RESUME'
      and is_archived
  ),
  1,
  'resume replacement archives the prior metadata record'
);
select is(
  (
    select count(*)::integer
    from storage.objects
    where bucket_id = 'resumes'
      and name = '21000000-0000-0000-0000-000000000004/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa.pdf'
  ),
  1,
  'resume replacement retains the archived private object'
);

select set_config('request.jwt.claim.sub', '21000000-0000-0000-0000-000000000005', true);
select is(
  (select count(*)::integer from public.documents),
  0,
  'another student cannot read resume metadata'
);
select is(
  (select count(*)::integer from storage.objects where bucket_id = 'resumes'),
  0,
  'another student cannot read resume objects'
);
select throws_ok(
  $$insert into storage.objects (bucket_id, name, owner_id, metadata)
    values (
      'resumes',
      '21000000-0000-0000-0000-000000000004/cccccccc-cccc-4ccc-8ccc-cccccccccccc.pdf',
      '21000000-0000-0000-0000-000000000005',
      jsonb_build_object('mimetype', 'application/pdf', 'size', 9)
    )$$,
  '42501',
  null,
  'another student cannot write into a different owner resume prefix'
);

reset role;
update public.student_profiles
set phone_number = '+91 90000 00000'
where user_id = '21000000-0000-0000-0000-000000000005';
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
  '21000000-0000-0000-0000-000000000005',
  'RESUME',
  'resumes',
  '21000000-0000-0000-0000-000000000005/dddddddd-dddd-4ddd-8ddd-dddddddddddd.pdf',
  'incomplete-academic.pdf',
  'application/pdf',
  9
);
insert into public.skills (id, display_name)
values ('23000000-0000-0000-0000-000000000001', 'SketchUp');
insert into public.student_skills (student_id, skill_id, proficiency_level)
values ('21000000-0000-0000-0000-000000000004', '23000000-0000-0000-0000-000000000001', 2);
insert into public.coordinator_student_scopes (coordinator_id, course, batch_year, assigned_by)
values ('21000000-0000-0000-0000-000000000002', 'BARCH', 2027, '21000000-0000-0000-0000-000000000003');

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '21000000-0000-0000-0000-000000000002', true);
select throws_ok(
  $$select public.verify_student_profile('21000000-0000-0000-0000-000000000005')$$,
  '23514',
  'The student profile is incomplete and cannot be verified',
  'verification rejects an otherwise complete student profile with no academic record'
);
select lives_ok(
  $$select public.verify_student_profile('21000000-0000-0000-0000-000000000004')$$,
  'a coordinator can verify a complete student profile without broad directory access'
);
reset role;
select is(
  (select verification_status::text from public.academic_records where student_id = '21000000-0000-0000-0000-000000000004'),
  'VERIFIED',
  'verification locks the current academic record'
);
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '21000000-0000-0000-0000-000000000002', true);
select throws_ok(
  $$select public.correct_verified_academic_record(
    '21000000-0000-0000-0000-000000000004', 8.5, 0::smallint, 'Correction'
  )$$,
  '42501',
  null,
  'a coordinator cannot correct verified academic data'
);

select set_config('request.jwt.claim.sub', '21000000-0000-0000-0000-000000000004', true);
select throws_ok(
  $$select public.save_student_academic_record(9.0, 1::smallint)$$,
  '42501',
  null,
  'verified academic data becomes immutable to the student'
);

select set_config('request.jwt.claim.sub', '21000000-0000-0000-0000-000000000003', true);
select lives_ok(
  $$select public.correct_verified_academic_record(
    '21000000-0000-0000-0000-000000000004', 8.5, 1::smallint, 'Registrar correction'
  )$$,
  'the TNP Secretary can make an audited verified-academic correction'
);
reset role;
select is(
  (
    select count(*)::integer
    from public.audit_logs
    where action = 'student.verified_academic_corrected'
      and actor_id = '21000000-0000-0000-0000-000000000003'
  ),
  1,
  'verified-academic correction creates audit evidence'
);
select ok(
  not has_table_privilege('authenticated', 'public.companies', 'select'),
  'Phase 5 and later company data remains default-deny'
);

select * from finish();
rollback;
