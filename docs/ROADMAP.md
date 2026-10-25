# LuzHire — Development Roadmap

How we get from the current scaffold to a production app hosted on Vercel. This file supersedes the phase table in `docs/ARCHITECTURE.md §10`; the architecture itself is unchanged.

**Product goal:** one Flutter codebase that is
- **responsive**: layouts reflow from 360 px phones up to 1440 px+ desktops (compact / medium / expanded / large breakpoints, DESIGN.md §10);
- **adaptive**: behaviour matches the device: touch vs mouse/keyboard, hover states, keyboard shortcuts on desktop web, platform back gestures and text-selection on Android/iOS, safe areas and notches, OS light/dark, text scaling, reduced motion, high contrast;
- **cross-platform**: web (primary, hosted on Vercel), Android and iOS builds from the same code.

---

## Overview

| # | Phase | Outcome | Needs from you | Status |
|---|---|---|---|---|
| 0 | Foundation | Monorepo, Flutter app, API, Supabase CLI, CI | — | ✅ Done (CI green on `b36df0c`) |
| 1 | Design system & adaptive shell | Neumorphic components, responsive/adaptive app shell, Stitch screen designs, first Vercel preview | Vercel account linked to GitHub | ✅ Done (live on luzhire.vercel.app; Stitch designs in `docs/design/`) |
| 2 | Backend foundation | Postgres schema, triggers, RLS, storage buckets, seed data, pgTAP tests in CI | Supabase project | ✅ Done (CI green; applied to the cloud project on 2026-10-19) |
| 3 | Authentication & roles | Firebase Auth (email + Google), Supabase third-party auth, role claims, guarded routes | Firebase project | ✅ Done (live sign-up verified 2026-10-19) |
| 4 | Public job board | Home, job search + filters, job detail, companies, saved jobs | — | 🟡 Live on main (Remotive imports fill the cloud database). Still needed: live "new jobs" banner |
| 5 | Candidate portal | Profile builder, resume upload, apply flow, realtime application tracker, interviews, offers | — | 🟡 Live on main (migration `20261019120000` applied to the cloud 2026-10-19). Still needed: a live check with real candidate and employer accounts |
| 6 | Employer workspace | Company profile + team, job editor, pipeline kanban (realtime), interviews, offers, analytics | — | 🟡 Live on main (migration `20261019130000` applied to the cloud 2026-10-19). Still needed: an end-to-end hire with real accounts, team switching for people in several companies |
| 7 | Admin console | Verification queue, moderation, users/roles, announcements, audit log, platform stats | — | 🟡 Live on main (migration `20261020120000` applied to the cloud 2026-10-20). Still needed: create the first admin account |
| 8 | Data ingestion & SEO | External job feeds, career news with relevance filter, SEO job pages, sitemap | Provider API keys (as Vercel env vars) | 🟡 Live on main (migration applied, `CRON_SECRET` set, first Remotive import of 10 jobs on 2026-10-20). Live job feeds (company career boards, Himalayas, Jobicy, Remote OK) on branch `phase-11-live-job-feeds`. Still needed: optional Adzuna keys |
| 9 | Notifications | In-app realtime centre, web/mobile push (FCM), transactional email | Email provider account (e.g. Resend) | 🟡 Live on main (web push and email verified 2026-10-20). Still needed: Android push (Firebase Android app + a phone), Outlook rendering check |
| 10 | Hardening | Performance budget, accessibility audit, security review, load test, monitoring | — | 🟡 Live on main (load test done 2026-10-20; see `docs/HARDENING.md`). Still needed: manual screen-reader and keyboard pass; Sentry optional |
| 10½ | Discovery features | Company directory with logos, career news, hiring map + recommendations, events | Run 5 migrations in Supabase; optional Adzuna keys | 🟡 Live on main (migrations applied 2026-10-21). Still needed: optional Adzuna keys |
| 11 | Production launch on Vercel | Production env + secrets, domain, release checklist, monitoring, handover docs; optional store builds | Domain (optional) | ⬜ |

Deployment is **continuous**, not left to the end. From Phase 1 onward every push to `main` deploys to Vercel; Phase 11 is the production cut-over and launch checklist.

---

## Way of working (every phase)

