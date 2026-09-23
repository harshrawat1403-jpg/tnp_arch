begin;
select plan(34);

insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data)
values
  ('31000000-0000-0000-0000-000000000001', 'super@example.test', now(), '{}'),
  ('31000000-0000-0000-0000-000000000002', 'coordinator@example.test', now(), '{}'),
  ('31000000-0000-0000-0000-000000000003', 'secretary@example.test', now(), '{}'),
  ('31000000-0000-0000-0000-000000000004', 'student-one@example.test', now(), '{}'),
  ('31000000-0000-0000-0000-000000000005', 'student-two@example.test', now(), '{}'),
  ('31000000-0000-0000-0000-000000000006', 'recruiter@example.test', now(), '{}');

insert into public.profiles (id, display_name, role, coordinator_slot)
values
  ('31000000-0000-0000-0000-000000000001', 'Super', 'SUPER_ADMIN', null),
  ('31000000-0000-0000-0000-000000000002', 'Coordinator', 'TNP_COORDINATOR', 1),
  ('31000000-0000-0000-0000-000000000003', 'Secretary', 'TNP_SECRETARY', null),
  ('31000000-0000-0000-0000-000000000004', 'Student One', 'STUDENT', null),
  ('31000000-0000-0000-0000-000000000005', 'Student Two', 'STUDENT', null),
  ('31000000-0000-0000-0000-000000000006', 'Recruiter', 'RECRUITER', null);

insert into public.student_roster (id, student_identifier, institutional_email, course, batch_year)
values
  ('32000000-0000-0000-0000-000000000004', 'STU-ONE', 'student-one@example.test', 'BARCH', 2027),
  ('32000000-0000-0000-0000-000000000005', 'STU-TWO', 'student-two@example.test', 'BPLAN', 2027);
insert into public.student_profiles (user_id, roster_id)
values
  ('31000000-0000-0000-0000-000000000004', '32000000-0000-0000-0000-000000000004'),
  ('31000000-0000-0000-0000-000000000005', '32000000-0000-0000-0000-000000000005');
insert into public.skills (id, display_name)
values
  ('33000000-0000-0000-0000-000000000001', 'Revit'),
  ('33000000-0000-0000-0000-000000000002', 'Autodesk Revit'),
  ('33000000-0000-0000-0000-000000000003', 'AutoCAD');

select is((select count(*)::integer from public.skills where normalized_name in ('revit', 'autodesk revit')), 2, 'semantic aliases remain distinct canonical records');
select throws_ok(
  $$insert into public.student_skills (student_id, skill_id, proficiency_level) values ('31000000-0000-0000-0000-000000000004', '33000000-0000-0000-0000-000000000001', 5)$$,
  '23514', null, 'proficiency outside 1 through 4 is rejected'
);

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '31000000-0000-0000-0000-000000000004', true);
select lives_ok($$select public.save_student_skill('33000000-0000-0000-0000-000000000001'::uuid, 3::smallint)$$, 'a student can declare an active catalog skill');
select is((select count(*)::integer from public.student_skills), 1, 'student skill has one canonical row');
select is((select count(*)::integer from public.student_skills where student_id = '31000000-0000-0000-0000-000000000004'), 1, 'student can read own skill');
select throws_ok(
  $$select public.review_student_skill((select id from public.student_skills limit 1), 'VERIFIED', null)$$,
  '42501', null, 'student cannot self-verify'
);
select throws_ok(
  $$update public.student_profiles set skills = array['Forged'] where user_id = '31000000-0000-0000-0000-000000000004'$$,
  '42501', null, 'student cannot write the legacy array'
);

