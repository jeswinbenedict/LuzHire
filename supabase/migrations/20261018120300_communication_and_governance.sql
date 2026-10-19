-- LuzHire · Phase 2 · Notifications, announcements, reports, audit log, news.

create table public.notifications (
  id         uuid primary key default gen_random_uuid(),
  user_id    text not null references public.profiles on delete cascade,
  type       text not null,                       -- e.g. application.new, application.stage
  title      text not null,
  body       text,
  data       jsonb not null default '{}'::jsonb,  -- ids for deep links
  read_at    timestamptz,
  created_at timestamptz not null default now()
);
create index notifications_user_idx on public.notifications (user_id, created_at desc);
create index notifications_unread_idx on public.notifications (user_id) where read_at is null;

-- Users may only mark their notifications read/unread.
create or replace function app.notifications_guard()
returns trigger
language plpgsql
as $$
begin
  if not app.is_privileged() and (
       new.user_id is distinct from old.user_id or new.type is distinct from old.type
    or new.title is distinct from old.title or new.body is distinct from old.body
    or new.data is distinct from old.data or new.created_at is distinct from old.created_at
  ) then
    raise exception 'Only read status of a notification can change' using errcode = '42501';
  end if;
  return new;
end
$$;
create trigger notifications_guard before update on public.notifications
  for each row execute function app.notifications_guard();

-- Insert one notification (used by SECURITY DEFINER triggers).
create or replace function app.notify(
  recipient text, kind text, heading text, message text, payload jsonb default '{}'::jsonb
)
returns void
language sql security definer
set search_path = public, pg_temp
as $$
  insert into public.notifications (user_id, type, title, body, data)
  values (recipient, kind, heading, message, coalesce(payload, '{}'::jsonb))
$$;

-- Notify every owner/recruiter of a company.
create or replace function app.notify_company(
  company uuid, kind text, heading text, message text, payload jsonb default '{}'::jsonb
)
returns void
language sql security definer
set search_path = public, pg_temp
as $$
  insert into public.notifications (user_id, type, title, body, data)
  select m.user_id, kind, heading, message, coalesce(payload, '{}'::jsonb)
  from public.company_members m
  where m.company_id = company and m.member_role in ('owner', 'recruiter')
$$;

create table public.announcements (
  id           uuid primary key default gen_random_uuid(),
  title        text not null check (length(trim(title)) between 1 and 160),
  body_md      text not null check (length(body_md) <= 10000),
  audience     public.announcement_audience not null default 'all',
  published_at timestamptz,
  created_by   text references public.profiles on delete set null,
  created_at   timestamptz not null default now()
);
create index announcements_published_idx on public.announcements (published_at desc);

create table public.reports (
  id          uuid primary key default gen_random_uuid(),
  reporter_id text not null references public.profiles on delete cascade,
  target_type text not null check (target_type in ('job', 'company', 'profile')),
  target_id   text not null,
  reason      text not null check (length(trim(reason)) between 3 and 2000),
  status      public.report_status not null default 'open',
  resolved_by text references public.profiles on delete set null,
  resolved_at timestamptz,
  created_at  timestamptz not null default now()
);
create index reports_open_idx on public.reports (created_at) where status = 'open';

create table public.audit_logs (
  id           bigint generated always as identity primary key,
  actor_id     text,
  actor_role   text,
  action       text not null,      -- <table>.<insert|update|delete>
  target_table text not null,
  target_id    text,
  diff         jsonb,              -- {column: [old, new]} for updates; row for insert/delete
  ip           inet,
  created_at   timestamptz not null default now()
);
create index audit_logs_created_idx on public.audit_logs (created_at desc);
create index audit_logs_target_idx on public.audit_logs (target_table, target_id);

-- Append-only: nobody (not even admins via the API) may edit or delete history.
create or replace function app.audit_logs_immutable()
returns trigger
language plpgsql
as $$
begin
  raise exception 'audit_logs is append-only' using errcode = '42501';
end
$$;
create trigger audit_logs_immutable before update or delete on public.audit_logs
  for each row execute function app.audit_logs_immutable();
revoke update, delete, truncate on public.audit_logs from anon, authenticated, service_role;

create or replace function app.audit()
returns trigger
language plpgsql security definer
set search_path = public, pg_temp
as $$
declare
  diff jsonb;
  target text;
begin
  if tg_op = 'UPDATE' then
    select jsonb_object_agg(n.key, jsonb_build_array(o.value, n.value))
    into diff
    from jsonb_each(to_jsonb(new)) n
    join jsonb_each(to_jsonb(old)) o using (key)
    where n.value is distinct from o.value and n.key not in ('updated_at', 'search');
    if diff is null then
      return null; -- nothing meaningful changed
    end if;
    target := to_jsonb(new) ->> 'id';
  elsif tg_op = 'INSERT' then
    diff := to_jsonb(new) - 'search';
    target := to_jsonb(new) ->> 'id';
  else
    diff := to_jsonb(old) - 'search';
    target := to_jsonb(old) ->> 'id';
  end if;
  if target is null and tg_table_name = 'company_members' then
    target := coalesce(to_jsonb(new), to_jsonb(old)) ->> 'company_id';
  end if;

  insert into public.audit_logs (actor_id, actor_role, action, target_table, target_id, diff)
  values (app.uid(), coalesce(app.role(), session_user::text), tg_table_name || '.' || lower(tg_op), tg_table_name, target, diff);
  return null;
end
$$;

create table public.news_articles (
  id           uuid primary key default gen_random_uuid(),
  source       text not null,
  url          text not null unique check (url ~* '^https?://'),
  title        text not null,
  summary      text check (length(summary) <= 600),
  image_url    text,
  published_at timestamptz not null,
  categories   text[] not null default '{}',
  relevance    real not null check (relevance between 0 and 1),
  created_at   timestamptz not null default now()
);
create index news_published_idx on public.news_articles (published_at desc);

-- ---------------------------------------------------------------- audit wiring
create trigger companies_audit after insert or update or delete on public.companies
  for each row execute function app.audit();
create trigger company_members_audit after insert or update or delete on public.company_members
  for each row execute function app.audit();
create trigger profiles_audit after update of role, account_status, email on public.profiles
  for each row execute function app.audit();
create trigger jobs_audit after update of status on public.jobs
  for each row when (old.status is distinct from new.status) execute function app.audit();
create trigger announcements_audit after insert or update or delete on public.announcements
  for each row execute function app.audit();
create trigger reports_audit after update on public.reports
  for each row execute function app.audit();
