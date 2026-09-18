# Repository instructions

This repository is reserved for a new Training & Placement (TNP) portal. Phases 1–2 establish the application foundation and versioned local schema only; they deliberately contain no cloud integration, client/server database integration, authentication, RLS, storage bucket, or product workflow implementation.

## Required operating model

- For any TNP application work, load and follow `.agents/skills/tnp-website-builder/SKILL.md` before editing.
- Inspect the current implementation, existing migrations, configuration, and relevant tests before proposing or making a change.
- Work phase-by-phase according to the roadmap. Do not begin a phase whose recorded prerequisites or exit criteria are incomplete without calling that out and obtaining a deliberate decision.
- Make the smallest safe change. Preserve working behavior and do not add unrelated department-management modules.
- Treat authorization, Row Level Security (RLS), migrations, validation, and tests as implementation work, not a later cleanup.
- Never put Supabase service-role credentials in browser code, bypass RLS from a client, reset a shared/production database, or make irreversible external changes without explicit authorization.
- Do not call a feature complete solely because it compiles. Use the relevant definition of done and report verification honestly.

## Product boundaries

V1 is a lightweight, free-tier-first TNP portal: public information; student profiles and applications; tightly scoped recruiter access; and administrative operations for the Technical Secretary, TNP Secretary, and TNP Coordinators. Excluded V1 modules include elections, committees, generic CMS/page builders, meetings, maintenance, and generic department management.

## Documentation maintenance

When a verified decision changes the architecture, schema, permission model, or delivery plan, update the matching reference under `.agents/skills/tnp-website-builder/references/` in the same change. Do not invent provider quotas; link to current official documentation when a quota affects a decision.

<!-- BEGIN:nextjs-agent-rules -->

# This is NOT the Next.js you know

This version has breaking changes — APIs, conventions, and file structure may all differ from your training data. Read the relevant guide in `node_modules/next/dist/docs/` (resolved from this file's directory; in monorepos the `next` package may not be visible from the repo root) before writing any code. Heed deprecation notices.

This block is written and re-added by `next dev` — verify at `node_modules/next/dist/server/lib/generate-agent-files.js`. Removing it from a diff only re-creates the uncommitted change; committing it with your work keeps the tree clean.

<!-- END:nextjs-agent-rules -->
