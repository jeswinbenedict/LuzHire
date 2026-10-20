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
| 🔴 `CRON_SECRET` | random string (32+ characters) that authorises the daily job import (`/api/ingest/jobs`, run by Vercel Cron). Production only |
| 🔴 `ADZUNA_APP_ID`, `ADZUNA_APP_KEY` | optional: free keys from developer.adzuna.com to import Indian jobs. Without them only Remotive is imported |
| 🟢 `ADMIN_EMAILS` | optional: comma-separated emails allowed to claim admin once (Account → Claim admin access). Remove them after use; later admins are promoted in the console |
| 🟢 `ALLOWED_ORIGINS` | optional, e.g. a staging domain; localhost is allowed automatically outside production |

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
  "FIREBASE_IOS_BUNDLE_ID": "dev.luzhire.luzhire"
}
```
If anything is missing, the Deploy job shows a **"Deploy skipped"** warning instead of silently passing. After every deploy, it smoke-tests `/`, `/api/health`, `/jobs` and `/favicon.svg` on the live URL.
For local development the same file lives at `app/env/local.json` (git-ignored).

## 5. First admin account

Sign-up never grants admin. After your own account exists (sign up normally as a job seeker), make it an admin **once** from the Firebase Admin SDK. I'll give you a one-off script, or run it with you, when we reach Phase 7. After that, admins promote others from the admin console (`/api/admin/users/:id/role`, which is audited).

---

### Checklist: what to send me
- [ ] 🟢 Firebase web config (6 values from step 1.4)
- [ ] 🟢 Supabase Project URL + publishable/anon key
- [ ] ✅ Confirm: Firebase providers enabled, Supabase Third-party Auth added, `supabase db push` done, Vercel secrets added, GitHub `VERCEL_TOKEN` secret added
