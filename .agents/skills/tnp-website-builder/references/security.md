# Security, RLS, and storage

## Authentication and sessions

Use Supabase Auth with secure server-side session handling appropriate to the installed Next.js/Supabase versions. Student registration requires a verified email exact-match against the protected roster; recruiters are invitation-only; administrative accounts are Super Admin-provisioned. Protect callback/redirect targets against open redirects. Rate-limit or otherwise defend login, registration, password recovery, invitations, upload, export, and public form abuse using platform-native/free-tier-compatible controls where possible; do not invent a paid service by default.

Never expose `service_role`, database password, private API keys, or raw error details in browser bundles, logs, screenshots, client errors, or commits. Check env values at startup and keep local, preview/staging, and production secrets separate. Dependency changes require a review for maintenance and supply-chain impact.

## RLS design

Enable RLS on every application table and storage object policy. Default deny; add narrow policies after a concrete access matrix. RLS helper functions must derive the current identity from `auth.uid()`/trusted database context and role from protected role data, not caller-supplied fields. Avoid recursive policies and broad `USING (true)` policies. Test policies as each user class in a non-production database.

| Resource             | Student                                                                   | Recruiter                                  | Coordinator / Secretary                                         | Super Admin                                    |
| -------------------- | ------------------------------------------------------------------------- | ------------------------------------------ | --------------------------------------------------------------- | ---------------------------------------------- |
| Profile/student data | Own row; permitted self-edit fields only                                  | None unless a granted applicant projection | Scoped TNP operation, least privilege                           | Full protected administrative access           |
| Skills/evidence      | Own pending/rejected declarations and evidence only; no self-verification | None                                       | Coordinator course/batch review only; catalog/correction denied | Catalog governance and audited correction only |
| Drives/eligibility   | Read published; no direct lifecycle mutation                              | Read assigned published scope              | Operation-specific TNP scope                                    | Full                                           |
| Applications/history | Own only; creation/withdrawal only through protected path                 | Explicit per-drive projection only         | Scoped management, transition function                          | Full                                           |
| Companies/recruiters | No broad write                                                            | Read-only assigned projection              | Managed operational scope                                       | Full                                           |
| Announcements        | Published audience read                                                   | Assigned/public audience read              | Manage permitted content                                        | Full                                           |
| Audit logs           | No                                                                        | No                                         | Only explicitly granted limited view, if any                    | Full only                                      |

For sensitive writes, favor narrowly permissioned RPC/database functions or server action transactions over granting broad table `UPDATE`. RLS does not replace server validation: validate input, role, scope, lifecycle, and state transition before/within the transaction. Use database grants to prevent untrusted roles from invoking administrative functions.

The matrix describes the eventual V1 boundary, not a grant of future-phase access. In Phase 7, students receive only published-drive projections and their own eligibility explanation; recruiter applicant/resume access and all application mutations remain denied. No Phase 7 staff student-eligibility directory is approved.

Phase 5 skill policies must derive the reviewed student's course/batch from protected roster data and compare it to `coordinator_student_scopes`; they must not trust a client-supplied scope or use the current opaque-ID profile-verification procedure as a directory permission. Students may mutate pending `student_skills` and correct/re-submit rejected records only; a re-submission returns the record to `PENDING`. The verification status, verifier, and timestamp are database-controlled. `TNP_SECRETARY`/`SUPER_ADMIN` catalog and verified-skill operations use narrow, audited database procedures.

## Private storage model

Use private buckets such as `resumes`, `profile-images`, a justified `portfolio-files`, and Phase 5 `skill-evidence`. Object paths begin with the immutable owner UUID and a generated object ID; never use an email or untrusted filename as an authority-bearing path. Skill evidence accepts an HTTPS project URL or a private PDF document recorded as `SKILL_EVIDENCE`; use the same bounded PDF validation/storage approach as resumes unless a later approved requirement changes it. Validate allowlisted MIME type plus file signature where feasible, content length, dimensions for images, and approximately 5 MB max PDF resume size unless a documented requirement changes it. Normalize/re-encode profile images to sensible dimensions/formats; prefer an external portfolio URL.

