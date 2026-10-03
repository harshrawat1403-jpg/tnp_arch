begin;
select plan(61);

insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data)
values
  ('41000000-0000-0000-0000-000000000001', 'super@example.test', now(), '{}'),
  ('41000000-0000-0000-0000-000000000002', 'secretary@example.test', now(), '{}'),
  ('41000000-0000-0000-0000-000000000003', 'coordinator-one@example.test', now(), '{}'),
  ('41000000-0000-0000-0000-000000000004', 'coordinator-two@example.test', now(), '{}'),
  ('41000000-0000-0000-0000-000000000005', 'student@example.test', now(), '{}'),
  ('41000000-0000-0000-0000-000000000006', 'recruiter@example.test', now(), '{}'),
  (
    '41000000-0000-0000-0000-000000000007',
    'invited.recruiter@example.test',
    now(),
    '{"recruiter_invitation_id":"42000000-0000-0000-0000-000000000005"}'
  );

insert into public.profiles (id, display_name, role, coordinator_slot)
values
  ('41000000-0000-0000-0000-000000000001', 'Super Admin', 'SUPER_ADMIN', null),
  ('41000000-0000-0000-0000-000000000002', 'TNP Secretary', 'TNP_SECRETARY', null),
  ('41000000-0000-0000-0000-000000000003', 'Coordinator One', 'TNP_COORDINATOR', 1),
  ('41000000-0000-0000-0000-000000000004', 'Coordinator Two', 'TNP_COORDINATOR', 2),
  ('41000000-0000-0000-0000-000000000005', 'Student', 'STUDENT', null),
  ('41000000-0000-0000-0000-000000000006', 'Existing Recruiter', 'RECRUITER', null);

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '41000000-0000-0000-0000-000000000003', true);
select lives_ok(
  $$select public.create_company('Coordinator Studio', 'https://coordinator.example.test', 'Coordinator draft')$$,
  'a coordinator can create an unarchived company draft'
);
select lives_ok(
  $$select public.update_company((select id from public.companies where normalized_name = 'coordinator studio'), 'Coordinator Studio Updated', 'https://coordinator.example.test', 'Updated draft')$$,
  'a coordinator can edit their own uninvited company draft'
);
select lives_ok(
  $$select public.create_recruiter_contact((select id from public.companies where normalized_name = 'coordinator studio updated'), 'Draft Recruiter', 'draft.recruiter@example.test', null)$$,
  'a coordinator can create a contact for their own uninvited company draft'
);
select set_config('request.jwt.claim.sub', '41000000-0000-0000-0000-000000000004', true);
select throws_ok(
  $$select public.update_company((select id from public.companies where normalized_name = 'coordinator studio updated'), 'Other Coordinator Change', 'https://coordinator.example.test', null)$$,
  '42501', null, 'a coordinator cannot edit another coordinator draft'
);
select set_config('request.jwt.claim.sub', '41000000-0000-0000-0000-000000000003', true);
select throws_ok(
  $$select public.set_company_archive_state((select id from public.companies where normalized_name = 'coordinator studio updated'), true)$$,
  '42501', null, 'a coordinator cannot archive a company'
);
select throws_ok(
  $$select * from public.prepare_recruiter_invitation((select id from public.recruiters where email = 'draft.recruiter@example.test'), false)$$,
  '42501', null, 'a coordinator cannot issue a recruiter invitation'
);

