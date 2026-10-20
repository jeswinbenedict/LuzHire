-- LuzHire · Phase 11 · Company directory with every hiring company. The
-- directory listed only employers with a LuzHire profile, so it stayed empty
-- while every live job came from feeds (Remotive, Adzuna). It now also lists
-- the companies behind imported jobs, with their feed logo and open roles.
-- Job cards also carry a native company's own logo.

-- ---------------------------------------------------------------- directory
-- One row per hiring company. Runs with the caller's rights, so RLS on
-- companies and jobs still decides what each visitor sees.
create view public.company_directory with (security_invoker = true) as
  select c.id,
         c.name,
         c.slug,
         c.logo_path,
         null::text as external_logo_url,
         c.verification,
         c.industry,
         c.size_range,
         c.hq_location,
         (select count(*)::int from public.jobs j
          where j.company_id = c.id and j.status = 'published') as open_jobs,
         false as is_external
  from public.companies c
  union all
  select null::uuid,
         min(j.company_name),
         'jobs-at-' || coalesce(nullif(app.slugify(min(j.company_name)), ''),
                                left(md5(lower(min(j.company_name))), 10)),
         null::text,
         (array_agg(j.external_logo_url order by j.published_at desc)
            filter (where j.external_logo_url is not null))[1],
         'unverified'::public.verification,
         null::text,
         null::text,
         null::text,
         count(*)::int,
         true
  from public.jobs j
  where j.source = 'external'
    and j.status = 'published'
    -- A company with a LuzHire profile is listed once, as itself.
    and not exists (select 1 from public.companies c where lower(c.name) = lower(j.company_name))
  group by lower(j.company_name);

grant select on public.company_directory to anon, authenticated;

-- ---------------------------------------------------------------- search
-- Same as 20261020170000 plus two things: an `employer` filter (the open
-- roles of an imported company, which has no company id) and the native
-- company's logo path for job cards.
drop function public.search_jobs(
  text, text, boolean, public.employment_type[], public.experience_level[],
  numeric, text[], int, uuid, timestamptz, uuid, int
);

create function public.search_jobs(
  q                  text default null,
  location           text default null,
  remote_only        boolean default false,
  types              public.employment_type[] default null,
  levels             public.experience_level[] default null,
  min_annual_salary  numeric default null,
  skill_slugs        text[] default null,
  posted_within_days int default null,
  company            uuid default null,
  after_published    timestamptz default null,
  after_id           uuid default null,
  page_size          int default 20,
  employer           text default null
)
returns table (
  id                uuid,
  source            public.job_source,
  company_id        uuid,
  company_name      text,
  company_logo_path text,
  external_logo_url text,
  external_source   text,
  external_url      text,
  title             text,
  slug              text,
  summary           text,
  employment_type   public.employment_type,
  experience_level  public.experience_level,
  workplace         public.workplace_type,
  location_text     text,
  salary_min        numeric,
  salary_max        numeric,
  salary_currency   char(3),
  salary_period     public.salary_period,
  status            public.job_status,
  deadline          date,
  application_count int,
  published_at      timestamptz
)
language sql stable security invoker
set search_path = public, extensions, pg_temp
as $$
  select j.id, j.source, j.company_id, j.company_name,
         (select c.logo_path from public.companies c where c.id = j.company_id),
         j.external_logo_url, j.external_source, j.external_url, j.title,
         j.slug, j.summary, j.employment_type, j.experience_level,
         j.workplace, j.location_text, j.salary_min, j.salary_max,
         j.salary_currency, j.salary_period, j.status, j.deadline,
         j.application_count, j.published_at
  from public.jobs j
  where j.status = 'published'
    and (
      coalesce(trim(q), '') = ''
      or j.search @@ websearch_to_tsquery('english', q)
      or j.title ilike '%' || trim(q) || '%'
      or j.company_name ilike '%' || trim(q) || '%'
    )
    and (
      coalesce(trim(location), '') = ''
      or j.location_text ilike '%' || trim(location) || '%'
      or (lower(trim(location)) = 'remote' and j.workplace = 'remote')
    )
    and (not coalesce(remote_only, false) or j.workplace = 'remote')
    and (types is null or cardinality(types) = 0 or j.employment_type = any (types))
    and (levels is null or cardinality(levels) = 0 or j.experience_level = any (levels))
    and (
      min_annual_salary is null
      or app.annual_salary(coalesce(j.salary_max, j.salary_min), j.salary_period) >= min_annual_salary
    )
    and (
      skill_slugs is null or cardinality(skill_slugs) = 0
      or exists (
        select 1 from public.job_skills js join public.skills s on s.id = js.skill_id
        where js.job_id = j.id and s.slug = any (skill_slugs)
      )
    )
    and (posted_within_days is null or j.published_at >= now() - make_interval(days => posted_within_days))
    and (company is null or j.company_id = company)
    and (coalesce(trim(employer), '') = '' or lower(j.company_name) = lower(trim(employer)))
    and (
      after_published is null
      or (j.published_at, j.id) < (after_published, coalesce(after_id, 'ffffffff-ffff-ffff-ffff-ffffffffffff'::uuid))
    )
  order by j.published_at desc, j.id desc
  limit least(greatest(coalesce(page_size, 20), 1), 50)
$$;
grant execute on function public.search_jobs to anon, authenticated;
