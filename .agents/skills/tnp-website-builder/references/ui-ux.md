# UI, UX, and accessibility

## Design language

Aim for a calm, professional institutional tool: warm off-white backgrounds, charcoal/black primary interface, restrained non-blue accents only for meaning, strong typography, generous whitespace, subtle borders, minimal shadows, generous click targets, and subtle CSS transitions. Use the approved black 2D department logo without altering its geometry or recoloring it. Avoid generic blue-SaaS styling, gradients, glassmorphism, excessive card grids, decorative motion, and visually heavy components. Use a small reusable vocabulary: Button, Input, Select, Textarea, Checkbox, Dialog, Drawer, Card, Badge, Table, Tabs, Dropdown, Toast, Skeleton, Pagination, EmptyState, and ErrorState. Build these from accessible primitives/native HTML where practical; do not install a large design system for one component.

## Responsive patterns

Design mobile first for student tasks and test four ranges: small mobile, larger mobile/tablet, laptop, desktop. Public navigation collapses into an accessible drawer with a visible menu control and focus management. Forms remain single-column at narrow widths, group related fields with fieldsets/legends where useful, and use persistent labels rather than placeholders as labels.

Admin tables must not merely shrink: preserve the essential columns, use a detail route/drawer or stacked labelled record card for secondary data, allow horizontal scroll only as a deliberate last resort with an affordance, and keep filters/sorting/pagination accessible. Destructive/irreversible actions require a clear confirmation that names the affected record; dialogs trap focus, return focus on close, and can be dismissed safely when appropriate.

## State and feedback requirements

Every meaningful screen and mutation needs loading, success, empty, validation error, permission denied, network/server error, and unexpected-error consideration. Skeletons mirror layout without hiding action labels. Empty states explain what is empty, why, and a permitted next action. State failures say what happened and what the user can safely do (for example, “Your resume is larger than 5 MB. Choose a smaller PDF.”), not “Request failed.” Provide retry for idempotent/recoverable actions; do not auto-retry a mutation that may have succeeded.

## Accessibility baseline

Target semantic HTML, keyboard-only completion of core journeys, visible focus, adequate text/non-text contrast, responsive zoom/reflow, correctly associated labels/errors, announced async status, and meaningful alt text. Do not communicate eligibility/status by color alone. Respect reduced motion. Use native controls before custom equivalents and test with a keyboard plus automated accessibility checks on core pages. Make route/page titles describe the current task.

## Data and privacy presentation

Show only necessary student/recruiter fields in each context. Mask or omit private contact/academic data when not needed. Never put a signed document URL into a rendered long-lived record, table export, client state, or analytics payload. Application status history should show a clear timestamp/status and permitted note without exposing internal-only deliberation.

## Phase 6 employer surfaces

Company and recruiter staff pages are compact operational views, not a CRM: paginated/filterable company list, focused company detail/edit, contact list, invitation status/actions, archive/reactivation, and published-drive grant/revoke. Use clear state badges plus text, URL-reflected filters/pages, empty/permission/error states, and confirmation dialogs that name the company/contact and downstream recruiter-access effect. Coordinator screens hide unavailable actions as a convenience but server/database denial remains authoritative.

The recruiter self-view displays only own contact, company, and granted-drive metadata. It never renders invitation URLs/tokens, grant flags, student data, or applicant/document controls. Ensure archive/revocation/expired-invitation states give a generic safe support message without disclosing another record's existence.

## Approved Phase 7 drive surfaces

The planned `/student/drives` and `/student/drives/[driveId]` are display-only, server-first surfaces. Preserve the approved warm off-white/charcoal institutional design, strong typography, black 2D department logo, generous whitespace, subtle borders, and minimal motion; do not introduce a dashboard template or heavy component system. Use a compact list with accessible URL-reflected filters and Previous/Next navigation, 20 records per page, ordered deadline then ID. Do not add Apply, withdrawal, applicant lists, status-transition/history, resume-sharing, matching/ranking, or other Phase 8 controls.

Student detail may show company name, title, drive type, location, deadline, description, `package_lpa`, `stipend_monthly`, `compensation_details`, structured eligibility criteria, informational other requirements, the caller's own eligibility result/reasons, and latest material-change notice/time. It must not render recruiter contacts, applicants/counts, audit metadata, internal notes, or other students. Render absent optional compensation clearly without inventing values. Hidden draft/closed/archived and nonexistent detail IDs receive the same generic not-found/unavailable treatment.

Show academic criterion result (`PASS`, `FAIL`, or `UNDETERMINED`) separately from availability. Map the canonical structured reason codes to factual, accessible explanations; missing/unverified academics mean a determination is pending, not a guessed CGPA/backlog failure. Never label a student ineligible because overall profile verification/completeness, phone/resume, skills, or evidence is missing. Criteria descriptions must reflect exact course/batch pairs rather than imply independent course and batch lists. Skills and free-text requirements are not machine eligibility gates.

An expired `PUBLISHED` drive remains visible with a clear deadline-passed state; at the exact deadline it is not open. Show times unambiguously with timezone context. The latest student-facing change notice/time is visible on affected drive detail, distinguished from the internal correction reason, which is never disclosed. Status and eligibility are conveyed with text, not color alone; handle empty/filter-empty, loading, permission, stale-data, validation, and failure states deliberately.

Staff surfaces remain bounded: draft create/edit, publish, close, archive, and one published-correction form. Both coordinators can edit any draft, without an ownership filter; unavailable privileged controls may be hidden but server/database denial remains authoritative. Every published content change, even a typo, requires an internal reason and student-facing notice plus expected revision. Do not expose a shortcut ordinary-edit form for published records. Explain stale revisions and require reload/review instead of blindly retrying.

Lifecycle confirmations name the drive and describe the irreversible effect: no reopening/unarchive, no draft archive, and closed/archived content/criteria read-only. Company archive refusal explains that published drives must first be explicitly closed, including expired published drives; it must not silently close them. Publication under an archived company is unavailable until reactivation. Deadline corrections before expiry require a future replacement; after expiry no extension/reopening is offered. Preserve existing notice/time through unrelated actions and preserve Phase 6 recruiter self-view/grant behavior without richer recruiter content.
