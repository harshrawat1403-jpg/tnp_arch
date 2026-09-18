# Security, RLS, and storage

## Authentication and sessions

Use Supabase Auth with secure server-side session handling appropriate to the installed Next.js/Supabase versions. Student registration requires a verified email exact-match against the protected roster; recruiters are invitation-only; administrative accounts are Super Admin-provisioned. Protect callback/redirect targets against open redirects. Rate-limit or otherwise defend login, registration, password recovery, invitations, upload, export, and public form abuse using platform-native/free-tier-compatible controls where possible; do not invent a paid service by default.

Never expose `service_role`, database password, private API keys, or raw error details in browser bundles, logs, screenshots, client errors, or commits. Check env values at startup and keep local, preview/staging, and production secrets separate. Dependency changes require a review for maintenance and supply-chain impact.

## RLS design

Enable RLS on every application table and storage object policy. Default deny; add narrow policies after a concrete access matrix. RLS helper functions must derive the current identity from `auth.uid()`/trusted database context and role from protected role data, not caller-supplied fields. Avoid recursive policies and broad `USING (true)` policies. Test policies as each user class in a non-production database.

| Resource             | Student                                                   | Recruiter                                  | Coordinator / Secretary                      | Super Admin                          |
| -------------------- | --------------------------------------------------------- | ------------------------------------------ | -------------------------------------------- | ------------------------------------ |
| Profile/student data | Own row; permitted self-edit fields only                  | None unless a granted applicant projection | Scoped TNP operation, least privilege        | Full protected administrative access |
| Drives/eligibility   | Read published; no direct lifecycle mutation              | Read assigned published scope              | Operation-specific TNP scope                 | Full                                 |
| Applications/history | Own only; creation/withdrawal only through protected path | Explicit per-drive projection only         | Scoped management, transition function       | Full                                 |
| Companies/recruiters | No broad write                                            | Read-only assigned projection              | Managed operational scope                    | Full                                 |
| Announcements        | Published audience read                                   | Assigned/public audience read              | Manage permitted content                     | Full                                 |
| Audit logs           | No                                                        | No                                         | Only explicitly granted limited view, if any | Full only                            |

For sensitive writes, favor narrowly permissioned RPC/database functions or server action transactions over granting broad table `UPDATE`. RLS does not replace server validation: validate input, role, scope, lifecycle, and state transition before/within the transaction. Use database grants to prevent untrusted roles from invoking administrative functions.

## Private storage model

Use private buckets such as `resumes`, `profile-images`, and only a justified `portfolio-files`. Object paths begin with the immutable owner UUID and a generated object ID; never use an email or untrusted filename as an authority-bearing path. Validate allowlisted MIME type plus file signature where feasible, content length, dimensions for images, and approximately 5 MB max PDF resume size unless a documented requirement changes it. Normalize/re-encode profile images to sensible dimensions/formats; prefer an external portfolio URL.

Storage policies permit an owner to upload/manage only their own permitted prefix and document type. Direct object reads are limited to the owner or a server-authorized, scope-checked action; issue short-lived signed URLs only after authorizing the requester and do not store them. Reconcile failed/orphaned upload objects and metadata through a controlled maintenance task. Do not preload PDFs in dashboards.

## Audit, privacy, and incident handling

Audit sensitive administrative actions: roles, verification/academic changes, drive/eligibility changes, status/selection changes, archive/delete-like actions, exports, and privileged recovery. Logs include actor, action, target type/id, timestamp, correlation ID, and a minimal sanitized before/after diff. Never put credentials, full resumes, unnecessary PII, or secret tokens in audit payloads. Restrict full audit-log access to `SUPER_ADMIN`.

On suspected exposure, preserve relevant audit evidence, revoke/restrict affected access or signed links, rotate secrets through the provider, assess scope, and follow institutional notification policy. Do not silently overwrite evidence or “fix” production with unreviewed destructive actions.
