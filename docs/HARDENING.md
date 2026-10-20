# Phase 10 — Hardening

What was checked, what changed, and what is still open. Measurements are on
the live site (`https://luzhire.vercel.app`) unless stated otherwise.

## Security

| Area | Control | Where |
|---|---|---|
| Access control (OWASP A01) | Row level security on **every** table; no policy lets visitors write; suspended users cannot write (restrictive policies). Enforced by pgTAP so a later migration cannot weaken it. | `supabase/tests/database/11_hardening.test.sql` |
| Privileged SQL (A01/A04) | Every `SECURITY DEFINER` function pins `search_path`; trigger functions that check `app.is_privileged()` are never `SECURITY DEFINER`. Both enforced by pgTAP. | same |
| Rate limits (A04/A07) | Per-IP fixed windows in Postgres (`public.rate_limit_hit`, server-only): sign-up bootstrap 20/min, claim-admin 5/10 min, admin actions 60/min, error reports 10/min. Answers `429` with `Retry-After`. Fails open if the counter is unreachable (tokens are still checked). | `api/_lib/rate-limit.ts`, migration `20261020150000` |
| Secrets (A02/A05) | Only public config in the client; service keys only in Vercel. Git history scanned (no keys, service accounts or env files); **gitleaks** now runs on every push over the full history (pinned 8.30.1, checksum-verified). | `.github/workflows/ci.yml` |
| Dependencies (A06) | `npm audit --omit=dev`: 0 vulnerabilities in what ships. Dev-only tooling (Vercel CLI) has advisories that do not reach production. New packages are pinned to releases at least two weeks old. | |
| Injection / XSS (A03) | All SQL through PostgREST or parameterised RPCs; SEO pages escape every value and JSON-LD is script-safe; emails escape user text; the image proxy serves raster images only, with `default-src 'none'; sandbox`. | `api/_lib/seo.ts`, `api/_lib/notify/messages.ts`, `api/_lib/image-proxy.ts` |
| SSRF (A10) | The image proxy only fetches `https://remotive.com` URLs, follows no redirects, caps size at 1 MB and times out after 5 s. | `api/_lib/image-proxy.ts` |
| Headers (A05) | HSTS (preload), `nosniff`, `Referrer-Policy`, `Permissions-Policy`, `X-Frame-Options: DENY`, `frame-ancestors 'none'`, COOP `same-origin-allow-popups` (Google sign-in pop-up keeps working). **Content-Security-Policy is enforced** with no `'unsafe-inline'` or `'unsafe-eval'` for scripts (only `'wasm-unsafe-eval'`, which Flutter's WASM build needs). It ran in report-only mode first; violations go to `/api/csp-report` and appear in the admin error log. Report-only found one source: FlutterFire injecting inline scripts to load the Firebase JS SDK. That SDK now loads from `web/firebase-sdk.js` (a test keeps its version and modules in sync with FlutterFire), and the splash script moved to `splash.js`. | `vercel.json`, `app/web/splash.js` |
| Logging (A09) | Unexpected API errors and app crashes go to an admin-only log (`public.app_errors`, 30-day retention, emails and tokens scrubbed, no user ids, no query strings). | `api/_lib/error-log.ts`, admin overview |

## Performance

Baseline (Lighthouse 13.5, mobile emulation, before Phase 10):

| Page | Perf | LCP | TBT | Transferred |
|---|---|---|---|---|
| `/` | 74 | 1.0 s | 720 ms | 3,781 KiB |
| `/jobs` | 72 | 0.8 s | 850 ms | 3,794 KiB |

LCP is already inside the 2.5 s target (the splash paints first). The cost is
the engine download and WASM start-up. Changes:

- **Fonts:** Flutter downloads every bundled font before the first frame. They are now subset to what LuzHire renders, and Inter's optical-size axis is pinned: 1,240 KB → 687 KB (`app/assets/fonts/README.md`).
- **Preloads:** the font manifest and fonts start downloading with the page instead of after `main.dart.wasm` (they used to begin at ~1.6 s, after a 270 ms `FontManifest.json` round trip).
- **Removed** the unused `cupertino_icons` package (one fewer start-up request).
- **Logos:** third-party job logos were blocked by CORS (they never showed and logged console errors). They now load through `/api/img`, cached for a week at the edge, and every network image decodes at its displayed size (`cacheWidth`).
- **Deferred loading:** measured, not adopted. Flutter 3.47 does not pass dart2wasm's `--enable-deferred-loading`, so deferred imports would not shrink the WASM download; they would only help the JavaScript fallback for old browsers. Revisit when Flutter supports multi-module WASM.

After (live, after deploy): see the table at the end of this file.

## Accessibility (WCAG 2.1 AA)

Automated in `app/test/accessibility_test.dart` (63 checks, run in CI):

- **Contrast:** every text colour on every surface and every chip is ≥ 4.5:1 in both themes; input outlines ≥ 3:1. This found two real failures, now fixed: success green (3.8:1 → 5.5:1, `#166534`) and the input outline on sunken wells (2.97:1 → 3.3:1, `#7D7973`). The pixel-based contrast check also runs on 14 screens in light and dark.
- **Labels:** every tappable control has an accessible name (14 screens, both themes).
- **Touch targets:** every control is ≥ 48 × 48 dp on phones (`LuzMinTarget`: icon buttons, text links, toggles, chips, account button, text and search fields). Mouse layouts keep their compact size.
- **200 % text:** 14 screens render at 200 % OS text size on a 375 px phone without clipping. Fixed: home hero badge, "Latest jobs" header, discipline tiles, chips, profile photo row, empty states, the employer verification banner and the admin sign-ups chart. Bottom-tab labels stop growing at 130 %, like system tab bars; each tab keeps its icon and accessible name.

Still manual: a screen-reader pass with NVDA (web) and TalkBack (Android), and keyboard-only navigation of the main flows.

## Reliability

- `/api/health?deep=1` also checks that the database answers (cached 30 s at the edge, so it cannot be used to load the database). The deploy smoke test now checks it too.
- **Uptime:** `.github/workflows/uptime.yml` checks `/`, `/jobs` and the deep health check every 30 minutes; GitHub emails the owner when a run fails.
- **Error log:** see Security → Logging. The admin overview shows the latest 10 entries.
- **Backups:** the free Supabase plan has no downloadable backups. Phase 11 moves production to the Pro plan (daily backups). Until then, take a manual dump before risky changes: `npx supabase db dump --linked -f backup.sql` (needs `supabase login` and `link`). Never commit the file (it contains user data).
- **Load test (500 concurrent users):** run on 2026-10-20, see *Load test* below.
- **Sentry:** replaced for now by the first-party error log above (no extra account). Can be added later with a DSN.

## After deploy (2026-10-20, live commit 17850ee)

Lighthouse 13.5, mobile emulation, same settings as the baseline (several
runs; the performance score varies ±4 with the test machine's CPU):

| Page | Perf | LCP | TBT | Transferred | Fonts start | Best practices |
|---|---|---|---|---|---|---|
| `/` before | 74 | 1.0 s | 720 ms | 3,781 KiB | 1.64 s | 77 |
| `/` after | 71–75 | 0.8–1.1 s | 700–900 ms | 3,561 KiB | 0.15 s | 81 |
| `/jobs` before | 72 | 0.8 s | 850 ms | 3,794 KiB | 1.64 s | 77 |
| `/jobs` after | 68–73 | 0.9–1.3 s | 820–1,070 ms | 3,526 KiB | 0.15 s | 81 |

- **LCP target met** (≤ 2.5 s on emulated mid-range mobile). Accessibility and SEO stay at 100.
- 220–270 KiB less to download, fonts start 1.5 s earlier, and the console is clean (the CORS logo errors are gone).
- The score is held back by main-thread time while the browser compiles Flutter's WASM (engine and app code). Only a smaller app or engine reduces that: a later Flutter release, or deferred loading once Flutter supports it for WASM.
- The remaining best-practices item is deprecation warnings inside Flutter's engine files (`skwasm.js`, `main.dart.mjs`), fixed only by a Flutter upgrade.

Live checks after deploy:
- Migrations `20261020150000` and `20261020160000` are applied to the cloud database, which passes the same invariants (RLS everywhere, definer functions pin `search_path`, no visitor write policies).
- Rate limit: the 11th error report in a minute from one IP gets `429` with `Retry-After: 60`.
- `/api/health?deep=1` reports `"database":"ok"`; `/api/img` serves Remotive logos (200 PNG) and refuses other hosts (403).
- CSP: report-only found one source (FlutterFire's inline script loader), fixed by `web/firebase-sdk.js`. Enforced from 7741ef8; home, the job board, an SEO job page, companies, both workspaces and notification settings load with sign-in and push working. One block appeared afterwards (Google sign-in's connectivity check to `www.google.com`), now allowed.

## Load test (2026-10-20)

[autocannon](https://github.com/mcollina/autocannon) 8.0.0 from one laptop,
500 concurrent connections, 15 s per scenario, against the live site.

| Scenario | Rate | Requests | OK | p50 | p90 | p99 |
|---|---|---|---|---|---|---|
| Job search, 20 results (`search_jobs` on Supabase, public key) | capped 250/s, reached 75/s | 1,121 | 100 % | 1.29 s | 4.96 s | 10.5 s |
| Job search, 1 result | capped 250/s, reached 241/s | 3,610 | 100 % | 0.35 s | 1.15 s | 3.35 s |
| App shell, API function, SEO page (Vercel) | uncapped / 500/s | stopped | see below | | | |

Findings:
- **The database copes with 500 users searching every 2 seconds** (241 searches/s, no errors or timeouts on the free plan). The 20-result run was held back by the payload: each page is 50 KB because `search_jobs` returns every job's full description (even 1 result is 7.5 KB), so 75 searches/s already filled this laptop's connection (≈ 30 Mbit/s).
- **Recommended follow-up:** return only the card fields (title, company, summary, salary, tags) from `search_jobs` and load the description when a job is opened. That cuts each results page several-fold, for users on mobile data too.
- **Vercel's firewall blocks single-source floods.** After 678 good responses for the app shell, Vercel's automatic DDoS mitigation answered `403` with its Security Checkpoint (`X-Vercel-Mitigated: challenge`) to everything from the test IP. Real browsers from that IP pass the checkpoint automatically, and the site stayed up for everyone else: the uptime check from GitHub's servers returned 200 for `/`, `/jobs` and the deep health check during and after the test. So Vercel's CDN and functions cannot be load-tested from one machine; that needs traffic from many IPs (for example a hosted load-testing service), and Vercel's edge is built to scale for cached pages.
- Server-side protection held: no errors were logged, the database stayed responsive (0.3 s for a 20-result search right after), and nothing needed a restart.