select set_config('request.jwt.claim.sub', '41000000-0000-0000-0000-000000000003', true);
select throws_ok(
  $$select public.grant_recruiter_drive_access('42000000-0000-0000-0000-000000000002', '42000000-0000-0000-0000-000000000006', null)$$,
  '42501', null, 'a coordinator cannot manage recruiter drive grants'
);
select set_config('request.jwt.claim.sub', '41000000-0000-0000-0000-000000000002', true);
select lives_ok(
  $$select public.create_company('Secretary Studio', 'https://secretary.example.test', null)$$,
  'the TNP Secretary can create a company'
);
select throws_ok(
  $$select public.update_company((select id from public.companies where normalized_name = 'coordinator studio updated'), 'Secretary Studio', null, null)$$,
  '23505', null, 'a duplicate normalized company name remains rejected'
);
select lives_ok(
  $$select public.create_recruiter_contact((select id from public.companies where normalized_name = 'secretary studio'), 'Secretary Recruiter', 'secretary.recruiter@example.test', '+91 90000 00000')$$,
  'the TNP Secretary can create a recruiter contact'
);
select throws_ok(
  $$select public.create_recruiter_contact((select id from public.companies where normalized_name = 'secretary studio'), 'Duplicate Email', 'draft.recruiter@example.test', null)$$,
  '23505', null, 'a duplicate recruiter email remains rejected'
);
select throws_ok(
  $$select public.create_company('HTTP Studio', 'http://not-allowed.example.test', null)$$,
  '23514', null, 'company URLs must use HTTPS'
);
select lives_ok(
  $$select * from public.prepare_recruiter_invitation((select id from public.recruiters where email = 'secretary.recruiter@example.test'), false)$$,
  'the TNP Secretary can prepare a recruiter invitation'
);
reset role;
insert into public.recruiter_invitations (id, recruiter_id, email, status, issued_by, expires_at)
values (
  '42000000-0000-0000-0000-000000000003',
  (select id from public.recruiters where email = 'draft.recruiter@example.test'),
  'draft.recruiter@example.test',
  'PREPARED',
  '41000000-0000-0000-0000-000000000002',
  now() + interval '1 hour'
);
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '41000000-0000-0000-0000-000000000003', true);
select throws_ok(
  $$select public.update_company((select id from public.companies where normalized_name = 'coordinator studio updated'), 'Locked Draft', 'https://coordinator.example.test', null)$$,
  '42501', null, 'a coordinator cannot edit a company after an invitation is issued'
);
select throws_ok(
  $$select public.update_recruiter_contact((select id from public.recruiters where email = 'draft.recruiter@example.test'), 'Locked Recruiter', 'draft.recruiter@example.test', null)$$,
  '42501', null, 'a coordinator cannot edit a recruiter after an invitation is issued'
);
reset role;
select is(
  public.enforce_student_roster_signup(
    jsonb_build_object('user', jsonb_build_object('email', 'draft.recruiter@example.test', 'user_metadata', jsonb_build_object('recruiter_invitation_id', '42000000-0000-0000-0000-000000000003')))
  ),
  '{}'::jsonb,
  'the single Auth hook permits a matching prepared recruiter invitation'
);
select is(
  public.enforce_student_roster_signup(
    jsonb_build_object('user', jsonb_build_object('email', 'wrong@example.test', 'user_metadata', jsonb_build_object('recruiter_invitation_id', '42000000-0000-0000-0000-000000000003')))
  ) -> 'error' ->> 'http_code',
  '403',
  'the Auth hook rejects a recruiter invitation email mismatch'
);
select is(
  public.enforce_student_roster_signup(
    jsonb_build_object('user', jsonb_build_object('email', 'draft.recruiter@example.test', 'user_metadata', jsonb_build_object('recruiter_invitation_id', 'not-a-uuid')))
  ) -> 'error' ->> 'http_code',
  '403',
  'the Auth hook rejects invalid invitation metadata'
);

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '41000000-0000-0000-0000-000000000002', true);
select lives_ok(
  $$select public.revoke_recruiter_invitation('42000000-0000-0000-0000-000000000003', 'Contact requested a pause')$$,
  'the TNP Secretary can revoke an active recruiter invitation with a reason'
);
reset role;
select is((select status::text from public.recruiter_invitations where id = '42000000-0000-0000-0000-000000000003'), 'REVOKED', 'revocation preserves a historical revoked invitation row');
select is(
  public.enforce_student_roster_signup(
    jsonb_build_object('user', jsonb_build_object('email', 'draft.recruiter@example.test', 'user_metadata', jsonb_build_object('recruiter_invitation_id', '42000000-0000-0000-0000-000000000003')))
  ) -> 'error' ->> 'http_code',
  '403',
  'the Auth hook rejects a revoked recruiter invitation'
);
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '41000000-0000-0000-0000-000000000002', true);
select lives_ok(
  $$select * from public.prepare_recruiter_invitation((select id from public.recruiters where email = 'draft.recruiter@example.test'), true)$$,
  'reissue creates a new prepared invitation after the prior invitation is revoked'
);