reset role;
insert into public.coordinator_student_scopes (coordinator_id, course, batch_year, assigned_by)
values ('31000000-0000-0000-0000-000000000002', 'BARCH', 2027, '31000000-0000-0000-0000-000000000003');

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '31000000-0000-0000-0000-000000000005', true);
reset role;
insert into public.student_skills (id, student_id, skill_id, proficiency_level)
values ('35000000-0000-0000-0000-000000000002', '31000000-0000-0000-0000-000000000005', '33000000-0000-0000-0000-000000000003', 2);

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '31000000-0000-0000-0000-000000000002', true);
select is((select count(*)::integer from public.student_skills), 1, 'coordinator only reads assigned course and batch skills');
select throws_ok(
  $$select public.review_student_skill('35000000-0000-0000-0000-000000000002', 'VERIFIED', null)$$,
  '42501', null, 'coordinator cannot review a student outside assigned scope'
);
select lives_ok(
  $$select public.review_student_skill((select id from public.student_skills where student_id = '31000000-0000-0000-0000-000000000004'), 'REJECTED', 'Please attach project evidence')$$,
  'coordinator can reject a pending scoped skill with a reason'
);
reset role;
select is((select verification_status::text from public.student_skills where student_id = '31000000-0000-0000-0000-000000000004'), 'REJECTED', 'rejection status persists');
select is((select reviewer_note from public.student_skills where student_id = '31000000-0000-0000-0000-000000000004'), 'Please attach project evidence', 'rejection reason persists');

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '31000000-0000-0000-0000-000000000004', true);
select lives_ok($$select public.save_student_skill('33000000-0000-0000-0000-000000000001'::uuid, 4::smallint)$$, 'student can correct and resubmit a rejected skill');
reset role;
select is((select verification_status::text from public.student_skills where student_id = '31000000-0000-0000-0000-000000000004'), 'PENDING', 'resubmission returns the skill to pending');

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '31000000-0000-0000-0000-000000000003', true);
select lives_ok(
  $$select public.review_student_skill((select id from public.student_skills where student_id = '31000000-0000-0000-0000-000000000004'), 'VERIFIED', null)$$,
  'TNP Secretary can verify a student skill'
);
select lives_ok($$select public.create_skill_catalog_entry('Rhino')$$, 'TNP Secretary can create a catalog skill');
select lives_ok($$select public.update_skill_catalog_entry((select id from public.skills where normalized_name = 'rhino'), 'Rhino 3D')$$, 'TNP Secretary can update a canonical catalog skill');
select is((select display_name from public.skills where normalized_name = 'rhino 3d'), 'Rhino 3D', 'catalog update persists the approved canonical name');
select lives_ok($$select public.archive_skill_catalog_entry((select id from public.skills where normalized_name = 'rhino 3d'))$$, 'TNP Secretary can archive a catalog skill');
select ok((select is_archived from public.skills where normalized_name = 'rhino 3d'), 'archived skills are marked unavailable for new selection');
select lives_ok($$select public.reactivate_skill_catalog_entry((select id from public.skills where normalized_name = 'rhino 3d'))$$, 'TNP Secretary can reactivate an archived catalog skill');
select ok((select not is_archived from public.skills where normalized_name = 'rhino 3d'), 'reactivated skills are active again');
select lives_ok($$select public.correct_verified_student_skill((select id from public.student_skills where student_id = '31000000-0000-0000-0000-000000000004'), 2::smallint, 'Office correction')$$, 'TNP Secretary can correct a verified skill with a reason');
select is((select proficiency_level::integer from public.student_skills where student_id = '31000000-0000-0000-0000-000000000004'), 2, 'verified skill correction persists without enabling student edits');
select lives_ok($$select public.assign_coordinator_student_scope('31000000-0000-0000-0000-000000000002'::uuid, 'BPLAN', 2027::smallint)$$, 'TNP Secretary can assign an explicit coordinator course and batch scope');
select lives_ok($$select public.remove_coordinator_student_scope('31000000-0000-0000-0000-000000000002'::uuid, 'BPLAN', 2027::smallint)$$, 'TNP Secretary can remove an explicit coordinator course and batch scope');
reset role;

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '31000000-0000-0000-0000-000000000004', true);
select throws_ok(
  $$select public.save_student_skill('33000000-0000-0000-0000-000000000001'::uuid, 1::smallint)$$,
  '42501', null, 'verified skills are immutable to students'
);

reset role;
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '31000000-0000-0000-0000-000000000003', true);
select lives_ok($$select public.revoke_verified_student_skill((select id from public.student_skills where student_id = '31000000-0000-0000-0000-000000000004'), 'Verification requires a fresh review')$$, 'TNP Secretary can revoke a verified skill with a reason');
select is((select verification_status::text from public.student_skills where student_id = '31000000-0000-0000-0000-000000000004'), 'PENDING', 'verified skill revocation returns the record to pending review');

reset role;
insert into public.documents (id, owner_id, document_kind, storage_bucket, storage_path, original_filename, mime_type, byte_size)
values ('34000000-0000-0000-0000-000000000001', '31000000-0000-0000-0000-000000000005', 'SKILL_EVIDENCE', 'skill-evidence', '31000000-0000-0000-0000-000000000005/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa.pdf', 'evidence.pdf', 'application/pdf', 9);
select throws_ok(
  $$insert into public.student_skill_evidence (student_skill_id, title, source_type, document_id) values ((select id from public.student_skills where student_id = '31000000-0000-0000-0000-000000000004'), 'Forged', 'DOCUMENT', '34000000-0000-0000-0000-000000000001')$$,
  '23514', 'Skill evidence document must be an active SKILL_EVIDENCE document owned by the student', 'cross-owner evidence document references are rejected'
);
select throws_ok(
  $$insert into public.student_skill_evidence (student_skill_id, title, source_type, project_url, document_id) values ((select id from public.student_skills where student_id = '31000000-0000-0000-0000-000000000004'), 'Both', 'PROJECT_URL', 'https://example.test', '34000000-0000-0000-0000-000000000001')$$,
  '23514', null, 'evidence requires exactly one approved source'
);

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '31000000-0000-0000-0000-000000000006', true);
select is((select count(*)::integer from public.student_skills), 0, 'recruiter cannot read student skills');
select throws_ok($$select public.create_skill_catalog_entry('Forged')$$, '42501', null, 'recruiter cannot manage the catalog');
reset role;
select ok((select count(*) from public.audit_logs where action in ('student.skill_reviewed', 'skill.catalog_created', 'skill.catalog_updated', 'skill.catalog_archived', 'skill.catalog_reactivated', 'coordinator.student_scope_assigned', 'coordinator.student_scope_removed', 'student.verified_skill_corrected', 'student.verified_skill_revoked')) >= 9, 'privileged skill actions create audit evidence');

select * from finish();
rollback;
