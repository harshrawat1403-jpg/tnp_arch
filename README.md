# TNP Portal

The Training & Placement portal has completed **Phase 3: Authentication, Authorization & RBAC Foundation**. The application now has server-first Supabase Auth session handling, a protected account confirmation route, and least-privilege RLS. It still has no public registration, profile-management, recruiter, drive, application, document, announcement, export, or dashboard workflow. Do not begin Phase 4 without an explicit, scoped request.

## Prerequisites

- Node.js 20.9 or later
- npm 10 or later
- Docker Desktop or another Docker-compatible runtime for local Supabase database verification

## Local development

1. Copy `.env.example` to `.env.local`. Set the local Supabase URL and **publishable** key from `npx supabase status`; do not add a secret/service-role key.
2. Run `npm install`.
3. Run `npm run dev` and open `http://localhost:3000`.

## Quality checks

Run the following before handing off an application change:

```bash
npm run format:check
npm run typecheck
npm run lint
npm test
npm run build
```

## Local database workflow

The project uses a local-only Supabase CLI stack. Do not run linked or remote database commands during ordinary development.

```bash
npm run db:start
npm run db:verify:local
npm run db:stop
```

`db:verify:local` resets **only** the local disposable database, applies every version-controlled migration, lints the schema, and runs the pgTAP tests. It never uses `--linked`, `db push`, or production credentials. For a schema change: add a new migration, inspect it, run the local verification sequence, update the relevant documentation/tests, then use staging and production processes only in their approved later phases.

## Authentication foundation

- `/login` provides password sign-in only for operator-provisioned accounts; it has no public registration or role assignment path.
- `/account` is a deliberately minimal protected session/role confirmation route, not a student or staff dashboard.
- `src/proxy.ts` refreshes Supabase sessions; protected Server Components independently validate claims and resolve the active profile through RLS.
- Only `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` are used by the application. A service-role key is neither required nor supported by this phase.
- Follow [supabase/BOOTSTRAP.md](supabase/BOOTSTRAP.md) for the one-time Super Admin bootstrap in a protected operator environment.

## Conventions

- The App Router lives in `src/app`; its components are Server Components unless a browser API or interaction actually requires `"use client"`.
- Shared layout/brand primitives live in `src/components`; small framework-neutral utilities live in `src/lib`.
- `NEXT_PUBLIC_APP_URL` is optional in development and, when set, must be an absolute HTTP(S) URL. Validation occurs at application startup through `src/lib/environment.ts`.
- `supabase/migrations/` is the only schema source of truth. Phase 3 adds a default-deny RLS and grant boundary; later workflow phases add narrowly scoped operations and policies only when needed.
- The real approved black 2D department logo has not been supplied to this repository. Do not invent or recolor it. When supplied, place the original asset at `public/brand/department-logo-black.svg` and replace the temporary text identity in `src/components/brand/department-identity.tsx` in the same reviewed change.
- See `.agents/skills/tnp-website-builder/` for the canonical product, security, and phase guidance.
