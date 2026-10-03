# Testing strategy

## Test layers

Unit-test pure input validation and presentation: structured eligibility reason rendering, profile completeness, skill proficiency/status transitions, exact-normalization import decisions, role/capability checks, state transition table, formatting/sanitization, pagination, and date/deadline display rules. These tests must cover boundary conditions and invalid input, not just happy paths. Phase 7 numerical eligibility is tested against the one authoritative database calculation, not reimplemented as a competing TypeScript engine.

Integration-test real application/database behavior against an isolated non-production Supabase/PostgreSQL setup: authentication/session guards, profile creation and permitted updates, role assignment safeguards, RLS denied and allowed operations, exact legacy-skill import, skill uniqueness/proficiency/status integrity, coordinator course/batch scope, evidence-document ownership, drive lifecycle/eligibility, duplicate application handling, application transitions/history/audit entries, exports, and storage policy/metadata behavior. Apply migrations from a clean database in CI or an equivalent repeatable environment.

E2E-test critical journeys with Playwright or a comparable browser test suite: student register/sign in -> profile -> pending skill/evidence -> review status; coordinator sign in -> assigned student-skill queue -> permitted verification/rejection; student -> drive -> eligibility explanation -> apply -> application history; TNP Secretary -> company/recruiter/drive -> selection workflow; Super Admin -> role management -> protected operation -> audit view. Include authorization-failure paths: a student must not read another student, edit a verified skill, self-verify, or attach another student's evidence; a recruiter cannot enumerate students or evidence; a coordinator cannot review an out-of-scope course/batch or access Super Admin actions; and direct/forged UI requests must be denied.

## Test data and isolation

Seed deterministic, minimum realistic fixtures: each role, two students with contrasting eligibility, multiple batches, open/closed drives, a recruiter with and without a grant, and terminal/in-progress applications. Never use production PII in test data. Use separate test storage prefixes/buckets and delete only an explicitly created isolated test namespace. Ensure tests do not require destructive access to shared staging/production environments.

## Required checks by change type

| Change                        | Minimum evidence                                                                                                        |
| ----------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| Pure UI/copy                  | Typecheck, lint, production build, responsive/keyboard review of affected screen.                                       |
| Domain logic                  | Above plus focused unit tests and relevant integration/E2E scenario.                                                    |
| Schema/migration/RLS/storage  | Migration from clean DB, constraints/indexes/RLS allowed+denied tests, rollback/recovery assessment, focused app tests. |
| Auth/roles/critical operation | Above plus adversarial authorization tests, audit assertion, and protected server/database boundary review.             |
| Release candidate             | Full appropriate unit/integration/E2E suite, build, migration verification, key mobile/performance checks.              |

Tests should assert behavior and protection boundaries, not merely implementation details. A known failure is documented with scope and owner; it is not silently treated as passing. If a test cannot run locally, report the exact blocker and use the strongest safe alternative evidence.

## Phase 5 required coverage

The normalized-skills release must prove all of the following against a clean database and representative legacy values:

- exact trim/case-normalized labels import deterministically; aliases/synonyms are not automatically merged and appear in the manual-review evidence;
- one student cannot hold duplicate canonical skill records; only levels 1–4 and valid `PENDING`/`VERIFIED`/`REJECTED` metadata combinations persist;
- a student can create/update only their own pending records, can correct and resubmit a rejected record as pending, cannot set reviewer fields, and cannot edit a verified record;
- a coordinator can review only students matching an assigned `coordinator_student_scopes` course/batch, while TNP Secretary/Super Admin catalog and correction boundaries are proven;
- a document reference from another owner, an archived document, or a non-`SKILL_EVIDENCE` document is rejected at the database boundary;
- private evidence storage allow/deny and signed-download behavior are covered, including recruiter denial;
- every privileged catalog, scope, verification, rejection, correction, and revocation operation has an audit assertion;
- no skill-derived query changes deterministic drive eligibility or application authorization.

## Phase 6 required coverage

Against a clean local Supabase database and isolated test identities, prove duplicate normalized company names and recruiter emails fail; invitation expiry, replay, revocation, invalid metadata, and email mismatch fail; a recruiter role cannot be forged; and exactly one confirmed Auth identity binds to exactly one recruiter contact.

Exercise a locally supported Supabase Admin invitation/reissue path rather than assuming repeated-invite behavior. Cover a `PREPARED` -> `SENT` -> `ACCEPTED` journey, delivery failure handling, revocation, expired invitation reissue, and the rule that a confirmed Auth user is never deleted/recreated merely to resend. Assert sanitized audit events for every company/contact/invitation/archive/grant transition.

