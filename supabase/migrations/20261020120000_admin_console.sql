-- LuzHire · Phase 7 · Admin console: suspension enforcement, reviews,
-- report resolution and platform stats.

-- ---------------------------------------------------------------- suspension
-- A suspended (or deleted) account must not change anything, even while its
-- last ID token is still valid. The API also disables the Firebase user so
-- it cannot sign in again.
create or replace function app.is_active()
returns boolean
language sql stable security definer
set search_path = public, pg_temp
as $$
  select not exists (
    select 1 from public.profiles
    where id = app.uid() and account_status <> 'active'
  )
$$;

-- RESTRICTIVE policies are AND-ed with the permissive ones, so they only
-- ever take access away.
do $$
declare
  t text;
begin
  foreach t in array array[
    'profiles', 'educations', 'experiences', 'profile_skills', 'resumes',
    'companies', 'company_members', 'company_invites', 'jobs', 'job_skills',
    'applications', 'interviews', 'offers', 'saved_jobs', 'reports',
    'announcements', 'skills'
  ] loop
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

-- ---------------------------------------------------------------- reviews
-- Verify or decline a company that asked for verification.
create or replace function public.review_company(company uuid, approve boolean, note text default null)
returns void
language plpgsql security invoker
set search_path = public, pg_temp
as $$
declare
  c public.companies;
  reason text := nullif(trim(coalesce(note, '')), '');
begin
  if not app.is_admin() then
    raise exception 'Only admins can review companies' using errcode = '42501';
  end if;
  update public.companies
  set verification = (case when approve then 'verified' else 'rejected' end)::public.verification
  where id = company and verification = 'pending'
  returning * into c;
  if c.id is null then
    raise exception 'This company is not waiting for review' using errcode = '23514';
  end if;
  perform app.notify_company(
    c.id,
    case when approve then 'company.verified' else 'company.rejected' end,
    case when approve then 'Company verified' else 'Verification declined' end,
    case when approve
      then c.name || ' is verified. New jobs now go live straight away.'
      else c.name || ' was not verified.' || coalesce(' Reason: ' || reason, '')
    end,
    jsonb_build_object('company_id', c.id)
  );
end
$$;

-- Publish or reject a job waiting for review; also takes down a published
-- job (reject) after a report.
create or replace function public.review_job(job uuid, approve boolean, note text default null)
returns void
language plpgsql security invoker
set search_path = public, pg_temp
as $$
declare
  j public.jobs;
  reason text := nullif(trim(coalesce(note, '')), '');
begin
  if not app.is_admin() then
    raise exception 'Only admins can review jobs' using errcode = '42501';
  end if;
  update public.jobs
  set status = (case when approve then 'published' else 'rejected' end)::public.job_status
  where id = job
    and source = 'native'
    and (status = 'pending_review' or (not approve and status = 'published'))
  returning * into j;
  if j.id is null then
    raise exception 'This job cannot be reviewed in its current state' using errcode = '23514';
  end if;
  perform app.notify_company(
    j.company_id,
    case when approve then 'job.published' else 'job.rejected' end,
    case when approve then 'Job published' else 'Job not approved' end,
    case when approve
      then j.title || ' is live on the job board.'
      else j.title || ' was taken off the job board.' || coalesce(' Reason: ' || reason, '')
    end,
    jsonb_build_object('job_id', j.id)
  );
end
$$;

-- ---------------------------------------------------------------- reports
create or replace function public.resolve_report(report uuid, outcome public.report_status)
returns void
language plpgsql security invoker
set search_path = public, pg_temp
as $$
declare
  r public.reports;
begin
  if not app.is_admin() then
    raise exception 'Only admins can resolve reports' using errcode = '42501';
  end if;
  if outcome not in ('actioned', 'dismissed') then
    raise exception 'A report is resolved as actioned or dismissed' using errcode = '23514';
  end if;
  update public.reports
  set status = outcome, resolved_by = app.uid(), resolved_at = now()
  where id = report and status = 'open'
  returning * into r;
  if r.id is null then
    raise exception 'This report is already resolved' using errcode = '23514';
  end if;
  perform app.notify(
    r.reporter_id, 'report.resolved', 'Thanks for your report',
    case when outcome = 'actioned'
      then 'We reviewed your report and took action.'
      else 'We reviewed your report and found no rule was broken.'
    end,
    jsonb_build_object('report_id', r.id)
  );
end
$$;

-- ---------------------------------------------------------------- stats
create or replace function public.admin_platform_stats()
returns jsonb
language plpgsql stable security invoker
set search_path = public, pg_temp
as $$
begin
  if not app.is_admin() then
    raise exception 'Only admins can see platform stats' using errcode = '42501';
  end if;
  return jsonb_build_object(
    'users', coalesce((select jsonb_object_agg(role, n) from (
      select role, count(*) n from public.profiles group by role) x), '{}'::jsonb),
    'suspended', (select count(*) from public.profiles where account_status = 'suspended'),
    'companies', coalesce((select jsonb_object_agg(verification, n) from (
      select verification, count(*) n from public.companies group by verification) x), '{}'::jsonb),
    'jobs', coalesce((select jsonb_object_agg(status, n) from (
      select status, count(*) n from public.jobs group by status) x), '{}'::jsonb),
    'applications', (select count(*) from public.applications),
    'open_reports', (select count(*) from public.reports where status = 'open'),
    'signups_by_week', (
      select coalesce(jsonb_agg(jsonb_build_object('week', w, 'count', n) order by w), '[]'::jsonb)
      from (
        select date_trunc('week', created_at)::date w, count(*) n
        from public.profiles where created_at > now() - interval '12 weeks'
        group by 1
      ) x
    )
  );
end
$$;

revoke all on function public.review_company(uuid, boolean, text) from public, anon;
revoke all on function public.review_job(uuid, boolean, text) from public, anon;
revoke all on function public.resolve_report(uuid, public.report_status) from public, anon;
revoke all on function public.admin_platform_stats() from public, anon;
grant execute on function public.review_company(uuid, boolean, text) to authenticated;
grant execute on function public.review_job(uuid, boolean, text) to authenticated;
grant execute on function public.resolve_report(uuid, public.report_status) to authenticated;
grant execute on function public.admin_platform_stats() to authenticated;
