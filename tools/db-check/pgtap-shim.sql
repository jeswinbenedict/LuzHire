-- Tiny subset of pgTAP so supabase/tests/database/*.test.sql also run in PGlite.
-- Supported: plan, ok, is, isnt, throws_ok (4 args), lives_ok, has_table, finish.
-- Real CI uses the genuine pgTAP via `supabase test db`.

create schema tap;
grant usage on schema tap to public;
create sequence tap.n;
grant usage, update on sequence tap.n to public;

create function tap._res(passed boolean, descr text) returns text language sql as $$
  select case when passed then 'ok ' else 'not ok ' end || nextval('tap.n') || ' - ' || coalesce(descr, '')
$$;

create function tap.plan(n int) returns text language plpgsql as $$
begin
  perform setval('tap.n', 1, false);
  return '1..' || n;
end
$$;

create function tap.ok(passed boolean, descr text default '') returns text language sql as $$
  select tap._res(coalesce(passed, false), descr)
$$;

create function tap."is"(have anyelement, want anyelement, descr text default '') returns text language sql as $$
  select tap._res(
    have is not distinct from want,
    descr || case when have is distinct from want
      then ' (have: ' || coalesce(have::text, 'NULL') || ', want: ' || coalesce(want::text, 'NULL') || ')' else '' end
  )
$$;

create function tap.isnt(have anyelement, want anyelement, descr text default '') returns text language sql as $$
  select tap._res(have is distinct from want, descr)
$$;

create function tap.throws_ok(sql text, errcode text, errmsg text, descr text) returns text language plpgsql as $$
begin
  execute sql;
  return tap._res(false, descr || ' (no exception was raised)');
exception when others then
  return tap._res(
    (errcode is null or sqlstate = errcode) and (errmsg is null or sqlerrm = errmsg),
    descr || case when (errcode is null or sqlstate = errcode) and (errmsg is null or sqlerrm = errmsg)
      then '' else ' (got ' || sqlstate || ': ' || sqlerrm || ')' end
  );
end
$$;

create function tap.lives_ok(sql text, descr text) returns text language plpgsql as $$
begin
  execute sql;
  return tap._res(true, descr);
exception when others then
  return tap._res(false, descr || ' (' || sqlstate || ': ' || sqlerrm || ')');
end
$$;

create function tap.has_table(sch name, tbl name, descr text) returns text language sql as $$
  select tap._res(exists (
    select 1 from pg_catalog.pg_tables where schemaname = sch and tablename = tbl
  ), descr)
$$;

create function tap.finish() returns setof text language sql as $$ select null::text where false $$;

grant execute on all functions in schema tap to public;
