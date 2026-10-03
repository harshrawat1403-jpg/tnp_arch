# Phase 0 specification freeze

**Status:** complete for Phase 1, with approved Phase 5 student-skills, Phase 6 company/recruiter, and Phase 7 drives/eligibility specification addenda. Phase 7 is specification-approved only; its implementation and verification remain pending. This is the canonical V1 decision record. Later changes require an explicit documented product decision and an update to the affected references.

## Product boundary and visual direction

V1 is one lightweight Training & Placement portal for a single department. It includes public TNP information; controlled accounts; student profile/resume/drive/application workflows; TNP-office management of students, companies, recruiters, drives, applications, announcements, exports, and basic statistics; and a strictly limited recruiter view. It excludes elections, committees, meetings, maintenance, generic events, generic CMS/page builders, unrelated department management, a generic workflow engine, payment, messaging/chat, and a native mobile app.

Public routes are Home, About TNP, placement/internship information, recruiter information, contact information, and Login. They contain no private data and use the approved institutional visual direction: warm off-white surfaces, charcoal/black primary UI, restrained non-blue accents only for meaning, strong typography, generous whitespace, subtle borders, minimal shadows, and the approved black 2D department logo. Gradients, glassmorphism, generic blue-SaaS styling, heavy card grids, decorative motion, and visually heavy components are excluded.

## Accounts, identity, and role hierarchy

There is exactly one active platform role per account. It is mutually exclusive and stored only in protected server/database data.

| Role              | Institutional identity      | V1 provisioning                                                                                          |
| ----------------- | --------------------------- | -------------------------------------------------------------------------------------------------------- |
| `SUPER_ADMIN`     | Technical Secretary         | Exactly one active protected account. It cannot be removed or deactivated without an atomic replacement. |
| `TNP_SECRETARY`   | TNP Secretary               | At most one active account. Assigned/removed only by Super Admin.                                        |
| `TNP_COORDINATOR` | TNP Coordinator 1 or 2      | At most two active accounts, each assigned slot 1 or 2. Assigned/removed only by Super Admin.            |
| `STUDENT`         | Eligible department student | Self-registration only when verified email exactly matches a preloaded student-roster record.            |
| `RECRUITER`       | Authorized employer contact | Invitation only, linked to one company and an expiry.                                                    |

There is no public administrative registration, self-service role conversion, multi-role account, or client-controlled role claim. Initial Super Admin provisioning is a one-time protected operator procedure; every later role change is a transactional, audited Super Admin action. A student/recruiter identity requiring a role change receives a controlled replacement/transition process rather than role stacking.

## Final permission boundaries

| Capability                                   | Student                                                                      | Recruiter                                | TNP Coordinator                                                                     | TNP Secretary                                                       | Super Admin                      |
| -------------------------------------------- | ---------------------------------------------------------------------------- | ---------------------------------------- | ----------------------------------------------------------------------------------- | ------------------------------------------------------------------- | -------------------------------- |
| Own profile/documents                        | Read/edit permitted personal fields; academic fields lock after verification | Read own contact/company projection only | No self-service student data ownership                                              | No                                                                  | No                               |
| Student records                              | Own only                                                                     | None                                     | Search/read; verify profile; may correct only unverified supporting data with audit | Full normal TNP management, including verified-academic corrections | Full                             |
| Companies/recruiters                         | No                                                                           | Read only assigned company/contact       | Read; create/edit own uninvited drafts                                              | Normal lifecycle, invitations, and grants                           | Same, with documented recovery   |
| Drives/eligibility                           | Read published results                                                       | Read explicitly assigned drives          | Create/edit drafts; no publish/archive                                              | Full lifecycle including publish/archive                            | Full                             |
| Applications                                 | Create once, own read, defined self-withdrawal only                          | Assigned per-drive projection only       | Read scoped applicants; shortlist/reject/interview only                             | All normal valid transitions including selection                    | Full plus exceptional correction |
| Announcements                                | Read permitted audience                                                      | Read assigned/public audience            | Draft/edit                                                                          | Publish/archive                                                     | Full                             |
| Exports/basic statistics                     | Own history only                                                             | No export                                | Aggregate dashboard only; no PII export                                             | Scoped operational exports/statistics                               | Full                             |
| Roles, critical config, recovery, full audit | No                                                                           | No                                       | No                                                                                  | No                                                                  | Exclusively Super Admin          |

