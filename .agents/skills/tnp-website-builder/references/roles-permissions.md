# Roles and permissions

## Fixed hierarchy

`SUPER_ADMIN` is the Technical Secretary, the ultimate system authority. `TNP_SECRETARY` operates TNP under that authority. Two `TNP_COORDINATOR` positions operate under both. `STUDENT` and `RECRUITER` are non-administrative roles. A user may not self-assign an administrative role. V1 permits exactly one active platform role per account: at most one TNP Secretary and two coordinators in explicit slots 1 and 2. The canonical capability matrix and role-provisioning rules are in [Phase 0 specification freeze](phase-0-specification-freeze.md).

## Permission matrix

| Capability                                          | Student      | Recruiter                                  | Coordinator                                                                                  | TNP Secretary          | Super Admin |
| --------------------------------------------------- | ------------ | ------------------------------------------ | -------------------------------------------------------------------------------------------- | ---------------------- | ----------- |
| Read/update own permitted profile                   | Yes          | Own company/contact only                   | No                                                                                           | No                     | No          |
| View public/published drives                        | Yes          | Assigned drives                            | Yes                                                                                          | Yes                    | Yes         |
| Apply/withdraw own application                      | Policy-bound | No                                         | No                                                                                           | No                     | No          |
| View applicants                                     | Own only     | Explicit assigned scope and minimum fields | Assigned/TNP scope                                                                           | All TNP scope          | All         |
| Verify students / manage profiles                   | No           | No                                         | Yes, bounded                                                                                 | Yes                    | Yes         |
| Manage companies, recruiters, drives, eligibility   | No           | Read-only assigned projection              | Create/edit drafts only; no publish/archive or critical settings                             | Yes                    | Yes         |
| Update application pipeline                         | No           | No                                         | `APPLIED` -> `SHORTLISTED`/`REJECTED`, `SHORTLISTED` -> `INTERVIEW`/`REJECTED`, within scope | All normal transitions | Yes         |
| Announcements, ordinary exports, statistics         | Read only    | Read assigned                              | Create/manage per scope                                                                      | Yes                    | Yes         |
| Assign/remove admin roles                           | No           | No                                         | No                                                                                           | No                     | Exclusively |
| Critical configuration, recovery, full audit access | No           | No                                         | No                                                                                           | No                     | Exclusively |

The matrix is a minimum: implement exact operation-level grants, not a broad “admin” bypass. The Phase 0 decision is that coordinators may only perform the listed non-selection pipeline transitions, cannot export PII or publish/archive drives, and cannot perform terminal corrections; the TNP Secretary conducts normal selection workflow and the Super Admin handles exceptional recovery.

## Enforcement model

Store role membership in protected server/database data, linked to `auth.users` through a profile record. A trusted server read or an RLS helper function resolves the role; never trust a hidden control, request body role, local storage, or JWT custom claim alone. RLS applies the same capability/scope rules for direct Supabase access. Privileged server actions re-check the actor before a mutation and database functions re-check it for stateful sensitive work.

Role assignment/removal is an atomic, audited Super Admin operation. V1 has exactly one active Super Admin, so a role change must atomically replace rather than remove or deactivate that account. It also enforces at most one active TNP Secretary and the two explicit coordinator slots, records before/after role data, and revokes access promptly. Bootstrap the first Super Admin through a documented, one-time protected operator procedure—not public registration.
