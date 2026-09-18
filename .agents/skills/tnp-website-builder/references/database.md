# Database and migration design

## Recommended normalized model

Use UUID primary keys (normally matching `auth.users.id` for person-owned records), `created_at`, `updated_at`, and `created_by`/`updated_by` where change ownership matters. Use `timestamptz` in UTC, `numeric` for CGPA/package values where calculation/precision matters, controlled enums/checks for lifecycle fields, and `text` only for genuinely open content.

| Table                        | Purpose and key rules                                                                                                                                                                         |
| ---------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `profiles`                   | One row per authenticated user; name, email snapshot if needed, active flag, and exactly one protected role; unique `user_id`. A coordinator role carries unique slot 1 or 2.                 |
| `student_roster`             | Protected allowlist for pre-provisioned student identity, institutional email, course/batch, and active status; unique normalized email and student identifier. It is not a public directory. |
| `student_profiles`           | Student-specific personal/contact/course/batch/skills/portfolio/completeness/verification fields; unique `user_id`; verification metadata.                                                    |
| `academic_records`           | Current academic facts plus optional approved history; unique student + academic period/program as appropriate; validated CGPA/backlog ranges.                                                |
| `companies`                  | Company identity, normalized display name, active/archive state; unique normalized name.                                                                                                      |
| `recruiters`                 | Contact belongs to exactly one company; user link optional until invitation accepted; unique company + normalized email.                                                                      |
| `placement_drives`           | Company, position, type (`PLACEMENT`/`INTERNSHIP`), description, compensation/stipend, location, deadline, lifecycle, creator/archive data.                                                   |
| `drive_eligible_batches`     | Join table, unique drive + batch/course; avoids array-only filtering.                                                                                                                         |
| `drive_eligibility`          | One row per drive: min CGPA, allowed current-active backlog count, and `exclude_previously_selected_placement`; checks on ranges. Other text is informational, not a hidden eligibility gate. |
| `applications`               | One student and one drive, current status, submitted/withdrawn timestamps; `UNIQUE(student_id, drive_id)`.                                                                                    |
| `application_status_history` | Append-only status transitions: application, from/to status, actor, reason/note, timestamp; transition check/function enforces validity.                                                      |
| `documents`                  | Owner, type, private storage bucket/object key, validated metadata, version/archive state; never public URL as authority.                                                                     |
| `announcements`              | Published/archived TNP notices, audience and schedule fields, author.                                                                                                                         |
| `audit_logs`                 | Append-only actor/action/target/type/timestamp/sanitized before-after metadata/correlation ID.                                                                                                |

Use a configurable `settings` table only for a short allowlist of genuinely global values, with Super Admin-only mutation and audited access; do not make it a generic configuration dumping ground. Recruiter drive grants, if required, should be a join table (`recruiter_drive_access`) with expiration and least-privilege fields.

## Integrity and query rules

- Foreign keys use restrictive behavior for important records. Archive/disable referenced entities instead of deleting them.
- Check drive deadline, compensation ranges, CGPA/backlog ranges, document type/size metadata, and status/lifecycle values. Validate inputs before the database too, but constraints remain authoritative.
- Index all foreign keys used in joins, `applications(drive_id, status)`, `applications(student_id, created_at desc)`, active/published drive deadlines, student course/batch/verification filters, recruiter company scope, and audit target/time queries. Use partial indexes only after measuring a common filtered predicate.
- Use keyset or bounded offset pagination with deterministic ordering for large admin lists. Filter/sort in SQL; select only required columns; inspect query plans for hot paths.
- Never duplicate “eligible” as mutable application truth. Store eligibility outcome/reason snapshot at submission only if needed for audit, alongside criteria version; recompute for authorization.

## Critical transactions

Application creation locks or safely evaluates the drive, confirms it is published/open, locks or reads the necessary verified student state consistently, calculates eligibility, inserts the unique application and initial history, and writes an audit entry in one transaction. A unique-constraint conflict maps to a clear “already applied” response.

Status transition verifies actor capability/scope, locks the application, validates the transition from its current state, updates current status, inserts history, and audits in one transaction. Role changes and irreversible/archive-sensitive operations follow the same pattern.

## Migration policy

Every schema, RLS, trigger, function, index, or storage-policy change is a version-controlled migration. Inspect generated SQL, test it against a disposable/local database and representative data, then apply through the environment-specific pipeline. Prefer additive/backward-compatible releases: add nullable/new fields, deploy compatible code, backfill safely, enforce constraints later, and remove old paths only after verification. Destructive changes require approved scope, tested backup/restore, impact inventory, a rollback/recovery plan, and a maintenance decision. Never use reset or destructive commands against staging/production casually. Record migration/application ordering whenever old and new app versions cannot coexist.

## Phase 2 baseline implementation

`supabase/migrations/20260917000000_initial_tnp_schema.sql` is the baseline. It creates the approved entities: protected account profiles; student roster/profile/current academic record; companies/recruiters and per-drive recruiter grants; drives, eligible batches, and deterministic criteria; applications/history; document metadata; announcements; and audit logs. The complete field-level source of truth is the migration; this summary is the operating map for future maintainers.

`profiles` has exactly one role enum value per account. A deferred PostgreSQL constraint trigger requires exactly one active `SUPER_ADMIN`; partial unique indexes limit the active TNP Secretary to one and the coordinator slots to one holder each for slots 1 and 2. The initial Super Admin must be inserted through the protected Phase 3 bootstrap process. The schema deliberately has no role-assignment UI or RLS yet.

`student_roster` is the pre-auth institutional-email allowlist. `student_profiles` consumes at most one roster entry, while `academic_records` is one current record per student and has a `PENDING`/`VERIFIED` status plus verifier metadata. This allows Phase 3 RLS to let a student edit only pending academic data while audited office corrections remain possible. Profile completeness and eligibility are derived rather than stored.

`drive_eligible_batches` and `drive_eligibility` are the only eligibility tables: course/batch, minimum CGPA, maximum current active backlogs, and the optional prior-placement-selection flag. Informational requirements are text only and cannot silently become a gating rule. `applications` has `UNIQUE(student_id, drive_id)`, a student-matching submitter, terminal-state metadata, and restrictive references. Its insert trigger atomically creates the initial `APPLIED` history/audit records; history and audit rows are append-only. The narrow `transition_application_status` function enforces the frozen transition graph, preserves history, creates an audit record, and requires a reason for terminal correction, but intentionally does **not** authorize the actor; Phase 3 must add role/scope checks before it is exposed.

Non-obvious indexes are documented on the schema itself: course/batch drive lookup, published drive deadline, applicant queue status, audience announcement feed, and targeted audit investigation. The local workflow is `schema change -> migration -> local db reset -> lint -> pgTAP -> staging later -> production later`; only `--local` reset is allowed in this repository workflow.

## Phase 3 access foundation

`20260918000000_auth_rbac_foundation.sql` is additive and does not rewrite the baseline. It enables RLS on all application tables, revokes table/sequence/function access from `anon` and `authenticated` by default, and sets matching default privileges for future public-schema objects. This preserves a default-deny boundary even if a later table is accidentally exposed through the Data API.

Only active users can select their own `profiles` row. A verified `SUPER_ADMIN` can read protected role records and append-only audit evidence; every other current role is limited to self-profile resolution. No authenticated role can directly write application tables, invoke the application transition function, or access future-domain data before that domain's approved phase. `private.has_active_role` is a pinned-search-path security-definer helper used only for policy evaluation and derives role membership from `auth.uid()`.
