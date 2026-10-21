-- Geocoding, the hiring map, jobs near a point and recommendations.
begin;
create extension if not exists pgtap with schema extensions;
select plan(13);

select is((select name from public.cities where id = app.city_in('Hybrid - Bangalore, IN')), 'Bengaluru',
  'aliases find a city in free text');
select is((select name from public.cities where id = app.city_in('Navi Mumbai, Maharashtra')), 'Navi Mumbai',
  'the longest matching name wins');
select is(app.city_in('Remote (Worldwide)'), null, 'remote-only text has no city');
select is(app.city_in('Punekar Street'), null, 'only whole words match');

insert into public.profiles (id, role, email, display_name, location, headline) values
  ('t-loc-emp', 'employer', 't-loc-emp@example.com', 'Emp', null, null),
  ('t-loc-cand', 'candidate', 't-loc-cand@example.com', 'Cand', 'Pune', 'Flutter developer');
insert into public.companies (id, owner_id, name, verification)
values ('70000000-0000-4000-a000-000000000001', 't-loc-emp', 'Qzx Map Co', 'verified');
insert into public.skills (id, name, slug) values (99001, 'Qzxlang', 'qzxlang');
insert into public.profile_skills (user_id, skill_id) values ('t-loc-cand', 99001);
insert into public.jobs (id, company_id, company_name, title, employment_type, workplace, status, location_text, published_at) values
  ('70000000-0000-4000-b000-000000000001', '70000000-0000-4000-a000-000000000001', '', 'Qzx Flutter developer', 'full_time', 'onsite', 'published', 'Hinjewadi, Pune', now() - interval '10 days'),
  ('70000000-0000-4000-b000-000000000002', '70000000-0000-4000-a000-000000000001', '', 'Qzx Accountant', 'full_time', 'onsite', 'published', 'Kolkata', now()),
  ('70000000-0000-4000-b000-000000000003', '70000000-0000-4000-a000-000000000001', '', 'Qzx Applied role', 'full_time', 'onsite', 'published', 'Pune', now());
insert into public.job_skills (job_id, skill_id) values ('70000000-0000-4000-b000-000000000002', 99001);

select ok(
  (select latitude between 18 and 19 and longitude between 73 and 74 from public.jobs
   where id = '70000000-0000-4000-b000-000000000001'),
  'new jobs are placed on the map from their location'
);
update public.jobs set location_text = 'Remote' where id = '70000000-0000-4000-b000-000000000003';
select is((select city_id from public.jobs where id = '70000000-0000-4000-b000-000000000003'), null,
  'changing the location re-geocodes the job');
update public.jobs set location_text = 'Pune' where id = '70000000-0000-4000-b000-000000000003';
insert into public.jobs (id, company_id, company_name, title, employment_type, workplace, status, location_text) values
  ('70000000-0000-4000-b000-000000000004', '70000000-0000-4000-a000-000000000001', '', 'Qzx Remote role', 'full_time', 'remote', 'published', 'Remote (Europe, USA, Singapore)');
select is((select city_id from public.jobs where id = '70000000-0000-4000-b000-000000000004'), null,
  'remote jobs stay off the map even when their text names a city');
update public.jobs set workplace = 'hybrid', location_text = 'Hybrid - Pune' where id = '70000000-0000-4000-b000-000000000004';
select ok((select city_id is not null from public.jobs where id = '70000000-0000-4000-b000-000000000004'),
  'a job that becomes hybrid gets its city');

select set_config('request.jwt.claims', '', true);
set local role anon;
select ok(
  (select open_jobs >= 2 from public.hiring_locations where name = 'Pune'),
  'the map counts open roles per city'
);
select ok(
  (select bool_and(distance_km <= 30) and count(*) >= 2
   from public.jobs_near(18.6, 73.75, 30) where title like 'Qzx%'),
  'jobs near a point stay within the radius'
);
select is(
  (select count(*)::int from public.jobs_near(18.6, 73.75, 30) where title = 'Qzx Accountant'),
  0,
  'jobs in other cities are not near'
);

reset role;
select set_config('request.jwt.claims', '{"sub":"t-loc-cand","app_role":"candidate","email_verified":true}', true);
set local role authenticated;
insert into public.applications (job_id, candidate_id) values ('70000000-0000-4000-b000-000000000003', 't-loc-cand');
select is(
  (select match_reasons from public.recommended_jobs(50) where title = 'Qzx Accountant'),
  array['Matches 1 of your skills', 'New this week'],
  'shared skills rank a job and say why'
);
select ok(
  not exists (select 1 from public.recommended_jobs(50) where title = 'Qzx Applied role')
  and (select 'In Pune' = any (match_reasons) and 'Fits your headline' = any (match_reasons)
       from public.recommended_jobs(50) where title = 'Qzx Flutter developer'),
  'recommendations leave out applied jobs and use headline and city'
);

reset role;
select * from finish();
rollback;
