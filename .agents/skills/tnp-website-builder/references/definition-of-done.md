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

## Evidence standard

Report exact commands/checks and their outcome, migration environment, representative manual checks, and known limitations. “Not run” is acceptable only when stated with the reason and remaining risk; it is not evidence of completion. A skipped release gate means the feature is incomplete for that environment, even if the code is ready for further development.

## Phase and launch completion

Do not close a roadmap phase until its listed exit criteria and relevant feature checklist are satisfied. Production readiness additionally requires a clean dependency install; tested staging migration path; environment/secret review; unit, integration, and critical E2E evidence; production build; authorization/RLS review; mobile and performance checks; health check; rollback/recovery consideration; and a named launch owner. Only the Technical Secretary (Super Admin authority) should approve protected production/recovery operations under the defined governance model.

## Stop conditions

Stop and surface a decision instead of guessing when a request would change role authority, exposes more recruiter/student data, weakens RLS, alters retention, applies a destructive migration, touches production secrets/data, or contradicts a documented policy. For ordinary implementation blockers, diagnose the root cause with focused evidence before choosing a repair.
