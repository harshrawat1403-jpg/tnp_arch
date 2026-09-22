# Roles and permissions

## Fixed hierarchy

`SUPER_ADMIN` is the Technical Secretary, the ultimate system authority. `TNP_SECRETARY` operates TNP under that authority. Two `TNP_COORDINATOR` positions operate under both. `STUDENT` and `RECRUITER` are non-administrative roles. A user may not self-assign an administrative role. V1 permits exactly one active platform role per account: at most one TNP Secretary and two coordinators in explicit slots 1 and 2. The canonical capability matrix and role-provisioning rules are in [Phase 0 specification freeze](phase-0-specification-freeze.md).

## Permission matrix

| Capability                                              | Student      | Recruiter                                  | Coordinator                                                                                  | TNP Secretary          | Super Admin |
| ------------------------------------------------------- | ------------ | ------------------------------------------ | -------------------------------------------------------------------------------------------- | ---------------------- | ----------- |
| Read/update own permitted profile                       | Yes          | Own company/contact only                   | No                                                                                           | No                     | No          |
| View public/published drives                            | Yes          | Assigned drives                            | Yes                                                                                          | Yes                    | Yes         |
| Apply/withdraw own application                          | Policy-bound | No                                         | No                                                                                           | No                     | No          |
| View applicants                                         | Own only     | Explicit assigned scope and minimum fields | Assigned/TNP scope                                                                           | All TNP scope          | All         |
| Verify students / manage profiles and skills            | No           | No                                         | Yes, only assigned course/batch scope                                                        | Yes                    | Yes         |
| Govern canonical skill catalog / correct verified skill | No           | No                                         | No                                                                                           | Yes                    | Yes         |
| Manage companies, recruiters, drives, eligibility       | No           | Read-only assigned projection              | Create/edit drafts only; no publish/archive or critical settings                             | Yes                    | Yes         |
| Update application pipeline                             | No           | No                                         | `APPLIED` -> `SHORTLISTED`/`REJECTED`, `SHORTLISTED` -> `INTERVIEW`/`REJECTED`, within scope | All normal transitions | Yes         |
| Announcements, ordinary exports, statistics             | Read only    | Read assigned                              | Create/manage per scope                                                                      | Yes                    | Yes         |
| Assign/remove admin roles                               | No           | No                                         | No                                                                                           | No                     | Exclusively |
| Critical configuration, recovery, full audit access     | No           | No                                         | No                                                                                           | No                     | Exclusively |

The matrix is a minimum: implement exact operation-level grants, not a broad “admin” bypass. The Phase 0 decision is that coordinators may only perform the listed non-selection pipeline transitions, cannot export PII or publish/archive drives, and cannot perform terminal corrections; the TNP Secretary conducts normal selection workflow and the Super Admin handles exceptional recovery.

## Approved Phase 5 skill authority

`coordinator_student_scopes` assigns a coordinator to explicit roster course/batch combinations. It is mandatory for a coordinator to list, read for review, verify, or reject a student's skill declaration; a supplied student ID, hidden route, or UI filter never establishes scope. Coordinators may verify or reject only pending declarations in their assigned scope and cannot alter a verified skill, catalog entry, evidence ownership, role, academic correction, export, or audit-log visibility.

Students may create/read/update their own pending declarations and evidence; correcting a rejected declaration resubmits it as pending. They cannot create catalog entries, set verification state/verifier metadata, or edit a verified skill. `TNP_SECRETARY` and `SUPER_ADMIN` manage canonical catalog lifecycle and carry out audited verified-skill correction or revocation. Recruiters have no Phase 5 access to student skills or evidence.

## Enforcement model

Store role membership in protected server/database data, linked to `auth.users` through a profile record. A trusted server read or an RLS helper function resolves the role; never trust a hidden control, request body role, local storage, or JWT custom claim alone. RLS applies the same capability/scope rules for direct Supabase access. Privileged server actions re-check the actor before a mutation and database functions re-check it for stateful sensitive work.

Role assignment/removal is an atomic, audited Super Admin operation. V1 has exactly one active Super Admin, so a role change must atomically replace rather than remove or deactivate that account. It also enforces at most one active TNP Secretary and the two explicit coordinator slots, records before/after role data, and revokes access promptly. Bootstrap the first Super Admin through a documented, one-time protected operator procedure—not public registration.

## Phase 3 enforcement status

Phase 3 stores no role in browser state or client claims. An authenticated request resolves its active role by selecting its own RLS-protected `profiles` row after verified token claims establish the user ID. A non-exposed database helper checks `auth.uid()` for Super Admin-only policy decisions. The only currently enabled cross-account capability is Super Admin read access to protected profiles and audit logs; operational capabilities remain unavailable until their designated workflow phase. See `supabase/BOOTSTRAP.md` for the initial Super Admin procedure.

## Phase 4 student-profile enforcement

Only an active, unconsumed roster email may create an Auth user, and only the confirmed Auth identity may invoke student provisioning. That procedure sets `STUDENT` itself; role, roster ID, course, batch, verifier, and storage path are never browser inputs. An active student may read only their own profile, roster facts, academic record, and document metadata; direct updates are limited to display name and permitted personal columns. They cannot edit a role, verification state, academic row, another student's data, or a later-phase table.

`TNP_COORDINATOR`, `TNP_SECRETARY`, and `SUPER_ADMIN` may invoke the complete-profile verification procedure. Only `TNP_SECRETARY` and `SUPER_ADMIN` may correct verified academic facts, with a non-empty reason and audit evidence. Those capabilities are database-checked using `auth.uid()` and protected role records; Phase 4 deliberately adds no student-directory or staff review UI.
