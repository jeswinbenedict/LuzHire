# Offline demo (localhost, no internet)

LuzHire runs fully on one laptop for a demonstration without internet: the
same app and the same server code as https://luzhire.vercel.app, against a
local copy of the database.

| Module | Address | Signs in | Demo account |
|---|---|---|---|
| Candidate | http://localhost:8081 | candidates | Tom — `tom@luzhire.local` |
| Recruiter | http://localhost:8082 | recruiters (employer accounts) | Lisa Immanuel — `lisa@luzhire.local` |
| Admin | http://localhost:8083 | admins | Jechu Emmanuel — `jechu@luzhire.local` |

The password of every demo account is the `DEMO_PASSWORD` value in
`tools/local/seed.mjs`. These accounts exist only in the local database.
Extra fictional accounts for a fuller demo: `candidate@luzhire.dev` (Asha
Verma, candidate) and `employer@luzhire.dev` (Meera Nair, recruiter), same
password.

Each module is its own origin, so the three can stay signed in side by side
in one browser (one tab each). A module only signs in its own role: Tom on
the Recruiter port is told to use the Candidate port.

## What runs where

```
browser ── :8081 / :8082 / :8083 ── tools/local/server.mjs
              │  the Flutter web build (app/build/demo)
              │  /api/*        the same functions as on Vercel (api/)
              │  /local-auth/* offline sign-in (api/_lib/local-identity.ts)
              ▼
        local Supabase in Docker (:54321) — Postgres with every migration,
        RLS, triggers, Realtime and Storage; data from supabase/seed.sql
```

- **Same code, different config.** The only differences from production are
  configuration: `AUTH_PROVIDER=local` in `app/env/demo.json` (generated)
  swaps Firebase sign-in for the local sign-in server, and the API runs with
  `LUZ_LOCAL_AUTH=1`. Roles, RLS, the hiring pipeline, notifications and
  every screen are the production code paths. The local identity is refused
  on Vercel.
- **One database.** All three modules use the same local Supabase, so an
  application Tom sends appears in Lisa's pipeline at once (Realtime), and a
  stage Lisa sets appears on Tom's tracker.
- **Offline.** Fonts, the app engine and the Firebase-free sign-in are all
  local. Things that need the internet by nature are off: Google sign-in,
  verification and notification emails, push notifications, map tiles on
  the hiring map, imported jobs/news (the demo uses seed data instead), and
  third-party company logos.

## Before the demo (once, with internet)

1. Install and start **Docker Desktop**.
2. From the repo root:

   ```bash
   npm install
   npm run demo:setup
   ```

   This downloads the database images (about 6 GB, once), creates the
   database with the demo data, the demo sign-ins and résumé files, and
   builds the app (`flutter` must be on the PATH, or set `FLUTTER` to its full path). Run it again after
   pulling new code.

## On demo day (no internet needed)

1. Start Docker Desktop.
2. `npm run demo` — starts the database and the three modules, and prints
   their addresses. Stop with Ctrl+C.
3. To start over with fresh demo data: `npm run demo:reset`, then
   `npm run demo`.

## Demo script

1. **Candidate** — http://localhost:8081 → sign in as Tom → *Find jobs* →
   open *Junior Flutter Developer* (Northstar Software): description,
   responsibilities, qualifications, skills, salary → *Apply* with his
   résumé → *My applications* shows it as **Applied**.
2. **Recruiter** — http://localhost:8082 → sign in as Lisa → *Pipeline* →
   Tom's application is in **Applied** → open it: profile, education,
   experience, skills, cover letter, résumé (PDF opens) → **Shortlist** →
   schedule an interview → *Make offer*, or **Reject**. Lisa can also edit
   her company (*Company*) and post a new job (*Jobs → New job*).
3. Back on the Candidate tab, Tom's application and notifications have
   updated live; he can accept the offer, which marks him **Hired**.
4. **Admin** — http://localhost:8083 → sign in as Jechu → *Overview*
   (platform numbers), *Verification* (companies), *Moderation* (jobs and
   reports), *Users* (roles, suspend, confirm email), *Announcements*,
   *Audit log* (every action above is recorded).

## Troubleshooting

| Problem | Fix |
|---|---|
| "Docker is not running" | Open Docker Desktop and wait for "running". |
| "No app build" | Run `npm run demo:setup` once (with internet). |
| Port 8081–8083 or 54321 in use | Close the other program, or `npx supabase stop` and retry. |
| Sign-in says the local server is not running | Keep the `npm run demo` window open. |
