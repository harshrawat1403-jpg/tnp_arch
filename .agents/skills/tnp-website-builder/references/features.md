# V1 feature specification

## Public site

Provide Home, About TNP, placement/internship information, recruiter information, contact, and login. Keep these routes small, accessible, static/revalidated where possible, and free from private data. Contact submissions are optional; do not add one without an abuse/spam and ownership plan. Recruiter information should explain the approved channel rather than expose personal staff data indiscriminately.

## Student system

Students register/sign in through Supabase Auth only when a verified email exactly matches a protected preloaded student-roster record; registration creates only `STUDENT` access. Recruiters are invitation-only and administrative roles have no public registration route. The profile covers personal and academic information, CGPA, course/batch, external portfolio URL, private resume, completeness, and verification state. Define completeness from required fields in shared domain logic and show the missing items. Verified academic fields lock for students; Coordinator verification and Secretary/Super Admin correction require audit evidence.

Skills use a controlled canonical catalog, not a free-text profile field. A student declares each skill once, selects proficiency level 1–4, and may attach an HTTPS project URL or a private PDF `SKILL_EVIDENCE` document they own. Student skills move through `PENDING`, `VERIFIED`, and `REJECTED`; students can update pending declarations or correct and resubmit rejected declarations, but cannot self-verify or edit a verified skill. The TNP Secretary and Super Admin govern catalog entries and audited verified-skill corrections; a coordinator reviews only students in an explicitly assigned course/batch scope. A verified skill may later inform transparent advisory matching, but never placement eligibility or application authorization.

Phase 7 provides `/student/drives` and `/student/drives/[driveId]` as display-only published-opportunity surfaces. Each drive separates academic `PASS`/`FAIL`/`UNDETERMINED` from availability and shows the caller's authoritative reason codes. Missing/unverified academics remain undetermined; skills, overall profile verification/completeness, and resume readiness never influence eligibility. There is no Apply action in this phase. Own applications/history belong to Phase 8; announcements belong to their later phase. A resume upload retains its existing type/size/ownership validation and archives prior metadata on replacement.

Student detail uses a narrow database projection for company name, title, drive type, location, deadline, description, package/stipend/compensation details, exact course/batch pairs and academic thresholds, informational requirements, caller eligibility/reasons, and latest correction notice/time. Recruiter contacts, applicant counts, internal notes, audit metadata, and other-student records are excluded. Listing uses SQL filters and page size 20 with one-row lookahead and `(application_deadline ASC, id ASC)` ordering; one bounded database call includes eligibility. An exposed eligibility filter must precede pagination.

## TNP administration

The eventual V1 dashboard provides useful counts and outstanding work without loading every record. Student management supports searchable, database-filtered, paginated lists; profile and skill-verification queues; and audit-safe academic/profile/verified-skill correction. Coordinator student lists/reviews are restricted to explicit course/batch assignments. Both coordinators may create/edit any `DRAFT` drive without creator ownership restrictions; only Secretary/Super Admin may publish, close, archive, or correct published content. Applicant counts and pipeline management remain Phase 8+ features.

Phase 7 staff UI is a bounded server-first drive list, draft create/edit, criteria form, publish/close/archive confirmations, and one published-correction form. Every published content/criteria change requires internal reason, student-facing notice, stale revision check, atomic update, revision increment, and audit; there is no less-protected typo/normal-edit path. Company/type cannot change after publication. Closed content/criteria are read-only except archival; archived content/criteria are immutable. A company with any published drive cannot be archived, and an archived company cannot publish a drive. Publication also requires a future deadline, one valid eligibility row, and at least one course/batch pair. Expired published drives remain visible without automatic closure; extending an expired deadline is prohibited.

Applicant management includes scoped list/filter/export, status timeline, shortlisting/interview/selection/rejection controls permitted to the actor, and a typed reason/note where policy requires it. Announcements, CSV exports compatible with spreadsheet tools, and basic database-aggregated placement statistics are V1; avoid client-side data dumps and complex BI/chart platforms.

## Recruiter system

Recruiters authenticate only through a Supabase Auth invitation tied to a pre-created active recruiter contact and active company. The TNP Secretary/Super Admin manages contact lifecycle and invitation issue/reissue/revoke; acceptance atomically binds one confirmed Auth identity to one recruiter contact. Recruiter account binding is not public registration, staff acceptance, or self-service role conversion.

Recruiters see a read-only own-contact/assigned-company projection and only explicitly granted, unexpired `PUBLISHED` drive metadata: title, type, location, and deadline. Applicant/resume fields are not exposed in Phase 6 even when legacy grant flags are populated. Recruiters cannot browse companies/recruiters/students, change administrative data, access profiles/skills/evidence/documents/resumes/applications/applicants/audit logs, export data, or infer activity outside their assigned work.

Staff company management is deliberately bounded: a paginated/filterable internal company list; company detail/edit; recruiter contacts under a company; invitation state/actions; archive/reactivation; and grant/revoke only for existing published drives. Coordinator company/contact authority ends at their own uninvited drafts; this does not restrict shared Phase 7 drive drafts. There is no generic CRM, drive lifecycle surface, applicant tooling, or recruiter-facing mutation in Phase 6. Phase 7 adds the approved company-archive precondition while preserving recruiter grants, projections, expiry/revocation, and dormant applicant/resume flags.

## Cross-feature rules

- Forms use accessible labels, server-side schema validation, idempotency where repeated submissions are plausible, and human-readable field/action errors.
- List pages use deterministic sorting, filters reflected in the URL where useful, empty/loading/error states, and pagination.
- Export is authorized, scoped, recorded in audit logs when it contains sensitive data, rate/size bounded, and generated from server-side filters—not the browser’s currently loaded rows.
- “Delete” for records with operational history normally means archive/disable; explain downstream impact. Drive archival is specifically `CLOSED -> ARCHIVED`, with no ordinary deletion, draft archival, reopening, or unarchive. Company archive requires all published drives to be closed first.
- Legacy profile skill strings migrate only through exact trim/case normalization. Alias or synonym decisions require manual catalog review; the application must not silently infer equivalence.
- Skill evidence documents use the existing private document registry and storage pattern. The database—not a client-provided identifier—enforces that evidence belongs to the student skill's owner.

Phase 7 excludes application creation/withdrawal, applicant lists, shortlist/interview/select/reject, application-history UI, applicant resume sharing, matching/ranking, career roles, notifications, exports, analytics, alumni, and announcements. Frozen Phase 7 requirements are not yet implemented.
