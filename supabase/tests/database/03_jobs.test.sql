-- Job visibility and moderation.
begin;
create extension if not exists pgtap with schema extensions;
select plan(9);

insert into public.profiles (id, role, email, display_name) values
  ('t-emp1', 'employer', 't-emp1@example.com', 'Verified Employer'),
  ('t-emp2', 'employer', 't-emp2@example.com', 'New Employer');
insert into public.companies (id, owner_id, name, verification) values
  ('20000000-0000-4000-a000-000000000001', 't-emp1', 'Verified Co', 'verified'),
  ('20000000-0000-4000-a000-000000000002', 't-emp2', 'Unverified Co', 'unverified');
insert into public.jobs (id, company_id, company_name, title, employment_type, status) values
  ('20000000-0000-4000-b000-000000000001', '20000000-0000-4000-a000-000000000001', '', 'Published role', 'full_time', 'published'),
  ('20000000-0000-4000-b000-000000000002', '20000000-0000-4000-a000-000000000001', '', 'Draft role', 'full_time', 'draft');

-- ---- anonymous visitor
select set_config('request.jwt.claims', '', true);
set local role anon;
select is((select count(*)::int from public.jobs where id = '20000000-0000-4000-b000-000000000001'), 1, 'visitors see published jobs');
select is((select count(*)::int from public.jobs where id = '20000000-0000-4000-b000-000000000002'), 0, 'visitors cannot see drafts');

-- ---- unverified company publishing
reset role;
select set_config('request.jwt.claims', '{"sub":"t-emp2","app_role":"employer","email_verified":true}', true);
set local role authenticated;
insert into public.jobs (id, company_id, company_name, title, employment_type, status)
values ('20000000-0000-4000-b000-000000000003', '20000000-0000-4000-a000-000000000002', '', 'Needs review', 'full_time', 'published');
select is(
  (select status::text from public.jobs where id = '20000000-0000-4000-b000-000000000003'),
  'pending_review', 'a job from an unverified company goes to review instead of going live'
);
select lives_ok(
  $$update public.jobs set title = 'Hijacked' where id = '20000000-0000-4000-b000-000000000001'$$,
  'editing another company''s job is filtered by RLS'
);
select throws_ok(
  $$insert into public.jobs (company_id, company_name, title, employment_type) values ('20000000-0000-4000-a000-000000000001', '', 'Sneaky', 'full_time')$$,
  '42501', null, 'employers cannot post under a company they do not belong to'
);

-- ---- verified company
reset role;
select is((select title from public.jobs where id = '20000000-0000-4000-b000-000000000001'), 'Published role', 'the other company''s job is unchanged');
select set_config('request.jwt.claims', '{"sub":"t-emp1","app_role":"employer","email_verified":true}', true);
set local role authenticated;
select throws_ok(
  $$update public.jobs set status = 'rejected' where id = '20000000-0000-4000-b000-000000000002'$$,
  '42501', null, 'employers cannot mark jobs as rejected (admin only)'
);
update public.jobs set application_count = 999 where id = '20000000-0000-4000-b000-000000000001';
select is(
  (select application_count from public.jobs where id = '20000000-0000-4000-b000-000000000001'),
  0, 'employers cannot inflate application counts'
);

-- ---- unverified email
reset role;
select set_config('request.jwt.claims', '{"sub":"t-emp1","app_role":"employer","email_verified":false}', true);
set local role authenticated;
select throws_ok(
  $$insert into public.jobs (company_id, company_name, title, employment_type) values ('20000000-0000-4000-a000-000000000001', '', 'Unverified email', 'full_time')$$,
  '42501', null, 'an unverified email address cannot post jobs'
);

reset role;
select * from finish();
rollback;
