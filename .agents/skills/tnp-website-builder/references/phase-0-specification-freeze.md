# Phase 0 specification freeze

**Status:** complete for Phase 1, with an approved Phase 5 student-skills specification addendum. This is the canonical V1 decision record. Later changes require an explicit documented product decision and an update to the affected references.

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
| Companies/recruiters                         | No                                                                           | Read only assigned company/contact       | Read; create/edit drafts                                                            | Create/edit/publish/archive                                         | Full                             |
| Drives/eligibility                           | Read published results                                                       | Read explicitly assigned drives          | Create/edit drafts; no publish/archive                                              | Full lifecycle including publish/archive                            | Full                             |
| Applications                                 | Create once, own read, defined self-withdrawal only                          | Assigned per-drive projection only       | Read scoped applicants; shortlist/reject/interview only                             | All normal valid transitions including selection                    | Full plus exceptional correction |
| Announcements                                | Read permitted audience                                                      | Read assigned/public audience            | Draft/edit                                                                          | Publish/archive                                                     | Full                             |
| Exports/basic statistics                     | Own history only                                                             | No export                                | Aggregate dashboard only; no PII export                                             | Scoped operational exports/statistics                               | Full                             |
| Roles, critical config, recovery, full audit | No                                                                           | No                                       | No                                                                                  | No                                                                  | Exclusively Super Admin          |

Coordinators cannot publish/archive drives, assign roles, alter critical settings, export PII, select candidates, correct terminal statuses, or access full audit logs. Recruiters cannot list students, change application status, export data, access documents by default, or infer activity outside a grant. These controls are enforced by server logic and database/RLS policies; UI hiding is only convenience.

## Data ownership, sensitivity, and lifecycle

| Data                                               | System owner and permitted writes                                                                        | Access/lifecycle                                                                                                                         |
| -------------------------------------------------- | -------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| Identity/role/roster                               | System; Super Admin role actions only                                                                    | Privileged; never client-provided. Student roster is a protected allowlist, not a public directory.                                      |
| Personal profile, portfolio, profile image, resume | Student writes own permitted values; metadata/storage policy enforce ownership                           | Confidential student data. Resume is private PDF, max 5 MB; profile image optional, normalized/compressed.                               |
| Skills and skill evidence                          | Controlled catalog is owned by TNP Secretary/Super Admin; students own pending declarations and evidence | `student_skills` is authoritative. Private PDF evidence and HTTPS project URLs are confidential; verified skills are locked to students. |
| Academic data                                      | Student supplies initial values; verified values are locked                                              | Coordinator verifies; TNP Secretary/Super Admin corrects with mandatory reason and audit. No correction-request workflow in V1.          |
| Company/recruiter records                          | TNP office owns canonical record                                                                         | Recruiter has a read-only assigned projection in V1.                                                                                     |
| Drive/eligibility/application/status               | TNP system/office owns operational record                                                                | Student may create one application and use the defined withdrawal only; status history is append-only.                                   |
| Documents/audit logs                               | System owns metadata/audit evidence                                                                      | Private buckets; short-lived authorized document URLs; full audit access only for Super Admin.                                           |

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

## Drives, eligibility, and applications

Drive lifecycle is `DRAFT -> PUBLISHED -> CLOSED -> ARCHIVED`; `ARCHIVED` is terminal. A published drive can be closed; any material published eligibility change is a TNP Secretary action with audit evidence and a clear student-facing impact notice. Applications are accepted only while `PUBLISHED`, before deadline, and when deterministic eligibility succeeds.

Machine-enforced eligibility fields are eligible course/batch, minimum CGPA, maximum **current active** backlogs, and optional `exclude_previously_selected_placement`. It defaults to false; when true, a student with a prior `SELECTED` placement application is ineligible. There is no global automatic placement lock. “Other requirements” are visible informational terms only in V1, not hidden discretionary gates. A new eligibility criterion must be structured, explainable, migration-backed, tested, and approved before becoming gating logic.