1. **Branch:** `phase-<n>-<name>` from `main`.
2. **Build** in small commits, credited only to `jeswinbenedict`, with no Claude co-author line (see CLAUDE.md).
3. **Definition of done**, checked before merge:
   - `flutter analyze` clean, `dart format` clean, all Flutter tests pass
   - `npm run typecheck` + `npm test` pass; pgTAP tests pass (from Phase 2)
   - Verified in the browser at 375 px, 768 px and 1280 px, in light **and** dark
   - Keyboard-only walkthrough of the new screens; no text below AA contrast
   - CI green on GitHub
4. **Merge:** push the branch, then you open and merge the PR on GitHub (or we merge to `main` directly if you prefer). Vercel deploys `main`.
5. **Update** the status column above and `CLAUDE.md`.

---

## Phase 0 — Foundation ✅
Delivered: monorepo (`app/`, `api/`, `supabase/`, `tests/`), Flutter 3.47 app for web, Android and iOS with Riverpod and go_router, `/api/health` Vercel function with a test, Supabase CLI init, `vercel.json`, CI workflow (analyze, test, WASM build) and prebuilt-deploy workflow, `CLAUDE.md`, `.gitattributes` and `.gitignore`.

## Phase 1 — Design system & adaptive shell ✅
**Done:** tokens, light/dark themes, relief painter, `LuzSurface`, `LuzButton`, `LuzIconButton`, `LuzTextField`, `LuzToggle`, `LuzFilterChip`, `LuzStatusChip`, `LuzCard`, `LuzDial`, design gallery, widget tests.
**Done on `phase-1-design-shell`:**
- Layout kit: `LuzBreakpoint`, `LuzContent`, `LuzGrid`, `LuzTwoPane`, `LuzInputModeScope` (touch vs pointer density)
- Adaptivity: path URLs (deep links), text scaling clamped at 200 %, Ctrl/⌘ K command menu (works while typing), "/" to search, adaptive modal (sheet on phones, dialog elsewhere)
- Components: modal/sheet/confirm, skeleton, empty state, toast, segmented tabs, checkbox, radio, range slider, avatar, logo socket, progress groove, hero search bar, data table, kanban column
- Shells: Spotlight (top nav ≥ 900 px; top bar + bottom nav + menu sheet below that) and Workspace (sidebar ≥ 1024 px, rail 600–1023, drawer below), routes for every section with phase placeholders, home hero
- 25 widget tests covering breakpoints, shells at each width, shortcuts, modal, slider, table and density

**Done on `phase-1-stitch-designs`:**
- Stitch project built from DESIGN.md: 11 light screens (home, job search, job detail, candidate dashboard on desktop and mobile; employer pipeline and admin queue on desktop) and 4 dark variants, saved with their HTML exports and a usage guide in `docs/design/`
- Home page rebuilt from the Stitch design: centred hero, popular-search chips, discipline tiles and an employer band (no invented statistics), with layout tests at 360, 768 and 1440 px
- Live on Vercel since Phase 3 (prebuilt deploy from GitHub Actions plus a smoke test)

**Original scope (kept for reference)**
- **Adaptive layout kit:** `LuzBreakpoint` helper (compact/medium/expanded/large), `AdaptiveScaffold` that swaps bottom nav ↔ navigation rail ↔ sidebar, two-pane list/detail layout, max-width content containers.
- **Platform adaptivity:** pointer vs touch density (`VisualDensity`), hover only on pointer devices, keyboard shortcuts (`Ctrl/⌘ K`, `/` to search, `Esc`), `SafeArea`, platform back handling (`PopScope`), adaptive dialogs (dialog on wide screens, bottom sheet on phones), text-scale and reduced-motion support.
- **More components:** `LuzBottomSheet`, `LuzDialog`, `LuzSkeleton`, `LuzEmptyState`, `LuzToast`, `LuzTabs`/segmented control, `LuzCheckbox`/`LuzRadio`, `LuzSlider` (salary range), `LuzAvatar`/logo socket, `LuzProgressGroove`, `LuzSearchBar` (hero), `LuzDataTable` (Workspace), `LuzKanbanColumn`.
- **App shells:** Spotlight shell (top nav / hamburger / candidate bottom bar) and Workspace shell (sidebar / rail / drawer + top bar), with placeholder routes for every section.
- **Stitch designs** (Stitch MCP; needs a session restart): home, job search, job detail, candidate dashboard, employer pipeline, admin queue, each in light, dark and mobile. Translate into the shells.
- **Vercel:** link the repo, add `VERCEL_TOKEN`, `VERCEL_ORG_ID` and `VERCEL_PROJECT_ID` as GitHub secrets, then get the first live deploy of the gallery and shells.

