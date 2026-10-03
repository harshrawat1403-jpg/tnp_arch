begin;
select plan(26);

insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data, created_at, invited_at)
values
  ('61000000-0000-0000-0000-000000000001', 'recovery.super@example.test', now(), '{}', now(), null),
  ('61000000-0000-0000-0000-000000000002', 'recovery.secretary@example.test', now(), '{}', now(), null),
  ('61000000-0000-0000-0000-000000000003', 'recovery.coordinator@example.test', now(), '{}', now(), null),
  ('61000000-0000-0000-0000-000000000004', 'recovery.student@example.test', now(), '{}', now(), null),
  ('61000000-0000-0000-0000-000000000005', 'recovery.recruiter@example.test', null, '{"recruiter_invitation_id":"62000000-0000-0000-0000-000000000003"}', now(), now()),
  ('61000000-0000-0000-0000-000000000006', 'first.recruiter@example.test', null, '{"recruiter_invitation_id":"62000000-0000-0000-0000-000000000006"}', now(), now());
insert into public.profiles (id, display_name, role, coordinator_slot)
values
  ('61000000-0000-0000-0000-000000000001', 'Recovery Super', 'SUPER_ADMIN', null),
  ('61000000-0000-0000-0000-000000000002', 'Recovery Secretary', 'TNP_SECRETARY', null),
  ('61000000-0000-0000-0000-000000000003', 'Recovery Coordinator', 'TNP_COORDINATOR', 1),
  ('61000000-0000-0000-0000-000000000004', 'Recovery Student', 'STUDENT', null);
insert into public.companies (id, name, created_by, updated_by)
values ('62000000-0000-0000-0000-000000000001', 'Recovery Studio', '61000000-0000-0000-0000-000000000002', '61000000-0000-0000-0000-000000000002');
insert into public.recruiters (id, company_id, full_name, email, created_by, updated_by)
values
  ('62000000-0000-0000-0000-000000000002', '62000000-0000-0000-0000-000000000001', 'Recovery Recruiter', 'recovery.recruiter@example.test', '61000000-0000-0000-0000-000000000002', '61000000-0000-0000-0000-000000000002'),
  ('62000000-0000-0000-0000-000000000005', '62000000-0000-0000-0000-000000000001', 'First Recruiter', 'first.recruiter@example.test', '61000000-0000-0000-0000-000000000002', '61000000-0000-0000-0000-000000000002');
insert into public.recruiter_invitations (id, recruiter_id, email, issued_by, expires_at)
values
  ('62000000-0000-0000-0000-000000000003', '62000000-0000-0000-0000-000000000002', 'recovery.recruiter@example.test', '61000000-0000-0000-0000-000000000002', now() + interval '1 hour'),
  ('62000000-0000-0000-0000-000000000006', '62000000-0000-0000-0000-000000000005', 'first.recruiter@example.test', '61000000-0000-0000-0000-000000000002', now() + interval '1 hour');

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '61000000-0000-0000-0000-000000000002', true);
select lives_ok($$select id, recruiter_id, status from public.recruiter_invitations order by issued_at desc, id desc$$, 'staff invitation ordering uses only authorized columns');
select throws_ok(
  $$select public.mark_recruiter_invitation_sent('62000000-0000-0000-0000-000000000003', '61000000-0000-0000-0000-000000000002', false)$$,
  '23514', null, 'failed finalization rolls back after provider-created Auth user exists'
);
reset role;
select is((select status::text from public.recruiter_invitations where id = '62000000-0000-0000-0000-000000000003'), 'PREPARED', 'provider success is not relabeled delivery failure');
select ok((select auth_user_id is null from public.recruiter_invitations where id = '62000000-0000-0000-0000-000000000003'), 'failed finalization has no recorded Auth binding');