| Current state                       | Normal next state         | Authorized actor                                                         |
| ----------------------------------- | ------------------------- | ------------------------------------------------------------------------ |
| `APPLIED`                           | `SHORTLISTED`, `REJECTED` | Coordinator, Secretary, Super Admin                                      |
| `APPLIED`                           | `WITHDRAWN`               | Student only before deadline; Secretary/Super Admin with recorded reason |
| `SHORTLISTED`                       | `INTERVIEW`, `REJECTED`   | Coordinator, Secretary, Super Admin                                      |
| `INTERVIEW`                         | `SELECTED`, `REJECTED`    | Secretary, Super Admin                                                   |
| `SELECTED`, `REJECTED`, `WITHDRAWN` | none                      | Terminal                                                                 |

Students cannot withdraw after shortlisting or deadline. A withdrawn application cannot be re-applied in V1. Terminal correction is not a normal transition: only Super Admin may invoke a separate audited correction that restores the immediately preceding non-terminal state, records mandatory reason plus old/new state in immutable history, and never deletes prior evidence.

## Required journeys and acceptance criteria

| Journey                       | V1 acceptance criteria                                                                                                                                                                                     |
| ----------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Public visitor                | Can reach each public route quickly without authentication or private data; approved logo and visual direction are used; keyboard/mobile navigation works.                                                 |
| Student onboarding/profile    | A roster-matched, verified-email student becomes only `STUDENT`, completes required data, sees missing fields, uploads a private valid PDF, and cannot edit verified academic fields.                      |
| Student skills                | A student selects controlled skills, records level 1–4 and permitted evidence, cannot self-verify or alter a verified skill, and receives a clear rejected/pending state.                                  |
| Student discovery/application | Student sees published drives with deterministic eligibility/reason codes; one atomic application succeeds only when eligible/open; duplicate/expired/ineligible requests fail safely; history is private. |
| Student withdrawal            | Only an `APPLIED` application before deadline can be self-withdrawn; repeat/reapply and post-shortlist withdrawal are denied clearly.                                                                      |
| Coordinator                   | Coordinator can perform only matrix operations; student-skill review is limited to assigned course/batch scope; direct publish/select/export/full-audit/role attempts fail, not merely hide controls.      |
| Secretary                     | Secretary manages normal company, recruiter, drive, application, announcement, export, and selection work; role/recovery/full-audit attempts are denied.                                                   |
| Super Admin                   | Role action prevents loss of last Super Admin and coordinator-slot overflow; it is atomic/audited. Terminal correction requires reason and preserves history.                                              |
| Recruiter                     | An invited recruiter sees only granted company/drive/applicant projection, no resume by default, no exports, and cannot enumerate unrelated students.                                                      |

## Quality, performance, cost, and Phase 1 entry

Public pages are static/revalidated Server Component routes by default. Authenticated work is server-rendered/dynamic with minimal client islands. No client-side all-record fetch, N+1 hot path, heavy animation/chart/component library, generic global state framework, decorative video, or external paid dependency is allowed without approved need. Images are optimized; fonts are limited; tables filter/sort/paginate in PostgreSQL and use small-screen detail/card patterns.

Targets are Lighthouse Performance 90+ on representative routes, LCP preferably under 2 seconds, CLS below 0.1, and INP below 200 ms where practical. All key screens cover loading, success, empty, validation, permission-denied, network/server, and unexpected-error states.

The free-tier-first stack is Next.js/TypeScript, Supabase PostgreSQL/Auth/Storage, Vercel, and GitHub. No VPS, Redis, microservices, external database, paid queue, paid monitoring, or paid CMS. Provider quotas are not hard-coded: storage/egress, database growth, auth volume, bandwidth/build limits, and uploads are checked against current official documentation before capacity-sensitive releases. The custom domain is the only expected initial recurring cost.

Phase 1 may begin: scope, roles, ownership, provisioning, operational rules, acceptance criteria, visual direction, performance targets, and free-tier constraints are finalized. It remains limited to repository foundation (Next.js/TypeScript setup, local-only environment example/validation, CI/build/lint/typecheck foundation, base layout conventions). It must not initialize Supabase/Vercel, use production secrets, add application features, or start schema work.
