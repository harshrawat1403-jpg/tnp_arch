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