Coordinators cannot publish/close/archive drives, correct published drives, assign roles, alter critical settings, export PII, select candidates, correct terminal statuses, or access full audit logs. Both coordinators may create/edit any drive in `DRAFT`; this shared drive permission is distinct from their own-uninvited company/contact draft permission and course/batch-scoped student review. Recruiters cannot list students, change application status, export data, access documents by default, or infer activity outside a grant. These controls are enforced by server logic and database/RLS policies; UI hiding is only convenience.

## Data ownership, sensitivity, and lifecycle

| Data                                               | System owner and permitted writes                                                                        | Access/lifecycle                                                                                                                                  |
| -------------------------------------------------- | -------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| Identity/role/roster                               | System; Super Admin role actions only                                                                    | Privileged; never client-provided. Student roster is a protected allowlist, not a public directory.                                               |
| Personal profile, portfolio, profile image, resume | Student writes own permitted values; metadata/storage policy enforce ownership                           | Confidential student data. Resume is private PDF, max 5 MB; profile image optional, normalized/compressed.                                        |
| Skills and skill evidence                          | Controlled catalog is owned by TNP Secretary/Super Admin; students own pending declarations and evidence | `student_skills` is authoritative. Private PDF evidence and HTTPS project URLs are confidential; verified skills are locked to students.          |
| Academic data                                      | Student supplies initial values; verified values are locked                                              | Coordinator verifies; TNP Secretary/Super Admin corrects with mandatory reason and audit. No correction-request workflow in V1.                   |
| Company/recruiter records and invitations          | TNP office owns canonical record; invitation/account binding is system-controlled                        | Recruiter has a read-only assigned projection in V1. Invitation secrets, Auth credentials, and provider errors are never stored in audit/UI data. |
| Drive/eligibility/application/status               | TNP system/office owns operational record                                                                | Student may create one application and use the defined withdrawal only; status history is append-only.                                            |
| Documents/audit logs                               | System owns metadata/audit evidence                                                                      | Private buckets; short-lived authorized document URLs; full audit access only for Super Admin.                                                    |

V1 uses archival rather than ordinary deletion. It has no automated permanent-purge mechanism or in-product retention scheduler. Exact institutionally mandated retention/deletion periods are a pre-production governance requirement and a gate for exports/production launch, not an implementation ambiguity. Replacing a document archives old metadata/object for controlled cleanup; no document is publicly readable.

## Approved Phase 5 extension — normalized student skills

The Phase 4 `student_profiles.skills` text array is a self-declared legacy profile field, not a canonical skills model. Phase 5 will add the authoritative normalized model: a controlled `skills` catalog, one `student_skills` record per student/skill, optional `student_skill_evidence` records, and explicit `coordinator_student_scopes` keyed to roster course and batch. It must not create a second permanent skill system or retain a dual-write path.

Each student skill has a proficiency level and an independent verification lifecycle:

| Level | Meaning                                                         |
| ----- | --------------------------------------------------------------- |
| 1     | Foundation — introductory understanding                         |
| 2     | Working — can use the skill with guidance                       |
| 3     | Applied — demonstrated in coursework or a project               |
| 4     | Advanced — independently demonstrated with substantial evidence |

Skill verification is `PENDING`, `VERIFIED`, or `REJECTED`. Students may create and update only their pending declarations and evidence; correcting a rejected declaration resubmits it as `PENDING` while the prior review remains in audit evidence. A verified student skill is not student-editable. `TNP_COORDINATOR` may verify or reject only pending declarations within an explicitly assigned course/batch scope. `TNP_SECRETARY` and `SUPER_ADMIN` govern the canonical catalog and may make audited correction, revocation, or archival decisions for verified skills. Every catalog, scope, verification, rejection, correction, and revocation action is audited.

Evidence is either an HTTPS project URL or a private PDF represented by `SKILL_EVIDENCE` in the existing document registry/storage pattern. A database-enforced invariant must prove that an evidence document is active, has the required kind, and belongs to the same student as its `student_skill`; a client-provided document ID is never sufficient authority.

