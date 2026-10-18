# LuzHire — Final Architecture Report

**Successor to CareerConnect (careerconnect-vitap.vercel.app)**
Prepared 18 Oct 2026 · Input: CareerConnect SRS v1, v2, "Final", D2 (SWE4007), UML Diagram Companion, and a review of the live site.

Target stack (fixed by the project owner):

| Concern | Choice |
|---|---|
| UI/UX design | Google Stitch via MCP → design tokens + screen specs |
| Client | Flutter (Dart) — one codebase for Web, Android, iOS |
| Authentication | Firebase Authentication |
| Database, realtime, file storage | Supabase (Postgres + Realtime + Storage) |
| Server code | JavaScript/TypeScript on Vercel Functions |
| Hosting | Vercel (web app + API); App Store / Play Store for mobile binaries |

---

## 1. What the documents specify (consolidated)

All SRS versions describe the same system. v2 is the most complete; v1 is an earlier draft of it; "Final" and D2 are condensed versions (D2 9 and D2 10 are byte-identical). The requirement set to carry forward:

**Roles:** Guest, Job Seeker (Candidate), Employer, Administrator.

**Functional requirements (FR-01 … FR-14):**
- FR-01 Registration & auth — email/password, role choice at sign-up, email verification, reset, persistent session.
- FR-02 Candidate profile — headline, bio, contact, skills, education, experience, resume, GitHub/LinkedIn/portfolio, completion %.
- FR-03 Company profile — logo, cover, description, industry, size, website, benefits, verification status; owner-only edits.
- FR-04 Job lifecycle — Draft → Published → Closed → Archived; title, type, level, salary range, location, skills, responsibilities, qualifications, benefits, deadline.
- FR-05 Search — keyword + company, industry, location, type, experience, salary, remote, skills, date posted.
- FR-06 Apply — resume + cover letter; duplicates prevented; no applying after deadline (D2 constraint).
- FR-07 Saved jobs, synced across devices.
- FR-08 Application tracking — Applied, Under Review, Shortlisted, Technical Assessment, Technical Interview, HR Interview, Final Review, Offer Issued, Hired, Rejected.
- FR-09 Candidate management — view profile, download resume, move stages, reject, schedule interview, issue offer.
- FR-10 Interviews — date/time, meeting link, interviewer, notes, status; reschedule/cancel notifies candidate.
- FR-11 Notifications — event-driven, role-specific; view / mark read / delete.
- FR-12 Admin — users, employer verification, job moderation, announcements, analytics, audit logs, config.
- FR-13 RBAC + ownership enforcement.
- FR-14 Immutable audit log.

**Non-functional targets:** page load ≤ 3 s, auth ≤ 2 s, search ≤ 2 s, ≥ 500 concurrent users, 99.5 % monthly availability, WCAG 2.1 AA, light/dark themes, Chrome/Edge/Firefox/Safari on Windows/macOS/Linux/Android/iOS.

**Listed as "future" in the SRS — promote to v1 where cheap:** Google/LinkedIn/GitHub sign-in, native mobile apps, push + email notifications, resume parsing, skill-match job recommendations, employer team members, interview feedback, server-side jobs (cron, search indexing).

---

## 2. Flaws in the existing CareerConnect

### 2.1 Observed on the live site (18 Oct 2026)

| # | Flaw | Evidence | LuzHire fix |
|---|---|---|---|
| 1 | **"Career News" is general headlines.** | /news showed NFL, SNL, Houthis, Dodgers, stock market — all tagged "Career"/"Placements"; newest item 5 days old. | Server-side ingestion from career-specific sources + relevance scoring; reject below threshold (§7.3). |
| 2 | **Fabricated company data.** | Every company card reads "Leading organization in Engineering · 50-500 employees", including Amazon. | Never synthesize facts. External companies show only what the source provides; native companies are employer-entered and admin-verified. |
| 3 | **Fake dashboard metrics on home page.** | "NETWORK LOAD 98.4 %", "AI MATCHING Skills 92 %", "+12.48 % network momentum" — hardcoded. | Show real counts from a materialized stats view, or nothing. |
| 4 | **Unmoderated native postings mixed with aggregated feeds.** | Top result "giga chad — web dev — $18–$22 /yr". | Native jobs go through `pending_review` unless the company is verified; salary period is a typed enum with sanity bounds. |
| 5 | **Raw scraped descriptions dumped into cards.** | Card text includes "Press space or enter keys to toggle section visibility". | Sanitize HTML → Markdown at ingestion; cards show a 2-line generated summary. |
| 6 | **One ~2 MB JS bundle (491 KB over the wire), no route splitting.** | Single `index-*.js` serves every route. | Flutter deferred imports per role module (§5.5). |
| 7 | **No SEO.** | `<title>` is "CareerConnect" on every route; unknown routes return HTTP 200; no JobPosting structured data. | Public SEO layer (§5.6). |
| 8 | **Likely API key in the client bundle.** | Bundle contains `apiKey=` query strings (3 occurrences). | All third-party keys live only in Vercel env vars; the client never calls third-party APIs directly. |
| 9 | **Mobile: full filter panel renders before any results.** | At 375 px the user scrolls past ~10 filter rows to reach the first job. | Filters in a bottom sheet with chip summary; results first. |

