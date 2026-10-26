<p align="center">
  <img src="brand/luzhire-logo-official.png" alt="LuzHire" width="420">
</p>

# LuzHire

A modern, full-stack online job portal designed to seamlessly connect talent with top opportunities.

LuzHire has verified employers and live application tracking. It runs on web, Android and iOS from one Flutter codebase, and its accessible neumorphic interface comes in light and dark themes.

| | |
|---|---|
| **Client** | Flutter (web, Android, iOS) |
| **Auth** | Firebase Authentication |
| **Data / realtime / storage** | Supabase (Postgres + RLS, Realtime, Storage) |
| **Server functions** | TypeScript on Vercel Functions |
| **Hosting** | Vercel |

**Live:** https://luzhire.vercel.app

## Documentation
- [Handover guide](docs/HANDOVER.md): start here. What it is, where things are, how to run and operate it
- [Architecture](docs/ARCHITECTURE.md): system design, data model, security
- [Roadmap](docs/ROADMAP.md): development phases and status
- [Design system](DESIGN.md): tokens, components, logo usage, accessibility rules
- [Setup](docs/SETUP.md): Firebase, Supabase, Vercel and GitHub settings; continuing on another computer
- [Release checklist and rollback plan](docs/RELEASE.md)
- [Hardening](docs/HARDENING.md): security, performance, accessibility and reliability work

## Run locally
```bash
cd app
flutter pub get
flutter run -d chrome --dart-define-from-file=env/example.json
```
`env/example.json` runs the app without sign-in or data. For the real services, recreate `env/local.json` as in [SETUP §7](docs/SETUP.md#7-continue-on-another-computer).

## Brand
The official logo is in [`brand/`](brand/), with a vector mark (`luzhire-mark.svg`) for app icons and UI. Usage rules are in [DESIGN.md §1a](DESIGN.md).

## License
[MIT](LICENSE) © 2026 A . Jeswin Karunya Benedict