The migration may automatically trim and case-normalize an exact legacy label only. It must not infer aliases, synonyms, or semantic equivalence. Ambiguous labels (for example, distinct names that may refer to the same product) require a manual catalog-review decision before any merge. The normalized records become authoritative after cutover; the legacy array is retained only as controlled migration history until an approved deprecation decision.

Verified skills are future advisory matching signals only. They may inform transparent student-to-role/opportunity matching, but never become a placement eligibility gate. Existing deterministic academic eligibility remains the only approved application-gating basis unless a later Phase 0 decision explicitly changes that rule.

## Approved Phase 6 extension — companies and recruiters

`companies`, `recruiters`, `placement_drives`, `recruiter_drive_access`, `profiles`, and `audit_logs` remain the canonical employer, contact, grant, identity, and audit records. Phase 6 adds only the necessary `recruiter_invitations` lifecycle record and narrowly additive revocation metadata for `recruiter_drive_access`; it does not create duplicate company, recruiter, drive, or grant models.

Companies remain internal-only and use their existing active/archive lifecycle; no company `DRAFT` or `PUBLISHED` state is added. A coordinator may read TNP company/contact records and create or edit only records they created, while the company/contact is unarchived and no recruiter invitation has ever been issued for it. Invitation issuance hands normal management to the TNP Secretary or Super Admin. Secretary/Super Admin may create, edit, archive, and reactivate companies and recruiter contacts. Archive is non-destructive, immediately suppresses recruiter access, and blocks new invitations/grants. Reactivation never revives a revoked or expired invitation.

A recruiter contact exists before an account. `recruiter_invitations` records `PREPARED`, `SENT`, `ACCEPTED`, `REVOKED`, or `DELIVERY_FAILED`, an email snapshot, the nullable unique Auth-user binding, issuer/expiry/acceptance/revocation metadata, and timestamps. Supabase Auth's invitation link is the only invitation secret. The system stores no custom verifier, OTP, invitation URL, password, or Admin secret. The Before User Created hook permits recruiter creation only for a matching, unexpired, unrevoked `PREPARED` invitation supplied by the trusted Admin invitation request metadata; ordinary public recruiter signup remains denied.

On accepted Supabase Auth invitation, `complete_recruiter_invitation()` derives `auth.uid()` and confirmed Auth email, verifies the matching `SENT` invitation and its Auth-user ID, atomically creates only a `RECRUITER` profile, binds exactly one `recruiters.user_id`, marks the invitation accepted, and audits it. A consumed invitation cannot replay. Reissue revokes/supersedes the previous unaccepted invitation and uses a Supabase-supported Admin resend path proven by local integration testing; it never deletes or recreates a confirmed Auth user merely to resend.

An active recruiter may read only their own contact, active assigned company, and explicitly granted, unexpired, `PUBLISHED` drive metadata: title, type, location, and deadline. Recruiters cannot enumerate companies/recruiters or access student/profile/skill/evidence/document/resume/application/applicant/audit/export data. `can_view_applicants` and `can_view_resumes` remain inactive and ineffective until a later approved phase. Secretary/Super Admin may grant/revoke access only for existing published drives; revocation preserves history and requires a reason. No Phase 6 operation creates/publishes drives or exposes applicant/resume data.

Every company, contact, invitation, recruiter archive/reactivation, and grant/revocation transition is an audited protected operation. Audit payloads contain only sanitized identifiers and state/reason metadata; they never contain links, tokens, OTPs, signed URLs, passwords, Admin secrets, or raw provider errors.

## Approved Phase 7 extension — drives and eligibility

Phase 7 publishes placement/internship opportunities and displays deterministic, explainable eligibility. Reuse `placement_drives`, `drive_eligible_batches`, `drive_eligibility`, `companies`, and the existing application/audit records. Do not replace these models or implement application workflows in this phase.

### Lifecycle, company archive, and deadlines

