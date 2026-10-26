# LuzHire — Services Setup (Firebase, Supabase, Vercel)

This turns on sign-in (Phase 3) and the cloud database (Phase 2). It takes about 20 minutes.
**Public** values (safe to share in chat or commit in `env/example.json`-style files) are marked 🟢.
**Secret** values are marked 🔴: put them only into Vercel/GitHub secret settings, never in chat, code or screenshots.

---

## 1. Firebase (sign-in)

1. Go to <https://console.firebase.google.com> → **Add project** → name it `luzhire` (Google Analytics optional).
2. **Build → Authentication → Get started**, then on **Sign-in method** enable:
   - **Email/Password** (leave "Email link" off)
   - **Google** (choose a support email)
3. **Authentication → Settings → Authorized domains**: add `localhost` (usually present) and your Vercel domain once you have it (e.g. `luzhire.vercel.app`).
4. **Project settings (⚙) → General → Your apps → Add app → Web (`</>`)**, nickname `luzhire-web`. Firebase shows a `firebaseConfig` object. Send me these 🟢 values:

   | firebaseConfig key | Goes into |
   |---|---|
   | `apiKey` | `FIREBASE_API_KEY` |
   | `authDomain` | `FIREBASE_AUTH_DOMAIN` |
   | `projectId` | `FIREBASE_PROJECT_ID` |
   | `storageBucket` | `FIREBASE_STORAGE_BUCKET` |
   | `messagingSenderId` | `FIREBASE_MESSAGING_SENDER_ID` |
   | `appId` | `FIREBASE_WEB_APP_ID` |

   (A Firebase web `apiKey` is not a secret. It only identifies the project; access is controlled by Auth and Supabase rules.)
5. *(Optional, for the Android app)* **Add app → Android**, package name `dev.luzhire.luzhire`. Send me its 🟢 `mobilesdk_app_id` (`FIREBASE_ANDROID_APP_ID`). Google sign-in on Android also needs your debug SHA-1 added there.
6. 🔴 **Project settings → Service accounts → Generate new private key.** This downloads a JSON file. **Do not send it to me.** You'll paste it into Vercel in step 3.

## 2. Supabase (database)

1. Go to <https://supabase.com/dashboard> → **New project** → name `luzhire`, region **Mumbai (ap-south-1)** (closest to Andhra Pradesh), and a strong database password 🔴 (keep it in your password manager).
2. **Project Settings → API**: send me 🟢 the **Project URL** (`SUPABASE_URL`) and the 🟢 **publishable key** (or legacy **anon** key, `SUPABASE_PUBLISHABLE_KEY`).
   🔴 The **service_role / secret key** stays private. It goes only into Vercel.
3. **Authentication → Third-party Auth → Add provider → Firebase**, enter your Firebase **Project ID**. This lets the database trust LuzHire sign-ins.
4. Apply the database (migrations from Phase 2). Run these commands yourself, because they need your Supabase login and database password:
   ```bash
   npx supabase login
   ```
   ```bash
   npx supabase link --project-ref <your-project-ref>
   ```
   ```bash
   npx supabase db push
   ```
   The project ref is the `xxxx` in `https://xxxx.supabase.co`. Do **not** run `seed.sql` on the cloud project. It holds demo data for local development only.
   (No CLI access? Paste the migration files, in order, into the dashboard SQL editor and also insert their versions into `supabase_migrations.schema_migrations`. That is how the LuzHire cloud project was set up; see docs/ROADMAP.md, Phase 2.)

## 3. Vercel (API secrets)

In the Vercel project → **Settings → Environment Variables** (Production + Preview):

| Name | Value |
|---|---|
| 🔴 `FIREBASE_SERVICE_ACCOUNT` | the service-account JSON from step 1.6: open the file in Notepad, copy everything and paste it (base64 also works) |
| 🔴 `SUPABASE_SERVICE_ROLE_KEY` | Supabase service_role / secret key |
| 🟢 `SUPABASE_URL` | Supabase Project URL |
| 🔴 `CRON_SECRET` | random string (32+ characters) that authorises the daily imports (`/api/ingest/jobs`, `/api/ingest/companies`, `/api/ingest/events` and `/api/ingest/news`, run by Vercel Cron). Production only |
| 🔴 `ADZUNA_APP_ID`, `ADZUNA_APP_KEY` | optional: free keys from developer.adzuna.com to import Indian jobs. Without them the other feeds (Remotive, Himalayas, Jobicy, Remote OK and the company career boards) still import |
| 🟢 `ADMIN_EMAILS` | optional: comma-separated emails allowed to claim admin once (Account → Claim admin access). Remove them after use; later admins are promoted in the console |
| 🟢 `ALLOWED_ORIGINS` | optional, e.g. a staging domain; localhost is allowed automatically outside production |
| 🔴 `NOTIFY_SECRET` | random string (32+ characters) that authorises the Supabase webhook calling `/api/notify/dispatch` (§6). Production only |
| 🟢 `SMTP_USER` | the mailbox that sends notification emails, e.g. a Gmail address made for LuzHire |
| 🔴 `SMTP_PASSWORD` | that mailbox's **app password** (Google Account → Security → 2-Step Verification → App passwords), not its normal password |
| 🟢 `SMTP_HOST`, `SMTP_PORT`, `EMAIL_FROM` | optional; default `smtp.gmail.com`, `465`, `LuzHire <SMTP_USER>`. Any SMTP provider works (Brevo, Resend, …) |

Set each secret for **Production and Preview** (not Development). Check that it appears in the list after saving, then delete the downloaded JSON file.

## 4. GitHub (deploy settings)

