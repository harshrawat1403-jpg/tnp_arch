begin;
select plan(33);

select has_table('public', 'profiles', 'profiles table exists');
select has_table('public', 'student_roster', 'student roster table exists');
select has_table('public', 'applications', 'applications table exists');
select has_table('public', 'audit_logs', 'audit logs table exists');
select has_column('public', 'academic_records', 'verification_status', 'academic records carry lockable verification state');
select has_function('public', 'transition_application_status', 'application transition function exists');

insert into auth.users (id, email, raw_user_meta_data)
values
  ('00000000-0000-0000-0000-000000000001', 'technical.secretary@example.test', '{}'),
  ('00000000-0000-0000-0000-000000000002', 'student.one@example.test', '{}'),
  ('00000000-0000-0000-0000-000000000003', 'tnp.secretary@example.test', '{}'),
  ('00000000-0000-0000-0000-000000000004', 'coordinator.one@example.test', '{}'),
  ('00000000-0000-0000-0000-000000000005', 'coordinator.two@example.test', '{}'),
  ('00000000-0000-0000-0000-000000000006', 'candidate@example.test', '{}'),
  ('00000000-0000-0000-0000-000000000007', 'candidate.two@example.test', '{}');

insert into public.profiles (id, display_name, role)
values
  ('00000000-0000-0000-0000-000000000001', 'Technical Secretary', 'SUPER_ADMIN'),
  ('00000000-0000-0000-0000-000000000002', 'Student One', 'STUDENT'),
  ('00000000-0000-0000-0000-000000000003', 'TNP Secretary', 'TNP_SECRETARY'),
  ('00000000-0000-0000-0000-000000000004', 'Coordinator One', 'TNP_COORDINATOR', 1),
  ('00000000-0000-0000-0000-000000000005', 'Coordinator Two', 'TNP_COORDINATOR', 2);

select throws_ok(
  $$insert into public.profiles (id, display_name, role)
    values ('00000000-0000-0000-0000-000000000006', 'Second Super Admin', 'SUPER_ADMIN')$$,
  '23505',
  null,
  'a second active SUPER_ADMIN is rejected'
);

select throws_ok(
  $$insert into public.profiles (id, display_name, role, coordinator_slot)
    values ('00000000-0000-0000-0000-000000000006', 'Third Coordinator', 'TNP_COORDINATOR', 1)$$,
  '23505',
  null,
  'a duplicate active coordinator slot is rejected'
);

select throws_ok(
  $$insert into public.profiles (id, display_name, role)
    values ('00000000-0000-0000-0000-000000000007', 'Second TNP Secretary', 'TNP_SECRETARY')$$,
  '23505',
  null,
  'a second active TNP Secretary is rejected'
);

select throws_ok(
  $$delete from public.profiles where id = '00000000-0000-0000-0000-000000000001';
    set constraints profiles_require_exactly_one_active_super_admin immediate$$,
  '23514',
  null,
  'the only active SUPER_ADMIN cannot be removed'
);

insert into public.student_roster (id, student_identifier, institutional_email, course, batch_year)
values ('10000000-0000-0000-0000-000000000001', 'STU-001', 'student.one@example.test', 'BARCH', 2027);

insert into public.student_profiles (user_id, roster_id)
values ('00000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000001');

insert into public.student_roster (id, student_identifier, institutional_email, course, batch_year)
values ('10000000-0000-0000-0000-000000000002', 'STU-002', 'candidate@example.test', 'BARCH', 2027);

select throws_ok(
  $$insert into public.student_profiles (user_id, roster_id)
    values ('00000000-0000-0000-0000-000000000004', '10000000-0000-0000-0000-000000000002')$$,
  '23514',
  null,
  'a non-student profile cannot receive student data'
);

insert into public.academic_records (student_id, course, batch_year, cgpa, active_backlog_count)
values ('00000000-0000-0000-0000-000000000002', 'BARCH', 2027, 8.20, 0);

select throws_ok(
  $$update public.academic_records
    set course = 'MARCH'
    where student_id = '00000000-0000-0000-0000-000000000002'$$,
  '23514',
  null,
  'academic course must remain aligned with roster data'
);

insert into public.companies (id, name, created_by)
values ('20000000-0000-0000-0000-000000000001', 'Example Studio', '00000000-0000-0000-0000-000000000001');

insert into public.placement_drives (
  id, company_id, title, drive_type, description, application_deadline, created_by
)
values (
  '30000000-0000-0000-0000-000000000001',
  '20000000-0000-0000-0000-000000000001',
  'Graduate Architect',
  'PLACEMENT',
  'Fictional test drive.',
  now() + interval '7 days',
  '00000000-0000-0000-0000-000000000001'
);

insert into public.drive_eligible_batches (drive_id, course, batch_year)
values ('30000000-0000-0000-0000-000000000001', 'BARCH', 2027);

insert into public.drive_eligibility (drive_id, minimum_cgpa, maximum_active_backlogs)
values ('30000000-0000-0000-0000-000000000001', 7.50, 0);

insert into public.applications (id, student_id, drive_id, submitted_by)
values (
  '40000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000002',
  '30000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000002'
);

