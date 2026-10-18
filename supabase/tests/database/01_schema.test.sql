-- Structural guarantees: RLS everywhere, state machine shape, append-only audit log.
begin;
create extension if not exists pgtap with schema extensions;
select plan(6);

select ok(
  not exists (
    select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity
  ),
  'every table in public has row level security enabled'
);

select has_table('public', 'applications', 'applications table exists');

select is(
  (select count(*)::int from public.application_stage_transitions where from_stage = 'applied'),
  4,
  'applied can move to exactly 4 stages'
);

select ok(
  not exists (
    select 1 from public.application_stage_transitions
    where from_stage in ('hired', 'rejected', 'withdrawn')
  ),
  'hired, rejected and withdrawn are terminal'
);

insert into public.audit_logs (action, target_table) values ('test.insert', 'test');

select throws_ok(
  $$update public.audit_logs set action = 'tampered'$$,
  '42501', null,
  'audit log rows cannot be edited, even by the database owner'
);

select throws_ok(
  $$delete from public.audit_logs$$,
  '42501', null,
  'audit log rows cannot be deleted'
);

select * from finish();
rollback;
