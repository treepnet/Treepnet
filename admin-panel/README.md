# Treepnet-admin-panel

Treepnet Admin Panel — High-performance, minimalist analytics dashboard designed for internal telemetry, user growth tracking, DAU/WAU/MAU activity, and infrastructure health monitoring.

## Features
- **Minimalist Linear & Vercel Design**: Clean typography, high data-ink ratio, custom dark/light themes.
- **Multi-Language Support**: Full English (EN) and Russian (RU) localization with instant switching.
- **Analytics Modules**:
  - **Overview (KPIs)**: Total users, DAU, WAU, MAU, stickiness ratio, reactions, top content.
  - **Growth & Signups**: Registration flow, age distribution, profile completeness, PII-safe users table.
  - **Activity**: 45s heartbeat tracking, hourly activity curves, dormancy analysis.
  - **Content**: Post & Story statistics, format ratios, reaction leaderboard.
  - **Engagement**: Comments, reply ratios, follow graph, influencer rankings.
  - **Referral System**: Tiers (Bronze to Platinum), conversion tracking, leaderboard.
  - **Chat & Messaging**: Volume trends, format distribution (text, photo, voice, video).
  - **Geography**: Regional analytics, international travel trends, top traveler rankings.
  - **Security & System**: Push notification queue health, DB connection pooling, rate limit status.
- **Interactive Controls**: Date range filtering (Today, 7D, 30D, 90D, All), CSV report export.

## Tech Stack
- **Framework**: React 18 + Vite + TypeScript
- **Styling**: Tailwind CSS
- **Charts**: Recharts
- **Icons**: Lucide React

## Getting Started

```bash
# Install dependencies
npm install

# Run development server
npm run dev

# Build for production
npm run build
```

## Data source

The dashboard is **not** mock data. It calls the read-only `analytics-api`
service (`oci-backend/functions/analytics-api`) on the same origin, which
connects as the locked-down `analytics_ro` Postgres role and returns only
PII-safe aggregates (see `src/lib/api.ts`):

- `GET /api/dashboard?preset=today|yesterday|7d|30d|90d|all` or
  `?from=YYYY-MM-DD&to=YYYY-MM-DD`: every number for the selected window (Tashkent
  days), compared with the window of the same length before it, plus "right
  now" snapshot numbers. The panel labels each card as period / now / all time.
- `GET /api/users`: every account with per-user counts (no email/phone).
- `GET /api/online`: live presence, polled every 30 s.

Online users, per-day actives and session lengths come from `analytics.activity`
(one row per user-minute), filled by the `track_presence` trigger on the app's
45 s heartbeat (`oci-backend/sql/analytics_v3.sql`). Tracking began 2026-10-16;
earlier days' activity is estimated from actions plus the nightly snapshot.

Local development: put `ADMIN_BASIC=admin:<password>` in `.env.local`
(gitignored) and run `npm run dev`; Vite proxies `/api` to the live server.

## Deployment (OCI stack)

Served by Caddy at `admin.treepnet.com` (and `admin.130-61-138-104.sslip.io`),
behind HTTP basic_auth (user `admin`; the bcrypt hash lives in the server
`.env` as `ADMIN_BASIC_HASH`). Caddy proxies `/api/*` to `analyticsapi:4300`
and serves this SPA from `./caddy/admin` for everything else.

To ship a new build:

```bash
npm run build
# from the backend repo's deploy dir on the server (~/treepnet):
#   rm -rf caddy/admin/* && copy this repo's dist/ into caddy/admin/
# Caddy serves it immediately; no restart needed.
```

Chat analytics and the System-health tab are intentionally out of scope for v1
(chat lives in its own `chat` database; system health needs an infra metrics
endpoint). The relevant views and tabs have been removed.