Drive lifecycle remains exactly `DRAFT -> PUBLISHED -> CLOSED -> ARCHIVED`. There is no reopening, unarchive, `DRAFT -> ARCHIVED`, or ordinary deletion. `CLOSED` content and criteria are read-only except the `CLOSED -> ARCHIVED` transition; archived content and criteria are immutable. Lifecycle metadata must satisfy `created_at <= published_at <= closed_at <= archived_at` for timestamps required by the current state, with later-state metadata absent until its transition.

A company cannot be archived while it has any `PUBLISHED` drive, including an expired published drive. Staff must explicitly close those drives first. An archive attempt must not automatically change drive lifecycle. Publication requires an active company, a future deadline, exactly one eligibility row, at least one explicit eligible `(course, batch_year)` pair, and valid criteria. Drafts under an archived company remain non-publishable until company reactivation. This company-archive guard is an approved Phase 7 addition to the Phase 6 operation, not a claim that the existing implementation already enforces it.

Use database `timestamptz`. Availability is `status = PUBLISHED AND database_evaluation_time < application_deadline`; equality with the deadline is already not open for future application authorization. Expiry does not mutate lifecycle, requires no cron/scheduler, and leaves an expired `PUBLISHED` drive visible with a deadline-passed state. A published deadline correction uses the protected correction operation with reason, notice, and audit. Before expiry, a replacement deadline must remain in the future; after expiry, deadline extension/reopening is prohibited.

### Eligibility authority and calculation

The only machine criteria are an exact eligible course/batch pair, minimum CGPA, maximum **current active** backlogs, and optional `exclude_previously_selected_placement` (default false). Course/batch come from protected `student_roster.course` and `student_roster.batch_year`; CGPA and backlog count come only from a verified `academic_records` row. Skills, skill verification/evidence, overall `student_profiles.verification_status`, profile completeness, and resume readiness must not influence eligibility. Overall profile verification is not an eligibility prerequisite.

The exclusion flag may be configured on either a `PLACEMENT` or `INTERNSHIP` target drive. It excludes a student only when an application currently has `current_status = SELECTED` and its associated drive is `PLACEMENT`. A selected internship does not count. A later approved audited terminal correction changes the authoritative current state; historical selection events alone do not perpetuate exclusion. There is no global placement lock. “Other requirements” are informational only. Any new machine criterion requires a later explicit decision, structured schema, migration, tests, and an explainable reason code.

Freeze one database-backed calculation shared by student list/detail and future Phase 8 application authorization. Public/student entry points derive identity from `auth.uid()` and never accept a student ID, course, batch, CGPA, backlog count, or evaluation time from the caller. Keep the academic result (`PASS`, `FAIL`, `UNDETERMINED`), availability state, and ordered structured reasons separate. Missing or unverified academic data produces `UNDETERMINED`; do not invent a numerical failure or treat unavailable data as zero. No mutable `is_eligible` is stored. A future application transaction must recompute using this same calculation against protected current state.

| Machine reason code             | Meaning                                                                          |
| ------------------------------- | -------------------------------------------------------------------------------- |
| `ELIGIBLE`                      | Academic criteria pass and the published drive is open, with no blocking reason. |
| `COURSE_NOT_ELIGIBLE`           | No allowed course/batch pair contains the student's protected course.            |
| `BATCH_NOT_ELIGIBLE`            | The course is represented, but the student's exact course/batch pair is absent.  |
| `CGPA_BELOW_MINIMUM`            | Verified CGPA is below the configured minimum.                                   |
| `ACTIVE_BACKLOG_LIMIT_EXCEEDED` | Verified current active backlogs exceed the configured maximum.                  |
| `PREVIOUSLY_SELECTED_PLACEMENT` | The configured exclusion flag finds a currently selected placement application.  |
| `ACADEMIC_DATA_UNAVAILABLE`     | The current academic record is missing.                                          |
| `ACADEMIC_UNVERIFIED`           | The current academic record is not verified.                                     |
| `DEADLINE_PASSED`               | Database evaluation time is at or after the deadline.                            |
| `DRIVE_CRITERIA_UNAVAILABLE`    | Required structured criteria are missing or invalid; authorization fails closed. |

