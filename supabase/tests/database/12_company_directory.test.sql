-- Company directory: LuzHire employers plus the companies behind imported jobs.
begin;
create extension if not exists pgtap with schema extensions;
select plan(7);

insert into public.profiles (id, role, email, display_name) values
  ('t-cd-emp', 'employer', 't-cd-emp@example.com', 'Emp');
insert into public.companies (id, owner_id, name, verification, logo_path) values
  ('50000000-0000-4000-a000-000000000001', 't-cd-emp', 'Qzx Native Labs', 'verified', 'q/logo.png'),
  ('50000000-0000-4000-a000-000000000002', 't-cd-emp', 'Qzx Rejected Co', 'rejected', null);
insert into public.jobs (company_id, company_name, title, employment_type, status) values
  ('50000000-0000-4000-a000-000000000001', '', 'Qzx Native Role', 'full_time', 'published'),
  ('50000000-0000-4000-a000-000000000001', '', 'Qzx Native Draft', 'full_time', 'draft');
insert into public.jobs (source, company_name, title, employment_type, status, published_at,
                         external_source, external_id, external_url, external_logo_url) values
  ('external', 'Qzx Feed Inc', 'Qzx Feed Role 1', 'full_time', 'published', now() - interval '2 hours',
   'remotive', 'qzx-1', 'https://remotive.com/remote-jobs/qzx-1', 'https://remotive.com/job/1/logo'),
  ('external', 'qzx feed inc', 'Qzx Feed Role 2', 'contract', 'published', now() - interval '1 hour',
   'remotive', 'qzx-2', 'https://remotive.com/remote-jobs/qzx-2', 'https://remotive.com/job/2/logo'),
  ('external', 'Qzx Feed Inc', 'Qzx Feed Closed', 'full_time', 'closed', now() - interval '3 hours',
   'remotive', 'qzx-3', 'https://remotive.com/remote-jobs/qzx-3', null),
  ('external', 'Qzx Native Labs', 'Qzx Same Name', 'full_time', 'published', now(),
   'remotive', 'qzx-4', 'https://remotive.com/remote-jobs/qzx-4', null);

select set_config('request.jwt.claims', '', true);
set local role anon;

select is(
  (select open_jobs from public.company_directory where is_external and name ilike 'qzx feed inc'),
  2,
  'an imported company is listed once (any spelling case) with its open roles'
);
select is(
  (select external_logo_url from public.company_directory where is_external and name ilike 'qzx feed inc'),
  'https://remotive.com/job/2/logo',
  'an imported company shows its newest feed logo'
);
select is(
  (select slug from public.company_directory where is_external and name ilike 'qzx feed inc'),
  'jobs-at-qzx-feed-inc',
  'imported companies get a stable slug'
);
select is(
  (select count(*)::int from public.company_directory where name ilike 'qzx native labs'),
  1,
  'a company with a LuzHire profile is not listed again from feeds'
);
select is(
  (select open_jobs from public.company_directory where name = 'Qzx Native Labs'),
  1,
  'drafts do not count as open roles'
);
select is(
  (select count(*)::int from public.company_directory where name = 'Qzx Rejected Co'),
  0,
  'rejected companies stay hidden'
);
select is(
  (select array_agg(title order by title) from public.search_jobs(employer => 'QZX FEED INC')),
  array['Qzx Feed Role 1', 'Qzx Feed Role 2']::text[],
  'search_jobs lists the open roles of an imported company'
);

reset role;
select * from finish();
rollback;
