# LuzHire — guide for Claude Code

LuzHire is a job portal (successor to CareerConnect): candidates, employers and admins, with realtime updates.
Read these first:
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
On this laptop the Flutter SDK is at `C:\Users\SUMA\dev\flutter\bin` (user PATH).

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
- [~] Phase 4: Public job board. Search, detail, companies and saved jobs are done (branch `phase-4-job-board`). Still to do: live new-jobs banner, real data
- [~] Phase 5: Candidate portal. Dashboard, profile, resumes, apply, live tracker, interviews, offers and notifications are live on main. Still to do: a live check with real accounts
- [~] Phase 6: Employer workspace. Company, team invites, job editor, realtime pipeline, interviews, offers and analytics are live on main. Still to do: a live end-to-end hire
- [~] Phase 7: Admin console. Verification, moderation and reports, users (role, suspend), announcements, audit log and stats are live on main. Still to do: the first admin account
- [ ] Phases 8–11: see ROADMAP