select throws_ok(
  $$insert into public.applications (student_id, drive_id, submitted_by)
    values (
      '00000000-0000-0000-0000-000000000002',
      '30000000-0000-0000-0000-000000000001',
      '00000000-0000-0000-0000-000000000002'
    )$$,
  '23505',
  null,
  'duplicate drive application is rejected'
);

select throws_ok(
  $$insert into public.applications (student_id, drive_id, submitted_by)
    values (
      '00000000-0000-0000-0000-000000000002',
      '30000000-0000-0000-0000-000000000001',
      '00000000-0000-0000-0000-000000000004'
    )$$,
  '23514',
  null,
  'an application submitter must be the student owner'
);

select lives_ok(
  $$select public.transition_application_status(
    '40000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000004',
    'SHORTLISTED',
    'Fictional shortlist'
  )$$,
  'an allowed status transition succeeds'
);

select is(
  (select current_status::text from public.applications where id = '40000000-0000-0000-0000-000000000001'),
  'SHORTLISTED',
  'transition updates current application status'
);

select is(
  (select count(*)::integer from public.application_status_history where application_id = '40000000-0000-0000-0000-000000000001'),
  2,
  'submission and transition write status history'
);

select is(
  (select count(*)::integer from public.audit_logs where entity_id = '40000000-0000-0000-0000-000000000001'),
  2,
  'submission and transition write audit rows'
);

select throws_ok(
  $$select public.transition_application_status(
    '40000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000004',
    'SELECTED',
    'Invalid skip'
  )$$,
  '23514',
  null,
  'invalid status transition is rejected'
);

select lives_ok(
  $$select public.transition_application_status(
    '40000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000004',
    'INTERVIEW',
    'Fictional interview'
  )$$,
  'a shortlisted application can move to interview'
);

select lives_ok(
  $$select public.transition_application_status(
    '40000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000001',
    'SELECTED',
    'Fictional selection'
  )$$,
  'an interview application can move to selected'
);

select throws_ok(
  $$select public.transition_application_status(
    '40000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000001',
    'INTERVIEW',
    null,
    true
  )$$,
  '23514',
  null,
  'a terminal correction requires a reason'
);

select lives_ok(
  $$select public.transition_application_status(
    '40000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000001',
    'INTERVIEW',
    'Selection entered in error',
    true
  )$$,
  'a terminal correction restores only the immediate previous state'
);

select is(
  (select current_status::text from public.applications where id = '40000000-0000-0000-0000-000000000001'),
  'INTERVIEW',
  'terminal correction restores the previous non-terminal status'
);

select throws_ok(
  $$update public.applications
    set current_status = 'NOT_A_STATUS'
    where id = '40000000-0000-0000-0000-000000000001'$$,
  '22P02',
  null,
  'invalid application enum value is rejected'
);

select throws_ok(
  $$update public.applications
    set current_status = 'INTERVIEW'
    where id = '40000000-0000-0000-0000-000000000001'$$,
  '23514',
  null,
  'direct application status mutation is rejected'
);

select throws_ok(
  $$update public.application_status_history
    set reason = 'tampered'
    where application_id = '40000000-0000-0000-0000-000000000001'$$,
  '23514',
  null,
  'application history is append-only'
);

select throws_ok(
  $$delete from public.audit_logs
    where entity_id = '40000000-0000-0000-0000-000000000001'$$,
  '23514',
  null,
  'audit logs are append-only'
);

insert into public.placement_drives (
  id, company_id, title, drive_type, description, application_deadline
)
values (
  '30000000-0000-0000-0000-000000000002',
  '20000000-0000-0000-0000-000000000001',
  'Archival test drive',
  'PLACEMENT',
  'Archive state test drive.',
  now() + interval '2 days'
);

update public.placement_drives
set status = 'PUBLISHED', published_at = now()
where id = '30000000-0000-0000-0000-000000000002';

update public.placement_drives
set status = 'CLOSED', closed_at = now()
where id = '30000000-0000-0000-0000-000000000002';

select throws_ok(
  $$update public.placement_drives
    set status = 'ARCHIVED'
    where id = '30000000-0000-0000-0000-000000000002'$$,
  '23514',
  null,
  'archived drive without archive metadata is rejected'
);

select throws_ok(
  $$insert into public.placement_drives (
    company_id, title, drive_type, description, application_deadline, status
  ) values (
    '20000000-0000-0000-0000-000000000001',
    'Invalid initial lifecycle state',
    'PLACEMENT',
    'Drives must begin as drafts.',
    now() + interval '1 day',
    'PUBLISHED'
  )$$,
  '23514',
  null,
  'a drive must be created in DRAFT status'
);

select throws_ok(
  $$update public.placement_drives
    set status = 'CLOSED', closed_at = now()
    where id = '30000000-0000-0000-0000-000000000001'$$,
  '23514',
  null,
  'drive lifecycle cannot skip from DRAFT to CLOSED'
);

select ok(to_regclass('public.applications_drive_status_idx') is not null, 'applicant queue index exists');
select ok(to_regclass('public.drive_eligible_batches_course_batch_idx') is not null, 'eligibility lookup index exists');

select * from finish();
rollback;
