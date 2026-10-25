-- Imported events (coding contests, hackathons).
begin;
create extension if not exists pgtap with schema extensions;
select plan(6);

insert into public.profiles (id, role, email, display_name) values
  ('t-ei-emp', 'employer', 't-ei-emp@example.com', 'Emp');
insert into public.companies (id, owner_id, name, verification) values
  ('81000000-0000-4000-a000-000000000001', 't-ei-emp', 'Qzx Import Co', 'verified');
insert into public.company_members (company_id, user_id, member_role) values
  ('81000000-0000-4000-a000-000000000001', 't-ei-emp', 'owner')
on conflict do nothing;

-- ---- the import (service role, privileged)
insert into public.events (id, kind, status, title, organizer_name, mode, starts_at, registration_url, external_source, external_id)
values ('81000000-0000-4000-b000-000000000001', 'competition', 'published', 'Qzx Codeforces Round', 'Codeforces', 'online',
        now() + interval '3 days', 'https://codeforces.com/contests/9999', 'codeforces', '9999');
select is((select status::text from public.events where id = '81000000-0000-4000-b000-000000000001'), 'published',
  'the import publishes events directly');
select throws_ok(
  $$insert into public.events (kind, status, title, organizer_name, mode, starts_at, registration_url, external_source, external_id)
    values ('competition', 'published', 'Qzx Same Round', 'Codeforces', 'online', now() + interval '3 days', 'https://codeforces.com/x', 'codeforces', '9999')$$,
  '23505', null, 'an imported event is stored once per source');
select throws_ok(
  $$insert into public.events (kind, status, title, organizer_name, mode, starts_at, external_source, external_id)
    values ('hackathon', 'published', 'Qzx No Link', 'Hack Club', 'online', now() + interval '3 days', 'hackclub', 'x1')$$,
  '23514', null, 'an imported event links to its page');

-- ---- employers cannot pose as a source
select set_config('request.jwt.claims', '{"sub":"t-ei-emp","app_role":"employer","email_verified":true}', true);
set local role authenticated;
select throws_ok(
  $$insert into public.events (kind, status, title, company_id, organizer_name, mode, starts_at, registration_url, external_source, external_id)
    values ('competition', 'published', 'Qzx Fake Round', '81000000-0000-4000-a000-000000000001', 'x', 'online', now() + interval '3 days', 'https://example.com', 'codeforces', '1')$$,
  '42501', null, 'employers cannot add imported events');
insert into public.events (id, kind, status, title, company_id, organizer_name, mode, starts_at)
values ('81000000-0000-4000-b000-000000000002', 'webinar', 'published', 'Qzx Own Webinar', '81000000-0000-4000-a000-000000000001', 'x', 'online', now() + interval '5 days');
select throws_ok(
  $$update public.events set external_source = 'hackclub', external_id = 'z', registration_url = 'https://example.com' where id = '81000000-0000-4000-b000-000000000002'$$,
  '42501', null, 'employers cannot re-label their events as imported');

-- ---- everyone sees published imported events
reset role;
select set_config('request.jwt.claims', '', true);
set local role anon;
select is((select count(*)::int from public.events where id = '81000000-0000-4000-b000-000000000001'), 1,
  'visitors see imported events');

select * from finish();
rollback;
