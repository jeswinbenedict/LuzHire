# LuzHire — Handover guide

Everything a new owner, maintainer or examiner needs to understand, run and operate LuzHire. Last updated 2026-10-26.

---

## 1. What LuzHire is

LuzHire is a job portal for India with three kinds of user:
- **Candidates** search jobs, build a profile, upload resumes, apply, and follow each application live, through interviews and offers.
- **Employers** create a company, invite a team, post jobs, move applicants through a live pipeline, schedule interviews, send offers and run hiring events.
- **Admins** verify companies, moderate jobs and reports, manage users, publish announcements and read the audit log.

It also fills itself with public data every day: jobs from company career boards and remote-job feeds, career news, and coding contests and hackathons.

**Live site:** https://luzhire.vercel.app · **Code:** https://github.com/jeswinbenedict/LuzHire

## 2. How it is built (one line each)

| Part | Technology | Where |
|---|---|---|
| App (web, Android, iOS) | Flutter, Riverpod, go_router, built as WebAssembly for the web | `app/` |
| Sign-in | Firebase Authentication (email and Google) with role claims | Firebase console |
| Database, realtime, files | Supabase: Postgres with row-level security, Realtime, Storage | `supabase/` |
| Server code | TypeScript Vercel Functions (Node 24), serverless | `api/` |
| Hosting and daily jobs | Vercel (site, functions, cron) | `vercel.json` |
| Build and checks | GitHub Actions: CI, deploy, uptime | `.github/workflows/` |

The full design is in `docs/ARCHITECTURE.md`. The visual design system is in `DESIGN.md`.

## 3. Where things are in the code

| Folder | What it holds |
|---|---|
| `app/lib/features/<feature>/` | One folder per area: `jobs`, `companies`, `candidate`, `employer`, `admin`, `events`, `news`, `notifications`, `auth`, `home`. Each has `data/` (repositories), `application/` (Riverpod providers) and `presentation/` (pages and widgets). |
| `app/lib/core/` | Shared code: theme tokens, `Luz*` widgets, shells, router, data models and enums. |
| `app/test/` | Widget and unit tests, with in-memory fakes in `test/support/`. |
| `api/` | One file per Vercel Function (12 at most on the Hobby plan). Shared helpers are in `api/_lib/`. |
| `api/_lib/ingest/` | The job importers. `boards.ts` is the list of company career boards. |
| `api/_lib/news/`, `api/_lib/events/` | The news and events importers. |
| `supabase/migrations/` | The database, in order. **Every rule lives here**: constraints, triggers and RLS. |
| `supabase/tests/database/` | pgTAP tests for those rules (`npm run db:check`). |
| `tests/api/` | Vitest tests for the functions. |
| `docs/` | Architecture, roadmap, setup, hardening, release and this guide. |

## 4. Running it on a laptop

docs/SETUP.md §7 has the full steps. In short:
```bash
git clone https://github.com/jeswinbenedict/LuzHire.git
cd LuzHire && npm ci && cd app && flutter pub get
gh variable get APP_ENV_JSON > env/local.json   # then set "APP_ENV": "local"
flutter run -d chrome --dart-define-from-file=env/local.json
```
Checks: run `npm test` and `npm run db:check` from the repo root, and `flutter analyze` and `flutter test` in `app/`.

**Demo data:** `supabase/seed.sql` has fictional companies, jobs and demo people (`candidate@luzhire.dev`, `employer@luzhire.dev` and `admin@luzhire.dev`). It is for local databases only (`npx supabase db reset`), **never** the cloud project. On the live site, sign up with real accounts.

## 5. Accounts and services

The owner, jeswinbenedict, holds every account. No one else needs a login to run the site.

| Service | Used for | Where its settings live |
|---|---|---|
| GitHub | Code, CI, deploys and the uptime check | Repo **Settings → Secrets and variables** (`VERCEL_TOKEN`, `APP_ENV_JSON`, `VERCEL_ORG_ID`, `VERCEL_PROJECT_ID`) |
| Vercel (team `jechu2`, project `luzhire`) | Hosting, functions and the four daily crons | **Settings → Environment Variables** (docs/SETUP.md §3) |
| Supabase (project `bvwvabpykvyxkifievqf`, Mumbai) | Database, realtime, storage | Dashboard: SQL editor, webhooks, Third-party Auth (Firebase) |
| Firebase | Sign-in, push messaging | Firebase console: providers, authorized domains, service account |
| Mailbox (SMTP) | Notification emails | Vercel variables `SMTP_USER` and `SMTP_PASSWORD` (an app password) |

