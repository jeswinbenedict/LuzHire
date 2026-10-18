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
| Server functions | TypeScript on Vercel Functions (Node 22) | `api/` (tests in `tests/api/`) |
| Hosting | Vercel (Flutter web is prebuilt in GitHub Actions) | `vercel.json`, `.github/workflows/` |

## Commands
```bash
# Flutter app (run from app/)
flutter pub get
flutter run -d chrome --dart-define-from-file=env/local.json
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
```
On this laptop the Flutter SDK is at `C:\Users\SUMA\dev\flutter\bin` (user PATH).

## Conventions
- **Flutter:** feature-first (`lib/features/<feature>/{data,domain,presentation}`), shared code in `lib/core/`. Use the Riverpod providers for state. Models use freezed. Never hardcode colours, radii, shadows or text styles. Use `LuzTokens` / `context.luz` and the `Luz*` widgets in `lib/core/widgets/`.
- **Neumorphism accessibility** (DESIGN.md §2): shadows never carry meaning alone. Inputs get an outline, selection gets an amber indicator, and focus gets a visible ring.
- **Database:** every invariant lives in Postgres (constraints, triggers, RLS). User IDs are Firebase UIDs (`text`). RLS uses `app.uid()` / `app.role()`, never `auth.uid()`.
- **Secrets:** only public client config (Supabase URL, anon key, Firebase options) goes in `app/env/*.json`, and those files are gitignored except `example.json`. The service-role key and third-party keys live only in Vercel env vars.
- Files in `api/` become Vercel Functions. Helpers go in `api/_lib/`, and tests stay out of `api/`.

## Git
- Commits must be credited to **jeswinbenedict**. Before committing, verify that `git config user.email` is `251479040+jeswinbenedict@users.noreply.github.com`.
- **Do not add `Co-Authored-By: Claude` or any other Claude attribution** to commits or PR descriptions in this repo (owner's instruction).
- Remote: `https://github.com/jeswinbenedict/LuzHire.git`, branch `main`.

## Status
The phase plan, status, definition of done and owner inputs are in **`docs/ROADMAP.md`**. Update it at the end of every phase.
- [x] Phase 0: Foundation
- [~] Phase 1: Design system & adaptive shell. Components, layout kit, shells and routes are done (branch `phase-1-design-shell`). Still to do: Stitch screens, first Vercel deploy
- [ ] Phases 2–11: see ROADMAP