Storage policies permit an owner to upload/manage only their own permitted prefix and document type. Direct object reads are limited to the owner or a server-authorized, scope-checked action; issue short-lived signed URLs only after authorizing the requester and do not store them. Reconcile failed/orphaned upload objects and metadata through a controlled maintenance task. Do not preload PDFs in dashboards.

For `SKILL_EVIDENCE`, storage prefix ownership is necessary but insufficient: the database registration path must also verify the active document kind and that `documents.owner_id` equals the student owning the linked `student_skill`. Reject cross-owner references even if the caller knows a valid document UUID. Recruiters have no evidence read or signed-URL capability in Phase 5.

## Audit, privacy, and incident handling

Audit sensitive administrative actions: roles, verification/academic changes, drive/eligibility changes, status/selection changes, archive/delete-like actions, exports, and privileged recovery. Logs include actor, action, target type/id, timestamp, correlation ID, and a minimal sanitized before/after diff. Never put credentials, full resumes, unnecessary PII, or secret tokens in audit payloads. Restrict full audit-log access to `SUPER_ADMIN`.

On suspected exposure, preserve relevant audit evidence, revoke/restrict affected access or signed links, rotate secrets through the provider, assess scope, and follow institutional notification policy. Do not silently overwrite evidence or “fix” production with unreviewed destructive actions.

## Phase 3 enforcement status

All Phase 2 application tables now have RLS enabled. Explicit grants are as narrow as the current routes require: authenticated users can resolve only their active profile; Super Admin can additionally read protected profiles and audit logs; all future-domain tables and workflow RPCs remain denied. The role helper is in the non-exposed `private` schema, has a pinned empty search path, and evaluates the caller through `auth.uid()`; it never accepts an arbitrary user ID or role claim.

The application uses only a project URL and browser-safe publishable key. Server Actions and Route Handlers use cookie-backed clients, `src/proxy.ts` refreshes verified claims, and no service-role key exists in source, browser code, or the environment template. Public signup is disabled in the local configuration until the separately approved student/recruiter onboarding phases.

## Phase 4 student registration and resume enforcement

Local and deployed Auth configuration must enable the approved Before User Created hook only when its `pg-functions://postgres/public/enforce_student_roster_signup` endpoint and least-privilege `supabase_auth_admin` permissions are installed. The hook sees only the protected roster and consumption facts it needs, normalizes with `lower(trim(email))`, and returns a generic denial. Confirmation is required before the callback can provision the fixed `STUDENT` role. The application never reports whether an unregistered email appears in the roster.

The Phase 4 resume bucket is private. Server validation checks the PDF signature, MIME type, and 5 MiB maximum before uploading; storage repeats the allowed MIME/size checks and applies owner-ID/UUID-prefix policies. The replacement procedure checks the uploaded object's owner and metadata before exposing document metadata. Signed downloads are generated only after RLS-backed metadata authorization, last 60 seconds, use `private, no-store`, and are not persisted. Failed metadata registration removes only the newly uploaded, unregistered object.

## Approved Phase 6 employer and invitation enforcement

The Before User Created hook becomes the sole pre-creation gate for either an active unused student roster record or a `PREPARED` recruiter invitation. A recruiter path must match the supplied non-secret invitation row ID, normalized incoming email, unexpired/unrevoked invitation, active recruiter contact, and active company. The hook returns a generic denial and is executable only by `supabase_auth_admin`; public signup cannot mint a recruiter role.

Only a `server-only` Admin client may call Supabase Auth invitation APIs, and only after a caller-authorized Secretary/Super Admin procedure creates the invitation state. Its secret is neither accepted nor exposed by browser code, client props, logs, audit data, or `NEXT_PUBLIC_*` environment values. The callback must use an allowlisted local path and invoke the acceptance procedure only after server-side Auth exchange. Ordinary code callbacks use PKCE; Admin invitations require the provider invite-token hash and caller-bound `verifyOtp`, because `inviteUserByEmail` does not support PKCE. Callback responses are private/no-store with no-referrer and never retain or relay the hash. That procedure derives `auth.uid()` and confirmed email, verifies `SENT` state plus stored Auth-user binding, and atomically creates the `RECRUITER` profile, binds the contact, consumes the invitation, and audits the result.

