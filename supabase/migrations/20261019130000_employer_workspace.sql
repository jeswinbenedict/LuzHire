-- LuzHire · Phase 6 · Employer workspace: team invitations and hiring stats.

-- ---------------------------------------------------------------- claims
create or replace function app.email()
returns text
language sql stable
as $$ select lower(app.claims() ->> 'email') $$;

-- ---------------------------------------------------------------- invitations
-- Owners invite teammates by email (RLS hides other people's profiles, so a
-- user id cannot be looked up). The invitee accepts with accept_company_invite.
create table public.company_invites (
  id          uuid primary key default gen_random_uuid(),
  company_id  uuid not null references public.companies on delete cascade,
  email       text not null check (email = lower(trim(email)) and email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  member_role public.member_role not null check (member_role in ('recruiter', 'viewer')),
  invited_by  text references public.profiles on delete set null,
  created_at  timestamptz not null default now(),
  unique (company_id, email)
);
create index company_invites_email_idx on public.company_invites (email);

alter table public.company_invites enable row level security;

create policy company_invites_select on public.company_invites for select to authenticated
  using (
    app.is_company_member(company_id, array['owner']::public.member_role[])
    or (email = (select app.email()) and (select app.email_verified()))
    or (select app.is_admin())
  );
create policy company_invites_insert on public.company_invites for insert to authenticated
  with check (app.is_company_member(company_id, array['owner']::public.member_role[]));
create policy company_invites_delete on public.company_invites for delete to authenticated
  using (
    app.is_company_member(company_id, array['owner']::public.member_role[])
    or email = (select app.email())
  );

create or replace function app.company_invites_before_insert()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  new.email := lower(trim(new.email));
  if not app.is_privileged() then
    new.invited_by := app.uid();
  end if;
  if exists (
    select 1 from public.company_members m join public.profiles p on p.id = m.user_id
    where m.company_id = new.company_id and p.email = new.email
  ) then
    raise exception 'That person is already on the team' using errcode = '23514';
  end if;
  return new;
end
$$;
create trigger company_invites_before_insert before insert on public.company_invites
  for each row execute function app.company_invites_before_insert();

-- Tell the invitee if they already have an account.
create or replace function app.company_invites_after_insert()
returns trigger
language plpgsql security definer
set search_path = public, pg_temp
as $$
declare
  who text;
  company_name text;
begin
  select id into who from public.profiles where email = new.email;
  select name into company_name from public.companies where id = new.company_id;
  if who is not null then
    perform app.notify(
      who, 'company.invite', 'Team invitation',
      'You were invited to join ' || company_name || ' on LuzHire.',
      jsonb_build_object('invite_id', new.id, 'company_id', new.company_id)
    );
  end if;
  return null;
end
$$;
create trigger company_invites_after_insert after insert on public.company_invites
  for each row execute function app.company_invites_after_insert();

-- Accepts an invitation addressed to the caller's verified email. Returns the
-- company id. Employers only (candidates keep separate accounts).
create or replace function public.accept_company_invite(invite uuid)
returns uuid
language plpgsql security definer
set search_path = public, pg_temp
as $$
declare
  i public.company_invites;
begin
  select * into i from public.company_invites where id = invite;
  if i.id is null or i.email is distinct from app.email() or not app.email_verified() then
    raise exception 'Invitation not found' using errcode = '42501';
  end if;
  if app.role() is distinct from 'employer' then
    raise exception 'Only employer accounts can join a company team' using errcode = '42501';
  end if;
  insert into public.company_members (company_id, user_id, member_role)
  values (i.company_id, app.uid(), i.member_role)
  on conflict (company_id, user_id) do nothing;
  delete from public.company_invites where id = i.id;
  perform app.notify_company(
    i.company_id, 'company.member_joined', 'New teammate',
    coalesce((select display_name from public.profiles where id = app.uid()), 'Someone')
      || ' joined the team.',
    jsonb_build_object('company_id', i.company_id)
  );
  return i.company_id;
end
$$;
revoke all on function public.accept_company_invite(uuid) from public, anon;
grant execute on function public.accept_company_invite(uuid) to authenticated;

-- ---------------------------------------------------------------- stats
-- Hiring numbers for one company. SECURITY INVOKER: RLS limits every count
-- to rows the caller may see, so non-members get zeros.
create or replace function public.company_hiring_stats(company uuid)
returns jsonb
language sql stable security invoker
set search_path = public, pg_temp
as $$
  with apps as (
    select a.* from public.applications a
    join public.jobs j on j.id = a.job_id
    where j.company_id = company
  )
  select jsonb_build_object(
    'stages', coalesce(
      (select jsonb_object_agg(stage, n) from (select stage, count(*) n from apps group by stage) s),
      '{}'::jsonb),
    'jobs', (
      select jsonb_build_object(
        'published', count(*) filter (where status = 'published'),
        'draft', count(*) filter (where status = 'draft'),
        'pending_review', count(*) filter (where status = 'pending_review'),
        'closed', count(*) filter (where status in ('closed', 'archived'))
      ) from public.jobs where company_id = company
    ),
    'avg_days_to_hire', (
      select round(avg(extract(epoch from (e.created_at - a.created_at)) / 86400)::numeric, 1)
      from public.application_events e join apps a on a.id = e.application_id
      where e.to_stage = 'hired'
    ),
    'applications_by_week', (
      select coalesce(jsonb_agg(jsonb_build_object('week', w, 'count', n) order by w), '[]'::jsonb)
      from (
        select date_trunc('week', created_at)::date w, count(*) n
        from apps where created_at > now() - interval '12 weeks'
        group by 1
      ) x
    )
  )
$$;
revoke all on function public.company_hiring_stats(uuid) from public, anon;
grant execute on function public.company_hiring_stats(uuid) to authenticated;
