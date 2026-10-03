# TNP Portal

The Training & Placement portal is implementing **Phase 7: Drives and Eligibility**. The application uses server-first Supabase Auth session handling, roster-gated student registration, normalized student skills, and bounded company/recruiter and drive lifecycles under least-privilege RLS. Applications, applicant browsing, matching, alumni, analytics, exports, and notifications remain deliberately deferred.

## Drives and eligibility

`/tnp/drives` provides bounded draft editing for both Coordinators and audited
publication/correction/closure/archive for the Secretary and Super Admin.
Published corrections require the current revision, an internal reason and a
student-facing notice. Closed/archived content cannot be edited or reopened.
Companies with any published drive (including expired ones) cannot be archived.

`/student/drives` lists only published drives, including expired published drives,
using SQL-filtered 20-row pages. A caller-bound database assessment uses exact
protected roster course/batch pairs and verified academic CGPA/backlogs. Missing
or unverified academics remain undetermined; overall profile completeness, skills
and resume readiness are not eligibility gates. Prior placement exclusion is
optional and uses current selected placement truth, not selection history.
Deadlines are exclusive database timestamps. No Apply button or application API
is introduced. Recruiter metadata grants and column projections remain unchanged.

The additive `20261003000000_drives_eligibility_foundation.sql` migration refuses
incompatible historical lifecycle/criteria data rather than inventing a backfill.
Review any such data explicitly before a separately authorized hosted rollout.

## Recruiter onboarding

Recruiter invitations finish at `/recruiter/setup-password` before the workspace.
The caller-bound Auth client sets the password; an authenticated active recruiter
can return through the workspace link. Local password setup uses the configured
Auth minimum (6 characters); Supabase enforces any stronger hosted policy.

Use the committed invite email template in local and hosted Auth configuration.
Admin invites do not support PKCE, so the template sends the provider token hash
to `/auth/callback` for server-side verification rather than a URL-fragment session.
See [Supabase email templates](https://supabase.com/docs/guides/auth/auth-email-templates).
No invitation URL, hash, or password is stored in application records or audit.

When Auth issuance succeeds but database finalization fails, the portal reports
that distinct result and preserves the prepared attempt. A Secretary/Super Admin
can reissue it. Recovery checks the exact prior invitation, recruiter, email and
Auth user binding; an unrecorded user binding additionally requires an unconfirmed
invited Auth user created during that prior invitation's valid window. Confirmed
users are never deleted/recreated. Issue/reissue audit events derive from history.

Local Auth also allowlists `http://127.0.0.1:3006/auth/callback` for isolated
onboarding verification when port 3000 is occupied.

## Prerequisites

- Node.js 20.9 or later
- npm 10 or later
- Docker Desktop or another Docker-compatible runtime for local Supabase database verification

## Local development

1. Copy `.env.example` to `.env.local`. Set the local Supabase URL and **publishable** key from `npx supabase status`. The recruiter-invitation flow additionally needs a server-only `SUPABASE_SECRET_KEY`; never use a `NEXT_PUBLIC_` name for it or commit its value.
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

## Authentication and bounded operational foundation

- `/register` permits an account only when a confirmed institutional email matches an active, unconsumed protected roster entry. It has no role selection path; provisioning creates only `STUDENT` access.
- `/login` provides password sign-in for approved accounts, and `/account` links an authenticated role to its bounded workspace.
- `/student` is a readiness-only dashboard; `/student/profile` contains personal, pending academic, and private PDF-resume forms. `/tnp/skills` provides bounded skill administration, and `/tnp/companies` provides bounded company/recruiter administration.
- `/recruiter` exposes only the recruiter’s own active contact, company, and explicitly granted published-drive metadata. It does not expose students, applications, resumes, skills, or evidence.
- `src/proxy.ts` refreshes Supabase sessions; protected Server Components independently validate claims and resolve the active profile through RLS.
- `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` are browser-safe connection values. `SUPABASE_SECRET_KEY` is server-only and used solely by the narrow recruiter invitation hand-off; it never replaces caller authorization or RLS.
- Follow [supabase/BOOTSTRAP.md](supabase/BOOTSTRAP.md) for the one-time Super Admin bootstrap in a protected operator environment.

## Conventions

- The App Router lives in `src/app`; its components are Server Components unless a browser API or interaction actually requires `"use client"`.
- Shared layout/brand primitives live in `src/components`; small framework-neutral utilities live in `src/lib`.
- `NEXT_PUBLIC_APP_URL` is optional in development and, when set, must be an absolute HTTP(S) URL. Validation occurs at application startup through `src/lib/environment.ts`.
- `supabase/migrations/` is the only schema source of truth. Phase 6 extends the single Auth hook to accept matching recruiter invitations and adds audited, narrow company/recruiter/invitation/grant procedures; later workflow phases add operations and policies only when needed.
- The real approved black 2D department logo has not been supplied to this repository. Do not invent or recolor it. When supplied, place the original asset at `public/brand/department-logo-black.svg` and replace the temporary text identity in `src/components/brand/department-identity.tsx` in the same reviewed change.
- See `.agents/skills/tnp-website-builder/` for the canonical product, security, and phase guidance.
