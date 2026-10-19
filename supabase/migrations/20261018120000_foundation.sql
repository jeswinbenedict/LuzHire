-- LuzHire · Phase 2 · Foundation: extensions, auth helpers, enums.
-- Identity comes from Firebase (Supabase Third-Party Auth). Claims used:
--   sub            Firebase UID (text)       -> app.uid()
--   app_role       candidate|employer|admin  -> app.role()
--   email_verified boolean                   -> app.email_verified()

create extension if not exists pg_trgm with schema extensions;

create schema if not exists app;
grant usage on schema app to anon, authenticated, service_role;

-- ---------------------------------------------------------------- claims
create or replace function app.claims()
returns jsonb
language sql stable
as $$ select coalesce(auth.jwt(), '{}'::jsonb) $$;

create or replace function app.uid()
returns text
language sql stable
as $$ select app.claims() ->> 'sub' $$;

create or replace function app.role()
returns text
language sql stable
as $$ select app.claims() ->> 'app_role' $$;

create or replace function app.email_verified()
returns boolean
language sql stable
as $$ select coalesce((app.claims() ->> 'email_verified')::boolean, false) $$;

create or replace function app.is_admin()
returns boolean
language sql stable
as $$ select coalesce(app.role() = 'admin', false) $$;

-- System writes (service role, migrations, SECURITY DEFINER triggers) and admins.
create or replace function app.is_privileged()
returns boolean
language sql stable
as $$
  select current_user in ('postgres', 'service_role', 'supabase_admin')
      or app.is_admin()
$$;

-- ---------------------------------------------------------------- utilities
create or replace function app.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end
$$;

create or replace function app.slugify(value text)
returns text
language sql immutable
as $$
  select trim(both '-' from regexp_replace(lower(coalesce(value, '')), '[^a-z0-9]+', '-', 'g'))
$$;

create or replace function app.try_uuid(value text)
returns uuid
language plpgsql immutable
as $$
begin
  return value::uuid;
exception when others then
  return null;
end
$$;

-- ---------------------------------------------------------------- enums
create type public.app_role          as enum ('candidate', 'employer', 'admin');
create type public.account_status    as enum ('active', 'suspended', 'deleted');
create type public.verification      as enum ('unverified', 'pending', 'verified', 'rejected');
create type public.member_role       as enum ('owner', 'recruiter', 'viewer');
create type public.job_status        as enum ('draft', 'pending_review', 'published', 'closed', 'archived', 'rejected');
create type public.job_source        as enum ('native', 'external');
create type public.employment_type   as enum ('full_time', 'part_time', 'contract', 'internship', 'temporary');
create type public.experience_level  as enum ('entry', 'mid', 'senior', 'lead');
create type public.workplace_type    as enum ('onsite', 'remote', 'hybrid');
create type public.salary_period     as enum ('hour', 'month', 'year');
create type public.application_stage as enum (
  'applied', 'under_review', 'shortlisted', 'assessment', 'technical_interview',
  'hr_interview', 'final_review', 'offer_issued', 'hired', 'rejected', 'withdrawn'
);
create type public.interview_mode    as enum ('video', 'phone', 'onsite');
create type public.interview_status  as enum ('scheduled', 'completed', 'cancelled', 'no_show');
create type public.offer_status      as enum ('issued', 'accepted', 'declined', 'withdrawn', 'expired');
create type public.announcement_audience as enum ('all', 'candidates', 'employers');
create type public.report_status     as enum ('open', 'actioned', 'dismissed');

-- Yearly equivalent for comparing salaries across periods (2080 work hours/year).
create or replace function app.annual_salary(amount numeric, period public.salary_period)
returns numeric
language sql immutable
as $$
  select case period
    when 'hour'  then amount * 2080
    when 'month' then amount * 12
    else amount
  end
$$;

create or replace function app.stage_label(stage public.application_stage)
returns text
language sql immutable
as $$
  select case stage
    when 'hr_interview' then 'HR interview'
    else initcap(replace(stage::text, '_', ' '))
  end
$$;