RLS/direct REST tests must prove coordinator own-draft allowance and non-owned/invited denial; Secretary/Super Admin normal lifecycle allowance; recruiter own contact/company/granted published-drive projection only; recruiter company/contact enumeration denial; archived recruiter/company denial; grant expiry/revocation denial; and denial of student, profile, skill, evidence, document, resume, application, applicant, audit, and export access. Test that applicant/resume grant flags remain ineffective. Include server-rendered mobile/keyboard smoke journeys for the staff list/detail and recruiter self-view.

## Phase 7 required coverage

These are future implementation exit checks; documentation finalization does not execute or satisfy them. Rehearse additive migrations on a clean local stack and inspect existing-data compatibility without resetting shared/production data.

- Prove both coordinators can create/edit either coordinator's draft, but neither can publish, close, archive, or correct published content. Prove Secretary/Super Admin allowances and student/recruiter mutation denials through procedures and direct REST, not merely hidden controls.
- Prove exact lifecycle transitions, no reopening/unarchive/draft archive/delete, state-appropriate timestamp chronology, read-only closed content/criteria, and terminal archived content/criteria immutability. Publication must fail atomically for archived companies, non-future deadlines, absent/invalid eligibility rows, or absent explicit eligible pairs.
- Prove company archive refuses every published drive, including an expired one, preserves drive state on failure, and succeeds only after all published drives are explicitly closed. Exercise concurrent publication/archive to prove the database invariant. Update the existing Phase 6 archive fixtures during implementation to close published drives first while preserving recruiter archive/revocation/expiry/grant regressions.
- Compare list/detail against the same database calculation. Test exact course/batch pairs (including two allowed pairs whose cross-combination is forbidden), CGPA/backlog limits at/below/above boundaries, existing non-null threshold defaults/ranges, and criteria-unavailable behavior. Missing/unverified academic records must produce `UNDETERMINED`, with no invented numeric failure. A pending/unverified overall profile with verified academics remains evaluable; phone/resume/completeness and added/removed/verified/unverified skills/evidence must not change eligibility.
- Test prior-placement exclusion disabled by default and enabled on both placement and internship target drives. Only current `SELECTED` applications on placement drives count; selected internships and historical-but-corrected selections do not. Use isolated fixtures/the already protected terminal-correction path without adding application workflows.
- Test before/exactly-at/after deadline against database time: exact deadline is not open, expired published drives remain visible, expiry never transitions lifecycle, and no cron is required. Before expiry, replacement deadlines must be future; after expiry, extension/reopening fails. Distinguish academic `PASS`/`FAIL`/`UNDETERMINED` from availability and verify the canonical ordered machine reasons, with hidden/nonexistent drive IDs producing identical generic student denial.
- Execute every published content/criteria correction, including a description-only typo and deadline change, through the same protected operation. Missing/blank/overlong reason or notice, forged role, immutable company/type changes, and stale revisions fail atomically. Successful mutations increment revision and write sanitized before/after audits; notice/time are paired, the latest notice is displayed, and unrelated actions preserve it. Assert all six lifecycle/content event classes and criteria-specific `drive.eligibility_updated` without student academic values or secret/provider data.
- Prove student projections expose only the approved own-result/published-detail fields and cannot disclose contacts, applicants/counts, audit/internal metadata, or other students. Test recruiter direct column-select and RPC denial for new description/compensation/criteria/notice fields; existing explicitly granted metadata remains unchanged. Reject caller-supplied student identity, roster/academic values, and evaluation time.
- Seed more than 20 drives, including tied deadlines, and verify SQL filtering precedes paging, deterministic `(application_deadline ASC, id ASC)` ordering, distinct adjacent pages, one-row lookahead, Previous/Next links, empty/out-of-range pages, and safe invalid/negative/extreme parameter handling. Inspect the query shape/`EXPLAIN` and prove one bounded page-plus-eligibility DB call with no per-row eligibility requests; an eligibility filter, if offered, operates before pagination.
- Run authenticated route/render/mobile/keyboard journeys for student list/detail and staff draft/publish/correct/close/archive. Confirm eligibility reasons and change notices are readable without color, expired-state feedback is clear, and no Apply/withdraw/applicant/history/resume-sharing control or other Phase 8 surface is present. Re-run existing student, skill, private-storage, invitation, password/recovery, and recruiter grants tests.

Implementation verification includes the full local DB verify command reaching exit 0, exact executed pgTAP counts, typecheck, lint, unit tests, production build/start, affected-file Prettier, diff/conflict checks, and security/scope review. Document the unrelated repository-wide CRLF baseline separately; do not rewrite it. A blocked database, authorization test, or critical smoke journey prevents Phase 7 implementation completion.