**Done when:** every component is in the gallery with tests; shells adapt correctly at all four breakpoints on web, Android emulator and an iOS layout check; the site is live on a `*.vercel.app` URL.
**You provide:** a Vercel account (sign in with GitHub as jeswinbenedict) and a Vercel token, plus a session restart so the Stitch tools load.

## Phase 2 — Backend foundation (Supabase) ✅
**Done on `phase-2-backend`:**
- 7 migrations: auth-claim helpers, enums, profiles + candidate data, companies + members, jobs (full-text + trigram search, moderation, slugs), notifications/announcements/reports/news, append-only audit log, application pipeline (state machine, events, interviews, offers, saved jobs), RLS on every table, storage buckets + policies, `search_jobs` RPC, realtime publication
- Business rules enforced in Postgres: duplicate applications are impossible, the deadline is enforced, stages can't be skipped, only candidates withdraw, offer acceptance marks the candidate hired, application counter, notifications, verification-gated publishing, and no self-promotion to admin
- Privacy: employers see a candidate only after that candidate applies, resumes are readable only by the owner or the hiring team for that application, and candidates read interviews through a view without private notes
- `seed.sql`: 24 fictional companies, 240 jobs, demo accounts
- 57 pgTAP assertions in `supabase/tests/database/`, run locally in PGlite (`npm run db:check`, no Docker needed) and in CI with the real Supabase stack
- Dart data layer: enums mirrored from SQL (a test catches drift), models, salary/time formatting, repositories for jobs, saved jobs, applications and notifications

**Cloud project (done 2026-10-19):** all 7 migrations were applied to `bvwvabpykvyxkifievqf` in one transaction from the Supabase SQL editor and recorded in `supabase_migrations.schema_migrations`, so a later `supabase db push` only sends new migrations. Verified there: 21 tables, all with RLS, 46 table policies, 13 storage policies, 4 buckets, 31 triggers, and realtime on notifications, applications, offers and saved_jobs. The demo seed stays local-only (docs/SETUP.md).

**Original scope:**
- Migrations: enums, all tables from ARCHITECTURE §6 (profiles, educations, experiences, skills, resumes, companies, company_members, jobs, job_skills, applications, stage transitions, application_events, interviews, offers, saved_jobs, notifications, announcements, reports, audit_logs, news_articles).
- Triggers: application counter, apply guard (published, deadline, verified email), stage-transition guard + history, notification fan-out, job moderation, audit log, `updated_at`, profile completion.
- RLS policies for every table; `app.uid()` / `app.role()` helpers; append-only audit log.
- Storage buckets and policies (avatars, company-media, private resumes with signed-URL RPC, offer letters).
- Full-text search: `tsvector`, GIN and trigram indexes, `search_jobs` RPC with keyset pagination.
- Seed data (≈ 50 companies, 500 jobs, demo users per role).
- pgTAP tests for every policy and trigger, run in CI (GitHub runners have Docker for `supabase start`).
- Typed Dart data layer: freezed models + repositories per feature.

**Done when:** `supabase db reset` + `supabase test db` pass in CI; migrations are applied to the cloud project.
**You provide:** a Supabase project (free tier is fine for development). Send its **project URL and anon key** only; you'll enter the DB password and service-role key yourself as secrets.

## Phase 3 — Authentication & roles ✅
**Done on `phase-3-auth`:**
- API: `POST /api/auth/bootstrap` sets `role=authenticated` + `app_role` claims and creates the profile. It is idempotent and never grants admin. `POST /api/admin/users/:id/role` is admin-only: it updates claims and profile, signs the user out, and writes an audit entry. CORS allows localhost outside production. 10 Vitest tests.
- Flutter: `AppConfig` from dart-defines (public values only), Firebase + Supabase start-up with the Firebase ID token as Supabase `accessToken` (anon until claims exist), and an `AuthGateway` (Firebase or disabled), `AuthController` and `AccountApi`.
- Screens: sign in, sign up (role choice, `?role=employer`), verify email (resend cooldown), forgot password (no account enumeration), choose role (first Google sign-in), no access, account (theme and sign out), and session loading.
- Router guards: role areas (`/me` candidate, `/employer` employer+admin, `/admin` admin), return-to-`from` with open-redirect protection, a verify-email hold, and choose-role. Shells show an avatar menu or "Finish setup" depending on state.
- Tests: 11 redirect unit tests and 11 end-to-end auth journeys (fakes), 70 app tests in total.