Reason ordering is deterministic: availability, criteria configuration, academic-data readiness, then course, batch, CGPA, backlogs, and prior selection. Return only applicable reasons, suppress comparisons that depend on missing/unverified academic inputs, and emit `ELIGIBLE` only without blockers. Internal authorization may distinguish `DRIVE_NOT_PUBLISHED`, `DRIVE_CLOSED`, and `DRIVE_ARCHIVED`; student detail/RPC responses must use a generic unavailable/not-found outcome for hidden or nonexistent IDs and must not permit hidden-state enumeration. Overall profile verification has no machine reason code.

### Staff mutations, published correction, and metadata

Both TNP Coordinators may create/edit any `DRAFT` drive; there is no per-coordinator drive ownership restriction. They cannot publish, close, archive, or correct published drives. TNP Secretary/Super Admin perform these operations through audited role-checking procedures, with no generic administrative bypass or broad authenticated mutation grants.

Once `PUBLISHED`, every permitted content/criteria change uses one protected published-correction operation. There is no subjective normal-edit versus material-edit exception. It requires Secretary/Super Admin authority, an internal reason, a student-facing change notice, a stale revision check, atomic mutation, revision increment, and sanitized before/after audit. `company_id` and `drive_type` are immutable after publication. A notice cannot be cleared by unrelated actions. Published corrections emit `drive.updated` with a published/material classification; eligibility changes additionally emit `drive.eligibility_updated`.

Approved additive drive metadata is `revision integer NOT NULL DEFAULT 1`, `last_material_change_notice text NULL`, and `last_material_change_at timestamptz NULL`. Notice/time must be present together; notice and mandatory correction reason are bounded to 1–2000 trimmed characters. Revision increments on every successful content/criteria mutation. Audit logs retain historical changes; the drive stores only the latest student-facing notice/time. Lifecycle/publish/correction integrity is database-enforced where appropriate.

Required events are `drive.created`, `drive.updated`, `drive.published`, `drive.closed`, `drive.archived`, and `drive.eligibility_updated`. Audit payloads contain sanitized drive/criteria before/after values and reasons, never student academic values, secrets, signed URLs, recruiter invitation data, or raw provider errors. Full audit access remains Super Admin-only.

### Read projections, performance, and phase boundary

Use narrow role-checking database projections/RPCs for student list/detail and richer staff reads; do not broaden shared `authenticated` base-table column grants to obtain descriptions, compensation, criteria, or internal metadata. Preserve Phase 6 recruiter grant behavior and its published metadata projection exactly; recruiters receive no eligibility results or student lists and applicant/resume flags remain ineffective.

Student detail may expose company name, title, type, location, deadline, description, `package_lpa`, `stipend_monthly`, `compensation_details`, structured criteria, informational requirements, caller eligibility/reasons, and latest change notice/time. It must not expose recruiter contacts, applicants/counts, audit metadata, internal notes, or other-student data. `/student/drives` and `/student/drives/[driveId]` are display-only Phase 7 surfaces, with no Apply action.

Student listing uses page size 20, SQL-side filtering, one-row lookahead, deterministic `(application_deadline ASC, id ASC)` ordering, and one bounded database call for the page plus eligibility, without N+1 queries. If an eligibility filter is exposed, it runs before pagination. Index additions require query-shape/`EXPLAIN` evidence. Staff lists are also SQL-paginated with URL-driven filters and deterministic ordering.

Phase 7 excludes application creation/withdrawal, applicant lists, shortlist/interview/select/reject operations, application-history UI, applicant resume sharing, matching/ranking, career roles, notifications, exports, analytics, alumni, and announcements. Application tables may be read internally only for the approved prior-selected-placement check; they acquire no public workflow grants in Phase 7.

## Applications — Phase 8 boundary

Applications are accepted in Phase 8 only while `PUBLISHED`, before deadline, and when the same authoritative eligibility calculation succeeds. The following frozen V1 application policy is not Phase 7 implementation scope.

