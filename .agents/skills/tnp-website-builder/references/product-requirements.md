# Product requirements and scope

## Mission and constraints

The product is one dependable TNP portal for a department, rebuilt from scratch. It serves public visitors, students, authorized recruiters, and a small TNP office team. Optimize in this order: reliability, security, data integrity, performance, simplicity, maintainability, responsive UX, visual quality. Prefer the stated free-tier stack; the custom domain is the expected initial recurring cost. Provider quotas change, so assess the current official Supabase/Vercel documentation before a capacity-sensitive decision rather than copying quota numbers into the product.

V1 explicitly excludes elections, committees, meeting/maintenance systems, generic events, page builders, generic CMS features, and all-purpose department management. Do not add a generic workflow engine: application states are fixed.

## Users and V1 outcomes

| User                | V1 outcome                                                                                                                                                                    |
| ------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Public visitor      | Quickly finds TNP information, placement/internship context, recruiter information, contact details, and login.                                                               |
| Student             | Maintains a verified profile and verifiable skills, discovers drives, understands eligibility, applies/withdraws when allowed, and follows announcements/application history. |
| Coordinator         | Performs bounded daily TNP tasks: course/batch-scoped student and skill-verification support, drive and applicant operations, and permitted status updates.                   |
| TNP Secretary       | Runs normal TNP operations: companies, recruiters, drives, applications, selections, announcements, exports, and statistics.                                                  |
| Technical Secretary | Owns sensitive administration, role assignment/removal, critical configuration, recovery operations, and full audit access.                                                   |
| Recruiter           | Has only the specific company/drive/applicant access explicitly granted by TNP office policy.                                                                                 |

## Fixed application workflow

Application statuses are `APPLIED`, `SHORTLISTED`, `INTERVIEW`, `SELECTED`, `REJECTED`, and `WITHDRAWN`. A status change appends history; it does not overwrite evidence of a prior decision.

| From        | Allowed next state               | Actor/policy                                                                                                                                                           |
| ----------- | -------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| APPLIED     | SHORTLISTED, REJECTED, WITHDRAWN | Coordinators/Secretaries/Super Admin may shortlist/reject; a student may withdraw only before drive deadline; Secretary/Super Admin may record withdrawal with reason. |
| SHORTLISTED | INTERVIEW, REJECTED              | Coordinators/Secretaries/Super Admin; students cannot withdraw.                                                                                                        |
| INTERVIEW   | SELECTED, REJECTED               | TNP Secretary/Super Admin only.                                                                                                                                        |
| SELECTED    | none                             | Terminal in V1; corrections require an audited privileged reversal policy, not an ordinary edit.                                                                       |
| REJECTED    | none                             | Terminal; corrections require an audited privileged reversal policy.                                                                                                   |
| WITHDRAWN   | none                             | Terminal; reapplication is not supported in V1.                                                                                                                        |

The drive itself has separate lifecycle states: `DRAFT`, `PUBLISHED`, `CLOSED`, `ARCHIVED`. Applications are accepted only for a published, open drive before its deadline and when deterministic eligibility succeeds. The finalized withdrawal, reapplication, and terminal-correction policies are in [Phase 0 specification freeze](phase-0-specification-freeze.md).

## Eligibility rule

Eligibility is a deterministic server-side/domain calculation over published criteria and eligible verified student data: course/batch, minimum CGPA, maximum current active backlogs, and optional exclusion of students previously selected for a placement drive. Other requirements are informational rather than hidden discretionary gates in V1. It returns a boolean plus user-safe reason codes, such as `BATCH_NOT_ELIGIBLE`, `CGPA_BELOW_MINIMUM`, `BACKLOG_LIMIT_EXCEEDED`, `PREVIOUS_PLACEMENT_SELECTION`, `PROFILE_UNVERIFIED`, or `DRIVE_CLOSED`. The UI maps reason codes to clear plain-language explanations. A stale client-side result never authorizes an application; eligibility is recomputed inside the application transaction.

## Phase 0 decisions

The completed V1 specification—including account provisioning, coordinator limits and course/batch scope, verified academic and skill-data handling, controlled skill catalog/evidence rules, current-active-backlog definition, optional prior-placement exclusion, withdrawal/correction rules, recruiter scope, archival lifecycle, exports, acceptance criteria, and visual direction—is recorded in [Phase 0 specification freeze](phase-0-specification-freeze.md). Verified skills are future advisory matching signals, never placement eligibility gates. It supersedes the former unresolved-policy list.
