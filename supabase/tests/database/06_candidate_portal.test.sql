-- Candidate portal: completion score (skills, primary resume) and set_primary_resume.
begin;
create extension if not exists pgtap with schema extensions;
select plan(8);

insert into public.profiles (id, role, email, display_name) values
  ('t-cp1', 'candidate', 't-cp1@example.com', 'Portal One'),
  ('t-cp2', 'candidate', 't-cp2@example.com', 'Portal Two');
insert into public.skills (name, slug) values
  ('Portal A', 'portal-a'), ('Portal B', 'portal-b'), ('Portal C', 'portal-c');

select set_config('request.jwt.claims', '{"sub":"t-cp1","app_role":"candidate","email_verified":true}', true);
set local role authenticated;

insert into public.profile_skills (user_id, skill_id)
select 't-cp1', id from public.skills where slug in ('portal-a', 'portal-b', 'portal-c');
select is((select profile_completion::int from public.profiles where id = 't-cp1'), 10,
  'three skills raise completion');

insert into public.resumes (id, user_id, storage_path, file_name, is_primary) values
  ('20000000-0000-4000-a000-000000000001', 't-cp1', 't-cp1/one.pdf', 'one.pdf', true),
  ('20000000-0000-4000-a000-000000000002', 't-cp1', 't-cp1/two.pdf', 'two.pdf', false);
select is((select profile_completion::int from public.profiles where id = 't-cp1'), 20,
  'a primary resume raises completion');

select lives_ok($$select public.set_primary_resume('20000000-0000-4000-a000-000000000002')$$,
  'candidate can switch their primary resume');
select is((select id from public.resumes where user_id = 't-cp1' and is_primary),
  '20000000-0000-4000-a000-000000000002'::uuid, 'exactly the chosen resume is primary');
select is((select count(*)::int from public.resumes where user_id = 't-cp1' and is_primary), 1,
  'only one primary resume');

delete from public.resumes where id = '20000000-0000-4000-a000-000000000002';
select is((select profile_completion::int from public.profiles where id = 't-cp1'), 10,
  'deleting the primary resume lowers completion');

delete from public.profile_skills where user_id = 't-cp1'
  and skill_id = (select id from public.skills where slug = 'portal-c');
select is((select profile_completion::int from public.profiles where id = 't-cp1'), 0,
  'dropping below three skills lowers completion');

reset role;
insert into public.resumes (id, user_id, storage_path, file_name) values
  ('20000000-0000-4000-a000-000000000003', 't-cp2', 't-cp2/other.pdf', 'other.pdf');
select set_config('request.jwt.claims', '{"sub":"t-cp1","app_role":"candidate","email_verified":true}', true);
set local role authenticated;
select throws_ok($$select public.set_primary_resume('20000000-0000-4000-a000-000000000003')$$,
  '42501', null, 'cannot make someone else''s resume primary');

reset role;
select * from finish();
rollback;
