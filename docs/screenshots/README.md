# LuzHire screenshots

The screenshot set for the project report, taken on 2026-10-27. Starred screens also come as a phone version (390 px) and in the dark theme.

- **Public screens (1–7, 15)** were captured from the live site, https://luzhire.vercel.app, so they show real imported jobs, company logos, news and events.
- **Signed-in screens (8–14)** were rendered from the app with **fictional demo data**: people, applicants and companies that don't exist. Real accounts are not shown. These images include the UI changes in PRs #42 (keyboard) and #43 (screen polish).

| # | Screen | Files |
|---|---|---|
| 1 ★ | Home | [desktop](01-home.png) · [phone](01-home-phone.png) · [dark](01-home-dark.png) |
| 2 ★ | Find jobs, with the preview pane | [desktop](02-find-jobs.png) · [phone](02-find-jobs-phone.png) · [dark](02-find-jobs-dark.png) |
| 3 | Job page | [desktop](03-job-page.png) |
| 4 | Hiring map | [desktop](04-hiring-map.png) |
| 5 | Companies directory | [desktop](05-companies.png) |
| 6 | Career news | [desktop](06-news.png) |
| 7 | Events | [desktop](07-events.png) |
| 8 ★ | Candidate dashboard | [desktop](08-candidate-dashboard.png) · [phone](08-candidate-dashboard-phone.png) · [dark](08-candidate-dashboard-dark.png) |
| 9 | Application tracker | [desktop](09-application-tracker.png) |
| 10 ★ | Employer pipeline | [desktop](10-employer-pipeline.png) · [phone](10-employer-pipeline-phone.png) · [dark](10-employer-pipeline-dark.png) |
| 11 | Job editor with live preview | [desktop](11-job-editor.png) |
| 12 | Employer analytics | [desktop](12-employer-analytics.png) |
| 13 | Admin overview | [desktop](13-admin-overview.png) |
| 14 | Admin audit log | [desktop](14-admin-audit-log.png) |
| 15 | Sign in | [desktop](15-sign-in.png) |

## Taking them again

The **signed-in screens** come from a render script that is not part of the normal test run. Run it from `app/`:

```bash
flutter test tool/report_screenshots_test.dart --update-goldens
```

The **public screens** are captured from the live site with headless Chrome. Run this from the repo root:

```bash
node tools/screenshots/live.mjs docs/screenshots "01-home|https://luzhire.vercel.app/|1440|900|0|11000|0"
```

Each argument is `name|url|width|height|dark (1 or 0)|wait in ms|scroll in px`. Phone widths (under 600 px) are captured at 2× with touch emulation. The script needs Chrome at its default Windows path; edit `chrome` at the top of the script for another path.
