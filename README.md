# TNP Portal

The Training & Placement portal has completed **Phase 2: Database Schema & Migration Foundation**. The version-controlled local database schema and tests exist, but there is still no Supabase client integration, authentication flow, RLS policy, storage bucket, product workflow UI, or remote project. Do not begin Phase 3 without an explicit, scoped request.

## Prerequisites

- Node.js 20.9 or later
- npm 10 or later
- Docker Desktop or another Docker-compatible runtime for local Supabase database verification

## Local development

1. Copy `.env.example` to `.env.local` only if an application URL is needed locally. Do not add secrets: Phases 1–2 use none.
2. Run `npm install`.
3. Run `npm run dev` and open `http://localhost:3000`.

## Quality checks

Run the following before handing off a Phase 1 change:

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

## Conventions

- The App Router lives in `src/app`; its components are Server Components unless a browser API or interaction actually requires `"use client"`.
- Shared layout/brand primitives live in `src/components`; small framework-neutral utilities live in `src/lib`.
- `NEXT_PUBLIC_APP_URL` is optional in development and, when set, must be an absolute HTTP(S) URL. Validation occurs at application startup through `src/lib/environment.ts`.
- `supabase/migrations/` is the only schema source of truth. The baseline contains schema/domain constraints only; RLS, grants, and any Supabase client belong to Phase 3.
- The real approved black 2D department logo has not been supplied to this repository. Do not invent or recolor it. When supplied, place the original asset at `public/brand/department-logo-black.svg` and replace the temporary text identity in `src/components/brand/department-identity.tsx` in the same reviewed change.
- See `.agents/skills/tnp-website-builder/` for the canonical product, security, and phase guidance.
