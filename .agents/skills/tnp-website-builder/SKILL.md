---
name: tnp-website-builder
description: Build or review the repository-local Training and Placement portal phase by phase, with Supabase security, data integrity, free-tier-first operations, and lightweight responsive Next.js UX. Use for any TNP product, schema, authorization, testing, release, or incident work; do not use for unrelated department modules.
metadata:
  short-description: Safely build the TNP portal
---

# TNP Website Builder

Build a simple, dependable Training & Placement portal, not a general department platform. The order of priorities is reliability, security, data integrity, performance, simplicity, maintainability, responsive UX, then visual polish. Default stack: Next.js + TypeScript, Supabase PostgreSQL/Auth/Storage, Vercel, and GitHub. Keep normal department-scale operation viable on free tiers wherever reasonably possible.

## Before making a change

1. Read `AGENTS.md`, inspect the current code, migrations, environment examples, and tests. Do not assume this specification is more current than a verified implementation decision.
2. Identify the roadmap phase, affected layers (UI, server action/route, domain rules, schema/migration, RLS/storage, tests, docs), and the smallest safe change.
3. Read the reference files below that govern those layers. Read only the relevant ones, but do not skip security, data, or test guidance when a change touches them.
4. State assumptions or a required product decision before implementing when it materially changes access, data retention, eligibility, selection policy, or production behavior.

## Non-negotiable rules

- Authorize on trusted server/database boundaries. UI visibility is never authorization; client-provided role claims are untrusted.
- Use version-controlled, reviewed migrations for schema/RLS/function changes. Do not manually alter production schema or reset a shared database.
- Preserve atomicity for critical workflows, especially role changes, applications, status changes, selection, and storage metadata changes.
- Prefer archive/soft-close behavior for important records. Permanent deletion and data export require explicit policy and authorization.
- Keep the public site static/light where possible; use React Server Components by default and add client JavaScript only where interaction requires it.
- Do not add microservices, Redis, queues, a generic workflow engine, a CMS, heavy component/chart/state libraries, or unrelated modules without a concrete approved need.
- Do not expose resumes or student data to recruiters unless a server-side and RLS authorization rule permits that exact access.

## Reference routing

| Need                                                  | Read                                                                                                                |
| ----------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| V1 scope and fixed workflow                           | [product requirements](references/product-requirements.md) and [features](references/features.md)                   |
| stack, boundaries, and project shape                  | [architecture](references/architecture.md)                                                                          |
| roles or access decision                              | [roles and permissions](references/roles-permissions.md) and [security](references/security.md)                     |
| tables, constraints, query patterns, or migrations    | [database](references/database.md) and [security](references/security.md)                                           |
| pages, components, responsive behavior, accessibility | [UI/UX](references/ui-ux.md)                                                                                        |
| speed, caching, assets, or budget                     | [performance](references/performance.md)                                                                            |
| tests or a regression                                 | [testing](references/testing.md)                                                                                    |
| environments, releases, health, recovery, or costs    | [deployment](references/deployment.md)                                                                              |
| selecting work or closing a phase                     | [development roadmap](references/development-roadmap.md) and [definition of done](references/definition-of-done.md) |

## Implementation loop

Trace the request end-to-end before editing. Implement domain validation close to the server/database boundary; add UI validation for feedback, not as the sole safeguard. Update tests and the relevant reference when behavior changes. Then run the checks proportionate to risk, including migration/RLS verification for data changes and mobile/accessibility checks for UI changes. Report what was verified, what was not, and why.

For debugging, investigate the actual failure across logs, stack traces, schema/migration state, environment, RLS/authorization, server-client boundary, network request, and focused tests. Do not pile on symptom patches.

## Roadmap gate

Use [development roadmap](references/development-roadmap.md) as the delivery gate. A later feature may be designed early, but it must not be released ahead of its required authorization, migration, observability, and test foundations. Apply [definition of done](references/definition-of-done.md) before marking any feature or phase complete.