### 2.2 Architectural flaws in the SRS design

1. **Highly relational data in a document store.** Users → Companies → Jobs → Applications → Interviews/Offers is relational. Firestore has no joins, no real full-text search (so FR-05 keyword search could not actually be met), and no referential integrity (SRS 8.3 admits FKs are "maintained by the application"). → **Postgres fixes all three.**
2. **Business invariants enforced in the browser.** The application counter is incremented by the client (Sequence 3.7); duplicates are checked by a read-then-write race; notifications are created client-side. Any user with devtools can skip these. → **Constraints and triggers in Postgres.**
3. **Role stored in a user-writable document.** Login reads `role` from the `users` doc (Sequence 3.6). Unless rules are perfect, a user can promote themselves to admin. → **Role lives in a server-set Firebase custom claim.**
4. **No server tier at all.** No place for cron, aggregation, email, push, secret keys, or admin actions. → **Vercel Functions + Postgres functions.**
5. **Interview date and time stored as separate strings.** Breaks across time zones. → `timestamptz`.
6. **D2 "User" table stores `Password`.** Must never exist; Firebase owns credentials.
7. **Stage pipeline has no state machine.** Any stage → any stage, no history. → transition table + `application_events` history.
8. **Inconsistent naming** across docs (Recruiter vs Employer, `User_Type` vs `role`, SRS "v3.0" referenced but v2 supplied). LuzHire uses one glossary (§11).

---

## 3. System architecture

```
                         ┌───────────────────────────────────────────┐
                         │          Flutter app (Dart)               │
                         │  Web (WASM)  ·  Android  ·  iOS           │
                         │  Riverpod · go_router · supabase_flutter  │
                         └──────┬───────────────┬───────────────┬────┘
              ID token (JWT)    │               │               │ HTTPS
        ┌───────────────────────┘               │               │
        ▼                                       ▼               ▼
┌──────────────────┐   Firebase JWT    ┌─────────────────────────────┐
│ Firebase Auth    │──────────────────▶│ Supabase                    │
│ email, Google,   │  (third-party     │  Postgres + RLS             │
│ GitHub, LinkedIn │   auth provider)  │  Realtime (Changes/Broadcast)│
│ custom claims:   │                   │  Storage (resumes, logos)   │
│  role, app_role  │                   │  pg_cron · pg_net           │
└────────▲─────────┘                   └──────────┬──────────────────┘
         │ Admin SDK                              │ DB webhooks / pg_net
         │                                        ▼
┌────────┴─────────────────────────────────────────────────────────┐
│ Vercel                                                           │
│  /            Flutter web build (static, CDN)                    │
│  /api/*       Vercel Functions (TypeScript, Node runtime)        │
│     auth/bootstrap   set custom claims, create profile row       │
│     admin/*          role changes, verification, moderation      │
│     ingest/jobs      external job feeds → normalized rows        │
│     ingest/news      career news → relevance-scored rows         │
│     notify/dispatch  FCM push + transactional email              │
│     resume/parse     PDF/DOCX → structured profile suggestions   │
│  /jobs/:slug  SEO HTML + JobPosting JSON-LD (see §5.6)           │
└──────────────────────────────────────────────────────────────────┘
```

**Principles**
- **The database is the source of truth for every invariant.** Uniqueness, stage transitions, counters, notifications, and audit entries happen in Postgres (constraints, triggers, `security definer` functions), so they hold no matter which client wrote.
- **The client reads and writes Supabase directly under RLS** for ordinary CRUD (fast, realtime). Anything needing a secret, a third party, or elevated privilege goes through `/api/*`.
- **One identity, two systems:** Firebase issues the JWT; Supabase trusts it via its Third-Party Auth integration; RLS reads claims from `auth.jwt()`.

