# LuzHire — Release checklist and rollback plan

Use this page for every production release, and once in full for the Phase 11 launch sign-off.
Production is **https://luzhire.vercel.app**. Every merge to `main` deploys it through `.github/workflows/deploy.yml`.

---

## 1. Before merging

- [ ] The PR is green on GitHub. CI runs:
  - `flutter analyze`, `dart format` and the Flutter tests;
  - `npm run typecheck` and the API tests;
  - the pgTAP database tests;
  - the WASM web build.
- [ ] Every new database policy or rule has a pgTAP test (CLAUDE.md).
- [ ] UI changes were checked in the browser at 375, 768 and 1280 px, in light and dark themes, and with the keyboard alone (ROADMAP "Definition of done").
- [ ] New environment variables are added in Vercel (Production and Preview) **before** the merge (docs/SETUP.md §3). Secrets never go in the repo or in chat.
- [ ] The PR says whether it has a **database migration**. If it does, see §2.

## 2. Database migrations

Migrations are **forward-only**. Write them so the code already on the live site keeps working after they are applied: add columns, tables and functions, and never rename or drop something live code still reads. That way the site never depends on the order of "apply migration" and "deploy code", and a code rollback (§5) never needs a database rollback.

1. Take a backup first if the migration changes or deletes existing rows:
   - On the free plan: `npx supabase db dump --linked -f backup.sql`. Keep the file out of the repo, because it holds user data.
   - On the Pro plan, the daily backup is enough.
2. Apply the migration **before** merging the PR whose code needs it:
   - Paste the file into the Supabase **SQL editor** and run it in one transaction.
   - Then record its version:
     ```sql
     insert into supabase_migrations.schema_migrations (version, name)
     values ('20261026120000', 'event_images');
     ```
   - Or run `npx supabase db push` if the CLI is linked.
3. Check the change took effect: the new table or column exists, RLS is on, and the new policies are listed.

## 3. Deploying

Merging to `main` is the deploy. The **Deploy (Vercel)** workflow:
1. builds Flutter web (WASM) with the public config from the GitHub variable `APP_ENV_JSON`;
2. uploads the prebuilt site to Vercel production;
3. smoke-tests the live URL:
   - every page and file in the list must answer 200: `/`, `/api/health`, `/jobs`, `/employer/pipeline`, `/favicon.svg`, `/robots.txt`, `/sitemap.xml`, `/api/health?deep=1` (database reachable), `/splash.js` and `/firebase-messaging-sw.js`;
   - an unknown job page must answer 404;
   - `/api/health` must report the commit that was just deployed.

If the workflow shows **"Deploy skipped"**, a GitHub secret or variable is missing (docs/SETUP.md §4). A skipped deploy is **not** a release.

## 4. After deploying

- [ ] The Deploy run is green, including its smoke test.
- [ ] `https://luzhire.vercel.app/api/health?deep=1` shows `"database":"ok"` and the new commit.
- [ ] Open the site in a private window. Home, Find jobs, a job page, Companies, News, Events and the hiring map load with no console errors.
- [ ] Sign in as a candidate, then as an employer. The dashboard and the employer workspace load.
- [ ] If the change touches imports, run that import once from Vercel → **Cron Jobs → Run** and check the page it feeds. The imports are `/api/ingest/jobs`, `/companies`, `/news` and `/events`.
- [ ] If the change touches notifications, use Account → Notification settings → *Send a test notification*.
- [ ] Watch the next **Uptime** run (every 30 minutes) and the error log (admin overview, or the `app_errors` table) for an hour.

## 5. Rollback plan

Pick the first step that fixes the problem. Write down what happened in the PR or in an issue.

| Problem | What to do | Time |
|---|---|---|
| The new release is broken (blank page, errors, a page missing) | **Vercel → Project → Deployments**: open the last good production deployment, then **⋯ → Instant Rollback**. The site is back in seconds, and nothing is rebuilt. | 1 min |
| After an instant rollback | Vercel stops promoting new deploys to production until you undo it. Fix the code (next row) and then **Promote** the fixed deployment, or use **Undo Rollback**. | — |
| Fixing the code for good | Revert the PR on GitHub (**Revert** button on the merged PR), then merge the revert. The deploy workflow ships the previous code and smoke-tests it. | 10 min |
| A daily import brings bad data | Vercel → **Settings → Cron Jobs**: **Disable** that cron. Then fix the cause and re-enable it. Imported jobs carry their feed in `external_source`, so one feed's rows can be closed together; admins can also hide news in `/admin/news` and take jobs down in `/admin/moderation`. | 5 min |
| A migration was wrong | Do **not** edit the applied file. Write a new migration that undoes or corrects it, test it with `npm run db:check`, and apply it as in §2. If data was lost, restore it from the backup taken in §2 step 1. | 30 min+ |
| A secret leaked (key in a log, chat or commit) | Rotate it at the source (Supabase, Firebase, the mailbox, Vercel or GitHub). Update the Vercel or GitHub value and redeploy. A secret pushed in a commit stays in git history, so rotating is the only fix. | 15 min |
| The site is down, but no release happened | Check `https://luzhire.vercel.app/api/health?deep=1`. If the database is failing, check the Supabase dashboard (a paused free project needs **Restore**). Also check the Vercel and Supabase status pages. | — |

## 6. Phase 11 launch sign-off

Tick these once. Then mark Phase 11 done in `docs/ROADMAP.md` and `CLAUDE.md`.

**Accounts and plans (owner)**
- [ ] Supabase on the **Pro** plan, or knowingly left on Free. Free has no auto-pause protection and no daily backups (docs/HARDENING.md, Reliability).
- [ ] Optional custom domain added in Vercel (**Settings → Domains**). If you add one:
  - set the GitHub variable `PRODUCTION_URL`;
  - add the domain to Firebase **Authentication → Settings → Authorized domains**;
  - update the Supabase webhook URL (docs/SETUP.md §6).
- [ ] The first admin is created: put your email in the Vercel variable `ADMIN_EMAILS`, redeploy, then use Account → **Claim admin access**. Remove the email from `ADMIN_EMAILS` afterwards.

**Live checks (owner, with real accounts)**
- [ ] A full hire with two accounts:
  1. the employer posts a job;
  2. the candidate applies;
  3. the employer moves the candidate through the pipeline and schedules an interview;
  4. the employer sends an offer and the candidate accepts it.

  Each step should show up for the other person within seconds.
- [ ] Notification emails look right in Gmail **and** Outlook.
- [ ] A screen-reader pass (NVDA or Narrator on Windows, TalkBack on Android) of sign-in, job search, apply and the pipeline.
- [ ] Optional: Android push on a phone. This needs the Android app registered in Firebase.

**Operations**
- [ ] The four daily imports ran today: check the admin overview for import runs.
- [ ] The Uptime workflow has been green for a day.
- [ ] The handover pack is complete (docs/HANDOVER.md, including the screenshot set).
