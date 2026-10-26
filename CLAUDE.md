# LuzHire — guide for Claude Code

LuzHire is a job portal (successor to CareerConnect): candidates, employers and admins, with realtime updates.
Read these first:
- `docs/HANDOVER.md`: what is where, operations and open items
- `docs/ARCHITECTURE.md`: the architecture, data model, RLS rules and phased build plan (§10)
- `DESIGN.md`: the design system (accessible neumorphism, Spotlight and Workspace zones, light and dark themes). Every UI change must use its tokens.

## Stack
| Layer | Tech | Location |
|---|---|---|
| Client (web, Android, iOS) | Flutter / Dart, Riverpod, go_router | `app/` |
| Auth | Firebase Authentication (custom claims `role`, `app_role`) | — |
| Data / realtime / storage | Supabase (Postgres + RLS, Realtime, Storage) | `supabase/` |
| Server functions | TypeScript on Vercel Functions (Node 24) | `api/` (tests in `tests/api/`) |
| Hosting | Vercel (Flutter web is prebuilt in GitHub Actions) | `vercel.json`, `.github/workflows/` |

## Commands
```bash
# Flutter app (run from app/)
flutter pub get
flutter run -d chrome --dart-define-from-file=env/local.json   # env/local.json: see docs/SETUP.md (git-ignored)
flutter analyze
flutter test
dart format lib test
flutter build web --wasm --release --no-web-resources-cdn --dart-define-from-file=env/example.json

# API + database (run from repo root)
npm run typecheck
npm test
npx supabase start        # local Postgres/Realtime/Storage (needs Docker)
npx supabase db reset     # apply migrations + seed
npx supabase test db      # pgTAP RLS tests
npm run db:check          # same migrations + pgTAP tests in PGlite, no Docker needed
```
The Flutter SDK (3.47.7 or newer) is on the user PATH: `C:\Users\SUMA\dev\flutter\bin` on the old laptop, `C:\Users\jeswi\OneDrive\Desktop\flutter_windows_3.38.4-stable\flutter\bin` on the new one.

## Conventions
- **Flutter:** feature-first (`lib/features/<feature>/{data,domain,presentation}`), shared code in `lib/core/`. Use the Riverpod providers for state. Models use freezed. Never hardcode colours, radii, shadows or text styles. Use `LuzTokens` / `context.luz` and the `Luz*` widgets in `lib/core/widgets/`.
- **Neumorphism accessibility** (DESIGN.md §2): shadows never carry meaning alone. Inputs get an outline, selection gets an orange indicator, and focus gets a visible ring.
- **Database:** every invariant lives in Postgres (constraints, triggers, RLS). User IDs are Firebase UIDs (`text`). RLS uses `app.uid()` / `app.role()`, never `auth.uid()`. Trigger functions that call `app.is_privileged()` must NOT be `SECURITY DEFINER` (inside them `current_user` is the owner). Add a pgTAP test for every new policy or rule, and keep Dart enums in `lib/core/data/enums.dart` in sync with SQL enums (a test enforces this).
- **Secrets:** only public client config (Supabase URL, anon key, Firebase options) goes in `app/env/*.json`, and those files are gitignored except `example.json`. The service-role key and third-party keys live only in Vercel env vars.
- Files in `api/` become Vercel Functions. Helpers go in `api/_lib/`, and tests stay out of `api/`.

## Git
- Commits must be credited to **jeswinbenedict**. Before committing, verify that `git config user.email` is `251479040+jeswinbenedict@users.noreply.github.com`.
- **Do not add `Co-Authored-By: Claude` or any other Claude attribution** to commits or PR descriptions in this repo (owner's instruction).
- Remote: `https://github.com/jeswinbenedict/LuzHire.git`, branch `main`.

## Status
The phase plan, status, definition of done and owner inputs are in **`docs/ROADMAP.md`**. Update it at the end of every phase.
- [x] Phase 0: Foundation
- [x] Phase 1: Design system & adaptive shell. Components, layout kit, shells, Stitch designs (`docs/design/`) and the live Vercel deploy
- [x] Phase 2: Backend foundation. Schema, RLS, storage, search, seed, 57 pgTAP assertions and the Dart data layer are done (branch `phase-2-backend`). CI green and applied to the cloud project
- [x] Phase 3: Auth. API, screens, guards and tests, live on Vercel with Firebase + Supabase (real sign-up verified)
- [x] Phase 4: Public job board. Search, detail, companies and saved jobs are live with about 1,800 imported jobs and a live new-jobs banner (PRs #35, #39)
- [~] Phase 5: Candidate portal. Dashboard, profile, resumes, apply, live tracker, interviews, offers and notifications are live on main, with the redesigned dashboard (#40), `.ics` calendar files and drag-and-drop resumes (#41). Still to do: a live check with real accounts
- [~] Phase 6: Employer workspace. Company, team invites, job editor, realtime pipeline, interviews, offers and analytics are live on main. Workspace company switcher live (#36). Still to do: a live end-to-end hire
- [~] Phase 7: Admin console. Verification, moderation and reports, users (role, suspend), announcements, audit log and stats are live on main. Still to do: the first admin account
- [~] Phase 8: Ingestion and SEO. Remotive/Adzuna imports (daily cron), SEO job pages, sitemap and robots are live on main (daily import running). Live job feeds (Greenhouse/Lever/Ashby career boards of 39 India employers, Himalayas, Jobicy, Remote OK) and company logos are live on main (PRs #19–#30). Still to do: optional Adzuna keys
- [~] Phase 9: Notifications. Preferences, push tokens, `/api/notify/dispatch` (FCM + SMTP email), settings page, workspace bell and web service worker are live on main; web push and email verified live. Still to do: Android push (Android app in Firebase + a phone), Outlook rendering check
- [~] Phase 10: Hardening. Security invariants, rate limits, enforced CSP (Firebase SDK loads from `web/firebase-sdk.js`), secret scan, font/preload/logo performance work, WCAG checks and fixes, deep health, uptime check and error log are live on main (`docs/HARDENING.md`). Load test done (see HARDENING.md). Keyboard checks on 32 screens (`test/keyboard_test.dart`, #42). Still to do: manual screen-reader pass
- [x] Discovery features (PRs #8–#11, #21–#34): company directory with logos, career news with images, hiring map with jobs near you and recommendations, and events with imported contests and hackathons. Live on main; all migrations applied to the cloud database (last: `20261026120000`, 2026-10-26)
- [~] Phase 11: production is live with monitoring; release checklist, rollback plan and handover guide (`docs/RELEASE.md`, `docs/HANDOVER.md`) on main, with screen polish (#43) and the report screenshots (`docs/screenshots/`, #44). Still to do: the owner sign-off items in RELEASE.md §6
