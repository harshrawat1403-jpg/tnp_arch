# Development roadmap

The phases are gates, not a reason to write every feature at once. Complete prerequisites and exit criteria before moving on; a small later-phase spike may be designed, but not released, when its foundations are absent. Record approved product decisions as they are made.

## Phase 0 — Specification freeze

- **Objective:** convert the product requirements into a short, agreed V1 backlog and decision log.
- **Prerequisites:** none.
- **Tasks:** confirm academic verification/backlog/selection/withdrawal/recruiter/retention policies; define support ownership and success metrics; exclude non-TNP scope.
- **Database/security:** select data classifications and preliminary role/capability decisions.
- **Tests:** review scenarios and acceptance criteria for each core journey.
- **Exit:** [Phase 0 specification freeze](phase-0-specification-freeze.md) records final V1 scope, role/capability boundaries, ownership, workflows, acceptance criteria, visual direction, performance/cost constraints, and any governance requirement deliberately deferred to pre-production.

## Phase 1 — Repository foundation

- **Objective:** create a minimal maintainable Next.js/TypeScript foundation and engineering checks.
- **Prerequisites:** Phase 0 decisions for foundation scope.
- **Tasks:** project setup, environment example/validation, formatting/lint/typecheck/build, baseline layout/error/loading conventions, CI skeleton, dependency budget.
- **Database/security:** no production project or secrets; decide local/staging isolation.
- **Tests:** clean install, typecheck, lint, production build, basic smoke page.
- **Exit:** reproducible local and preview build with no secret committed and documented commands.

## Phase 2 — Database schema and migrations

- **Objective:** establish the normalized base model and safe migration workflow.
- **Prerequisites:** Phase 0 data decisions and Phase 1 tooling.
- **Tasks:** initial tables, constraints, timestamps, indexes, archive conventions, seed-safe fixtures, migration review workflow.
- **Database/security:** prepare tables for Phase 3 RLS, keep automatic Data API exposure disabled locally, and document backup/compatibility approach. Do not add policies or grants before authenticated access is implemented.
- **Tests:** apply from clean disposable database; constraint/index and migration ordering tests.
- **Exit:** schema represents core entities, duplicate application protection is proven, and migration rehearsal succeeds.

## Phase 3 — Authentication, authorization, and RLS

- **Objective:** make identity and least privilege trustworthy before product data is exposed.
- **Prerequisites:** Phases 1–2 and approved role/bootstrapping policy.
- **Tasks:** session handling, protected role data, Super Admin bootstrap/runbook, capabilities, RLS policies/functions, audit foundation, private storage base.
- **Database/security:** test allowed and denied access for all roles; privileged operations are transactional/audited.
- **Tests:** integration/RLS tests plus forged-client/direct-access negative cases.
- **Exit:** no public admin assignment, no browser service secret, and each role boundary has evidence.

**Implemented foundation:** `20260918000000_auth_rbac_foundation.sql` supplies default-deny RLS/grants, active-profile role resolution, and Super Admin audit/profile read boundaries. Server-first sign-in/sign-out, callback exchange, claim refresh, protected account behavior, an operator-only Super Admin bootstrap runbook, and pgTAP allow/deny coverage are in place. Product workflows remain deferred.

## Phase 4 — Student profiles

- **Objective:** give students a secure, complete, verifiable profile.
- **Prerequisites:** Phase 3.
- **Tasks:** registration flow, personal/academic forms, completeness, verification state, resume/portfolio/private storage, student dashboard shell.
- **Database/security:** validate document constraints and ownership; audit verification/academic correction.
- **Tests:** student self-access denial/allowance, uploads, profile validation, mobile/keyboard journey.
- **Exit:** a verified test student can safely complete and view their profile; unauthorized reads/writes fail.

**Implemented foundation:** `20260918010000_student_profiles_foundation.sql` supplies normalized roster-gated signup, confirmed identity-derived student provisioning, field-level personal-profile RLS, locked academic records with audited office correction, and private resume storage. The server-rendered registration, readiness-only dashboard, profile forms, and signed download surface prove the narrow student flow; database and runtime smoke coverage includes direct Auth-hook denial, provisioning, replacement, and cross-student storage denial. Staff review/listing and all placement workflows remain deferred.

## Phase 5 — Student skills and bounded administration

- **Objective:** replace self-declared legacy skill strings with an authoritative, verifiable student-skill model while enabling bounded TNP-office review.
- **Prerequisites:** Phase 4 and the approved normalized-skills, evidence, catalog-governance, and coordinator course/batch scope decisions in the Phase 0 freeze.
- **Tasks:** controlled skill catalog; student skill declarations at proficiency levels 1–4; HTTPS project URL/private-PDF evidence; pending/verified/rejected review; indexed, paginated scoped queues; permitted audited correction/revocation; status visibility; safe export groundwork.
- **Database/security:** add `skills`, `student_skills`, `student_skill_evidence`, and `coordinator_student_scopes` additively. Make normalized skills authoritative through a one-way exact-normalization legacy import. Enforce evidence-document ownership in the database, retain default-deny Data API exposure, use private `SKILL_EVIDENCE` storage, and grant coordinators only assigned course/batch access.
- **Tests:** clean migration and exact-import/collision-review coverage; level/status/uniqueness/ownership constraints; student, coordinator, Secretary, Super Admin, and recruiter RLS allow/deny cases; verification/rejection/correction audit tests; realistic queue query/pagination checks; mobile/keyboard review.
- **Exit:** a student can manage pending/rejected skills and evidence, a scoped coordinator can review only assigned students, verified skills are student-immutable, evidence cannot cross ownership boundaries, catalog governance is audited, and no unscoped directory or placement-eligibility gate exists.