set local role authenticated;
select set_config('request.jwt.claim.sub', '61000000-0000-0000-0000-000000000003', true);
select throws_ok($$select * from public.prepare_recruiter_invitation('62000000-0000-0000-0000-000000000002', true)$$, '42501', null, 'coordinator cannot recover the invitation');
select set_config('request.jwt.claim.sub', '61000000-0000-0000-0000-000000000004', true);
select throws_ok($$select public.mark_recruiter_invitation_sent('62000000-0000-0000-0000-000000000003', '61000000-0000-0000-0000-000000000005', true)$$, '42501', null, 'student cannot finalize the invitation');
select set_config('request.jwt.claim.sub', '61000000-0000-0000-0000-000000000002', true);
select lives_ok($$select * from public.prepare_recruiter_invitation('62000000-0000-0000-0000-000000000002', true)$$, 'the Secretary can supersede a prepared attempt with unrecorded Auth success');
reset role;
select is((select status::text from public.recruiter_invitations where id = '62000000-0000-0000-0000-000000000003'), 'REVOKED', 'the failed-finalization attempt remains in history');

-- Unknown/missing metadata, different recruiter/email, and unrelated Auth
-- timestamps must never serve as proof of a provider-created identity.
update auth.users set raw_user_meta_data = '{}' where id = '61000000-0000-0000-0000-000000000005';
set local role authenticated;
select set_config('request.jwt.claim.sub', '61000000-0000-0000-0000-000000000002', true);
select throws_ok($$select public.mark_recruiter_invitation_sent((select id from public.recruiter_invitations where recruiter_id = '62000000-0000-0000-0000-000000000002' and status = 'PREPARED'), '61000000-0000-0000-0000-000000000005', true)$$, '23514', null, 'missing invitation metadata is denied');
reset role;
update auth.users set raw_user_meta_data = '{"recruiter_invitation_id":"62000000-0000-0000-0000-000000000006"}' where id = '61000000-0000-0000-0000-000000000005';
set local role authenticated;
select throws_ok($$select public.mark_recruiter_invitation_sent((select id from public.recruiter_invitations where recruiter_id = '62000000-0000-0000-0000-000000000002' and status = 'PREPARED'), '61000000-0000-0000-0000-000000000005', true)$$, '23514', null, 'metadata for another recruiter is denied');
reset role;
update auth.users set raw_user_meta_data = '{"recruiter_invitation_id":"62000000-0000-0000-0000-000000000003"}', email = 'wrong@example.test' where id = '61000000-0000-0000-0000-000000000005';
set local role authenticated;
select throws_ok($$select public.mark_recruiter_invitation_sent((select id from public.recruiter_invitations where recruiter_id = '62000000-0000-0000-0000-000000000002' and status = 'PREPARED'), '61000000-0000-0000-0000-000000000005', true)$$, '23514', null, 'recovery cannot weaken exact Auth email matching');
reset role;
update auth.users set created_at = now() - interval '1 day',
  raw_user_meta_data = jsonb_build_object('recruiter_invitation_id', (select id::text from public.recruiter_invitations where recruiter_id = '62000000-0000-0000-0000-000000000002' and status = 'PREPARED'))
