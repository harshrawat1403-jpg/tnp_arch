# Environments, deployment, health, and recovery

## Environment separation

Never use production as development. Maintain isolated local/development, preview/staging, and production environments, including separate credentials and preferably separate Supabase projects/databases/storage where practical. Preview deployments must never point to production secrets or accept production write traffic. `.env.example` documents variable names; secret values stay in the platform’s protected environment settings.

| Environment       | Purpose                                     | Data/access                                                                                 |
| ----------------- | ------------------------------------------- | ------------------------------------------------------------------------------------------- |
| Local/development | Fast feature work and migration experiments | Synthetic/local data only; developer credentials.                                           |
| Preview/staging   | Pull-request/release verification           | Isolated schema/data, test identities, migration rehearsal, restricted access.              |
| Production        | Controlled real service                     | Approved migrations/secrets only; least-privilege operator access and real-data safeguards. |

## Delivery workflow

Use a simple feature branch -> implementation -> focused tests -> typecheck/lint/build -> preview/staging verification -> review/merge -> controlled production path. Protect the production branch from direct obviously broken changes and require review appropriate to the risk. Keep commits small enough to review migrations, RLS, and domain logic alongside UI changes. Do not merge a failed migration, known authorization breach, or unreviewed destructive schema operation merely to meet a deadline.

Before production, confirm dependency installation, required environment variables, migration state, typecheck, lint, unit/integration tests, critical E2E tests, production build, permissions/RLS, key mobile routes, representative performance checks, and health endpoint. A compile success is one signal, not production readiness.

## Deployment and rollback

Deploy backward-compatible schema changes before code that depends on them when possible. For a failure, stop rollout, identify whether code/configuration/schema caused it, and roll back application deployment to the last known good version if schema compatibility permits. Do not casually roll back a database migration: some changes are not reversible without data loss. Each non-trivial migration records its forward fix, compatibility window, backup/recovery consideration, and owner. Test restore procedures on non-production data before relying on them.

Production backup/point-in-time recovery options and responsibilities must be verified against the chosen provider plan before launch. The Technical Secretary owns the protected recovery decision; restoration is an exceptional, audited operation after scope assessment.

## Lightweight health and observability

Implement a minimal unauthenticated or appropriately protected `/api/health` endpoint that verifies application liveness and, if safe, a bounded database connectivity check. It returns no secrets, internal schema details, or user data. Use Vercel/Supabase platform logs and lightweight structured server logs first. Include timestamp, request/correlation ID, route/operation class, sanitized error category, and duration where useful.

Watch server errors, database/migration failures, failed auth, failed uploads, denied critical operations, export failures, and unexpectedly slow queries/actions. Alerting/monitoring must remain proportionate to actual need and free-tier feasibility; add external paid tooling only after a concrete approved gap. Avoid logging raw personal documents, tokens, passwords, or full sensitive request bodies.

## Controlled launch

Launch progressively: Technical Secretary -> TNP Secretary -> Coordinators -> small test student group -> one batch -> broader student population -> recruiters. At each stage collect real feedback, review errors/permissions/data accuracy, and resolve critical issues before expanding. Maintain a reversible feature/route access strategy where practical, clear support ownership, and a rollback contact path. Do not announce broad availability until critical journeys, authorization, backups/recovery awareness, and operations checks are evidenced.