**Implemented foundation:** `20260924000000_add_skill_evidence_document_kind.sql`, `20260924000100_student_skills_and_bounded_administration.sql`, and `20260924000200_skill_catalog_reactivation.sql` add the approved normalized skill/evidence/scope model, exact-label legacy import, default-deny RLS, private PDF evidence storage, and audited role-checking procedures. `/student/skills` provides catalog-backed student declarations/evidence, and `/tnp/skills` supplies a database-scoped staff review queue plus bounded Secretary/Super Admin catalog lifecycle, scope assignment, and verified-skill correction/revocation controls. Career tracks/roles, matching, employer workflows, applications, exports, analytics, and all other Phase 6+ work remain deferred.

## Phase 6 — Companies and recruiters

- **Objective:** manage employer records and constrained recruiter access.
- **Prerequisites:** Phases 3 and 5; recruiter onboarding/grant policy resolved.
- **Tasks:** company lifecycle, recruiter contacts/invitations, company ownership and per-drive grant model.
- **Database/security:** recruiter RLS/projections and invitation expiry/scope controls.
- **Tests:** recruiter cannot enumerate unrelated records; company/recruiter archive cases.
- **Exit:** recruiter can access only explicitly authorized company/drive information.

## Phase 7 — Drives and eligibility

- **Objective:** publish trustworthy placement/internship opportunities with explainable eligibility.
- **Prerequisites:** Phases 4–6 and backlog/eligibility decisions.
- **Tasks:** drive CRUD/archive/publish/close, batches, eligibility criteria, student listing/detail, reason-code UI.
- **Database/security:** lifecycle checks, indexed eligibility query path, audited published changes.
- **Tests:** eligibility matrix/boundaries, unpublished/closed denial, mobile detail/performance check.
- **Exit:** eligibility is identical at display and server-authorized application time, with clear reasons.

## Phase 8 — Applications and selection pipeline

- **Objective:** deliver atomic application and controlled status workflow.
- **Prerequisites:** Phase 7 and terminal-correction/withdrawal policy.
- **Tasks:** apply, withdraw, applicant lists, history, shortlist/interview/select/reject, status notes and notifications only if justified.
- **Database/security:** application transaction, unique constraint, transition function, audit history.
- **Tests:** concurrent duplicate apply, every valid/invalid transition, role/scope denials, critical E2E journeys.
- **Exit:** no partial application/status operation and selection results are traceable.

## Phase 9 — Announcements

- **Objective:** publish audience-appropriate notices.
- **Prerequisites:** Phase 3.
- **Tasks:** authoring, publish/schedule/archive, audience display, accessible list/detail states.
- **Database/security:** author/audit fields and audience RLS.
- **Tests:** audience visibility, scheduling, empty/error states.
- **Exit:** announcements do not leak restricted content and can be managed without a CMS.

## Phase 10 — Exports and basic analytics

- **Objective:** provide operational data without data dumps or expensive tooling.
- **Prerequisites:** Phases 5–8 and data-retention/export policy.
- **Tasks:** authorized CSV-compatible exports, scoped server aggregation, basic count/trend views.
- **Database/security:** audit sensitive exports, indexes/query budgets, field minimization.
- **Tests:** export authorization/contents/size bound, aggregation correctness and performance.
- **Exit:** no browser-wide fetch and no unscoped PII export.

## Phase 11 — Reliability, errors, and audit refinement

- **Objective:** make failure modes clear, safe, and diagnosable.
- **Prerequisites:** core workflows available.
- **Tasks:** typed error mapping, loading/empty/error states, idempotency decisions, correlation logs, audit coverage review, health endpoint.
- **Database/security:** transaction/rollback review and log redaction.
- **Tests:** failure injection for critical operations and no sensitive error leakage.
- **Exit:** critical user journeys have understandable failure behavior and audit evidence.

## Phase 12 — Automated test hardening

- **Objective:** make regressions detectable.
- **Prerequisites:** representative flows from Phases 3–11.
- **Tasks:** expand unit/integration/E2E suites, CI checks, deterministic fixtures, migration-from-clean tests.
- **Database/security:** RLS/storage negative tests are required.
- **Tests:** full suite and flake review.
- **Exit:** core journeys and authorization boundaries run reliably in isolated automation.

## Phase 13 — Performance, accessibility, and responsive optimization

- **Objective:** validate real usage quality before launch.
- **Prerequisites:** core UI and test fixtures.
- **Tasks:** bundle/query review, Web Vitals baseline, keyboard/screen-reader-oriented checks, small-screen admin patterns, asset optimization.
- **Database/security:** verify optimizations do not broaden cache/data access.
- **Tests:** representative Lighthouse/device/network and accessibility checks.
- **Exit:** known targets/regressions are measured, documented, and acceptable for controlled launch.

## Phase 14 — Staging, deployment, and monitoring

- **Objective:** prove a safe operational release path.
- **Prerequisites:** Phases 1–13 applicable exit criteria.
- **Tasks:** staging rehearsal, environment checks, deployment/rollback runbook, health/log review, backup/recovery verification.
- **Database/security:** migration compatibility and least-privilege production configuration review.
- **Tests:** release-candidate suite plus staging smoke and health check.
- **Exit:** Technical Secretary can make an informed go/no-go decision with evidence.

## Phase 15 — Controlled production launch

- **Objective:** introduce V1 safely through the staged audiences in deployment guidance.
- **Prerequisites:** Phase 14 and explicit launch approval.
- **Tasks:** phased access, feedback triage, error/permission review, communication and support plan.
- **Database/security:** monitor real access/audit patterns and do not relax protections to solve support friction.
- **Tests:** post-deploy smoke for each admitted audience and rollback readiness confirmation.
- **Exit:** each rollout cohort meets success/incident criteria before expansion; broader release is explicitly approved.
