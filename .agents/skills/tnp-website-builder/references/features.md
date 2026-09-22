# V1 feature specification

## Public site

Provide Home, About TNP, placement/internship information, recruiter information, contact, and login. Keep these routes small, accessible, static/revalidated where possible, and free from private data. Contact submissions are optional; do not add one without an abuse/spam and ownership plan. Recruiter information should explain the approved channel rather than expose personal staff data indiscriminately.

## Student system

Students register/sign in through Supabase Auth only when a verified email exactly matches a protected preloaded student-roster record; registration creates only `STUDENT` access. Recruiters are invitation-only and administrative roles have no public registration route. The profile covers personal and academic information, CGPA, course/batch, external portfolio URL, private resume, completeness, and verification state. Define completeness from required fields in shared domain logic and show the missing items. Verified academic fields lock for students; Coordinator verification and Secretary/Super Admin correction require audit evidence.

Skills use a controlled canonical catalog, not a free-text profile field. A student declares each skill once, selects proficiency level 1–4, and may attach an HTTPS project URL or a private PDF `SKILL_EVIDENCE` document they own. Student skills move through `PENDING`, `VERIFIED`, and `REJECTED`; students can update pending declarations or correct and resubmit rejected declarations, but cannot self-verify or edit a verified skill. The TNP Secretary and Super Admin govern catalog entries and audited verified-skill corrections; a coordinator reviews only students in an explicitly assigned course/batch scope. A verified skill may later inform transparent advisory matching, but never placement eligibility or application authorization.

The student dashboard lists eligible and ineligible drives. Each drive displays an explicit outcome: the reason it can be applied for, or the actionable/non-sensitive reason it cannot. The detail view exposes only the student’s own applications/history, applicable announcements, and appropriate placement/internship history. A resume upload validates type and size at client feedback, server, storage policy, and metadata levels; replacement archives the former document rather than leaving orphaned objects.

## TNP administration

The dashboard provides useful counts and outstanding work without loading every record. Student management supports searchable, database-filtered, paginated lists; profile and skill-verification queues; and audit-safe academic/profile/verified-skill correction. Coordinator lists and review operations are restricted to explicit course/batch assignments; they are never an unscoped student directory. Companies, recruiters, and drives use archive states and explicit lifecycle publishing. Drive management edits eligibility before publication, shows applicant counts, and protects changes that could surprise already-applied students; materially changing published eligibility needs a documented policy and audit.

Applicant management includes scoped list/filter/export, status timeline, shortlisting/interview/selection/rejection controls permitted to the actor, and a typed reason/note where policy requires it. Announcements, CSV exports compatible with spreadsheet tools, and basic database-aggregated placement statistics are V1; avoid client-side data dumps and complex BI/chart platforms.

## Recruiter system

Recruiters authenticate by expiring invitation. They see a read-only assigned company/contact projection and only drives granted to their recruiter/company scope. Applicant fields are a minimum necessary per-drive projection; resume access is denied by default and needs a later explicit per-drive grant decision. Recruiters cannot browse all students, change administrative statuses, access audit logs, export data, or infer students outside their assigned work.

## Cross-feature rules

- Forms use accessible labels, server-side schema validation, idempotency where repeated submissions are plausible, and human-readable field/action errors.
- List pages use deterministic sorting, filters reflected in the URL where useful, empty/loading/error states, and pagination.
- Export is authorized, scoped, recorded in audit logs when it contains sensitive data, rate/size bounded, and generated from server-side filters—not the browser’s currently loaded rows.
- “Delete” for companies, drives, applications, documents, and data with operational history normally means archive/disable; explain downstream impact before the action.
- Legacy profile skill strings migrate only through exact trim/case normalization. Alias or synonym decisions require manual catalog review; the application must not silently infer equivalence.
- Skill evidence documents use the existing private document registry and storage pattern. The database—not a client-provided identifier—enforces that evidence belongs to the student skill's owner.
