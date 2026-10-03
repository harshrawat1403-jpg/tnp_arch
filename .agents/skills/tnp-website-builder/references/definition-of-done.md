# Definition of done

## Feature completion checklist

A feature is complete only when applicable items are evidenced, not merely asserted:

- Requirement and scope are implemented without unrelated expansion.
- Data model, constraints, indexes, migration, and compatibility are correct when data changes.
- Server/database authorization, RLS, storage policy, and least privilege are correct when access changes.
- Client and server validation, atomicity/idempotency, state transitions, and audit events are correct where relevant.
- Loading, success, empty, validation, permission-denied, network/server, and unexpected-error states are deliberate.
- Mobile/tablet/desktop behavior, keyboard flow, semantic/accessibility basics, and privacy presentation are reviewed.
- Focused unit/integration/E2E tests are added or updated and pass; authorization failure paths are tested for protected work.
- Typecheck, lint, production build, and the appropriate migration/RLS/storage verification pass.
- Existing behavior is regression-checked; no obvious security or material performance regression remains.
- Documentation/decision log is updated when architecture, schema, roles, operational process, or a product rule changes.

For normalized skills specifically, completion also requires evidence that the legacy-array cutover is one-way and exact-normalization-only, ambiguity has a manual-review record, coordinator review is course/batch scoped, verified skills are student-immutable, and cross-owner evidence-document references fail at the database boundary. Advisory matching must be demonstrated as non-gating: it cannot alter drive eligibility or application authorization.

For Phase 6 specifically, completion requires a clean local migration/RLS rehearsal; a locally proven Supabase Admin invitation/reissue integration; confirmed-email, one-to-one recruiter-account binding; replay/expiry/revocation/archive denial evidence; default-deny direct REST/RLS tests; sanitized audit assertions; and recruiter proof that only own active contact/company plus granted unexpired published-drive metadata is available. It also requires evidence that applicant/resume flags remain ineffective, no browser receives an Admin secret, grant revocation preserves history, staff/recruiter pages use bounded deterministic pagination, and no Phase 7+ drive/application functionality was introduced.

## Phase 7 specification and implementation gates

Specification finalization is a documentation-only gate: the 13 affected references agree with the canonical approved Phase 7 decisions, pass scoped formatting/diff/conflict checks, and introduce no application code, migrations, routes, actions, UI, test files, or README changes. It does not mark Phase 7 implemented, verified, deployed, or authorize Phase 8. Checkpointing requires a separate user request.

Phase 7 implementation is complete only with evidence of all of the following:

- Reused drive/cohort/eligibility tables and additive revision/latest-notice metadata; state-appropriate chronological invariants, exact lifecycle, read-only closed/archived content, and database-protected publication/company-archive checks, including concurrent execution.
- One authoritative database eligibility calculation for caller-derived student list/detail and future application authorization; protected roster plus verified academics only, independent of overall profile/completeness/skills/evidence, exact course/batch pairing, current selected-placement semantics, and deterministic separate academic/availability/reason outputs.
- Both coordinators can edit any draft but cannot perform privileged lifecycle/correction actions. Secretary/Super Admin operations are role-checked, atomic, audited, stale-revision-safe, and every published content/criteria change requires reason plus notice. Company/type cannot change after publication; notice/time are bounded/paired and survive unrelated actions.
- Exact-deadline denial, visible expired published drives, no expiry scheduler, future-only replacement before expiry, and no extension/reopening after expiry.
- Narrow student/staff projections with no broadened authenticated base-table column/mutation grants, no hidden-state enumeration or other-student data, unchanged Phase 6 recruiter metadata/grants, and no private-data leakage.
- URL-driven SQL paging of 20 records plus one lookahead, deterministic deadline/ID order, filtering before pagination, and one bounded page-plus-eligibility call without N+1; indexes justified by query/plan evidence.
- The complete Phase 7 coverage in `testing.md`, successful final local DB verification with exact assertion count, unit tests, typecheck, lint, build/start, affected-file formatting, authenticated mobile/keyboard smoke, security review, and prior-phase regressions. Report the known unrelated CRLF baseline separately rather than changing it.
- Display-only student routes and bounded staff operations, with no application creation/withdrawal, applicant/status/history/resume workflows, matching/ranking, career roles, notifications, exports/analytics, alumni, or announcements.

A missing or blocked implementation verification item remains an exit blocker; specification approval alone does not satisfy this checklist.

## Evidence standard

Report exact commands/checks and their outcome, migration environment, representative manual checks, and known limitations. “Not run” is acceptable only when stated with the reason and remaining risk; it is not evidence of completion. A skipped release gate means the feature is incomplete for that environment, even if the code is ready for further development.

## Phase and launch completion

Do not close a roadmap phase until its listed exit criteria and relevant feature checklist are satisfied. Production readiness additionally requires a clean dependency install; tested staging migration path; environment/secret review; unit, integration, and critical E2E evidence; production build; authorization/RLS review; mobile and performance checks; health check; rollback/recovery consideration; and a named launch owner. Only the Technical Secretary (Super Admin authority) should approve protected production/recovery operations under the defined governance model.

## Stop conditions

Stop and surface a decision instead of guessing when a request would change role authority, exposes more recruiter/student data, weakens RLS, alters retention, applies a destructive migration, touches production secrets/data, or contradicts a documented policy. For ordinary implementation blockers, diagnose the root cause with focused evidence before choosing a repair.