Phase 6 keeps Data API default-deny. Recruiter RLS predicates must require active profile role, exact `recruiters.user_id = auth.uid()`, unarchived recruiter/company, and an unexpired non-revoked grant for a `PUBLISHED` same-company drive. Staff use narrow selects and protected procedures; no broad authenticated mutation grant, `USING (true)` policy, or recruiter table enumeration is permitted. Company/recruiter archive immediately fails recruiter predicates. Grants are revoked, not deleted, and no recruiter may access applicant/resume fields, even if legacy flags are true.

Audit data records sanitized lifecycle facts and mandatory grant-revocation reason only. It excludes invitation links, OTPs/tokens, passwords, Admin secrets, signed URLs, and raw provider errors.

## Approved Phase 7 drive and eligibility enforcement

This is an approved specification, not an assertion that the Phase 7 protections are already installed. Retain Phase 6 recruiter grants and their exact active-company/contact, published-drive, expiry, and revocation predicates. Do not expand the shared `authenticated` base-table column grants to deliver student/staff drive details: richer role-checking projections/RPCs must prevent those columns becoming readable by a granted recruiter. Keep default-deny RLS and no broad authenticated table mutation grants.

The student entry points derive identity from `auth.uid()` and read course/batch from the protected roster and CGPA/active backlogs only from verified academic records. They accept no supplied student ID, course, batch, academic values, or evaluation time. One private database calculation serves student list/detail and future Phase 8 application authorization. Missing or unverified academic data is `UNDETERMINED`; overall profile verification/completeness, skills, skill verification, and evidence are never gates. A hidden draft/closed/archived or nonexistent ID yields the same generic student outcome, without disclosing state. No other-student eligibility or academic values may be returned.

Both coordinators may create/edit any `DRAFT` drive, without creator ownership restrictions; only Secretary/Super Admin may publish, close, archive, or correct published content. Every permitted published content/criteria change, including small copy edits, uses one protected atomic correction operation with a mandatory internal reason, student-facing notice, expected-revision check, incremented revision, and sanitized before/after audit. `company_id` and `drive_type` are immutable after publication. Preserve the latest notice/time through unrelated lifecycle operations; a stale request must leave content, criteria, revision, notice, and audit unchanged.

Enforce `DRAFT -> PUBLISHED -> CLOSED -> ARCHIVED`, state-appropriate chronological timestamps, terminal archive, and read-only closed/archived content and criteria at the database boundary. Publication requires an active company, future deadline, exactly one valid eligibility row, and at least one explicit course/batch pair. The protected company archive path must refuse any `PUBLISHED` drive, including an expired one, without automatically changing drive state. Serialize company archive against publication so concurrent requests cannot invalidate the active-company invariant.

Evaluate openness with database `timestamptz` time strictly before the deadline. Expiry does not change lifecycle or require a scheduler. Published deadline correction requires the same reason/notice/audit operation; a replacement before expiry must remain future, and extension/reopening after expiry is prohibited. Prior-placement exclusion uses only current `SELECTED` applications belonging to `PLACEMENT` drives, including the result of approved audited terminal corrections; it does not add application mutation authority in Phase 7.

The six approved events are `drive.created`, `drive.updated`, `drive.published`, `drive.closed`, `drive.archived`, and `drive.eligibility_updated`. Published corrections emit `drive.updated` classified published/material; criteria corrections additionally emit the eligibility event. Audit payloads omit student academic values, secrets, signed URLs, invitation data, and raw provider errors. No new Admin client, Auth behavior, recruiter private-data access, application workflow, or other Phase 8 functionality is authorized by this specification.
