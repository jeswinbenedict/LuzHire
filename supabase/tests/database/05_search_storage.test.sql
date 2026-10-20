-- Job search RPC and storage access rules.
begin;
create extension if not exists pgtap with schema extensions;
select plan(12);

insert into public.profiles (id, role, email, display_name) values
  ('t-cand1', 'candidate', 't-cand1@example.com', 'Cand One'),
  ('t-cand2', 'candidate', 't-cand2@example.com', 'Cand Two'),
  ('t-emp1',  'employer',  't-emp1@example.com',  'Emp One');
insert into public.companies (id, owner_id, name, verification)
values ('40000000-0000-4000-a000-000000000001', 't-emp1', 'Zyxwv Search Co', 'verified');
insert into public.jobs (id, company_id, company_name, title, employment_type, workplace, status, published_at, salary_min, salary_max, salary_currency, salary_period, description_md) values
  ('40000000-0000-4000-b000-000000000001', '40000000-0000-4000-a000-000000000001', '', 'Qwerty Flutter Wizard', 'full_time', 'remote', 'published', now() - interval '1 hour', 40, 50, 'USD', 'hour', 'The full Wizard description.'),
  ('40000000-0000-4000-b000-000000000002', '40000000-0000-4000-a000-000000000001', '', 'Qwerty Flutter Apprentice', 'full_time', 'onsite', 'published', now() - interval '2 hours', 60000, 80000, 'USD', 'year', default),
  ('40000000-0000-4000-b000-000000000003', '40000000-0000-4000-a000-000000000001', '', 'Qwerty Flutter Draft', 'full_time', 'remote', 'draft', null, null, null, null, null, default);

-- ---- search as a visitor
select set_config('request.jwt.claims', '', true);
set local role anon;
select is((select count(*)::int from public.search_jobs(q => 'qwerty flutter')), 2, 'keyword search finds both published matches');
select is((select count(*)::int from public.search_jobs(q => 'qwerty') where status <> 'published'), 0, 'drafts never appear in search');
select is((select count(*)::int from public.search_jobs(q => 'qwerty', remote_only => true)), 1, 'remote filter');
select is(
  (select title from public.search_jobs(q => 'qwerty', min_annual_salary => 100000)),
  'Qwerty Flutter Wizard',
  'salary filter compares yearly equivalents ($50/hour beats $80k/year)'
);
select isnt(
  (select id from public.search_jobs(q => 'qwerty', page_size => 1,
     after_published => (select published_at from public.search_jobs(q => 'qwerty', page_size => 1)),
     after_id => (select id from public.search_jobs(q => 'qwerty', page_size => 1)))),
  (select id from public.search_jobs(q => 'qwerty', page_size => 1)),
  'keyset pagination returns the next job'
);
select is((select count(*)::int from public.search_jobs(q => 'Zyxwv')), 2, 'search matches company name');
-- Results are job cards: no description, lists or search vector (a page was
-- 50-80 KB). The detail view loads the full job by slug.
select is(
  (select array_agg(a.name order by a.ord)
   from pg_proc p, unnest(p.proargnames, p.proargmodes) with ordinality as a(name, mode, ord)
   where p.oid = 'public.search_jobs'::regproc and a.mode = 't'),
  array['id', 'source', 'company_id', 'company_name', 'external_logo_url',
        'external_source', 'external_url', 'title', 'slug', 'summary',
        'employment_type', 'experience_level', 'workplace', 'location_text',
        'salary_min', 'salary_max', 'salary_currency', 'salary_period',
        'status', 'deadline', 'application_count', 'published_at']::text[],
  'search results carry only the job card fields'
);
select is(
  (select j.description_md from public.jobs j
   where j.slug = (select slug from public.search_jobs(q => 'qwerty', page_size => 1))),
  'The full Wizard description.',
  'a visitor loads the full description of a search result by its slug'
);

-- ---- storage: resumes
reset role;
select set_config('request.jwt.claims', '{"sub":"t-cand1","app_role":"candidate","email_verified":true}', true);
set local role authenticated;
select lives_ok(
  $$insert into storage.objects (bucket_id, name) values ('resumes', 't-cand1/cv.pdf')$$,
  'a candidate can upload a resume to their own folder'
);
select throws_ok(
  $$insert into storage.objects (bucket_id, name) values ('resumes', 't-cand2/cv.pdf')$$,
  '42501', null, 'a candidate cannot upload into someone else''s folder'
);
insert into public.resumes (id, user_id, storage_path, file_name, is_primary)
values ('40000000-0000-4000-c000-000000000001', 't-cand1', 't-cand1/cv.pdf', 'cv.pdf', true);

reset role;
select set_config('request.jwt.claims', '{"sub":"t-emp1","app_role":"employer","email_verified":true}', true);
set local role authenticated;
select is((select count(*)::int from storage.objects where name = 't-cand1/cv.pdf'), 0, 'employers cannot read a resume before an application');

reset role;
select set_config('request.jwt.claims', '{"sub":"t-cand1","app_role":"candidate","email_verified":true}', true);
set local role authenticated;
insert into public.applications (job_id, candidate_id, resume_id)
values ('40000000-0000-4000-b000-000000000001', 't-cand1', '40000000-0000-4000-c000-000000000001');

reset role;
select set_config('request.jwt.claims', '{"sub":"t-emp1","app_role":"employer","email_verified":true}', true);
set local role authenticated;
select is((select count(*)::int from storage.objects where name = 't-cand1/cv.pdf'), 1, 'the hiring team can read the resume attached to an application');

reset role;
select * from finish();
rollback;
