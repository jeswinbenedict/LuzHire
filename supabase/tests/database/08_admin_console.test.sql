-- Admin console: reviews, report resolution, stats and suspension.
begin;
create extension if not exists pgtap with schema extensions;
select plan(16);

insert into public.profiles (id, role, email, display_name) values
  ('t-adm', 'admin',     't-adm@example.com', 'Admin'),
  ('t-emp', 'employer',  't-emp@example.com', 'Employer'),
  ('t-can', 'candidate', 't-can@example.com', 'Candidate'),
  ('t-sus', 'candidate', 't-sus@example.com', 'Suspended');
update public.profiles set account_status = 'suspended' where id = 't-sus';
insert into public.companies (id, owner_id, name, verification) values
  ('80000000-0000-4000-a000-000000000001', 't-emp', 'Review Co', 'pending');
insert into public.jobs (id, company_id, company_name, title, employment_type, status) values
  ('80000000-0000-4000-b000-000000000001', '80000000-0000-4000-a000-000000000001', '', 'Waiting', 'full_time', 'pending_review'),
  ('80000000-0000-4000-b000-000000000002', '80000000-0000-4000-a000-000000000001', '', 'Live',    'full_time', 'published');
insert into public.reports (id, reporter_id, target_type, target_id, reason) values
  ('80000000-0000-4000-c000-000000000001', 't-can', 'job', '80000000-0000-4000-b000-000000000002', 'Looks like a scam');

-- ---- non-admins are refused
select set_config('request.jwt.claims', '{"sub":"t-emp","app_role":"employer","email_verified":true}', true);
set local role authenticated;
select throws_ok($$select public.review_company('80000000-0000-4000-a000-000000000001', true)$$,
  '42501', null, 'employers cannot review companies');
select throws_ok($$select public.review_job('80000000-0000-4000-b000-000000000001', true)$$,
  '42501', null, 'employers cannot review jobs');
select throws_ok($$select public.admin_platform_stats()$$,
  '42501', null, 'employers cannot see platform stats');

-- ---- admin decisions
reset role;
select set_config('request.jwt.claims', '{"sub":"t-adm","app_role":"admin","email_verified":true}', true);
set local role authenticated;
select lives_ok($$select public.review_company('80000000-0000-4000-a000-000000000001', true)$$,
  'admins verify a pending company');
select is((select verification::text from public.companies where id = '80000000-0000-4000-a000-000000000001'),
  'verified', 'the company is verified');
select throws_ok($$select public.review_company('80000000-0000-4000-a000-000000000001', false)$$,
  '23514', 'This company is not waiting for review', 'a decided company cannot be reviewed again');
select lives_ok($$select public.review_job('80000000-0000-4000-b000-000000000001', true)$$,
  'admins publish a job waiting for review');
select lives_ok($$select public.review_job('80000000-0000-4000-b000-000000000002', false, 'Misleading salary')$$,
  'admins take down a published job');
select is((select status::text from public.jobs where id = '80000000-0000-4000-b000-000000000002'),
  'rejected', 'the reported job is off the board');
select lives_ok($$select public.resolve_report('80000000-0000-4000-c000-000000000001', 'actioned')$$,
  'admins resolve a report');
select is((select resolved_by from public.reports where id = '80000000-0000-4000-c000-000000000001'),
  't-adm', 'the resolver is recorded');
select is((public.admin_platform_stats() -> 'users' ->> 'candidate')::int,
  (select count(*)::int from public.profiles where role = 'candidate'),
  'stats count users by role');

reset role;
select is((select count(*)::int from public.notifications where user_id = 't-emp'
           and type in ('company.verified', 'job.published', 'job.rejected')), 3,
  'the company hears about every decision');
select is((select body from public.notifications where user_id = 't-emp' and type = 'job.rejected'),
  'Live was taken off the job board. Reason: Misleading salary', 'the reason reaches the employer');

-- ---- suspended accounts cannot write
select set_config('request.jwt.claims', '{"sub":"t-sus","app_role":"candidate","email_verified":true}', true);
set local role authenticated;
select throws_ok(
  $$insert into public.applications (job_id, candidate_id) values ('80000000-0000-4000-b000-000000000001', 't-sus')$$,
  '42501', null, 'a suspended candidate cannot apply');
select throws_ok(
  $$insert into public.saved_jobs (user_id, job_id) values ('t-sus', '80000000-0000-4000-b000-000000000001')$$,
  '42501', null, 'a suspended candidate cannot save jobs');

reset role;
select * from finish();
rollback;
