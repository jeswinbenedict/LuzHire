-- Employer workspace: team invitations and hiring stats.
begin;
create extension if not exists pgtap with schema extensions;
select plan(12);

insert into public.profiles (id, role, email, display_name) values
  ('t-own',  'employer',  't-own@example.com',  'Owner'),
  ('t-rec',  'employer',  't-rec@example.com',  'Recruiter'),
  ('t-new',  'employer',  't-new@example.com',  'Newcomer'),
  ('t-out',  'employer',  't-out@example.com',  'Outsider'),
  ('t-cnd',  'candidate', 't-cnd@example.com',  'Candidate');
insert into public.companies (id, owner_id, name, verification)
values ('70000000-0000-4000-a000-000000000001', 't-own', 'Team Co', 'verified');
insert into public.company_members (company_id, user_id, member_role)
values ('70000000-0000-4000-a000-000000000001', 't-rec', 'recruiter');
insert into public.jobs (id, company_id, company_name, title, employment_type, status) values
  ('70000000-0000-4000-b000-000000000001', '70000000-0000-4000-a000-000000000001', '', 'Role A', 'full_time', 'published'),
  ('70000000-0000-4000-b000-000000000002', '70000000-0000-4000-a000-000000000001', '', 'Role B', 'full_time', 'draft');
insert into public.applications (job_id, candidate_id)
values ('70000000-0000-4000-b000-000000000001', 't-cnd');

-- ---- owner invites
select set_config('request.jwt.claims', '{"sub":"t-own","app_role":"employer","email":"t-own@example.com","email_verified":true}', true);
set local role authenticated;
select lives_ok(
  $$insert into public.company_invites (id, company_id, email, member_role)
    values ('70000000-0000-4000-c000-000000000001', '70000000-0000-4000-a000-000000000001', 'T-New@Example.com ', 'recruiter')$$,
  'the owner can invite by email'
);
select is((select email from public.company_invites where id = '70000000-0000-4000-c000-000000000001'),
  't-new@example.com', 'invite emails are normalised');
select throws_ok(
  $$insert into public.company_invites (company_id, email, member_role)
    values ('70000000-0000-4000-a000-000000000001', 't-rec@example.com', 'viewer')$$,
  '23514', 'That person is already on the team', 'cannot invite an existing member'
);
select throws_ok(
  $$insert into public.company_invites (company_id, email, member_role)
    values ('70000000-0000-4000-a000-000000000001', 'x@example.com', 'owner')$$,
  '23514', null, 'invites cannot grant ownership'
);

-- ---- a recruiter cannot invite
reset role;
select set_config('request.jwt.claims', '{"sub":"t-rec","app_role":"employer","email":"t-rec@example.com","email_verified":true}', true);
set local role authenticated;
select throws_ok(
  $$insert into public.company_invites (company_id, email, member_role)
    values ('70000000-0000-4000-a000-000000000001', 'y@example.com', 'viewer')$$,
  '42501', null, 'only owners can invite'
);

-- ---- someone else cannot accept
reset role;
select set_config('request.jwt.claims', '{"sub":"t-out","app_role":"employer","email":"t-out@example.com","email_verified":true}', true);
set local role authenticated;
select is((select count(*)::int from public.company_invites), 0, 'outsiders cannot see invitations');
select throws_ok(
  $$select public.accept_company_invite('70000000-0000-4000-c000-000000000001')$$,
  '42501', 'Invitation not found', 'an invitation for another email cannot be accepted'
);
select is(public.company_hiring_stats('70000000-0000-4000-a000-000000000001') -> 'stages', '{}'::jsonb,
  'outsiders get no hiring numbers');

-- ---- the invitee accepts
reset role;
select set_config('request.jwt.claims', '{"sub":"t-new","app_role":"employer","email":"t-new@example.com","email_verified":true}', true);
set local role authenticated;
select is((select count(*)::int from public.company_invites), 1, 'the invitee sees their invitation');
select is(public.accept_company_invite('70000000-0000-4000-c000-000000000001'),
  '70000000-0000-4000-a000-000000000001'::uuid, 'accepting returns the company');
select is((select member_role::text from public.company_members
           where company_id = '70000000-0000-4000-a000-000000000001' and user_id = 't-new'),
  'recruiter', 'the invitee joins with the invited role');

-- ---- stats for members
select is(public.company_hiring_stats('70000000-0000-4000-a000-000000000001') -> 'stages' ->> 'applied', '1',
  'members see real application counts');

reset role;
select * from finish();
rollback;
