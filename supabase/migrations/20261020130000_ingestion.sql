-- LuzHire · Phase 8 · Job ingestion runs (written by the ingest function with
-- the service role; admins can read them).

create table public.ingest_runs (
  id          bigint generated always as identity primary key,
  source      text not null,
  started_at  timestamptz not null default now(),
  finished_at timestamptz,
  fetched     int not null default 0 check (fetched >= 0),
  inserted    int not null default 0 check (inserted >= 0),
  updated     int not null default 0 check (updated >= 0),
  skipped     int not null default 0 check (skipped >= 0),
  closed      int not null default 0 check (closed >= 0),
  error       text
);
create index ingest_runs_started_idx on public.ingest_runs (started_at desc);

alter table public.ingest_runs enable row level security;
create policy ingest_runs_admin on public.ingest_runs for select to authenticated
  using ((select app.is_admin()));
