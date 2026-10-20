-- Ingestion runs: admin-only reads, no client writes; external jobs.
begin;
create extension if not exists pgtap with schema extensions;
select plan(4);

insert into public.profiles (id, role, email, display_name) values
  ('t-ia', 'admin', 't-ia@example.com', 'Admin'),
  ('t-ic', 'candidate', 't-ic@example.com', 'Candidate');
insert into public.ingest_runs (source, fetched, inserted) values ('remotive', 10, 7);
insert into public.jobs (source, company_name, title, employment_type, status,
                         external_source, external_id, external_url)
values ('external', 'Remote Co', 'Remote Flutter Dev', 'full_time', 'published',
        'remotive', 'r-1', 'https://remotive.com/remote-jobs/x-1');

select set_config('request.jwt.claims', '{"sub":"t-ic","app_role":"candidate","email_verified":true}', true);
set local role authenticated;
select is((select count(*)::int from public.ingest_runs), 0, 'candidates cannot read ingest runs');
select throws_ok($$insert into public.ingest_runs (source) values ('x')$$, '42501', null,
  'clients cannot write ingest runs');
select is((select count(*)::int from public.jobs where external_id = 'r-1'), 1,
  'published external jobs are public');

reset role;
select set_config('request.jwt.claims', '{"sub":"t-ia","app_role":"admin","email_verified":true}', true);
set local role authenticated;
select is((select count(*)::int from public.ingest_runs where source = 'remotive'), 1,
  'admins read ingest runs');

reset role;
select * from finish();
rollback;