where id = '61000000-0000-0000-0000-000000000005';
set local role authenticated;
select throws_ok($$select public.mark_recruiter_invitation_sent((select id from public.recruiter_invitations where recruiter_id = '62000000-0000-0000-0000-000000000002' and status = 'PREPARED'), '61000000-0000-0000-0000-000000000005', true)$$, '23514', null, 'editable metadata naming the current invitation cannot prove an unrelated Auth identity');
reset role;
update auth.users set raw_user_meta_data = '{"recruiter_invitation_id":"62000000-0000-0000-0000-000000000003"}' where id = '61000000-0000-0000-0000-000000000005';
update auth.users set email = 'recovery.recruiter@example.test', created_at = now() - interval '1 day' where id = '61000000-0000-0000-0000-000000000005';
set local role authenticated;
select throws_ok($$select public.mark_recruiter_invitation_sent((select id from public.recruiter_invitations where recruiter_id = '62000000-0000-0000-0000-000000000002' and status = 'PREPARED'), '61000000-0000-0000-0000-000000000005', true)$$, '23514', null, 'an unrelated pre-existing Auth user cannot claim the old prepared attempt');
reset role;
update auth.users set created_at = now(), invited_at = null where id = '61000000-0000-0000-0000-000000000005';
set local role authenticated;
select throws_ok($$select public.mark_recruiter_invitation_sent((select id from public.recruiter_invitations where recruiter_id = '62000000-0000-0000-0000-000000000002' and status = 'PREPARED'), '61000000-0000-0000-0000-000000000005', true)$$, '23514', null, 'an Auth user without provider invitation evidence is denied');
reset role;
update auth.users set invited_at = now(), email_confirmed_at = now() where id = '61000000-0000-0000-0000-000000000005';
set local role authenticated;
select throws_ok($$select public.mark_recruiter_invitation_sent((select id from public.recruiter_invitations where recruiter_id = '62000000-0000-0000-0000-000000000002' and status = 'PREPARED'), '61000000-0000-0000-0000-000000000005', true)$$, '23514', null, 'confirmed users with unrecorded bindings are not silently recreated or rebound');
reset role;
update auth.users set email_confirmed_at = null where id = '61000000-0000-0000-0000-000000000005';

set local role authenticated;
select lives_ok($$select public.mark_recruiter_invitation_sent((select id from public.recruiter_invitations where recruiter_id = '62000000-0000-0000-0000-000000000002' and status = 'PREPARED'), '61000000-0000-0000-0000-000000000005', false)$$, 'exact stale metadata recovers the same invited unconfirmed user despite a misleading false flag');
reset role;
select is((select count(*)::integer from public.audit_logs where entity_id in (select id from public.recruiter_invitations where recruiter_id = '62000000-0000-0000-0000-000000000002') and action = 'recruiter.invitation_reissued'), 1, 'reissue audit classification derives from history');
select is((select count(*)::integer from public.audit_logs where entity_id in (select id from public.recruiter_invitations where recruiter_id = '62000000-0000-0000-0000-000000000002') and action = 'recruiter.invitation_issued'), 0, 'false caller flag cannot falsify an issuance audit');
select is((select auth_user_id from public.recruiter_invitations where recruiter_id = '62000000-0000-0000-0000-000000000002' and status = 'SENT'), '61000000-0000-0000-0000-000000000005'::uuid, 'recovery retains the original Auth identity');

set local role authenticated;
select lives_ok($$select public.mark_recruiter_invitation_sent('62000000-0000-0000-0000-000000000006', '61000000-0000-0000-0000-000000000006', true)$$, 'first issuance cannot become reissue merely through a true flag');
reset role;
select is((select action from public.audit_logs where entity_id = '62000000-0000-0000-0000-000000000006'), 'recruiter.invitation_issued', 'initial audit classification ignores the misleading caller flag');

update auth.users set email_confirmed_at = now() where id = '61000000-0000-0000-0000-000000000005';
set local role authenticated;
select set_config('request.jwt.claim.sub', '61000000-0000-0000-0000-000000000005', true);
select lives_ok($$select public.complete_recruiter_invitation()$$, 'recovered confirmed invitation completes binding');
select throws_ok($$select public.complete_recruiter_invitation()$$, '42501', null, 'recovered invitation replay remains denied');
select throws_ok($$select public.mark_recruiter_invitation_sent('62000000-0000-0000-0000-000000000006', '61000000-0000-0000-0000-000000000006', true)$$, '42501', null, 'recruiter cannot finalize another invitation');
reset role;
select is((select user_id from public.recruiters where id = '62000000-0000-0000-0000-000000000002'), '61000000-0000-0000-0000-000000000005'::uuid, 'recovery creates no duplicate or replacement account');
select ok(not has_table_privilege('authenticated', 'public.recruiter_invitations', 'UPDATE'), 'recovery grants no direct authenticated mutations');

select * from finish();
rollback;
