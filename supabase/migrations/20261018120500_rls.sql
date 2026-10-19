-- LuzHire · Phase 2 · Row Level Security. Default deny: every table has RLS on,
-- and access exists only where a policy below grants it. The service role
-- (Vercel functions) bypasses RLS. Helpers are wrapped in (select …) so they
-- are evaluated once per statement, not per row.

alter table public.profiles                     enable row level security;
alter table public.educations                   enable row level security;
alter table public.experiences                  enable row level security;
alter table public.skills                       enable row level security;
alter table public.profile_skills               enable row level security;
alter table public.resumes                      enable row level security;
alter table public.companies                    enable row level security;
alter table public.company_members              enable row level security;
alter table public.jobs                         enable row level security;
alter table public.job_skills                   enable row level security;
alter table public.applications                 enable row level security;
alter table public.application_stage_transitions enable row level security;
alter table public.application_events           enable row level security;
alter table public.interviews                   enable row level security;
alter table public.offers                       enable row level security;
alter table public.saved_jobs                   enable row level security;
alter table public.notifications                enable row level security;
alter table public.announcements                enable row level security;
alter table public.reports                      enable row level security;
alter table public.audit_logs                   enable row level security;
alter table public.news_articles                enable row level security;

-- ---------------------------------------------------------------- profiles
create policy profiles_select on public.profiles for select to authenticated
  using (
    id = (select app.uid())
    or (select app.is_admin())
    or app.can_view_candidate(id)
    or app.shares_company(id)
  );
create policy profiles_update on public.profiles for update to authenticated
  using (id = (select app.uid()) or (select app.is_admin()))
  with check (id = (select app.uid()) or (select app.is_admin()));
-- Inserts happen only through /api/auth/bootstrap (service role).

-- ---------------------------------------------------------------- candidate data
create policy educations_select on public.educations for select to authenticated
  using (user_id = (select app.uid()) or (select app.is_admin()) or app.can_view_candidate(user_id));
create policy educations_write on public.educations for all to authenticated
  using (user_id = (select app.uid())) with check (user_id = (select app.uid()));

create policy experiences_select on public.experiences for select to authenticated
  using (user_id = (select app.uid()) or (select app.is_admin()) or app.can_view_candidate(user_id));
create policy experiences_write on public.experiences for all to authenticated
  using (user_id = (select app.uid())) with check (user_id = (select app.uid()));

create policy profile_skills_select on public.profile_skills for select to authenticated
  using (user_id = (select app.uid()) or (select app.is_admin()) or app.can_view_candidate(user_id));
create policy profile_skills_write on public.profile_skills for all to authenticated
  using (user_id = (select app.uid())) with check (user_id = (select app.uid()));

create policy resumes_select on public.resumes for select to authenticated
  using (user_id = (select app.uid()) or (select app.is_admin()) or app.can_view_candidate(user_id));
create policy resumes_write on public.resumes for all to authenticated
  using (user_id = (select app.uid())) with check (user_id = (select app.uid()));

create policy skills_select on public.skills for select to anon, authenticated using (true);
create policy skills_insert on public.skills for insert to authenticated
  with check ((select app.email_verified()) and slug = app.slugify(name));

-- ---------------------------------------------------------------- companies
create policy companies_select on public.companies for select to anon, authenticated
  using (verification <> 'rejected' or app.is_company_member(id) or (select app.is_admin()));
create policy companies_insert on public.companies for insert to authenticated
  with check (
    owner_id = (select app.uid())
    and (select app.role()) in ('employer', 'admin')
    and (select app.email_verified())
  );
create policy companies_update on public.companies for update to authenticated
  using (app.can_edit_company(id) or (select app.is_admin()))
  with check (app.can_edit_company(id) or (select app.is_admin()));
create policy companies_delete on public.companies for delete to authenticated
  using (owner_id = (select app.uid()) or (select app.is_admin()));

create policy company_members_select on public.company_members for select to authenticated
  using (app.is_company_member(company_id) or (select app.is_admin()));
create policy company_members_manage on public.company_members for all to authenticated
  using (app.is_company_member(company_id, array['owner']::public.member_role[]) or (select app.is_admin()))
  with check (app.is_company_member(company_id, array['owner']::public.member_role[]) or (select app.is_admin()));

-- ---------------------------------------------------------------- jobs
create policy jobs_select on public.jobs for select to anon, authenticated
  using (
    status = 'published'
    or (company_id is not null and app.is_company_member(company_id))
    or (select app.is_admin())
  );
