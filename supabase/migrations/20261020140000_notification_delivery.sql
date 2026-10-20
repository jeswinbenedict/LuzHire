-- LuzHire · Phase 9 · Notification preferences, push tokens and delivery.
-- In-app notifications are still written by triggers (app.notify). A
-- Supabase database webhook on notifications INSERT calls
-- /api/notify/dispatch, which claims undelivered rows here and sends push
-- (FCM) and email according to each user's preferences.

create type public.notification_category as enum
  ('applications', 'interviews', 'offers', 'team', 'account');
create type public.push_platform as enum ('web', 'android', 'ios');
create type public.delivery_channel as enum ('push', 'email');
create type public.delivery_status as enum ('sent', 'failed', 'skipped');

-- Which preference group a notification type belongs to.
create or replace function app.notification_category(kind text)
returns public.notification_category
language sql immutable
as $$
  select (case
    when kind like 'application.%' then 'applications'
    when kind like 'interview.%' then 'interviews'
    when kind like 'offer.%' then 'offers'
    when kind in ('company.invite', 'company.member_joined') then 'team'
    else 'account'
  end)::public.notification_category
$$;

-- ---------------------------------------------------------------- preferences
-- One row per (user, category) the user changed; no row = both channels on.
-- In-app notifications are always kept.
create table public.notification_preferences (
  user_id    text not null references public.profiles on delete cascade,
  category   public.notification_category not null,
  push       boolean not null default true,
  email      boolean not null default true,
  updated_at timestamptz not null default now(),
  primary key (user_id, category)
);
create trigger notification_preferences_touch before update on public.notification_preferences
  for each row execute function app.touch_updated_at();

alter table public.notification_preferences enable row level security;
create policy notification_preferences_select on public.notification_preferences
  for select to authenticated using (user_id = (select app.uid()));
create policy notification_preferences_insert on public.notification_preferences
  for insert to authenticated with check (user_id = (select app.uid()));
create policy notification_preferences_update on public.notification_preferences
  for update to authenticated
  using (user_id = (select app.uid())) with check (user_id = (select app.uid()));
create policy notification_preferences_delete on public.notification_preferences
  for delete to authenticated using (user_id = (select app.uid()));

-- ---------------------------------------------------------------- push tokens
-- FCM registration tokens, one per browser/device. A token moves to whoever
-- signed in on that device last (register_push_token).
create table public.push_tokens (
  token        text primary key check (length(token) between 20 and 4096),
  user_id      text not null references public.profiles on delete cascade,
  platform     public.push_platform not null,
  created_at   timestamptz not null default now(),
  last_seen_at timestamptz not null default now()
);
create index push_tokens_user_idx on public.push_tokens (user_id, last_seen_at desc);

alter table public.push_tokens enable row level security;
create policy push_tokens_select on public.push_tokens
  for select to authenticated using (user_id = (select app.uid()));
create policy push_tokens_delete on public.push_tokens
  for delete to authenticated using (user_id = (select app.uid()));
-- No insert/update policies: clients register through the function below.

create or replace function public.register_push_token(
  device_token text, device_platform public.push_platform
)
returns void
language plpgsql security definer
set search_path = public, pg_temp
as $$
declare
  me text := app.uid();
begin
  if me is null or not app.is_active()
     or not exists (select 1 from public.profiles where id = me) then
    raise exception 'Sign in to turn on push notifications' using errcode = '42501';
  end if;
  if device_token is null or length(device_token) not between 20 and 4096 then
    raise exception 'Invalid push token' using errcode = '22023';
  end if;
  insert into public.push_tokens (token, user_id, platform)
  values (device_token, me, device_platform)
  on conflict (token) do update
    set user_id = excluded.user_id, platform = excluded.platform, last_seen_at = now();
  -- Keep each user's 10 most recent devices.
  delete from public.push_tokens t
  where t.user_id = me
    and t.token not in (
      select k.token from public.push_tokens k
      where k.user_id = me order by k.last_seen_at desc limit 10
    );
end
$$;
revoke all on function public.register_push_token(text, public.push_platform) from public, anon;
grant execute on function public.register_push_token(text, public.push_platform) to authenticated;

-- ---------------------------------------------------------------- delivery
alter table public.notifications add column dispatched_at timestamptz;
-- Rows that existed before delivery was switched on are not sent.
update public.notifications set dispatched_at = created_at;
create index notifications_pending_idx on public.notifications (created_at)
  where dispatched_at is null;