reset role;
-- This fixture represents a provider-created invited user, not arbitrary
-- editable metadata on an unrelated existing Auth account.
update auth.users set created_at = now(), invited_at = now()
where id = '41000000-0000-0000-0000-000000000007';
insert into public.recruiters (id, company_id, full_name, email, created_by, updated_by)
values (
  '42000000-0000-0000-0000-000000000004',
  (select id from public.companies where normalized_name = 'secretary studio'),
  'Expired Recruiter',
  'expired.recruiter@example.test',
  '41000000-0000-0000-0000-000000000002',
  '41000000-0000-0000-0000-000000000002'
);
insert into public.recruiter_invitations (recruiter_id, email, status, issued_by, issued_at, expires_at)
values (
  '42000000-0000-0000-0000-000000000004',
  'expired.recruiter@example.test',
  'PREPARED',
  '41000000-0000-0000-0000-000000000002',
  now() - interval '2 hours',
  now() - interval '1 hour'
);
select is(
  public.enforce_student_roster_signup(
    jsonb_build_object('user', jsonb_build_object('email', 'expired.recruiter@example.test', 'user_metadata', jsonb_build_object('recruiter_invitation_id', (select id::text from public.recruiter_invitations where email = 'expired.recruiter@example.test'))))
  ) -> 'error' ->> 'http_code',
  '403',
  'the Auth hook rejects an expired recruiter invitation'
);
insert into public.companies (id, name, website_url, created_by, updated_by)
values ('42000000-0000-0000-0000-000000000001', 'Binding Studio', 'https://binding.example.test', '41000000-0000-0000-0000-000000000002', '41000000-0000-0000-0000-000000000002');
insert into public.recruiters (id, company_id, full_name, email, created_by, updated_by)
values ('42000000-0000-0000-0000-000000000002', '42000000-0000-0000-0000-000000000001', 'Invited Recruiter', 'invited.recruiter@example.test', '41000000-0000-0000-0000-000000000002', '41000000-0000-0000-0000-000000000002');
insert into public.recruiter_invitations (id, recruiter_id, email, status, issued_by, expires_at)
values ('42000000-0000-0000-0000-000000000005', '42000000-0000-0000-0000-000000000002', 'invited.recruiter@example.test', 'PREPARED', '41000000-0000-0000-0000-000000000002', now() + interval '1 hour');

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '41000000-0000-0000-0000-000000000002', true);
select lives_ok(
  $$select public.mark_recruiter_invitation_sent('42000000-0000-0000-0000-000000000005', '41000000-0000-0000-0000-000000000007', false)$$,
  'a matching server-created Auth user transitions a prepared invitation to sent'
);

select set_config('request.jwt.claim.sub', '41000000-0000-0000-0000-000000000007', true);
select lives_ok($$select public.complete_recruiter_invitation()$$, 'a confirmed invited user can complete recruiter binding once');
reset role;
select is((select role::text from public.profiles where id = '41000000-0000-0000-0000-000000000007'), 'RECRUITER', 'completion creates only a recruiter profile');
select is((select user_id::text from public.recruiters where id = '42000000-0000-0000-0000-000000000002'), '41000000-0000-0000-0000-000000000007', 'completion binds the one recruiter contact to the invited Auth user');
select is((select status::text from public.recruiter_invitations where id = '42000000-0000-0000-0000-000000000005'), 'ACCEPTED', 'completion accepts the invitation atomically');

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '41000000-0000-0000-0000-000000000007', true);
select throws_ok($$select public.complete_recruiter_invitation()$$, '42501', null, 'replaying recruiter invitation completion fails');
reset role;
insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data)
values (
  '41000000-0000-0000-0000-000000000008',
  'reissued.recruiter@example.test',
  now(),
  '{"recruiter_invitation_id":"42000000-0000-0000-0000-000000000007"}'
);
insert into public.recruiters (id, company_id, full_name, email, created_by, updated_by)
values (
  '42000000-0000-0000-0000-000000000008',
  '42000000-0000-0000-0000-000000000001',
  'Reissued Recruiter',
  'reissued.recruiter@example.test',
  '41000000-0000-0000-0000-000000000002',
  '41000000-0000-0000-0000-000000000002'
);
insert into public.recruiter_invitations (id, recruiter_id, email, status, auth_user_id, issued_by, expires_at, revoked_at, revoked_by, revocation_reason)
values (
  '42000000-0000-0000-0000-000000000007',
  '42000000-0000-0000-0000-000000000008',
  'reissued.recruiter@example.test',
  'REVOKED',
  '41000000-0000-0000-0000-000000000008',
  '41000000-0000-0000-0000-000000000002',
  now() + interval '1 hour',
  now(),
  '41000000-0000-0000-0000-000000000002',
  'Superseded by reissue'
);
insert into public.recruiter_invitations (id, recruiter_id, email, status, issued_by, expires_at)
values (
  '42000000-0000-0000-0000-000000000009',
  '42000000-0000-0000-0000-000000000008',
  'reissued.recruiter@example.test',
  'PREPARED',
  '41000000-0000-0000-0000-000000000002',
  now() + interval '1 hour'
);
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '41000000-0000-0000-0000-000000000002', true);
select lives_ok(
  $$select public.mark_recruiter_invitation_sent('42000000-0000-0000-0000-000000000009', '41000000-0000-0000-0000-000000000008', true)$$,
  'reissue accepts the existing Auth user only when a matching invitation was safely superseded'
);
reset role;
select is((select status::text from public.recruiter_invitations where id = '42000000-0000-0000-0000-000000000009'), 'SENT', 'reissue binds the new invitation without trusting stale Auth metadata');

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '41000000-0000-0000-0000-000000000007', true);
select is((select count(*)::integer from public.companies), 1, 'a recruiter can read only their own active company');
select is((select count(*)::integer from public.recruiters), 1, 'a recruiter can read only their own active contact');
select is((select count(*)::integer from public.student_profiles), 0, 'a recruiter cannot read student profile data');
select is((select count(*)::integer from public.student_roster), 0, 'a recruiter cannot read the student roster');
select is((select count(*)::integer from public.academic_records), 0, 'a recruiter cannot read academic records');
select is((select count(*)::integer from public.student_skills), 0, 'a recruiter cannot read student skills');
select is((select count(*)::integer from public.student_skill_evidence), 0, 'a recruiter cannot read student skill evidence');
select is((select count(*)::integer from public.documents), 0, 'a recruiter cannot read private documents or resumes');
select throws_ok($$select * from public.applications$$, '42501', null, 'a recruiter cannot read applications');
select is((select count(*)::integer from public.audit_logs), 0, 'a recruiter cannot read audit logs');

