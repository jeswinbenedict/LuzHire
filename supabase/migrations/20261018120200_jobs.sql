-- LuzHire · Phase 2 · Jobs (native postings + aggregated external feeds).

create table public.jobs (
  id                uuid primary key default gen_random_uuid(),
  source            public.job_source not null default 'native',
  company_id        uuid references public.companies on delete cascade,   -- native only
  company_name      text not null,                                        -- denormalised for search/cards
  external_logo_url text,
  external_source   text,
  external_id       text,
  external_url      text check (external_url ~* '^https?://'),
  posted_by         text references public.profiles on delete set null,
  title             text not null check (length(trim(title)) between 2 and 160),
  slug              text not null unique,
  description_md    text not null default '' check (length(description_md) <= 30000),
  summary           text check (length(summary) <= 400),
  employment_type   public.employment_type not null,
  experience_level  public.experience_level,
  workplace         public.workplace_type not null default 'onsite',
  location_text     text,
  country_code      char(2),
  salary_min        numeric check (salary_min >= 0),
  salary_max        numeric check (salary_max >= 0),
  salary_currency   char(3),
  salary_period     public.salary_period,
  responsibilities  text[] not null default '{}',
  qualifications    text[] not null default '{}',
  benefits          text[] not null default '{}',
  status            public.job_status not null default 'draft',
  deadline          date,
  application_count int not null default 0 check (application_count >= 0),
  view_count        int not null default 0 check (view_count >= 0),
  published_at      timestamptz,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  search tsvector generated always as (
    setweight(to_tsvector('english'::regconfig, coalesce(title, '')), 'A') ||
    setweight(to_tsvector('english'::regconfig, coalesce(company_name, '') || ' ' || coalesce(location_text, '')), 'B') ||
    setweight(to_tsvector('english'::regconfig, coalesce(summary, '') || ' ' || coalesce(description_md, '')), 'C')
  ) stored,
  unique (external_source, external_id),
  check (salary_min is null or salary_max is null or salary_min <= salary_max),
  -- A salary needs a currency and a period, so "$18–22 /yr" mistakes can't happen.
  check ((salary_min is null and salary_max is null) or (salary_currency is not null and salary_period is not null)),
  check ((source = 'native') = (company_id is not null)),
  check (source = 'native' or (external_source is not null and external_id is not null and external_url is not null))
);

create index jobs_search_idx      on public.jobs using gin (search);
create index jobs_title_trgm      on public.jobs using gin (title extensions.gin_trgm_ops);
create index jobs_company_trgm    on public.jobs using gin (company_name extensions.gin_trgm_ops);
create index jobs_feed_idx        on public.jobs (published_at desc, id desc) where status = 'published';
create index jobs_company_idx     on public.jobs (company_id);
create index jobs_location_trgm   on public.jobs using gin (location_text extensions.gin_trgm_ops);

create table public.job_skills (
  job_id   uuid not null references public.jobs on delete cascade,
  skill_id int  not null references public.skills on delete cascade,
  primary key (job_id, skill_id)
);
create index job_skills_skill_idx on public.job_skills (skill_id);

create trigger jobs_touch before update on public.jobs for each row execute function app.touch_updated_at();

-- Moderation + integrity for job writes made by employers.
-- Runs as the caller (not SECURITY DEFINER) so app.is_privileged() sees the
-- real role; reading companies is allowed by their RLS policies.
create or replace function app.jobs_before_write()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  privileged boolean := app.is_privileged();
  company_verified boolean;
begin
  if tg_op = 'INSERT' then
    if new.slug is null or new.slug = '' then
      new.slug := app.slugify(new.title) || '-' || right(replace(new.id::text, '-', ''), 8);
    end if;
    if not privileged then
      new.application_count := 0;
      new.view_count := 0;
      new.posted_by := app.uid();
    end if;
  else
    if not privileged then
      if new.company_id is distinct from old.company_id
         or new.source is distinct from old.source
         or new.posted_by is distinct from old.posted_by then
        raise exception 'company, source and author of a job cannot change' using errcode = '42501';
      end if;
      new.application_count := old.application_count;
      new.view_count := old.view_count;
      new.published_at := old.published_at;
    end if;
  end if;

  if new.source = 'native' then
    select c.name, c.verification = 'verified' into new.company_name, company_verified
    from public.companies c where c.id = new.company_id;
  end if;

  if not privileged then
    if new.status = 'rejected' and (tg_op = 'INSERT' or old.status <> 'rejected') then
      raise exception 'Only an admin can reject a job' using errcode = '42501';
    end if;
    -- Unverified companies go through review before anything is public.
    if new.status = 'published' and (tg_op = 'INSERT' or old.status <> 'published')
       and not coalesce(company_verified, false) then
      new.status := 'pending_review';
    end if;
  end if;

  if new.status = 'published' and new.published_at is null then
    new.published_at := now();
  end if;
  return new;
end
$$;
create trigger jobs_before_write before insert or update on public.jobs
  for each row execute function app.jobs_before_write();

-- Keep denormalised company name in sync.
create or replace function app.companies_sync_job_names()
returns trigger
language plpgsql security definer
set search_path = public, pg_temp
as $$
begin
  if new.name is distinct from old.name then
    update public.jobs set company_name = new.name where company_id = new.id;
  end if;
  return null;
end
$$;
create trigger companies_sync_job_names after update of name on public.companies
  for each row execute function app.companies_sync_job_names();

-- Is the current user an owner/recruiter (or any member) of the job's company?
create or replace function app.is_job_member(
  job uuid,
  roles public.member_role[] default array['owner', 'recruiter', 'viewer']::public.member_role[]
)
returns boolean
language sql stable security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.jobs j
    join public.company_members m on m.company_id = j.company_id
    where j.id = job and m.user_id = app.uid() and m.member_role = any (roles)
  )
$$;