**Secrets stay in Vercel and GitHub only**: the service-role key, `CRON_SECRET`, `NOTIFY_SECRET`, the Firebase service account and the mail password. The files in `app/env/*.json` hold only public client config, and they are git-ignored apart from `example.json`.

## 6. Day-to-day operations

**Daily imports** (Vercel Cron, times in IST)

| Time | Route | What it imports |
|---|---|---|
| 06:45 | `/api/ingest/companies` | Greenhouse, Lever and Ashby career boards of 39 companies hiring in India (India roles only) |
| 07:00 | `/api/ingest/jobs` | Remotive, Himalayas, Jobicy, Remote OK (and Adzuna India if its keys are set) |
| 07:15 | `/api/ingest/news` | Career headlines from Remotive's blog, DEV and freeCodeCamp, with images |
| 07:30 | `/api/ingest/events` | Codeforces contests and Hack Club hackathons |

Each run is logged in `ingest_runs` and shown on the admin overview. To run one now: Vercel → **Cron Jobs → Run**.

Sources were chosen after reading their terms. **Do not add** Devpost, MLH, Naukri, Unstop or the GDG API: their terms or robots.txt forbid it.

**Common tasks**
- *Add a company's career board:* check that it lists India roles, then add `{ token, name, domain }` to the right list in `api/_lib/ingest/boards.ts`.
- *Change the database:* add a new file in `supabase/migrations/` and a pgTAP test, then apply it as in docs/RELEASE.md §2.
- *Make someone an admin:* an existing admin uses **Admin → Users → Change role**. That route is audited, and the person is signed out so the new role applies.
- *Hide a bad news item or job:* use **Admin → News** or **Admin → Moderation**.

**Monitoring**
- The **Uptime** workflow checks the site, the API and the database every 30 minutes. GitHub emails the owner if a check fails.
- `https://luzhire.vercel.app/api/health?deep=1` shows the live commit and whether the database answers.
- App errors and CSP violations land in the `app_errors` table (Supabase); the admin overview shows the latest 10.

**Releases and rollback:** see docs/RELEASE.md.

## 7. Known limits and open items

The status of each phase is in docs/ROADMAP.md. The items that need the owner are:
- **First admin account:** set `ADMIN_EMAILS` in Vercel, then use Account → Claim admin access.
- **A live end-to-end hire** with two real accounts.
- **Adzuna keys** (optional), for more located Indian jobs on the map.
- **Android push:** register the Android app in Firebase and test on a phone.
- **Outlook check** of the notification emails, and a manual **screen-reader pass**.
- **Supabase plan:** the free plan pauses a project after a week without activity (the daily imports should keep it awake) and has no daily backups. Pro is recommended for production.
- **Hiring drives and webinars** come only from employers. No source we may legally import from lists them.

## 8. Screenshot set for the project report

Capture each screen at 1280 px in light theme, plus the starred ones at 390 px (phone) and in dark theme. Save them in `docs/screenshots/`.

| # | Screen | URL |
|---|---|---|
| 1 ★ | Home | `/` |
| 2 ★ | Find jobs, with the preview pane | `/jobs` |
| 3 | Job page | `/jobs/<slug>` |
| 4 | Hiring map | `/jobs/map` |
| 5 | Companies directory | `/companies` |
| 6 | Career news | `/news` |
| 7 | Events | `/events` |
| 8 ★ | Candidate dashboard | `/me` |
| 9 | Application tracker | `/me/applications` |
| 10 ★ | Employer pipeline | `/employer/pipeline` |
| 11 | Job editor with live preview | `/employer/jobs/new` |
| 12 | Employer analytics | `/employer/analytics` |
| 13 | Admin overview | `/admin` |
| 14 | Admin audit log | `/admin/audit` |
| 15 | Sign in | `/sign-in` |