reset role;
insert into public.placement_drives (id, company_id, title, drive_type, description, application_deadline, created_by, updated_by)
values ('42000000-0000-0000-0000-000000000006', '42000000-0000-0000-0000-000000000001', 'Existing published drive', 'PLACEMENT', 'Existing record only', now() + interval '7 days', '41000000-0000-0000-0000-000000000002', '41000000-0000-0000-0000-000000000002');
insert into public.drive_eligibility (drive_id) values ('42000000-0000-0000-0000-000000000006');
insert into public.drive_eligible_batches (drive_id,course,batch_year) values ('42000000-0000-0000-0000-000000000006','B.Arch',2027);
update public.placement_drives
set status = 'PUBLISHED', published_at = now()
where id = '42000000-0000-0000-0000-000000000006';

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '41000000-0000-0000-0000-000000000002', true);
select lives_ok(
  $$select public.grant_recruiter_drive_access('42000000-0000-0000-0000-000000000002', '42000000-0000-0000-0000-000000000006', null)$$,
  'the TNP Secretary can grant metadata access only to an existing published company drive'
);
reset role;
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '41000000-0000-0000-0000-000000000007', true);
select is((select count(*)::integer from public.placement_drives), 1, 'the recruiter can read the explicitly granted published drive metadata');

reset role;
update public.recruiter_drive_access
set expires_at = now() - interval '1 minute'
where recruiter_id = '42000000-0000-0000-0000-000000000002'
  and drive_id = '42000000-0000-0000-0000-000000000006';
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '41000000-0000-0000-0000-000000000007', true);
select is((select count(*)::integer from public.placement_drives), 0, 'an expired grant stops recruiter drive visibility');

reset role;
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '41000000-0000-0000-0000-000000000002', true);
select lives_ok(
  $$select public.grant_recruiter_drive_access('42000000-0000-0000-0000-000000000002', '42000000-0000-0000-0000-000000000006', null)$$,
  'the TNP Secretary can reactivate an expired grant without creating duplicate history'
);
select lives_ok(
  $$select public.revoke_recruiter_drive_access('42000000-0000-0000-0000-000000000002', '42000000-0000-0000-0000-000000000006', 'Access withdrawn')$$,
  'the TNP Secretary can revoke recruiter drive access with a reason'
);
reset role;
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '41000000-0000-0000-0000-000000000007', true);
select is((select count(*)::integer from public.placement_drives), 0, 'a revoked grant immediately stops recruiter drive visibility');