Vercel's servers can't build Flutter, so `.github/workflows/deploy.yml` builds the app on GitHub and uploads it. Vercel's own Git builds are switched off in `vercel.json`.
In GitHub → repo → **Settings → Secrets and variables → Actions**:

| Kind | Name | Value |
|---|---|---|
| 🔴 **Secret** | `VERCEL_TOKEN` | Vercel → Account Settings → Tokens → Create (scope: your team, no expiry or long) |
| 🟢 Variable | `VERCEL_ORG_ID` | Vercel team ID (`team_…`, Team Settings → General) |
| 🟢 Variable | `VERCEL_PROJECT_ID` | Vercel project ID (`prj_…`, Project Settings → General) |
| 🟢 Variable | `APP_ENV_JSON` | the public client config below |

```json
{
  "APP_ENV": "production",
  "SUPABASE_URL": "https://xxxx.supabase.co",
  "SUPABASE_PUBLISHABLE_KEY": "…",
  "API_BASE_URL": "",
  "FIREBASE_API_KEY": "…",
  "FIREBASE_PROJECT_ID": "…",
  "FIREBASE_MESSAGING_SENDER_ID": "…",
  "FIREBASE_AUTH_DOMAIN": "….firebaseapp.com",
  "FIREBASE_STORAGE_BUCKET": "….firebasestorage.app",
  "FIREBASE_WEB_APP_ID": "1:…:web:…",
  "FIREBASE_ANDROID_APP_ID": "",
  "FIREBASE_IOS_APP_ID": "",
  "FIREBASE_IOS_BUNDLE_ID": "dev.luzhire.luzhire",
  "FIREBASE_VAPID_KEY": ""
}
```
`FIREBASE_VAPID_KEY` is optional (public): Firebase console → Project settings → Cloud Messaging → Web Push certificates. Left empty, web push uses the Firebase SDK's built-in key.
If anything is missing, the Deploy job shows a **"Deploy skipped"** warning instead of silently passing. After every deploy, it smoke-tests the live URL (pages, API, database and the deployed commit; see docs/RELEASE.md §3).
For local development the same file lives at `app/env/local.json` (git-ignored).

## 5. First admin account

Sign-up never grants admin. To make the first one:
1. Sign up normally and verify your email.
2. In Vercel, set `ADMIN_EMAILS` to that email (§3) and redeploy (GitHub → Actions → Deploy → Run workflow).
3. In LuzHire, open Account → **Claim admin access** (`POST /api/auth/claim-admin`: verified emails on the list only, audited).
4. Remove the email from `ADMIN_EMAILS`.

After that, admins promote others from Admin → Users (`/api/admin/users/:id/role`, which is audited).

## 6. Notifications (push and email)

In-app notifications need nothing. Push and email are sent by `/api/notify/dispatch`, which a Supabase **database webhook** calls whenever a notification is created:
1. Vercel: add `NOTIFY_SECRET`, `SMTP_USER` and `SMTP_PASSWORD` (§3), then redeploy.
2. Supabase → **Database → Webhooks → Create a new hook**: name `notify_dispatch`, table `public.notifications`, event **Insert**, type **HTTP Request**, method **POST**, URL `https://luzhire.vercel.app/api/notify/dispatch`, timeout `10000` ms, HTTP header `Authorization` = `Bearer <NOTIFY_SECRET>` (the word Bearer, one space, then the secret; without `Bearer ` every call gets 401).
3. In LuzHire: Account → **Notification settings** → *Turn on push notifications*, then *Send a test notification*. The push and the email should arrive within seconds.

Each notification is delivered once (the database claims it), only from the last hour, only to verified email addresses, and only for the groups the user left on. Admins can read what was sent in `notification_deliveries`. Android push additionally needs the Android app registered in Firebase (`FIREBASE_ANDROID_APP_ID`); iOS needs an Apple Push key (paid Apple developer account).

---

## 7. Continue on another computer

Everything is on GitHub; the cloud services (Supabase, Firebase, Vercel) need no setup again. Only the git-ignored `app/env/local.json` has to be recreated.

1. Install Git, [Flutter](https://docs.flutter.dev/get-started/install) (stable, 3.47 or newer), [Node.js 24](https://nodejs.org/) and the [GitHub CLI](https://cli.github.com/). Docker is only needed for `npx supabase start`; `npm run db:check` works without it.
2. Clone and install:
   ```bash
   git clone https://github.com/jeswinbenedict/LuzHire.git
   cd LuzHire
   npm ci
   cd app && flutter pub get && cd ..
   ```
3. Credit commits to the right account:
   ```bash
   git config user.name "A . Jeswin Karunya Benedict"
   git config user.email "251479040+jeswinbenedict@users.noreply.github.com"
   ```
4. Recreate the app config from the GitHub variable (public values only), then change `"APP_ENV"` in it from `"production"` to `"local"`:
   ```bash
   gh auth login
   gh variable get APP_ENV_JSON > app/env/local.json
   ```
5. Check that everything works:
   ```bash
   npm test
   npm run db:check
   cd app && flutter analyze && flutter test
   flutter run -d chrome --dart-define-from-file=env/local.json
   ```

Secrets (service-role key, `CRON_SECRET`, Firebase service account, mail password) stay in Vercel and GitHub; they are not needed on the laptop. New database migrations are applied in the Supabase dashboard (SQL editor), as in section 2.

### Checklist: what to send me
- [ ] 🟢 Firebase web config (6 values from step 1.4)
- [ ] 🟢 Supabase Project URL + publishable/anon key
- [ ] ✅ Confirm: Firebase providers enabled, Supabase Third-party Auth added, `supabase db push` done, Vercel secrets added, GitHub `VERCEL_TOKEN` secret added
