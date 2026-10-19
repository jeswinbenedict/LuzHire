-- Profile privacy and privilege escalation.
begin;
create extension if not exists pgtap with schema extensions;
select plan(8);

insert into public.profiles (id, role, email, display_name) values
  ('t-cand1', 'candidate', 't-cand1@example.com', 'Cand One'),
  ('t-cand2', 'candidate', 't-cand2@example.com', 'Cand Two'),
  ('t-emp1',  'employer',  't-emp1@example.com',  'Emp One');
insert into public.companies (id, owner_id, name, verification)
values ('10000000-0000-4000-a000-000000000001', 't-emp1', 'Profile Test Co', 'verified');
insert into public.jobs (id, company_id, company_name, title, employment_type, status)
values ('10000000-0000-4000-b000-000000000001', '10000000-0000-4000-a000-000000000001', '', 'Engineer', 'full_time', 'published');

-- ---- as candidate 1
select set_config('request.jwt.claims', '{"sub":"t-cand1","app_role":"candidate","email_verified":true}', true);
set local role authenticated;

select is((select count(*)::int from public.profiles where id = 't-cand1'), 1, 'candidate can read their own profile');
select is((select count(*)::int from public.profiles where id = 't-cand2'), 0, 'candidate cannot read another candidate');
select throws_ok(
  $$update public.profiles set role = 'admin' where id = 't-cand1'$$,
  '42501', null, 'candidate cannot promote themselves to admin'
);
select lives_ok(
  $$update public.profiles set headline = 'Flutter developer' where id = 't-cand1'$$,
  'candidate can edit their own headline'
);
select lives_ok(
  $$update public.profiles set headline = 'hacked' where id = 't-cand2'$$,
  'updating someone else''s profile is silently filtered by RLS'
);

reset role;
select is((select headline from public.profiles where id = 't-cand2'), null::text, 'the other profile is unchanged');

-- ---- as employer: candidate is invisible until they apply
select set_config('request.jwt.claims', '{"sub":"t-emp1","app_role":"employer","email_verified":true}', true);
set local role authenticated;
select is((select count(*)::int from public.profiles where id = 't-cand1'), 0, 'employer cannot see a candidate who has not applied');

reset role;
select set_config('request.jwt.claims', '{"sub":"t-cand1","app_role":"candidate","email_verified":true}', true);
set local role authenticated;
insert into public.applications (job_id, candidate_id)
values ('10000000-0000-4000-b000-000000000001', 't-cand1');

reset role;
select set_config('request.jwt.claims', '{"sub":"t-emp1","app_role":"employer","email_verified":true}', true);
set local role authenticated;
select is((select count(*)::int from public.profiles where id = 't-cand1'), 1, 'employer can see the profile once the candidate applies');

reset role;
select * from finish();
rollback;
