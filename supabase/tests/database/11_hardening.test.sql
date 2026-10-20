-- Phase 10 hardening: API rate limits and schema-wide security invariants
-- (so a future migration cannot quietly weaken them).
begin;
create extension if not exists pgtap with schema extensions;
select plan(13);

-- ---------------------------------------------------------------- rate limits
set local role service_role;
select is(
  (select array_agg(public.rate_limit_hit('t:bootstrap:1.2.3.4', 3, 60)) from generate_series(1, 4)),
  array[true, true, true, false],
  'a bucket allows max_hits per window, then refuses');
select ok(public.rate_limit_hit('t:bootstrap:5.6.7.8', 3, 60), 'other callers have their own bucket');
reset role;

select set_config('request.jwt.claims', '{"sub":"t-x","app_role":"candidate"}', true);
set local role authenticated;
select throws_ok($$select public.rate_limit_hit('x', 100, 60)$$, '42501', null,
  'signed-in clients cannot use the rate limiter');
select throws_ok($$select count(*) from app.rate_limits$$, '42501', null,
  'or read its counters');
reset role;
set local role anon;
select throws_ok($$select public.rate_limit_hit('x', 100, 60)$$, '42501', null,
  'visitors cannot either');
reset role;

-- ---------------------------------------------------------------- error log
insert into public.profiles (id, role, email, display_name) values
  ('t-ea', 'admin', 't-ea@example.com', 'Admin'),
  ('t-ec', 'candidate', 't-ec@example.com', 'Candidate');
insert into public.app_errors (source, message) values ('web', 'TypeError: x is null');

select set_config('request.jwt.claims', '{"sub":"t-ec","app_role":"candidate"}', true);
set local role authenticated;
select is((select count(*)::int from public.app_errors), 0, 'non-admins cannot read the error log');
select throws_ok($$insert into public.app_errors (source, message) values ('web', 'spam')$$,
  '42501', null, 'clients cannot write to the error log directly');
reset role;
select set_config('request.jwt.claims', '{"sub":"t-ea","app_role":"admin"}', true);
set local role authenticated;
select is((select count(*)::int from public.app_errors where message = 'TypeError: x is null'), 1,
  'admins read the error log');
reset role;
select throws_ok($$insert into public.app_errors (source, message) values ('desktop', 'x')$$,
  '23514', null, 'only known sources are accepted');

-- ---------------------------------------------------------------- invariants
select is(
  (select string_agg(schemaname || '.' || tablename, ', ' order by tablename)
   from pg_tables where schemaname in ('public', 'app') and not rowsecurity),
  null,
  'every table has row level security enabled');

select is(
  (select string_agg(n.nspname || '.' || p.proname, ', ' order by p.proname)
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname in ('public', 'app') and p.prosecdef
     and not exists (select 1 from unnest(coalesce(p.proconfig, '{}')) c where c like 'search_path=%')),
  null,
  'every SECURITY DEFINER function pins its search_path');

select is(
  (select string_agg(p.proname, ', ' order by p.proname)
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname in ('public', 'app') and p.prosecdef
     and p.prorettype = 'trigger'::regtype and p.prosrc like '%is_privileged%'),
  null,
  'trigger functions that check app.is_privileged() are not SECURITY DEFINER');

select is(
  (select string_agg(tablename || '.' || policyname, ', ' order by tablename)
   from pg_policies
   where schemaname in ('public', 'app')
     and roles && array['anon', 'public']::name[]
     and cmd <> 'SELECT'),
  null,
  'no policy lets visitors insert, update or delete');

select * from finish();
rollback;
