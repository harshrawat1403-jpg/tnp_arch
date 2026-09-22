# Testing strategy

## Test layers

Unit-test pure domain logic: eligibility and reason codes, input validation, profile completeness, skill proficiency/status transitions, exact-normalization import decisions, role/capability checks, state transition table, formatting/sanitization, and date/deadline rules. These tests must cover boundary conditions and invalid input, not just happy paths.

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