**Live (2026-10-19):** a real employer sign-up on luzhire.vercel.app called `/api/auth/bootstrap` (200) and created the matching `profiles` row in the cloud database. Fixes found on the way: firebase-admin needs `jose` 5 on Vercel's runtime (package.json override), only Firebase `auth/*` errors map to 401 (misconfiguration now shows as 503), and `FIREBASE_SERVICE_ACCOUNT` is accepted as raw or base64 JSON. Android sign-in still needs the Android app registered in Firebase (Phase 11, optional store builds).

**Original scope:**
- Firebase project; Email/Password + Google providers; Flutter `firebase_core` / `firebase_auth` for web, Android and iOS.
- Supabase Third-Party Auth (Firebase) configured; `accessToken` callback in `Supabase.initialize`.
- `/api/auth/bootstrap` (Firebase Admin SDK on Vercel): sets `role: authenticated` and `app_role`, creates the profile row; `/api/admin/users/:id/role`.
- Screens: sign in, sign up (role choice), verify email, forgot password, account settings; theme preference synced to profile.
- go_router guards by role and email-verified state; deep links preserved through login.
- Tests: claim-escalation attempt fails; candidate cannot read another profile (pgTAP); widget tests for auth forms.

**Done when:** a new user can sign up on web and Android, lands on the right dashboard, and RLS sees their claims.
**You provide:** a Firebase project. You add the Firebase Admin service-account JSON as a Vercel env var yourself; never paste it in chat.

## Phase 4 — Public job board (Spotlight) 🟡
**Done on `phase-4-job-board`** (built from the Stitch designs in `docs/design/`):
- Job search at `/jobs`: keyword + location, remote, job type, experience, minimum salary, date posted and skills. Every filter lives in the URL, so links are shareable. Layouts: filters | results | live preview at ≥ 1360 px, filters | results from 1024 px, and a "Filters (n)" bottom sheet on phones. Keyset pagination loads the next page while you scroll (with a "Load more" fallback), plus skeletons, empty, error and "not available in this build" states.
- Job detail at `/jobs/:slug`: header chips, description (small Markdown renderer), responsibilities, requirements, skills, benefits, a company card and "More from <company>". The apply panel (salary, apply, save, copy link, posted / deadline / applicant count) is sticky on desktop and a pinned bottom bar on phones. External jobs open the source site. Native jobs ask visitors to sign in; the in-app apply form comes in Phase 5.
- Companies at `/companies` (search, verified badge) and `/companies/:slug` (about, benefits, open roles).
- Saved jobs: a bookmark on every card, synced through Realtime with instant optimistic feedback, the `/me/saved` page, and visitors offered sign-in.
- Home: "Latest jobs" (real postings only; hidden when there are none).
- 19 widget tests against in-memory repositories (94 app tests in total).

**Still to do:** the live "new jobs" banner (Realtime broadcast), and real jobs in the cloud database. It is empty until employers post (Phase 6) or feeds are ingested (Phase 8). The seed stays local-only.

**Original scope:**
- Home (hero search, categories, live "new jobs" banner via Realtime broadcast, honest stats).
- Job search: keyword + filters (location, remote, type, level, salary slider, skills, posted date), filter bottom sheet on phones / side panel on desktop, list ↔ two-pane detail on expanded, infinite keyset pagination, URL-synced filters (shareable links).
- Job detail (sticky apply panel/bar, company card, similar jobs), companies directory + company page, saved jobs (bookmark ribbon, synced).
- Empty, error and loading states; skeletons.

**Done when:** search p95 < 300 ms on seed data; all states verified at three widths in both themes.

