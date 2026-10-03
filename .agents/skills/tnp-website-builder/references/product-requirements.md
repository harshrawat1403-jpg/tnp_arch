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
| Recruiter           | Is invited to one employer contact and sees only their own company plus explicitly granted published-drive metadata; applicant access remains a later policy.                 |

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

Eligibility uses one authoritative database-backed calculation over protected roster course/batch pairs and verified `academic_records.cgpa`/`active_backlog_count`, plus optional `exclude_previously_selected_placement` (default false). Skills, skill verification/evidence, overall profile verification/completeness, and resume readiness are not eligibility gates. Missing or unverified academic data yields an academic result of `UNDETERMINED`, not an invented failure. Other requirements remain informational.

The flag applies when configured on either placement or internship opportunities. Only an application currently `SELECTED` for a `PLACEMENT` drive counts; selected internships and historical selections reversed by an approved audited correction do not count. There is no global placement lock.

Keep academic `PASS`/`FAIL`/`UNDETERMINED`, availability, and ordered structured reasons separate. The machine codes are `ELIGIBLE`, `COURSE_NOT_ELIGIBLE`, `BATCH_NOT_ELIGIBLE`, `CGPA_BELOW_MINIMUM`, `ACTIVE_BACKLOG_LIMIT_EXCEEDED`, `PREVIOUSLY_SELECTED_PLACEMENT`, `ACADEMIC_DATA_UNAVAILABLE`, `ACADEMIC_UNVERIFIED`, `DEADLINE_PASSED`, and `DRIVE_CRITERIA_UNAVAILABLE`. Their meaning/order is canonical in the [Phase 0 freeze](phase-0-specification-freeze.md#eligibility-authority-and-calculation). Internal authorization may distinguish unpublished/closed/archived drives, but student endpoints return a generic unavailable/not-found result for hidden IDs.

Student entry points derive identity from `auth.uid()` and never accept student identity, academic facts, or evaluation time from the caller. No mutable eligibility flag or parallel client calculation is stored. In Phase 8, the same calculation must be rerun inside the application transaction; a stale displayed result does not authorize submission.

## Approved Phase 7 delivery boundary

Phase 7 implements drive display and bounded staff lifecycle only. Both coordinators may edit any draft; only Secretary/Super Admin publish, close, archive, or correct published content. Preserve exactly `DRAFT -> PUBLISHED -> CLOSED -> ARCHIVED`, terminal archival, chronological lifecycle metadata, and read-only closed/archived content/criteria. Publication requires an active company, future deadline, one criteria row, and at least one explicit course/batch pair. Company archival is denied while any drive remains `PUBLISHED`, even after deadline expiry; close drives explicitly rather than changing their state during archival.

Availability is `PUBLISHED` and database evaluation time strictly before the `timestamptz` deadline. Expired published opportunities may remain visible; no scheduler is needed. Every published correction needs one protected Secretary/Super Admin operation, internal reason, student notice, revision check/increment, atomic mutation, and before/after audit. Company/type are immutable after publication, and an expired deadline cannot be extended/reopened. The latest notice persists independently of unrelated actions.

Use the existing eligibility tables and approved additive revision/notice metadata, narrow student/staff RPC projections, and bounded SQL pagination. Compensation fields are approved student-facing detail fields. Recruiter access remains Phase 6 metadata-only. Phase 7 exposes no Apply action, applicant counts, student lists, or application/status/history/resume-sharing workflow. Matching, career roles, notifications, exports, analytics, alumni, and announcements remain outside this phase.

## Phase 0 decisions

The completed V1 specification—including account provisioning, coordinator limits and course/batch scope, protected academic and skill-data handling, controlled skill catalog/evidence rules, current-active-backlog definition, current-state prior-placement exclusion, withdrawal/correction rules, approved Phase 6 recruiter boundaries, approved Phase 7 drive/eligibility rules, archival lifecycle, exports, acceptance criteria, and visual direction—is recorded in [Phase 0 specification freeze](phase-0-specification-freeze.md). Verified skills are future advisory matching signals, never eligibility gates. Overall profile verification/completeness is also independent of eligibility. The approved addenda supersede the former unresolved-policy lists; specification approval is not implementation completion.