| Current state                       | Normal next state         | Authorized actor                                                         |
| ----------------------------------- | ------------------------- | ------------------------------------------------------------------------ |
| `APPLIED`                           | `SHORTLISTED`, `REJECTED` | Coordinator, Secretary, Super Admin                                      |
| `APPLIED`                           | `WITHDRAWN`               | Student only before deadline; Secretary/Super Admin with recorded reason |
| `SHORTLISTED`                       | `INTERVIEW`, `REJECTED`   | Coordinator, Secretary, Super Admin                                      |
| `INTERVIEW`                         | `SELECTED`, `REJECTED`    | Secretary, Super Admin                                                   |
| `SELECTED`, `REJECTED`, `WITHDRAWN` | none                      | Terminal                                                                 |

Students cannot withdraw after shortlisting or deadline. A withdrawn application cannot be re-applied in V1. Terminal correction is not a normal transition: only Super Admin may invoke a separate audited correction that restores the immediately preceding non-terminal state, records mandatory reason plus old/new state in immutable history, and never deletes prior evidence.

## Required journeys and acceptance criteria

These are eventual V1 journeys, not permission to implement later phases. Phase 7 acceptance is display-only student discovery plus bounded staff drive operations under its approved addendum; application submission/withdrawal/history and other later-phase journeys remain deferred.

| Journey                       | V1 acceptance criteria                                                                                                                                                                                             |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Public visitor                | Can reach each public route quickly without authentication or private data; approved logo and visual direction are used; keyboard/mobile navigation works.                                                         |
| Student onboarding/profile    | A roster-matched, verified-email student becomes only `STUDENT`, completes required data, sees missing fields, uploads a private valid PDF, and cannot edit verified academic fields.                              |
| Student skills                | A student selects controlled skills, records level 1–4 and permitted evidence, cannot self-verify or alter a verified skill, and receives a clear rejected/pending state.                                          |
| Student discovery/application | Student sees published drives with deterministic eligibility/reason codes; one atomic application succeeds only when eligible/open; duplicate/expired/ineligible requests fail safely; history is private.         |
| Student withdrawal            | Only an `APPLIED` application before deadline can be self-withdrawn; repeat/reapply and post-shortlist withdrawal are denied clearly.                                                                              |
| Coordinator                   | Coordinator can perform only matrix operations; student-skill review is limited to assigned course/batch scope; direct publish/select/export/full-audit/role attempts fail, not merely hide controls.              |
| Secretary                     | Secretary manages normal company, recruiter, drive, application, announcement, export, and selection work; role/recovery/full-audit attempts are denied.                                                           |
| Super Admin                   | Role action prevents loss of last Super Admin and coordinator-slot overflow; it is atomic/audited. Terminal correction requires reason and preserves history.                                                      |
| Recruiter                     | An invited recruiter can complete a one-time account binding and sees only own contact, assigned company, and granted published-drive metadata; no applicant/resume projection, exports, or unrelated enumeration. |

## Quality, performance, cost, and Phase 1 entry

Public pages are static/revalidated Server Component routes by default. Authenticated work is server-rendered/dynamic with minimal client islands. No client-side all-record fetch, N+1 hot path, heavy animation/chart/component library, generic global state framework, decorative video, or external paid dependency is allowed without approved need. Images are optimized; fonts are limited; tables filter/sort/paginate in PostgreSQL and use small-screen detail/card patterns.

Targets are Lighthouse Performance 90+ on representative routes, LCP preferably under 2 seconds, CLS below 0.1, and INP below 200 ms where practical. All key screens cover loading, success, empty, validation, permission-denied, network/server, and unexpected-error states.

The free-tier-first stack is Next.js/TypeScript, Supabase PostgreSQL/Auth/Storage, Vercel, and GitHub. No VPS, Redis, microservices, external database, paid queue, paid monitoring, or paid CMS. Provider quotas are not hard-coded: storage/egress, database growth, auth volume, bandwidth/build limits, and uploads are checked against current official documentation before capacity-sensitive releases. The custom domain is the only expected initial recurring cost.

Phase 1 may begin: scope, roles, ownership, provisioning, operational rules, acceptance criteria, visual direction, performance targets, and free-tier constraints are finalized. It remains limited to repository foundation (Next.js/TypeScript setup, local-only environment example/validation, CI/build/lint/typecheck foundation, base layout conventions). It must not initialize Supabase/Vercel, use production secrets, add application features, or start schema work.
