# Testing strategy

## Test layers

Unit-test pure domain logic: eligibility and reason codes, input validation, profile completeness, role/capability checks, state transition table, formatting/sanitization, and date/deadline rules. These tests must cover boundary conditions and invalid input, not just happy paths.

Integration-test real application/database behavior against an isolated non-production Supabase/PostgreSQL setup: authentication/session guards, profile creation and permitted updates, role assignment safeguards, RLS denied and allowed operations, drive lifecycle/eligibility, duplicate application handling, application transitions/history/audit entries, exports, and storage policy/metadata behavior. Apply migrations from a clean database in CI or an equivalent repeatable environment.

E2E-test critical journeys with Playwright or a comparable browser test suite: student register/sign in -> profile -> drive -> eligibility explanation -> apply -> application history; coordinator sign in -> student/drive/applicant work -> permitted status update; TNP Secretary -> company/recruiter/drive -> selection workflow; Super Admin -> role management -> protected operation -> audit view. Include authorization-failure paths: a student must not read another student, a recruiter cannot enumerate students, a coordinator cannot access Super Admin actions, and direct/forged UI requests must be denied.

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