reset role;
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '41000000-0000-0000-0000-000000000001', true);
select throws_ok(
  $$select public.set_company_archive_state('42000000-0000-0000-0000-000000000001', true)$$,
  '23514', null, 'even a revoked grant cannot permit company archive while its drive is published'
);
-- Phase 7 requires explicit drive closure before company archival.
select public.transition_drive('42000000-0000-0000-0000-000000000006',
  (public.staff_drive_detail('42000000-0000-0000-0000-000000000006')->>'revision')::integer, 'CLOSED');
select public.set_company_archive_state('42000000-0000-0000-0000-000000000001', true);
select lives_ok(
  $$select public.set_company_archive_state('42000000-0000-0000-0000-000000000001', false)$$,
  'the Super Admin can reactivate a company without changing grant history'
);
reset role;
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '41000000-0000-0000-0000-000000000007', true);
select is((select count(*)::integer from public.placement_drives), 0, 'company reactivation does not revive a revoked recruiter grant');
reset role;
select is((select status::text from public.recruiter_invitations where id = '42000000-0000-0000-0000-000000000007'), 'REVOKED', 'company reactivation does not revive a revoked invitation');

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '41000000-0000-0000-0000-000000000001', true);
select lives_ok(
  $$select public.set_recruiter_archive_state('42000000-0000-0000-0000-000000000002', true)$$,
  'the Super Admin can archive a recruiter contact'
);
reset role;
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '41000000-0000-0000-0000-000000000007', true);
select is((select count(*)::integer from public.recruiters), 0, 'archiving a recruiter immediately denies recruiter contact access');

reset role;
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '41000000-0000-0000-0000-000000000001', true);
select lives_ok(
  $$select public.set_recruiter_archive_state('42000000-0000-0000-0000-000000000002', false)$$,
  'the Super Admin can reactivate an active-company recruiter binding'
);
reset role;
-- Closed drives never reopen: a fresh published fixture exercises re-grant.
insert into public.placement_drives (id,company_id,title,drive_type,description,application_deadline)
values ('42000000-0000-0000-0000-000000000010','42000000-0000-0000-0000-000000000001','New grant fixture','PLACEMENT','Fresh valid drive',now()+interval '7 days');
insert into public.drive_eligibility(drive_id) values ('42000000-0000-0000-0000-000000000010');
insert into public.drive_eligible_batches(drive_id,course,batch_year) values ('42000000-0000-0000-0000-000000000010','B.Arch',2027);
update public.placement_drives set status='PUBLISHED',published_at=now() where id='42000000-0000-0000-0000-000000000010';
set local role authenticated;
select lives_ok(
  $$select public.grant_recruiter_drive_access('42000000-0000-0000-0000-000000000002', '42000000-0000-0000-0000-000000000010', null)$$,
  'the Super Admin can grant published-drive access after recruiter reactivation'
);
select public.transition_drive('42000000-0000-0000-0000-000000000010',
  (public.staff_drive_detail('42000000-0000-0000-0000-000000000010')->>'revision')::integer,'CLOSED');
select lives_ok(
  $$select public.set_company_archive_state('42000000-0000-0000-0000-000000000001', true)$$,
  'the Super Admin can archive a company non-destructively'
);
reset role;
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '41000000-0000-0000-0000-000000000007', true);
select is((select count(*)::integer from public.companies), 0, 'archiving a company immediately denies recruiter company access');
select is((select count(*)::integer from public.placement_drives), 0, 'archiving a company keeps recruiter drive access ineffective');

reset role;
select ok(
  (select count(*) from public.audit_logs where action in ('company.created', 'recruiter.created', 'recruiter.invitation_issued', 'recruiter.invitation_accepted', 'recruiter.drive_granted', 'recruiter.drive_revoked', 'recruiter.archived', 'recruiter.reactivated', 'company.archived')) >= 9,
  'sensitive Phase 6 lifecycle operations create audit evidence'
);
select ok(
  has_column_privilege('authenticated', 'public.companies', 'id', 'select')
  and not has_table_privilege('authenticated', 'public.companies', 'insert')
  and not has_table_privilege('authenticated', 'public.companies', 'update'),
  'company records retain narrow read grants without broad authenticated mutation privileges'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.recruiter_invitations'::regclass),
  'recruiter invitations have Row Level Security enabled'
);

select * from finish();
rollback;