## Phase 5 — Candidate portal 🟡
**Done on `phase-5-candidate-portal`** (from the Stitch candidate-dashboard designs):
- Dashboard `/me`: greeting, profile-strength groove, real-count tiles (active applications, upcoming interviews, saved jobs, offers to answer), recent applications with stage steppers, upcoming interviews and a live notification list (mark read / mark all read, tap to open the application). Full list at `/me/notifications`.
- Profile builder `/me/profile`: about-you form (name, headline, location, phone, bio, LinkedIn/GitHub/portfolio with validation), photo upload (avatars bucket), skills (add, remove, suggestions), experience and education with add/edit/delete forms, and "next steps" that mirror the database completion score.
- Resumes: PDF/DOCX upload up to 5 MB to the private bucket, primary resume (atomic `set_primary_resume` RPC, new migration `20261019120000_candidate_portal.sql`), view through a 10-minute signed link, delete.
- Apply flow: from the job page, pick a resume (primary preselected), upload one inline, or apply without one, plus an optional cover letter (6,000 characters). Database errors (duplicate, deadline, closed) show in the form. The job page then shows "Applied · <stage>".
- Live tracker `/me/applications` (Realtime): filters (all, in progress, offers, closed) and per application a stepper, timeline from `application_events`, interviews, offer (amount, start date, letter, accept/decline with confirmation), what was sent, and withdraw.
- Interviews `/me/interviews`: upcoming and past, calendar-page date, mode, join link, add to Google Calendar.
- The Ctrl/⌘ K command menu now lists only the pages the signed-in role may open.
- 14 widget tests (Realtime stage change, apply, withdraw, accept offer, profile validation, menu roles) and 8 pgTAP assertions (111 app tests, 65 database assertions).

**Deferred:** drag-and-drop resume tray on web (file picker only for now), resume parsing (`resumes.parsed`), and `.ics` downloads (Google Calendar link instead). The "< 1 s" stage-change check needs the employer pipeline (Phase 6).

**Original scope:**
- Dashboard (completeness groove, applications, upcoming interviews, saved, recommended).
- Profile builder (headline, bio, links, skills, education, experience) with completion %.
- Resume upload (drag-and-drop tray on web, file picker on mobile), preview, primary resume.
- Apply flow (resume + cover letter, duplicate and deadline errors), applications tracker with **realtime** stage chips and timeline, interviews (calendar pages, add-to-calendar), offers (accept/decline).
- Notification centre (realtime, mark read).

**Done when:** an employer stage change appears on the candidate screen in < 1 s.

