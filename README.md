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

## Documentation
- [Architecture](docs/ARCHITECTURE.md): system design, data model, security
- [Roadmap](docs/ROADMAP.md): development phases and status
- [Design system](DESIGN.md): tokens, components, logo usage, accessibility rules

## Run locally
```bash
cd app
flutter pub get
flutter run -d chrome --dart-define-from-file=env/example.json
```

## Brand
The official logo is in [`brand/`](brand/), with a vector mark (`luzhire-mark.svg`) for app icons and UI. Usage rules are in [DESIGN.md §1a](DESIGN.md).

## License
[MIT](LICENSE) © 2026 A . Jeswin Karunya Benedict