---

## 4. Authentication: Firebase Auth → Supabase

### 4.1 Setup
1. Firebase project: enable Email/Password, Google, GitHub; LinkedIn via OIDC (needs Identity Platform) or defer.
2. Supabase Dashboard → Authentication → Third-party Auth → add **Firebase** with the Firebase project ID.
3. Every Firebase user must carry the custom claim **`role: "authenticated"`** (Supabase maps it to the Postgres role). The app's own role goes in a separate claim, **`app_role`** (`candidate` | `employer` | `admin`).
4. Claims are set **only** by `/api/auth/bootstrap` using the Firebase Admin SDK on Vercel. (No Firebase Cloud Functions or Blaze plan needed.)

### 4.2 Sign-up flow
```
Flutter                         Firebase Auth          /api/auth/bootstrap            Supabase
  │ createUser / OAuth ─────────────▶│                         │                           │
  │◀──────────── ID token (no claims)│                         │                           │
  │ POST {requestedRole} + Bearer token ──────────────────────▶│ verifyIdToken             │
  │                                  │◀── setCustomUserClaims ─│ {role:'authenticated',    │
  │                                  │                         │  app_role:'candidate'}    │
  │                                  │                         │ insert profiles row ─────▶│ (service key)
  │◀──────────────────────────────── 200 ─────────────────────│                           │
  │ getIdToken(forceRefresh: true)   │                         │                           │
  │ all Supabase calls now carry the claims ───────────────────────────────────────────▶ │ RLS
```
- `requestedRole` may only be `candidate` or `employer`; `admin` is granted only via `/api/admin/users/:id/role` by an existing admin, and is audited.
- Unverified email: RLS allows reading public data and editing your own profile, but blocks applying and posting (`auth.jwt()->>'email_verified' = 'true'`).

### 4.3 Flutter wiring
```dart
await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
await Supabase.initialize(
  url: Env.supabaseUrl,
  anonKey: Env.supabaseAnonKey,
  accessToken: () async =>
      FirebaseAuth.instance.currentUser?.getIdToken(),
);
```
Listen to `FirebaseAuth.instance.idTokenChanges()` and re-subscribe Realtime channels when the token rotates (hourly).

### 4.4 RLS helper functions
```sql
create schema if not exists app;
create function app.uid() returns text language sql stable
  as $$ select auth.jwt() ->> 'sub' $$;
create function app.role() returns text language sql stable
  as $$ select auth.jwt() ->> 'app_role' $$;
create function app.is_admin() returns boolean language sql stable
  as $$ select coalesce(auth.jwt() ->> 'app_role' = 'admin', false) $$;
```
User IDs are Firebase UIDs, so every user FK is `text`, **not** `uuid`, and policies use `app.uid()`, **not** `auth.uid()`. Wrap calls as `(select app.uid())` in policies so Postgres evaluates them once per query.

---

## 5. Client: Flutter

### 5.1 Packages
| Purpose | Package |
|---|---|
| State / DI | `flutter_riverpod` + `riverpod_annotation` (codegen) |
| Routing | `go_router` (redirect guards by `app_role`, deep links) |
| Data | `supabase_flutter`, `firebase_auth`, `firebase_core`, `firebase_messaging` |
| Models | `freezed` + `json_serializable` |
| Forms | `reactive_forms` or `flutter_form_builder` |
| Local cache | `drift` (SQLite; also runs on web) for saved jobs, drafts, last search |
| Files | `file_picker`, `syncfusion_flutter_pdfviewer` or `pdfx` for resume preview |
| Charts | `fl_chart` (employer/admin analytics) |
| i18n | `flutter_localizations` + `intl` (ARB files) |
| Testing | `flutter_test`, `integration_test`, `mocktail`, `patrol` (optional E2E) |

### 5.2 Folder layout (feature-first)
```
app/lib/
  main.dart
  bootstrap.dart                 # Firebase + Supabase init, error zones
  core/
    env/                         # --dart-define values
    theme/                       # tokens from Stitch → ThemeData (light/dark)
    router/                      # go_router, guards, deferred route loaders
    supabase/                    # client provider, realtime helpers
    auth/                        # session controller, claims parsing
    widgets/                     # design-system components
    utils/                       # result types, error mapping, formatters
  features/
    auth/          {data,domain,presentation}
    jobs/          # public search, job detail, saved jobs
    companies/
    candidate/     # dashboard, profile, resume, applications, interviews, offers
    employer/      # company, job editor, pipeline (kanban), interviews, analytics, team
    admin/         # verification queue, moderation, users, announcements, audit
    notifications/
    news/
```
Each feature: `data/` (repository talking to Supabase), `domain/` (freezed models, pure logic), `presentation/` (widgets + Riverpod controllers). This keeps the SRS's repository/service split without a separate "service" layer per entity.

