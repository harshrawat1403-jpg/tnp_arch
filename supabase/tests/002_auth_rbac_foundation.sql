begin;
select plan(21);

insert into auth.users (id, email, raw_user_meta_data)
values
  ('11000000-0000-0000-0000-000000000001', 'super-admin@example.test', '{}'),
  ('11000000-0000-0000-0000-000000000002', 'student@example.test', '{}'),
  ('11000000-0000-0000-0000-000000000003', 'secretary@example.test', '{}'),
  ('11000000-0000-0000-0000-000000000004', 'coordinator@example.test', '{}'),
  ('11000000-0000-0000-0000-000000000005', 'recruiter@example.test', '{}');

insert into public.profiles (id, display_name, role, coordinator_slot)
values
  ('11000000-0000-0000-0000-000000000001', 'Super Admin', 'SUPER_ADMIN', null),
  ('11000000-0000-0000-0000-000000000002', 'Student', 'STUDENT', null),
  ('11000000-0000-0000-0000-000000000003', 'TNP Secretary', 'TNP_SECRETARY', null),
  ('11000000-0000-0000-0000-000000000004', 'Coordinator', 'TNP_COORDINATOR', 1),
  ('11000000-0000-0000-0000-000000000005', 'Recruiter', 'RECRUITER', null);

insert into public.audit_logs (actor_id, action, entity_type, entity_id)
values (
  '11000000-0000-0000-0000-000000000001',
  'test.phase_3_fixture',
  'profile',
  '11000000-0000-0000-0000-000000000001'
);

select is(
  (
    select count(*)::integer
    from pg_catalog.pg_class as relation
    join pg_catalog.pg_namespace as namespace on namespace.oid = relation.relnamespace
    where namespace.nspname = 'public'
      and relation.relname in (
        'profiles',
        'student_roster',
        'student_profiles',
        'academic_records',
        'companies',
        'recruiters',
        'placement_drives',
        'drive_eligible_batches',
        'drive_eligibility',
        'recruiter_drive_access',
        'applications',
        'application_status_history',
        'documents',
        'announcements',
        'audit_logs'
      )
      and relation.relrowsecurity
  ),
  15,
  'every Phase 2 application table has RLS enabled'
);

select ok(
  has_table_privilege('authenticated', 'public.profiles', 'select'),
  'authenticated users may resolve a profile through the narrow profile grant'
);

select ok(
  not has_table_privilege('authenticated', 'public.companies', 'select'),
  'company data remains unavailable before the company-management phase'
);

select ok(
  not has_function_privilege('authenticated', 'public.transition_application_status(uuid, uuid, public.application_status, text, boolean)', 'execute'),
  'application transition RPC remains unavailable before the applications phase'
);

set local role anon;
select throws_ok(
  $$select * from public.profiles$$,
  '42501',
  null,
  'anonymous callers cannot read profiles'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '11000000-0000-0000-0000-000000000002', true);

select is(
  (select count(*)::integer from public.profiles),
  1,
  'a student can resolve only their own active profile'
);

select is(
  (select count(*)::integer from public.profiles where id = '11000000-0000-0000-0000-000000000001'),
  0,
  'a student cannot resolve the super-admin profile'
);

select ok(
  private.has_active_role(array['STUDENT'::public.app_role]),
  'role helper resolves the caller role from auth.uid()'
);

select ok(
  not private.has_active_role(array['SUPER_ADMIN'::public.app_role]),
  'role helper does not accept a forged elevated role'
);

select is(
  (select count(*)::integer from public.audit_logs),
  0,
  'a student cannot read audit logs'
);

select throws_ok(
  $$update public.profiles set role = 'SUPER_ADMIN' where id = '11000000-0000-0000-0000-000000000002'$$,
  '42501',
  null,
  'a student cannot mutate the protected role column'
);

select throws_ok(
  $$select * from public.companies$$,
  '42501',
  null,
  'a student cannot access company data before its approved phase'
);

select throws_ok(
  $$select public.transition_application_status(
    '11000000-0000-0000-0000-000000000001',
    '11000000-0000-0000-0000-000000000002',
    'SHORTLISTED',
    null,
    false
  )$$,
  '42501',
  null,
  'a student cannot invoke a future application-transition RPC'
);

select set_config('request.jwt.claim.sub', '11000000-0000-0000-0000-000000000004', true);

select is(
  (select count(*)::integer from public.profiles),
  1,
  'a coordinator remains limited to their own profile in Phase 3'
);

select is(
  (select count(*)::integer from public.audit_logs),
  0,
  'a coordinator cannot access full audit logs'
);

select set_config('request.jwt.claim.sub', '11000000-0000-0000-0000-000000000003', true);

select is(
  (select count(*)::integer from public.profiles),
  1,
  'the TNP Secretary remains limited to their own profile in Phase 3'
);

select is(
  (select count(*)::integer from public.audit_logs),
  0,
  'the TNP Secretary cannot access full audit logs'
);

select set_config('request.jwt.claim.sub', '11000000-0000-0000-0000-000000000005', true);

select is(
  (select count(*)::integer from public.profiles),
  1,
  'a recruiter can resolve only their own profile'
);

select is(
  (select count(*)::integer from public.audit_logs),
  0,
  'a recruiter cannot access audit logs'
);

select set_config('request.jwt.claim.sub', '11000000-0000-0000-0000-000000000001', true);

select is(
  (select count(*)::integer from public.profiles),
  5,
  'the Super Admin can resolve protected role records'
);

select is(
  (select count(*)::integer from public.audit_logs),
  1,
  'the Super Admin can access full audit evidence'
);

select * from finish();
rollback;
