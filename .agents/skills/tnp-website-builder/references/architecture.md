# Architecture

## Recommended shape

One Next.js TypeScript application is deployed on Vercel. It uses Supabase for PostgreSQL, authentication, and private object storage. GitHub provides source control and pull-request review. There is no separate backend, worker fleet, cache cluster, CMS, microservice, or generic domain layer in V1.

```text
Browser
  -> Next.js public Server Components / static pages
  -> authenticated Next.js server actions or route handlers
  -> Supabase Auth + PostgreSQL (RLS) + Storage (private buckets)
                 ^
          migrations, SQL functions, RLS policies
```

Use the Supabase browser client only for session-safe interactions whose RLS policy is deliberately sufficient. Use the server client for protected mutations, server-rendered data, and privileged orchestration. A service-role client is server-only, narrowly isolated, and is not a substitute for authorization; most ordinary requests should use the calling user's JWT/RLS context.

## Project organization when implementation begins

Keep the structure conventional and shallow. A suitable shape is `app/` for routes/layouts/loading/error states, `components/` for reusable UI, `lib/` for Supabase clients and shared safe utilities, `features/<domain>/` for focused domain logic/forms/queries, `supabase/migrations/` and `supabase/tests/` for database work, and `tests/` for application tests. Prefer direct feature-local code over repository/use-case abstractions unless duplication is proven.

Separate pure eligibility, transition, and validation functions from transport/UI so they can be unit-tested. Keep server-only modules clearly marked and avoid importing them into client components.

## Phase 1 established conventions

The repository uses npm with a committed lockfile, Next.js App Router, strict TypeScript, ESLint, Prettier, and Vitest. Application routes and route boundaries live in `src/app`; shared visual primitives are in `src/components`; framework-neutral utilities and their focused tests are in `src/lib`. The `@/*` alias resolves to `src/*`. Components are Server Components unless they require a browser API or interaction; the global error boundary is the only initial client component.

The Phase 1 app layer has only a minimal public development shell, metadata, loading/not-found/error states, environment validation, and a private-free local configuration template. It contains no Supabase client, authentication, storage, user role, or product feature code. Phase 2 adds schema migrations outside the application layer. The approved real department logo is expected at `public/brand/department-logo-black.svg` when supplied; until then, the shell uses an explicit text identity rather than a fabricated mark.

## Phase 2 established conventions

The repository uses the project-scoped Supabase CLI for local-only database development. `supabase/migrations/` is the sole schema source of truth; each change is a reviewed SQL migration applied in timestamp order. `supabase/tests/` holds pgTAP integration tests. CLI runtime state is ignored, while `config.toml`, migrations, and tests are committed. No Supabase browser/server client, remote project link, RLS policy, storage bucket, or authentication workflow exists in Phase 2.

The schema references `auth.users` only as an identity boundary for a future Phase 3 auth integration. Application tables stay in `public`, use restrictive foreign keys, and carry the data needed for later RLS without granting access now. The local CLI config disables automatic Data API exposure for new tables; Phase 3 must add reviewed RLS policies and grants before any client integration.

## Phase 3 established conventions

`@supabase/ssr` supplies a server-only cookie client. Password sign-in, sign-out, callback exchange, claim validation, and active-profile resolution run on the server; no browser Supabase client is needed yet. `src/proxy.ts` is the Next.js 16 session-refresh boundary and uses `getClaims()` rather than trusting a session cookie. Protected Server Components repeat the verified-claim and RLS-backed profile lookup, so Proxy remains an optimistic redirect aid rather than the sole authorization decision.

`/login` is the only auth entry route and has no registration flow. `/account` proves an authenticated, active profile and shows no product data. Supabase browser-safe URL/publishable-key values live in `.env.local`; a service-role key is neither read nor accepted by application code. The one-time protected Super Admin bootstrap is documented at `supabase/BOOTSTRAP.md`.

The Phase 3 migration enables RLS on every Phase 2 application table and revokes Data API table/function privileges from `anon` and `authenticated` by default. The only current grants are authenticated self-profile resolution and Super Admin read-only access to protected profiles/audit evidence. The role helper lives in a non-exposed `private` schema, pins `search_path`, and derives its answer from `auth.uid()`. Future workflow policies and RPC grants must be additive and scoped to their own approved phase.

## Phase 4 established conventions

Student registration, profile read models, and mutations remain server-first: `/register`, `/student`, and `/student/profile` are Server Component routes, while the sole client island is the pending-state submit button. The database Auth hook gates Auth-user creation to an active, unconsumed normalized roster email; after email confirmation, the callback invokes the identity-derived `complete_student_registration()` procedure. No form accepts a role, roster identity, or storage authority from the browser.

The student read model performs RLS-backed, per-user server queries. Personal details use narrow column updates; academic submission, verification, correction, and resume replacement use role-checking database procedures. A private resume download route first confirms the active document metadata through RLS, then creates a 60-second signed URL without persisting it. Student routes are dynamic and protected in Proxy as a session-refresh aid; their Server Components and actions still enforce identity and role independently.

## Trust boundaries

The browser may request an operation but cannot decide roles, eligibility, drive scope, status transition, document access, or audit entitlement. Next.js validates input and obtains the authenticated identity. PostgreSQL constraints/RLS/transactional functions protect persistent state. Storage policies protect bytes and document metadata controls discoverability. Administrative SQL functions should use a trusted current user identifier, check role internally, set a safe `search_path`, minimize privileges, and be `SECURITY DEFINER` only where necessary.

## Phase 5 planned skills boundary

Phase 5 will replace the Phase 4 self-declared skill array as the application authority with server-first reads and mutations over normalized `skills`, `student_skills`, `student_skill_evidence`, and `coordinator_student_scopes`. The legacy array is a controlled one-time import source, not a parallel write model. Skill catalog changes and verified-skill corrections run through role-checking, audited database operations; a coordinator queue must always join the caller's explicit roster course/batch scope.

Skill evidence keeps the existing document registry/storage split: a database invariant verifies that a referenced active `SKILL_EVIDENCE` document belongs to the same student, while storage policy protects the corresponding private object prefix. The browser supplies neither verifier metadata nor evidence ownership authority. Verified skills are read-only to students and future matching remains advisory, separate from the deterministic drive-eligibility path.

## Rendering and caching

Public pages should be static or revalidated server-rendered pages. Authenticated dashboards are user-specific and normally dynamic. Fetch data on the server, select only necessary columns, use explicit pagination, and place independently slow dashboard areas behind Suspense/loading boundaries. Cache shared public content deliberately and invalidate it when TNP updates it; never serve one user’s protected data from a shared cache.

## Configuration

Commit an `.env.example` containing names and descriptions only. Public browser values use the `NEXT_PUBLIC_` prefix only when genuinely safe (for example Supabase URL and publishable/anon key). Server secrets, service-role credentials, and external integration secrets must not be logged, committed, rendered, or passed to client components. Validate required environment variables at build/startup and use separate local, preview/staging, and production Supabase/Vercel projects or isolated environments.

## Failure boundaries

Use route-level error UI for recoverable presentation failures and typed domain errors for expected validation/permission/state failures. Log sanitized server context with a correlation identifier. A failure in a critical multi-row operation rolls back all database changes and does not leave a success-looking UI.
