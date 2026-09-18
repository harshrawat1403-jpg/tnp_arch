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

## Trust boundaries

The browser may request an operation but cannot decide roles, eligibility, drive scope, status transition, document access, or audit entitlement. Next.js validates input and obtains the authenticated identity. PostgreSQL constraints/RLS/transactional functions protect persistent state. Storage policies protect bytes and document metadata controls discoverability. Administrative SQL functions should use a trusted current user identifier, check role internally, set a safe `search_path`, minimize privileges, and be `SECURITY DEFINER` only where necessary.

## Rendering and caching

Public pages should be static or revalidated server-rendered pages. Authenticated dashboards are user-specific and normally dynamic. Fetch data on the server, select only necessary columns, use explicit pagination, and place independently slow dashboard areas behind Suspense/loading boundaries. Cache shared public content deliberately and invalidate it when TNP updates it; never serve one user’s protected data from a shared cache.

## Configuration

Commit an `.env.example` containing names and descriptions only. Public browser values use the `NEXT_PUBLIC_` prefix only when genuinely safe (for example Supabase URL and publishable/anon key). Server secrets, service-role credentials, and external integration secrets must not be logged, committed, rendered, or passed to client components. Validate required environment variables at build/startup and use separate local, preview/staging, and production Supabase/Vercel projects or isolated environments.

## Failure boundaries

Use route-level error UI for recoverable presentation failures and typed domain errors for expected validation/permission/state failures. Log sanitized server context with a correlation identifier. A failure in a critical multi-row operation rolls back all database changes and does not leave a success-looking UI.