create policy jobs_insert on public.jobs for insert to authenticated
  with check (
    source = 'native'
    and (select app.email_verified())
    and (select app.role()) in ('employer', 'admin')
    and app.can_edit_company(company_id)
  );
create policy jobs_update on public.jobs for update to authenticated
  using ((company_id is not null and app.can_edit_company(company_id)) or (select app.is_admin()))
  with check ((company_id is not null and app.can_edit_company(company_id)) or (select app.is_admin()));
create policy jobs_delete on public.jobs for delete to authenticated
  using ((status = 'draft' and app.can_edit_company(company_id)) or (select app.is_admin()));

create policy job_skills_select on public.job_skills for select to anon, authenticated
  using (exists (select 1 from public.jobs j where j.id = job_id));
create policy job_skills_write on public.job_skills for all to authenticated
  using (app.is_job_member(job_id, array['owner', 'recruiter']::public.member_role[]))
  with check (app.is_job_member(job_id, array['owner', 'recruiter']::public.member_role[]));

-- ---------------------------------------------------------------- applications
create policy applications_select on public.applications for select to authenticated
  using (
    candidate_id = (select app.uid())
    or app.is_job_member(job_id)
    or (select app.is_admin())
  );
create policy applications_insert on public.applications for insert to authenticated
  with check (
    candidate_id = (select app.uid())
    and (select app.role()) = 'candidate'
    and (select app.email_verified())
  );
create policy applications_update on public.applications for update to authenticated
  using (
    candidate_id = (select app.uid())
    or app.is_job_member(job_id, array['owner', 'recruiter']::public.member_role[])
    or (select app.is_admin())
  );

create policy transitions_select on public.application_stage_transitions for select to anon, authenticated
  using (true);

create policy application_events_select on public.application_events for select to authenticated
  using (exists (select 1 from public.applications a where a.id = application_id));

create policy interviews_select on public.interviews for select to authenticated
  using (app.is_application_member(application_id) or (select app.is_admin()));
create policy interviews_write on public.interviews for all to authenticated
  using (app.is_application_member(application_id, array['owner', 'recruiter']::public.member_role[]))
  with check (app.is_application_member(application_id, array['owner', 'recruiter']::public.member_role[]));

create policy offers_select on public.offers for select to authenticated
  using (
    app.is_application_candidate(application_id)
    or app.is_application_member(application_id)
    or (select app.is_admin())
  );
create policy offers_insert on public.offers for insert to authenticated
  with check (app.is_application_member(application_id, array['owner', 'recruiter']::public.member_role[]));
create policy offers_update on public.offers for update to authenticated
  using (
    app.is_application_candidate(application_id)
    or app.is_application_member(application_id, array['owner', 'recruiter']::public.member_role[])
  );

create policy saved_jobs_own on public.saved_jobs for all to authenticated
  using (user_id = (select app.uid())) with check (user_id = (select app.uid()));

-- ---------------------------------------------------------------- communication
create policy notifications_select on public.notifications for select to authenticated
  using (user_id = (select app.uid()));
create policy notifications_update on public.notifications for update to authenticated
  using (user_id = (select app.uid())) with check (user_id = (select app.uid()));
create policy notifications_delete on public.notifications for delete to authenticated
  using (user_id = (select app.uid()));

create policy announcements_public on public.announcements for select to anon
  using (audience = 'all' and published_at is not null and published_at <= now());
create policy announcements_select on public.announcements for select to authenticated
  using (
    (select app.is_admin())
    or (
      published_at is not null and published_at <= now()
      and (
        audience = 'all'
        or (audience = 'candidates' and (select app.role()) = 'candidate')
        or (audience = 'employers' and (select app.role()) = 'employer')
      )
    )
  );
create policy announcements_admin on public.announcements for all to authenticated
  using ((select app.is_admin())) with check ((select app.is_admin()));

create policy reports_insert on public.reports for insert to authenticated
  with check (reporter_id = (select app.uid()) and status = 'open');
create policy reports_select on public.reports for select to authenticated
  using (reporter_id = (select app.uid()) or (select app.is_admin()));
create policy reports_update on public.reports for update to authenticated
  using ((select app.is_admin())) with check ((select app.is_admin()));

create policy audit_logs_admin on public.audit_logs for select to authenticated
  using ((select app.is_admin()));

create policy news_select on public.news_articles for select to anon, authenticated
  using (true);
