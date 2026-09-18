# Performance and free-tier discipline

## Engineering targets and budget

Treat Lighthouse Performance 90+, LCP preferably below 2 seconds on representative pages/connections, CLS below 0.1, and INP below 200 ms where practical as targets, not release guarantees. Establish a baseline once the foundation exists and compare representative public, student, and admin routes before release. Investigate material regressions rather than gaming a single score.

Keep public routes small: system or carefully subsetted fonts, optimized image dimensions, `next/image` where appropriate, WebP/AVIF when compatible, no decorative heavy video by default, and a small JavaScript budget. Prefer Server Components and static/revalidated content; isolate interactive controls into small client components. Avoid animation libraries, huge component packages, global client state, chart libraries for basic counts, and client-side fetching where server rendering suffices.

## Data-path rules

Paginate every growth-prone list; filter/sort/aggregate in PostgreSQL with indexes and tight selected columns. Never fetch all students/applications to the browser for filtering, charts, or export. Prevent N+1 queries by shaping joins/batched queries intentionally and inspect query plans/slow operation logs for hot screens. Use Suspense/streaming only when it improves perceived latency without confusing state; add route-level loading UI for slower pages.

Authenticated data is dynamic/private by default. Cache only data with an explicit audience and invalidation story. Use cache tags/revalidation carefully after public content changes. Do not cache personalized dashboards in shared output.

## Storage and provider-cost guardrails

Storage, egress, database size, auth volume, build minutes/bandwidth, and function limits are capacity risks. Before adding file-heavy or background-like behavior, consult current official Supabase/Vercel documentation and measure projected department demand; do not hard-code quotas that may drift. Restrict uploads, avoid duplicate resume versions, use external URLs for portfolios, lazy-load document actions, compress images, and archive/review old records under a documented retention policy. Use platform logs and health checks before adding third-party observability.

## Regression checks

At minimum, production builds must surface route/bundle problems; representative routes receive mobile network/device inspection, Lighthouse/Web Vitals sampling, and database query review when their data shape changes. Record a brief measurement context (route, environment, data size, tool/date) so trends are meaningful. Fix the largest measured bottleneck first, not hypothetical micro-optimizations.