-- Users still may only change read status (dispatched_at is system-owned).
create or replace function app.notifications_guard()
returns trigger
language plpgsql
as $$
begin
  if not app.is_privileged() and (
       new.user_id is distinct from old.user_id or new.type is distinct from old.type
    or new.title is distinct from old.title or new.body is distinct from old.body
    or new.data is distinct from old.data or new.created_at is distinct from old.created_at
    or new.dispatched_at is distinct from old.dispatched_at
  ) then
    raise exception 'Only read status of a notification can change' using errcode = '42501';
  end if;
  return new;
end
$$;

-- What was sent where (admins can read it; only the server writes it).
create table public.notification_deliveries (
  id              bigint generated always as identity primary key,
  notification_id uuid not null references public.notifications on delete cascade,
  channel         public.delivery_channel not null,
  status          public.delivery_status not null,
  detail          text check (length(detail) <= 500),
  created_at      timestamptz not null default now()
);
create index notification_deliveries_created_idx on public.notification_deliveries (created_at desc);
create index notification_deliveries_notification_idx on public.notification_deliveries (notification_id);

alter table public.notification_deliveries enable row level security;
create policy notification_deliveries_admin on public.notification_deliveries
  for select to authenticated using ((select app.is_admin()));

-- Claims up to [max_count] undelivered notifications from the last hour (so
-- each one is delivered at most once, even with concurrent calls) and
-- returns what the dispatcher needs: recipient, channels allowed by their
-- preferences and their push tokens. Suspended accounts get nothing.
-- Server only (service role).
create or replace function public.claim_notification_deliveries(max_count int default 50)
returns table (
  id            uuid,
  user_id       text,
  type          text,
  title         text,
  body          text,
  data          jsonb,
  created_at    timestamptz,
  category      public.notification_category,
  email         text,
  display_name  text,
  role          public.app_role,
  send_push     boolean,
  send_email    boolean,
  tokens        text[]
)
language sql security invoker
set search_path = public, pg_temp
as $$
  with claimed as (
    update public.notifications n
    set dispatched_at = now()
    where n.id in (
      select p.id from public.notifications p
      where p.dispatched_at is null and p.created_at > now() - interval '1 hour'
      order by p.created_at
      limit greatest(1, least(coalesce(max_count, 50), 200))
      for update skip locked
    )
    returning n.*
  )
  select c.id, c.user_id, c.type, c.title, c.body, c.data, c.created_at, k.category,
         pr.email, pr.display_name, pr.role,
         pr.account_status = 'active' and coalesce(np.push, true),
         pr.account_status = 'active' and coalesce(np.email, true),
         coalesce(
           (select array_agg(t.token order by t.last_seen_at desc)
            from public.push_tokens t where t.user_id = c.user_id),
           '{}'::text[])
  from claimed c
  join public.profiles pr on pr.id = c.user_id
  cross join lateral (select app.notification_category(c.type) as category) k
  left join public.notification_preferences np
    on np.user_id = c.user_id and np.category = k.category
  order by c.created_at
$$;
revoke all on function public.claim_notification_deliveries(int) from public, anon, authenticated;
grant execute on function public.claim_notification_deliveries(int) to service_role;

-- "Send me a test": an ordinary notification to yourself, so push and email
-- can be checked end to end. At most one a minute.
create or replace function public.send_test_notification()
returns void
language plpgsql security definer
set search_path = public, pg_temp
as $$
declare
  me text := app.uid();
begin
  if me is null or not app.is_active()
     or not exists (select 1 from public.profiles where id = me) then
    raise exception 'Sign in to send a test notification' using errcode = '42501';
  end if;
  if exists (
    select 1 from public.notifications
    where user_id = me and type = 'system.test' and created_at > now() - interval '1 minute'
  ) then
    raise exception 'You just sent a test. Try again in a minute.' using errcode = '23514';
  end if;
  perform app.notify(me, 'system.test', 'Test notification',
    'Notifications are working. You can change what you receive in your notification settings.');
end
$$;
revoke all on function public.send_test_notification() from public, anon;
grant execute on function public.send_test_notification() to authenticated;

-- Suspended users cannot change anything (Phase 7 rule).
do $$
declare
  t text;
begin
  foreach t in array array['notification_preferences', 'push_tokens'] loop
    execute format(
      'create policy %I on public.%I as restrictive for insert to authenticated with check ((select app.is_active()))',
      t || '_active_insert', t);
    execute format(
      'create policy %I on public.%I as restrictive for update to authenticated using ((select app.is_active())) with check ((select app.is_active()))',
      t || '_active_update', t);
    execute format(
      'create policy %I on public.%I as restrictive for delete to authenticated using ((select app.is_active()))',
      t || '_active_delete', t);
  end loop;
end
$$;
