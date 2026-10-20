-- LuzHire · Phase 10 · First-party error log. Crashes in the app (web,
-- Android, iOS) arrive through POST /api/telemetry/error; unexpected API
-- errors are recorded by the API itself. Only the server writes (service
-- role); admins read and clear. No user ids or emails are stored.

create table public.app_errors (
  id          bigint generated always as identity primary key,
  source      text not null check (source in ('web', 'android', 'ios', 'api')),
  message     text not null check (length(message) between 1 and 500),
  detail      text check (length(detail) <= 4000),
  route       text check (length(route) <= 200),
  release     text check (length(release) <= 40),
  user_agent  text check (length(user_agent) <= 300),
  created_at  timestamptz not null default now()
);
create index app_errors_created_idx on public.app_errors (created_at desc);

alter table public.app_errors enable row level security;
create policy app_errors_admin_select on public.app_errors for select to authenticated
  using ((select app.is_admin()));
create policy app_errors_admin_delete on public.app_errors for delete to authenticated
  using ((select app.is_admin()));

-- Errors older than 30 days are not useful; the API prunes on insert.
create or replace function public.prune_app_errors()
returns void
language sql security definer
set search_path = public, pg_temp
as $$
  delete from public.app_errors where created_at < now() - interval '30 days'
$$;
revoke all on function public.prune_app_errors() from public, anon, authenticated;
grant execute on function public.prune_app_errors() to service_role;
