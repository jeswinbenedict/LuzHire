-- The recruitment pipeline: applying, stage state machine, offers, interviews.
begin;
create extension if not exists pgtap with schema extensions;
select plan(24);

insert into public.profiles (id, role, email, display_name) values
  ('t-cand1', 'candidate', 't-cand1@example.com', 'Cand One'),
  ('t-cand2', 'candidate', 't-cand2@example.com', 'Cand Two'),
  ('t-cand3', 'candidate', 't-cand3@example.com', 'Cand Three'),
  ('t-emp1',  'employer',  't-emp1@example.com',  'Hiring Manager'),
  ('t-emp2',  'employer',  't-emp2@example.com',  'Other Employer');
insert into public.companies (id, owner_id, name, verification)
values ('30000000-0000-4000-a000-000000000001', 't-emp1', 'Pipeline Co', 'verified');
insert into public.jobs (id, company_id, company_name, title, employment_type, status, deadline) values
  ('30000000-0000-4000-b000-000000000001', '30000000-0000-4000-a000-000000000001', '', 'Open role',    'full_time', 'published', null),
  ('30000000-0000-4000-b000-000000000002', '30000000-0000-4000-a000-000000000001', '', 'Draft role',   'full_time', 'draft',     null),
  ('30000000-0000-4000-b000-000000000003', '30000000-0000-4000-a000-000000000001', '', 'Expired role', 'full_time', 'published', current_date - 1);

-- ---- applying (candidate 1)
select set_config('request.jwt.claims', '{"sub":"t-cand1","app_role":"candidate","email_verified":true}', true);
set local role authenticated;
select lives_ok(
  $$insert into public.applications (id, job_id, candidate_id) values ('30000000-0000-4000-d000-000000000001', '30000000-0000-4000-b000-000000000001', 't-cand1')$$,
  'a verified candidate can apply to a published job'
);
select throws_ok(
  $$insert into public.applications (job_id, candidate_id) values ('30000000-0000-4000-b000-000000000001', 't-cand1')$$,
  '23505', null, 'applying twice to the same job is impossible'
);
select throws_ok(
  $$insert into public.applications (job_id, candidate_id) values ('30000000-0000-4000-b000-000000000002', 't-cand1')$$,
  '23514', 'This job is not accepting applications', 'cannot apply to a draft'
);
select throws_ok(
  $$insert into public.applications (job_id, candidate_id) values ('30000000-0000-4000-b000-000000000003', 't-cand1')$$,
  '23514', 'The application deadline has passed', 'cannot apply after the deadline'
);
select throws_ok(
  $$update public.applications set stage = 'shortlisted' where id = '30000000-0000-4000-d000-000000000001'$$,
  '42501', null, 'a candidate cannot advance their own application'
);

-- ---- unverified email
reset role;
select set_config('request.jwt.claims', '{"sub":"t-cand2","app_role":"candidate","email_verified":false}', true);
set local role authenticated;
select throws_ok(
  $$insert into public.applications (job_id, candidate_id) values ('30000000-0000-4000-b000-000000000001', 't-cand2')$$,
  '42501', null, 'an unverified email cannot apply'
);

reset role;
select is((select application_count from public.jobs where id = '30000000-0000-4000-b000-000000000001'), 1, 'the job''s application counter went up by one');
select is((select count(*)::int from public.notifications where user_id = 't-emp1' and type = 'application.new'), 1, 'the hiring team was notified');

-- ---- hiring team moves the application
select set_config('request.jwt.claims', '{"sub":"t-emp1","app_role":"employer","email_verified":true}', true);
set local role authenticated;
select lives_ok(
  $$update public.applications set stage = 'shortlisted' where id = '30000000-0000-4000-d000-000000000001'$$,
  'the hiring team can shortlist'
);
select throws_ok(
  $$update public.applications set stage = 'hired' where id = '30000000-0000-4000-d000-000000000001'$$,
  '23514', 'Cannot move an application from Shortlisted to Hired', 'stages cannot be skipped'
);
select lives_ok(
  $$update public.applications set stage = 'hr_interview' where id = '30000000-0000-4000-d000-000000000001'$$,
  'shortlisted -> HR interview is allowed'
);
select lives_ok(
  $$insert into public.interviews (application_id, scheduled_at, mode, meeting_url, notes)
    values ('30000000-0000-4000-d000-000000000001', now() + interval '1 day', 'video', 'https://meet.example.com/x', 'private notes')$$,
  'the hiring team can schedule an interview'
);
select lives_ok(
  $$insert into public.offers (application_id, salary, currency, salary_period) values ('30000000-0000-4000-d000-000000000001', 1200000, 'INR', 'year')$$,
  'the hiring team can issue an offer'
);

-- ---- another employer sees nothing
reset role;
select set_config('request.jwt.claims', '{"sub":"t-emp2","app_role":"employer","email_verified":true}', true);
set local role authenticated;
select is((select count(*)::int from public.applications where id = '30000000-0000-4000-d000-000000000001'), 0, 'other employers cannot see the application');

-- ---- candidate side
reset role;
select is((select stage::text from public.applications where id = '30000000-0000-4000-d000-000000000001'), 'offer_issued', 'issuing an offer moves the application to Offer issued');
select set_config('request.jwt.claims', '{"sub":"t-cand1","app_role":"candidate","email_verified":true}', true);
set local role authenticated;
select is((select count(*)::int from public.interviews), 0, 'candidates cannot read interview rows (they hold private notes)');
select is((select count(*)::int from public.candidate_interviews), 1, 'candidates see their interview through the safe view');
select throws_ok(
  $$update public.offers set salary = 99999999 where application_id = '30000000-0000-4000-d000-000000000001'$$,
  '42501', null, 'a candidate cannot change the offer terms'
);
select lives_ok(
  $$update public.offers set status = 'accepted' where application_id = '30000000-0000-4000-d000-000000000001'$$,
  'a candidate can accept the offer'
);

reset role;
select is((select stage::text from public.applications where id = '30000000-0000-4000-d000-000000000001'), 'hired', 'accepting the offer marks the candidate as hired');
select is(
  (select count(*)::int from public.application_events where application_id = '30000000-0000-4000-d000-000000000001'),
  5, 'every stage change is recorded (applied, shortlisted, HR interview, offer, hired)'
);
select is(
  (select count(*)::int from public.notifications where user_id = 't-cand1' and type = 'application.stage'),
  4, 'the candidate was notified of each stage change'
);

-- ---- withdrawing (candidate 3)
select set_config('request.jwt.claims', '{"sub":"t-cand3","app_role":"candidate","email_verified":true}', true);
set local role authenticated;
insert into public.applications (id, job_id, candidate_id)
values ('30000000-0000-4000-d000-000000000003', '30000000-0000-4000-b000-000000000001', 't-cand3');
select lives_ok(
  $$update public.applications set stage = 'withdrawn' where id = '30000000-0000-4000-d000-000000000003'$$,
  'a candidate can withdraw'
);
reset role;
select is((select count(*)::int from public.notifications where user_id = 't-emp1' and type = 'application.withdrawn'), 1, 'the hiring team is told about the withdrawal');

select * from finish();
rollback;
