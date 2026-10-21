-- Opportunities: hiring drives, hackathons and competitions.
begin;
create extension if not exists pgtap with schema extensions;
select plan(16);

insert into public.profiles (id, role, email, display_name) values
  ('t-ev-emp', 'employer', 't-ev-emp@example.com', 'Emp'),
  ('t-ev-emp2', 'employer', 't-ev-emp2@example.com', 'Emp Two'),
  ('t-ev-c1', 'candidate', 't-ev-c1@example.com', 'Cand One'),
  ('t-ev-c2', 'candidate', 't-ev-c2@example.com', 'Cand Two');
insert into public.companies (id, owner_id, name, verification) values
  ('80000000-0000-4000-a000-000000000001', 't-ev-emp', 'Qzx Events Co', 'verified'),
  ('80000000-0000-4000-a000-000000000002', 't-ev-emp2', 'Qzx New Co', 'unverified');
insert into public.company_members (company_id, user_id, member_role) values
  ('80000000-0000-4000-a000-000000000001', 't-ev-emp', 'owner'),
  ('80000000-0000-4000-a000-000000000002', 't-ev-emp2', 'owner')
on conflict do nothing;

-- ---- employers post
select set_config('request.jwt.claims', '{"sub":"t-ev-emp","app_role":"employer","email_verified":true}', true);
set local role authenticated;
insert into public.events (id, kind, status, title, company_id, organizer_name, mode, location_text, starts_at, registration_deadline, capacity)
values ('80000000-0000-4000-b000-000000000001', 'walk_in', 'published', 'Qzx Walk-in drive', '80000000-0000-4000-a000-000000000001', 'x', 'in_person', 'Koramangala, Bangalore', now() + interval '5 days', now() + interval '4 days', 1);
insert into public.events (id, kind, status, title, company_id, organizer_name, mode, starts_at, registration_deadline, team_min, team_max)
values ('80000000-0000-4000-b000-000000000002', 'hackathon', 'published', 'Qzx Hack', '80000000-0000-4000-a000-000000000001', 'x', 'online', now() + interval '10 days', now() + interval '9 days', 2, 4);
insert into public.events (id, kind, status, title, company_id, organizer_name, mode, starts_at, registration_url)
values ('80000000-0000-4000-b000-000000000003', 'competition', 'published', 'Qzx External contest', '80000000-0000-4000-a000-000000000001', 'x', 'online', now() + interval '10 days', 'https://example.com/register');
insert into public.events (id, kind, status, title, company_id, organizer_name, mode, starts_at)
values ('80000000-0000-4000-b000-000000000004', 'webinar', 'published', 'Qzx Past webinar', '80000000-0000-4000-a000-000000000001', 'x', 'online', now() - interval '1 day');

select is((select organizer_name from public.events where id = '80000000-0000-4000-b000-000000000001'), 'Qzx Events Co',
  'the organiser is the company');
select ok((select city_id is not null and latitude is not null from public.events where id = '80000000-0000-4000-b000-000000000001'),
  'in-person events are placed on the map');
select throws_ok(
  $$insert into public.events (kind, title, company_id, organizer_name, mode, starts_at) values ('walk_in', 'No place', '80000000-0000-4000-a000-000000000001', 'x', 'in_person', now() + interval '1 day')$$,
  '23514', null, 'in-person events need a location');
select throws_ok(
  $$update public.events set status = 'rejected' where id = '80000000-0000-4000-b000-000000000001'$$,
  '42501', null, 'only admins reject events');

reset role;
select set_config('request.jwt.claims', '{"sub":"t-ev-emp2","app_role":"employer","email_verified":true}', true);
set local role authenticated;
insert into public.events (id, kind, status, title, company_id, organizer_name, mode, starts_at)
values ('80000000-0000-4000-b000-000000000005', 'campus_drive', 'published', 'Qzx Unverified drive', '80000000-0000-4000-a000-000000000002', 'x', 'online', now() + interval '3 days');
select is((select status::text from public.events where id = '80000000-0000-4000-b000-000000000005'), 'pending_review',
  'events from unverified companies wait for review');
select throws_ok(
  $$insert into public.events (kind, title, company_id, organizer_name, mode, starts_at) values ('walk_in', 'Not mine', '80000000-0000-4000-a000-000000000001', 'x', 'online', now() + interval '1 day')$$,
  '42501', null, 'employers post only for their own company');

-- ---- visitors
reset role;
select set_config('request.jwt.claims', '', true);
set local role anon;
select is((select count(*)::int from public.events where title like 'Qzx%'), 4,
  'visitors see published events only');
select ok((select events >= 1 from public.hiring_locations where name = 'Bengaluru'),
  'the hiring map counts upcoming in-person events');

-- ---- candidates register
reset role;
select set_config('request.jwt.claims', '{"sub":"t-ev-c1","app_role":"candidate","email_verified":true}', true);
set local role authenticated;
insert into public.event_registrations (event_id, user_id) values ('80000000-0000-4000-b000-000000000001', 't-ev-c1');
select is((select registration_count from public.events where id = '80000000-0000-4000-b000-000000000001'), 1,
  'registering counts');
select throws_ok(
  $$insert into public.event_registrations (event_id, user_id) values ('80000000-0000-4000-b000-000000000002', 't-ev-c1')$$,
  '23514', 'Give your team a name', 'team events need a team name');
select throws_ok(
  $$insert into public.event_registrations (event_id, user_id) values ('80000000-0000-4000-b000-000000000003', 't-ev-c1')$$,
  '23514', null, 'external events register on the organiser site');
select throws_ok(
  $$insert into public.event_registrations (event_id, user_id) values ('80000000-0000-4000-b000-000000000004', 't-ev-c1')$$,
  '23514', null, 'registration closes when the event starts');

reset role;
select set_config('request.jwt.claims', '{"sub":"t-ev-c2","app_role":"candidate","email_verified":true}', true);
set local role authenticated;
select throws_ok(
  $$insert into public.event_registrations (event_id, user_id) values ('80000000-0000-4000-b000-000000000001', 't-ev-c2')$$,
  '23514', 'This event is full', 'a full event takes no more registrations');
select is((select count(*)::int from public.event_registrants('80000000-0000-4000-b000-000000000001')), 0,
  'candidates cannot list who registered');

reset role;
select set_config('request.jwt.claims', '{"sub":"t-ev-emp","app_role":"employer","email_verified":true}', true);
set local role authenticated;
select is((select display_name from public.event_registrants('80000000-0000-4000-b000-000000000001')), 'Cand One',
  'the hiring team sees who registered');

reset role;
select set_config('request.jwt.claims', '{"sub":"t-ev-c1","app_role":"candidate","email_verified":true}', true);
set local role authenticated;
delete from public.event_registrations where event_id = '80000000-0000-4000-b000-000000000001';
reset role;
select is((select registration_count from public.events where id = '80000000-0000-4000-b000-000000000001'), 0,
  'withdrawing frees the place');

select * from finish();
rollback;