### 5.3 Real-time strategy
| Screen | Mechanism |
|---|---|
| My notifications, my applications, my interviews | `supabase.from(...).stream(primaryKey: ['id']).eq('user_id', uid)` (Postgres Changes under RLS) |
| Employer pipeline for a company | Private **Broadcast** channel `company:<id>` fed by a DB trigger (`realtime.broadcast_changes`), authorized by RLS on `realtime.messages` — scales better than Postgres Changes with many listeners |
| Admin queues | Private Broadcast `admin:queues` |
| Public job board | Broadcast `jobs:public` → "12 new jobs — tap to refresh" banner (no live reflow under the user's thumb) |
| Interview reschedule, offer status | Covered by the user's notification + application streams |

Optimistic UI for stage moves and saves; roll back on error.

### 5.4 Responsive layout
Breakpoints: compact < 600, medium 600–1024, expanded > 1024. Navigation: bottom bar (compact) → rail (medium) → sidebar (expanded). Job search: list + detail in two panes on expanded; filter bottom sheet on compact.

### 5.5 Web performance
Flutter web downloads its rendering engine before the first frame, so it needs deliberate care to meet "page load ≤ 3 s":
- Build with `flutter build web --wasm --release` (skwasm, CanvasKit fallback for older browsers).
- **Deferred imports** for `employer/`, `admin/`, analytics charts and the PDF viewer (`import ... deferred as employer;`) so candidates never download them.
- A lightweight HTML/CSS splash in `web/index.html` that paints immediately while the engine loads.
- `--tree-shake-icons`; serve fonts locally; cache-immutable headers for hashed assets (`vercel.json`).
- Keyset pagination (`published_at, id`) — never offset; 20 items per page.
- Budget: ≤ 2.5 s LCP on a mid-range phone over 4G for `/jobs`; search API p95 ≤ 300 ms.

### 5.6 SEO for public job pages
Canvas-rendered Flutter pages are not indexable the way HTML is, and job portals live on search traffic (Google for Jobs). Recommended:
- A Vercel Function at `/jobs/:slug` that returns a lightweight server-rendered HTML page (title, description, salary, company, **JobPosting JSON-LD**, canonical URL, Open Graph) with an "Open in LuzHire" button that loads the Flutter app at the matching route.
- `/sitemap.xml` and `/robots.txt` generated from published jobs.
- Correct HTTP 404/410 for missing or closed jobs.

*Alternative (decide before Phase 6):* a separate Next.js/Astro public site for landing + job pages, with Flutter at `app.` subdomain. More work, better SEO and marketing control.

---

## 6. Data model (Supabase Postgres)

Migrations live in `supabase/migrations/` and are created with the Supabase CLI. Sketch:

```sql
-- enums
create type app_role          as enum ('candidate','employer','admin');
create type account_status    as enum ('active','suspended','deleted');
create type verification      as enum ('unverified','pending','verified','rejected');
create type job_status        as enum ('draft','pending_review','published','closed','archived','rejected');
create type job_source        as enum ('native','external');
create type employment_type   as enum ('full_time','part_time','contract','internship','temporary');
create type experience_level  as enum ('entry','mid','senior','lead');
create type workplace_type    as enum ('onsite','remote','hybrid');
create type salary_period     as enum ('hour','month','year');
create type application_stage as enum ('applied','under_review','shortlisted','assessment',
  'technical_interview','hr_interview','final_review','offer_issued','hired','rejected','withdrawn');
create type interview_status  as enum ('scheduled','completed','cancelled','no_show');
create type offer_status      as enum ('issued','accepted','declined','withdrawn','expired');

-- identity & profile
create table profiles (
  id text primary key,                       -- Firebase UID
  role app_role not null,
  email text not null unique,
  display_name text not null,
  avatar_path text,
  headline text, bio text, phone text, location text,
  links jsonb not null default '{}',         -- github, linkedin, portfolio
  account_status account_status not null default 'active',
  profile_completion smallint not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table educations  (id uuid primary key default gen_random_uuid(), user_id text references profiles on delete cascade,
  institution text not null, degree text, field text, start_date date, end_date date, grade text);
create table experiences (id uuid primary key default gen_random_uuid(), user_id text references profiles on delete cascade,
  company text not null, title text not null, start_date date, end_date date, description text);
create table skills         (id serial primary key, name text not null, slug text not null unique);
create table profile_skills (user_id text references profiles on delete cascade, skill_id int references skills, primary key (user_id, skill_id));
create table resumes (id uuid primary key default gen_random_uuid(), user_id text references profiles on delete cascade,
  storage_path text not null, file_name text not null, parsed jsonb, is_primary boolean not null default false,
  created_at timestamptz not null default now());

-- companies & team
create table companies (
  id uuid primary key default gen_random_uuid(),
  owner_id text not null references profiles,
  name text not null, slug text not null unique,
  logo_path text, cover_path text, description text, industry text,
  size_range text, website text, hq_location text, benefits text[] not null default '{}',
  verification verification not null default 'unverified',
  verified_at timestamptz,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table company_members (company_id uuid references companies on delete cascade,
  user_id text references profiles on delete cascade, member_role text not null check (member_role in ('owner','recruiter','viewer')),
  primary key (company_id, user_id));

-- jobs (native + aggregated)
create table jobs (
  id uuid primary key default gen_random_uuid(),
  source job_source not null default 'native',
  company_id uuid references companies,            -- null for external
  external_company text, external_logo_url text,
  external_source text, external_id text, external_url text,
  posted_by text references profiles,
  title text not null, slug text not null unique,
  description_md text not null, summary text,
  employment_type employment_type not null,
  experience_level experience_level,
  workplace workplace_type not null default 'onsite',
  location_text text, country_code char(2),
  salary_min numeric, salary_max numeric, salary_currency char(3), salary_period salary_period,
  responsibilities text[] not null default '{}', qualifications text[] not null default '{}', benefits text[] not null default '{}',
  status job_status not null default 'draft',
  deadline date,
  application_count int not null default 0, view_count int not null default 0,
  published_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  search tsvector generated always as (
    setweight(to_tsvector('english', coalesce(title,'')), 'A') ||
    setweight(to_tsvector('english', coalesce(external_company,'') || ' ' || coalesce(location_text,'')), 'B') ||
    setweight(to_tsvector('english', coalesce(description_md,'')), 'C')) stored,
  unique (external_source, external_id),
  check (salary_min is null or salary_max is null or salary_min <= salary_max),
  check ((source = 'native') = (company_id is not null))
);
create table job_skills (job_id uuid references jobs on delete cascade, skill_id int references skills, primary key (job_id, skill_id));
create index jobs_search_idx on jobs using gin (search);
create index jobs_title_trgm on jobs using gin (title gin_trgm_ops);   -- typo-tolerant prefix search
create index jobs_feed_idx   on jobs (published_at desc, id) where status = 'published';

-- applications pipeline
create table applications (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references jobs,
  candidate_id text not null references profiles,
  resume_id uuid references resumes,
  cover_letter text,
  stage application_stage not null default 'applied',
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  unique (job_id, candidate_id)                      -- FR-06 duplicate prevention, race-free
);
create table application_stage_transitions (from_stage application_stage, to_stage application_stage, primary key (from_stage, to_stage));
create table application_events (id bigserial primary key, application_id uuid references applications on delete cascade,
  from_stage application_stage, to_stage application_stage not null, actor_id text, note text, created_at timestamptz not null default now());
create table interviews (id uuid primary key default gen_random_uuid(), application_id uuid not null references applications on delete cascade,
  scheduled_at timestamptz not null, duration_min int not null default 45, mode text check (mode in ('video','phone','onsite')),
  meeting_url text, location text, interviewer_ids text[] not null default '{}', notes text, feedback jsonb,
  status interview_status not null default 'scheduled', created_at timestamptz not null default now());
create table offers (id uuid primary key default gen_random_uuid(), application_id uuid not null unique references applications on delete cascade,
  salary numeric, currency char(3), start_date date, letter_path text, expires_at timestamptz,
  status offer_status not null default 'issued', created_at timestamptz not null default now());
create table saved_jobs (user_id text references profiles on delete cascade, job_id uuid references jobs on delete cascade,
  created_at timestamptz not null default now(), primary key (user_id, job_id));

-- communication & governance
create table notifications (id uuid primary key default gen_random_uuid(), user_id text not null references profiles on delete cascade,
  type text not null, title text not null, body text, data jsonb not null default '{}', read_at timestamptz,
  created_at timestamptz not null default now());
create index notifications_user_idx on notifications (user_id, created_at desc);
create table announcements (id uuid primary key default gen_random_uuid(), title text not null, body_md text not null,
  audience text not null check (audience in ('all','candidates','employers')), published_at timestamptz,
  created_by text references profiles, created_at timestamptz not null default now());
create table reports (id uuid primary key default gen_random_uuid(), reporter_id text references profiles,
  target_type text not null, target_id text not null, reason text not null,
  status text not null default 'open' check (status in ('open','actioned','dismissed')), resolved_by text, created_at timestamptz not null default now());
create table audit_logs (id bigserial primary key, actor_id text, actor_role text, action text not null,
  target_table text, target_id text, diff jsonb, ip inet, created_at timestamptz not null default now());
create table news_articles (id uuid primary key default gen_random_uuid(), source text not null, url text not null unique,
  title text not null, summary text, image_url text, published_at timestamptz not null,
  categories text[] not null default '{}', relevance real not null, created_at timestamptz not null default now());
```

### 6.1 Triggers and functions (invariants live here)
| Function | Fires on | Does |
|---|---|---|
| `jobs_bump_application_count` | `applications` insert | `application_count + 1` (security definer — the client can't touch it) |
| `applications_guard_insert` | `applications` before insert | Job must be `published`, deadline not passed, candidate email verified |
| `applications_guard_stage` | `applications` before update of `stage` | Transition must exist in `application_stage_transitions`; actor must be a member of the job's company (or the candidate, for `withdrawn` only); writes `application_events` |
| `notify_on_event` | `application_events`, `interviews`, `offers` insert/update | Inserts the matching `notifications` row(s) |
| `jobs_moderation` | `jobs` before insert/update | Native job from an unverified company goes to `pending_review` instead of `published` |
| `audit_*` | admin-relevant tables | Appends to `audit_logs` |
| `touch_updated_at` | all mutable tables | Maintains `updated_at` |
| `profile_completion` | `profiles`, `educations`, `experiences`, `resumes`, `profile_skills` | Recomputes completion % |

`audit_logs` is append-only: `revoke update, delete on audit_logs from authenticated, anon;` plus a trigger that raises on update/delete.

### 6.2 RLS summary
| Table | Select | Insert / Update / Delete |
|---|---|---|
| profiles | self; employers for candidates who applied to their company; admin | self (not `role`, not `account_status`); admin |
| educations, experiences, profile_skills, resumes | owner; employers via an application; admin | owner |
| companies | public | owner/members (`verification` admin-only) |
| jobs | public where `status = 'published'`; company members see all their own | company members (native only); external rows are service-role only |
| applications | candidate (own); company members of the job | candidate inserts own; stage updates via guard trigger |
| interviews, offers | candidate of the application; company members | company members; candidate may update `offers.status` to accepted/declined |
| saved_jobs, notifications | owner | owner (notifications insert only via triggers) |
| announcements | published + audience match | admin |
| reports | reporter; admin | any verified user inserts; admin updates |
| audit_logs | admin | none (triggers only) |

Write **pgTAP tests** for every policy (`supabase test db`) — RLS mistakes are the #1 risk in this design.

### 6.3 Storage buckets
| Bucket | Access |
|---|---|
| `avatars` | public read; owner write at `avatars/<uid>/*` |
| `company-media` | public read; company members write at `<company_id>/*` |
| `resumes` | **private**; owner read/write at `<uid>/*`; employers read only via a short-lived signed URL issued by an RPC that checks an application exists. Max 5 MB, PDF/DOCX only |
| `offer-letters` | private; candidate + company members of that application |

---

## 7. Server tier (Vercel Functions, TypeScript)

```
api/
  _lib/ firebaseAdmin.ts  supabaseAdmin.ts  verifyToken.ts  rateLimit.ts  errors.ts
  auth/bootstrap.ts
  admin/users/[id]/role.ts      admin/companies/[id]/verify.ts
  ingest/jobs.ts                ingest/news.ts
  notify/dispatch.ts            resume/parse.ts
  seo/job.ts                    seo/sitemap.ts
```
- Every handler verifies the Firebase ID token (`verifyIdToken`) and checks `app_role` before doing anything privileged.
- The Supabase **service-role key** and all third-party keys are Vercel env vars only — never in the Flutter build.
- Validate input with `zod`; return typed error codes the client maps to messages.

### 7.1 Scheduling
Trigger ingestion with **Supabase `pg_cron` + `pg_net`** calling `/api/ingest/*` with a shared secret header. This works on Vercel's Hobby plan, where Vercel Cron is limited to once per day.

### 7.2 Job aggregation (`/api/ingest/jobs`, every 30 min)
1. Fetch from providers whose terms allow redistribution (the old app used Himalayas, Jobicy, Remotive, Arbeitnow, Adzuna — check each one's attribution and rate-limit rules).
2. Normalize: map to enums, parse salary + **period**, ISO country, workplace type; drop rows missing title/company/URL.
3. Sanitize HTML → Markdown (strip scripts, accessibility helper text, tracking pixels); generate a 2-line `summary`.
4. Upsert on `(external_source, external_id)`; close jobs that disappear from the feed for 48 h.
5. Dedupe across providers by `hash(lower(title) + lower(company) + country)`.
6. External jobs link out ("Apply on <source>"); only native jobs use the in-app application pipeline.

### 7.3 Career news (`/api/ingest/news`, every 2 h)
- Sources: career/HR/tech-hiring RSS feeds and keyword queries (hiring, layoffs, internships, placements, salaries, India + global).
- Score relevance with a keyword model first; optionally an LLM classifier for borderline items. Store only `relevance ≥ 0.6`.
- Store title, summary, source and link only — link out to the publisher; never republish full articles.

### 7.4 Notifications fan-out
`notifications` insert → Supabase **Database Webhook** → `/api/notify/dispatch` → FCM push (mobile + web push) and transactional email (e.g. Resend) according to user preferences. In-app delivery is already instant through Realtime.

### 7.5 Resume parsing (`/api/resume/parse`)
On upload, extract text (pdf-parse / mammoth) and produce **suggested** skills, education and experience that the candidate confirms — never auto-overwrite the profile.

---

## 8. Design system with Google Stitch MCP

**The design system is defined in [`/DESIGN.md`](../DESIGN.md)** (Stitch DESIGN.md format). It has two zones: *Spotlight* for public and candidate screens (Jobright-inspired) and *Workspace* for employer and admin screens (Linear-inspired), with LuzHire's own amber brand, and light and dark themes. Every Stitch prompt and every Flutter widget must use its tokens.

Stitch generates screen designs and HTML/CSS, not Flutter widgets, so use it as the design source and translate:
1. Connect the Stitch MCP server in Claude Code (`claude mcp add ...` with the details you'll provide).
2. Generate in this order: tokens/style guide → public screens (home, job search, job detail, company) → candidate → employer → admin. Ask for light **and** dark variants and compact + expanded layouts.
3. Extract tokens (color roles, type scale, spacing, radii, elevation) into `core/theme/tokens.dart` → `ThemeData` with Material 3 `ColorScheme` for light/dark.
4. Build `core/widgets/` components (JobCard, StageChip, FilterSheet, EmptyState, Skeleton, StatTile, KanbanColumn) from the Stitch screens before building features.
5. Check contrast ≥ 4.5:1, touch targets ≥ 48 dp, focus order, and `Semantics` labels (WCAG 2.1 AA requirement).

---

## 9. Repository, environments, CI/CD

```
luzhire/
  app/                     # Flutter project (web, android, ios)
  api/                     # Vercel Functions (TypeScript)
  supabase/
    migrations/  seed.sql  tests/ (pgTAP)  config.toml
  docs/ARCHITECTURE.md
  vercel.json  package.json  tsconfig.json
  .github/workflows/ci.yml  deploy.yml
  CLAUDE.md
```

**Environments:** `local` (Supabase CLI in Docker + Firebase Auth emulator) → `preview` (Vercel preview + Supabase branch or staging project) → `production`. Flutter config through `--dart-define-from-file=env/<env>.json` (only public values: Supabase URL + anon key, Firebase options).

**Vercel deployment:** Vercel's build image does not include Flutter, so build in GitHub Actions and deploy the prebuilt output:
```
flutter build web --wasm --release        # → app/build/web
vercel build --prod                       # outputDirectory = app/build/web, functions from api/
vercel deploy --prebuilt --prod
```
`vercel.json`: rewrite everything except `/api/*`, `/jobs/*` (SEO), `/sitemap.xml`, and static assets to `/index.html`; immutable cache headers on hashed assets; security headers (CSP, HSTS, `X-Content-Type-Options`, `Referrer-Policy`); COOP/COEP headers if multi-threaded skwasm is enabled.

**Mobile:** Android and iOS builds go to Play Console / App Store Connect (Codemagic or GitHub Actions + fastlane). Vercel only hosts the web build and API.

**CI gates:** `flutter analyze`, `dart format --set-exit-if-changed`, unit + widget tests, `supabase db lint`, pgTAP RLS tests, `tsc --noEmit` + Vitest for `api/`, Lighthouse CI on the SEO pages.

**Observability:** Sentry (Flutter + Vercel), Supabase logs/advisors, Vercel Analytics, a `/api/health` endpoint.

---

## 10. Build plan for Claude Code

> **Superseded by [`docs/ROADMAP.md`](ROADMAP.md)**, which has the current phase order (0–11), status, definition of done and the inputs needed from the project owner. The table below is the original plan, kept for reference.

Each phase ends with something runnable and tested. Feed one phase at a time.

| Phase | Deliverable | Done when |
|---|---|---|
| 0. Foundation | `git init` in this folder, monorepo skeleton, `CLAUDE.md`, Flutter app with go_router + Riverpod, Supabase CLI init, Vercel project linked, CI running | Empty app deploys to a Vercel preview URL |
| 1. Design system | Stitch MCP connected; tokens → ThemeData light/dark; core widgets; responsive shell | Widget gallery screen shows all components in both themes |
| 2. Auth | Firebase Auth (email + Google), `/api/auth/bootstrap`, Supabase third-party auth, role guards, email verification gate | pgTAP test proves a candidate token cannot read another user's profile |
| 3. Schema & RLS | All migrations, triggers, policies, storage buckets, seed data | All pgTAP tests green |
| 4. Public job board | Search with FTS + filters, job detail, companies, saved jobs, keyset pagination, filter sheet on mobile | Search p95 < 300 ms on 10k seeded jobs |
| 5. Candidate | Profile builder, resume upload + parse suggestions, apply flow, applications tracker (realtime), interviews, offers, notifications center | Stage change by employer appears on the candidate screen in < 1 s |
| 6. Employer | Company profile, team invites, job editor (draft/publish), pipeline kanban (Broadcast), interview scheduler, offers, analytics | Full hire flow passes as an integration test |
| 7. Admin | Verification queue, moderation, reports, users/roles, announcements, audit log viewer, platform stats | Every admin action creates an audit row |
| 8. Ingestion & SEO | Job aggregation, news ingestion, SEO job pages + sitemap + JSON-LD | Google Rich Results Test passes on a job page |
| 9. Notifications | DB webhook → FCM + email, preferences screen | Push arrives on Android and web |
| 10. Hardening | Deferred loading, Lighthouse/perf budget, accessibility audit, Sentry, load test (500 concurrent), mobile store builds | NFR targets met and recorded |

**First prompt for Claude Code (Phase 0):**
> Read docs/ARCHITECTURE.md. Do Phase 0 only: initialise git in this folder, create the monorepo layout in §9, scaffold the Flutter app (web/android/ios) with go_router and Riverpod, initialise the Supabase CLI project, add an `api/health.ts` Vercel Function, write `vercel.json` and a GitHub Actions workflow that builds Flutter web with `--wasm` and deploys prebuilt to Vercel. Write a CLAUDE.md summarising the stack, commands and conventions. Stop after Phase 0 and report.

---

## 11. Glossary (use these names everywhere)
- **Candidate** — the job seeker role (`app_role = 'candidate'`). Not "user" or "applicant" in code.
- **Employer** — a person with `app_role = 'employer'`; belongs to one or more **companies** through `company_members`. Never "recruiter" as a role name (`recruiter` is only a company member role).
- **Job** — a vacancy; `source` is `native` or `external`.
- **Application** — a candidate's application to a native job; its position in the pipeline is its **stage**.
- **Admin** — platform administrator.

## 12. Decisions for the project owner
1. **SEO approach** — Vercel-function job pages (recommended, §5.6) or a separate Next.js/Astro public site.
2. **LinkedIn sign-in** — requires upgrading Firebase Auth to Identity Platform; defer unless needed for v1.
3. **News & job feed providers** — confirm each provider's terms allow commercial redistribution before Phase 8.
4. **Supabase plan** — the free tier pauses projects after a week of inactivity and has no daily backups; use Pro for production.