## Phase 6 — Employer workspace 🟡
**Done on `phase-6-employer-workspace`** (Linear-style Workspace zone, from the Stitch pipeline design):
- Onboarding: an employer without a company creates one (becoming its owner) or accepts a team invitation.
- Company & team `/employer/company`: profile form (name, industry, size, website, HQ, about, benefits), logo upload, a verification card ("Request verification" for owners), team list with roles (owners switch recruiter/viewer or remove members), and email invitations with revoke. New migration `20261019130000_employer_workspace.sql`: `company_invites` with RLS, `accept_company_invite` RPC and `app.email()`.
- Jobs `/employer/jobs`: sortable table (status, applicants, posted), and an editor (`/employer/jobs/new`, `/employer/jobs/:id`) with a live search-card preview, validation (title, salary range, deadline), skills, publish, draft, close, reopen, archive and delete-draft. Unverified companies' jobs go to "Pending review" (enforced in Postgres) and the toast explains it.
- Pipeline `/employer/pipeline?job=…`: realtime kanban with all stages. Drag and drop on desktop (long-press on touch) accepts only the moves the database allows, and dropping on "Offer issued" opens the offer form. The candidate panel (side panel ≥ 1200 px, full screen below) has "Move to" buttons (keyboard path), confirm-before-reject, resume via signed link, cover letter, skills, experience, education, links, history, interviews (complete / no-show / cancel) and the offer (withdraw).
- Interviews: schedule form (date, time, length, video/phone/in-person with link or address, private notes the candidate never sees) and a company-wide list `/employer/interviews`.
- Offers: amount, currency, period, start date, reply-by date and an optional PDF letter (offer-letters bucket). Only from HR interview or final review, matching the transition table.
- Overview `/employer` and Analytics `/employer/analytics`: real counts only, from `company_hiring_stats` (runs under the caller's RLS). Funnel, applications per week, average time to hire, and job status counts.
- Viewer role: read-only everywhere. 13 widget tests (onboarding, invites, review flow, live move, drag rules, interview and offer forms, viewer, analytics) and 12 pgTAP assertions (125 app tests, 77 database assertions).

**Still to do:** a full hire with real accounts on the live site, and team switching for people in several companies (the switcher exists on the company page).

**Original scope:**
- Company profile + verification request; team invites (owner, recruiter, viewer).
- Job editor (draft → publish / pending review) with live card preview.
- Pipeline kanban per job (drag-and-drop + keyboard move, Realtime broadcast), candidate drawer (profile, resume via signed URL, history), bulk actions.
- Interview scheduler (timezone-aware), offers, analytics (funnel, time-to-hire) with real data only.
- Command menu (`Ctrl/⌘ K`).

**Done when:** a full hire flow (post → apply → interview → offer → hired) passes as an integration test.

## Phase 7 — Admin console 🟡
**Done on `phase-7-admin-console`:**
- Overview `/admin`: queues that need attention (companies to verify, jobs to review, open reports), user, company, job and application counts, and sign-ups per week, all from `admin_platform_stats`.
- Verification `/admin/verification`: verify or decline (with a reason) companies that asked. The company owners and recruiters are notified.
- Moderation `/admin/moderation`: publish or reject jobs waiting for review, and handle reports (take a job down with a reason, mark actioned, dismiss). The reporter is thanked when it is resolved. Anyone signed in can report a job or company from its public page.
- Users `/admin/users`: search, filter by role or suspended, change role (API: claims + sign-out + audit) and suspend or reactivate. Suspension goes through the new `POST /api/admin/users/:id/status`, which updates the profile, disables Firebase sign-in, revokes sessions and audits. Postgres also blocks every write from a suspended account at once (restrictive RLS through `app.is_active()`), even before its last token expires. Admins cannot change their own role or status.
- Announcements `/admin/announcements`: create, edit, publish or keep as a draft, choose the audience, and delete. Published ones show as a dismissible banner on Home, the candidate dashboard and the employer overview.
- Audit log `/admin/audit`: newest first, filter by table or actor, load more, and the JSON diff of each change. Entries stay append-only.
- New migration `20261020120000_admin_console.sql` (review RPCs, `resolve_report`, stats, suspension guards), 16 pgTAP assertions, 3 API tests and 14 widget tests (93 database assertions, 16 API tests, 142 app tests).

**First admin:** the owner lists their email in the Vercel variable `ADMIN_EMAILS`, signs in and uses Account → Claim admin access (`POST /api/auth/claim-admin`: verified email on the list only, audited). Afterwards the email is removed from the list, and further admins are promoted from Users in the console.

**Original scope:**
- Verification queue, job moderation queue, reports, user management (suspend, role change), announcements, audit-log viewer (filters, JSON diff in mono), platform stats.

**Done when:** every admin action creates an audit row and is reversible where it should be.

## Phase 8 — Data ingestion & SEO 🟡
**Done on `phase-8-ingestion-seo`:**
- Daily import `GET /api/ingest/jobs` (Vercel Cron at 07:00 IST, `Authorization: Bearer $CRON_SECRET`). Providers, chosen after reading their terms:
  - **Remotive** (worldwide remote, no key): one call a day (their limit is 4), links back and names Remotive on every listing, and never passes jobs to Google Jobs. External pages are `noindex` with no JobPosting markup. The free feed can be a sample, so missing jobs close only when the feed reports it is complete; otherwise they expire after 30 days.
  - **Adzuna India** (optional, free keys): "Jobs by Adzuna" link on every listing. Estimated ("predicted") salaries are not shown as real ones.
  - Arbeitnow was skipped (mostly German-language European jobs).
- Normalisation: untrusted HTML becomes the app's small Markdown subset (scripts and links dropped), titles become plain text, salary text is read only when unambiguous ("12–18 LPA", "$80–100k", "$45/hour"; "per task" stays blank), employment types are mapped, tags link to existing skills, duplicates are removed within a feed and across providers, and each run is logged in `ingest_runs` (new migration `20261020130000_ingestion.sql`, shown on the admin overview).
- SEO: `/jobs/:slug` is served by `api/seo/job`: the app's own index.html with the job's title, description, canonical URL and Open Graph tags, JobPosting JSON-LD for LuzHire's own jobs, 404 for unknown and 410 for closed jobs, and a `<noscript>` summary. The Flutter app then boots as normal. `/sitemap.xml` lists public pages, native jobs and verified companies, and `robots.txt` keeps private areas out. The deploy smoke test now checks robots, the sitemap and the 404.
- Tests: 13 ingestion tests, 6 SEO tests (39 API), 4 pgTAP assertions (97 database), plus attribution and imports widget tests (146 app).

**Career news:** done in the discovery features (#9, below).

**Live job feeds (branch `phase-11-live-job-feeds`, 2026-10-23).** The cloud database had only 9 jobs (the free Remotive feed now lists 9 in total), so more sources were added, each checked against its terms:
- **Company career boards** (`GET /api/ingest/companies`, own daily cron at 06:45 IST): the public job-board APIs of Greenhouse, Lever and Ashby, for a curated list of 39 companies hiring in India (`api/_lib/ingest/boards.ts`: Databricks, MongoDB, Okta, Stripe, Razorpay, Groww, Paytm, Meesho, CRED, Sarvam AI and others). Only roles located in India are kept (about 1,200 on 2026-10-23). These boards are the employers' own, so a listed role stays open however old it is, and a role that leaves its board is closed, but only for boards that answered that day (a failing board is logged, not emptied). Cards say "From the company careers page".
- **Remote feeds** in the existing `/api/ingest/jobs` run: **Himalayas** (remote jobs open to people in India, about 200 a day; credited with a link, the application link kept unchanged, never passed to Google Jobs), **Jobicy** (APAC and worldwide remote; credited and linked) and **Remote OK** (worldwide or Asia only; credited with a followed link, their logo never used).
- Providers in a run now download side by side, and the stored-job lookup reads in pages (PostgREST returns 1,000 rows at most). Himalayas logos load through `/api/img` (no CORS on their CDN).
- No database migration: everything fits the Phase 8 columns. Tests: 10 new ingestion tests (87 API) and a source-credit test (Flutter).
To add a company, check that its board lists India roles and add `{ token, name, domain }` to the right list in `boards.ts`.

**Company logos (2026-10-25).** Career boards send no logos, so each board has its company's `domain` and jobs carry its site icon (Google's favicon service, through `/api/img`). Feeds that send no logo (Remote OK, some Himalayas companies) go through `api/_lib/ingest/logos.ts` on every import: a logo already stored for the company is reused; otherwise the company's site is taken from links in the description or a Clearbit name lookup (a `.com` named exactly like the company, or the single exact match; never a guess between same-named companies), and its icon is checked before use. After each import, stored published jobs still without a logo are filled in too (feeds such as Himalayas list only their newest jobs, so older ones never pass through the import again). Companies with no findable site show a tinted initials tile in the app and are tried again each run. On 2026-10-25 this found logos for 29 of the 64 companies that had none.

**Original scope:**
- `/api/ingest/jobs`: provider adapters, normalisation (salary period!), HTML → Markdown sanitising, cross-provider dedupe, expiry; scheduled by Supabase `pg_cron` + `pg_net`.
- `/api/ingest/news`: career-specific sources + relevance scoring; Career News screen.
- SEO: `/jobs/:slug` server-rendered HTML with JobPosting JSON-LD, `/sitemap.xml`, `/robots.txt`, correct 404/410.

**Done when:** Google Rich Results Test passes on a job page; no off-topic news items get through.
**You provide:** API keys for chosen providers (entered as Vercel env vars), after checking their terms.

## Phase 9 — Notifications
**Status: live on main and verified** (migration applied; mailbox, `NOTIFY_SECRET` and Supabase webhook set up; a live test delivered web push and email on 2026-10-20; 116 pgTAP assertions, 53 API tests, 166 Flutter tests). Still to do: Android push (needs the Android app registered in Firebase and a phone), an Outlook rendering check.
- In-app (already realtime) + preferences screen.
- Push: FCM for web (service worker) and Android/iOS; DB webhook → `/api/notify/dispatch`.
- Transactional email templates (application received, stage change, interview, offer).

**Done when:** push arrives on web and Android; emails render in Gmail and Outlook.

## Phase 10 — Hardening
**Status: live on main** (see `docs/HARDENING.md`: RLS and security-definer invariants in pgTAP and on the cloud database, API rate limits, enforced CSP with violation reports, gitleaks in CI, font subsetting and preloads, logo proxy, WCAG checks on 14 screens with fixes, deep health check, uptime workflow, error log; LCP ≤ 1.3 s). Load test done (database copes with 500 users searching every 2 s). Search results trimmed to job cards, about 9× smaller (migration `20261020170000`, applied to the cloud on 2026-10-21 with the discovery migrations). Still to do: a manual screen-reader and keyboard pass, Sentry (optional).
- Performance: deferred imports for employer/admin, image sizing, bundle check, Lighthouse on SEO pages, LCP ≤ 2.5 s on mid-range mobile.
- Accessibility: full WCAG 2.1 AA pass (screen reader on web/Android, keyboard, contrast, 200 % text).
- Security: RLS review, OWASP checklist, CSP headers, rate limits on API, dependency audit, secret scan.
- Reliability: Sentry (Flutter + functions), `/api/health` uptime monitor, Supabase backups, load test (500 concurrent users).

## Phase 10½ — Discovery features (PRs #8–#11) 🟡
**Live on main.** Migrations `20261020170000`, `20261021120000`, `20261021130000`, `20261021140000` and `20261021150000` were applied to the cloud database on 2026-10-21 (one transaction from the SQL editor, recorded in `schema_migrations`). Still to do: first news import (runs at the next morning cron), optional Adzuna India keys for located jobs.
- **Companies directory with every hiring company** (#8): the `company_directory` view adds the companies behind imported jobs, with their feed logo and open-role counts; imported companies get `/companies/jobs-at-<name>`; job cards show LuzHire companies' own logos; Home shows "Companies hiring now".
- **Career news** (#9): `/api/ingest/news` (daily cron) imports linked headlines from Remotive's blog, DEV #career and freeCodeCamp, filtered to career topics. DEV's feed has no images: headlines are saved first, then up to 60 still without an image get one from DEV's articles API (one request), or else from their article page's preview image (`og:image`, only on those three sites, within a 20 s budget so the run stays under the 60 s limit) (2026-10-25); admins write articles at `/admin/news` (read at `/news/:slug`), feature stories and hide headlines; `/news` has topics, a featured row and Home section.
- **Hiring map, jobs near you, recommendations** (#10): a `cities` gazetteer geocodes jobs; `/jobs/map` (OpenStreetMap tiles) shows open roles per city and "Jobs near me" by device location; `recommended_jobs()` ranks jobs by skills, headline, city and freshness with reasons ("Picked for you" on Home). Adzuna India keys would add located Indian jobs without code changes.
- **Imported events (2026-10-25):** `/api/ingest/events` (daily cron, 07:30 IST) imports upcoming coding contests from Codeforces' official API and hackathons from Hack Club's open hackathon directory (online and hybrid ones, in-person only in Asia-Pacific/India), credited "via Hack Club", with registration on the organiser's site. Future events that leave a source's list are cancelled. Migration `20261025120000_event_imports.sql` adds `external_source`/`external_id` (only the import may set them; 6 pgTAP assertions) and must be applied in the Supabase SQL editor. Devpost and MLH were left out: their terms forbid republishing listings. Hiring drives and webinars still come from employers on LuzHire.
- **Opportunities** (#11): Unstop-style `/events` for walk-in and campus drives, hiring challenges, hackathons, competitions and webinars; in-app (individual or team) or external registration with deadline and capacity enforced in Postgres; `/employer/events` with registrants and `/admin/events` review; events on the hiring map.

## Phase 11 — Production launch on Vercel
- Production Supabase project (Pro plan recommended: no auto-pause, daily backups) + production Firebase project.
- Vercel production env vars, custom domain (optional), HTTPS, security headers and CSP enforced.
- Release checklist and rollback plan; seed real admin account; smoke tests on the live URL.
- Handover docs: README, setup guide, demo accounts, architecture + design docs, and a screenshot set for the project report.
- Optional: Android APK/AAB and iOS TestFlight builds.

**Done when:** the production URL passes the smoke test and the release checklist is signed off.

---

## Inputs checklist (what only you can do)

| When | Item | How to share safely |
|---|---|---|
| Phase 1 | Vercel account linked to GitHub `jeswinbenedict`, plus a Vercel token | Add the token yourself as GitHub secret `VERCEL_TOKEN` |
| Phase 1 | Restart the Claude session (loads Stitch tools) | — |
| Phase 2 | Supabase project | URL + anon key are public, so you can paste them. Keep the service-role key and DB password in secrets only |
| Phase 3 | Firebase project (web, Android, iOS apps registered) | Web config is public. Service-account JSON goes into Vercel env vars only |
| Phase 8 | Job/news provider API keys | Vercel env vars only |
| Phase 9 | Sending mailbox (e.g. a Gmail with an app password), `NOTIFY_SECRET`, Supabase webhook | Vercel env vars + Supabase dashboard (SETUP.md §6) |
| Phase 11 | Domain (optional) | DNS settings in Vercel |
