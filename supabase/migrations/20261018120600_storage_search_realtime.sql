-- LuzHire · Phase 2 · Storage buckets, job search RPC, realtime publication.

-- ---------------------------------------------------------------- storage
-- Paths: avatars/<uid>/…, company-media/<company_id>/…,
--        resumes/<uid>/…, offer-letters/<application_id>/…
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('avatars',       'avatars',       true,  2097152, array['image/png', 'image/jpeg', 'image/webp']),
  ('company-media', 'company-media', true,  5242880, array['image/png', 'image/jpeg', 'image/webp', 'image/svg+xml']),
  ('resumes',       'resumes',       false, 5242880, array['application/pdf', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document']),
  ('offer-letters', 'offer-letters', false, 5242880, array['application/pdf'])
on conflict (id) do nothing;

-- Can the current user read this resume object? Owner, or the hiring team of
-- a job the candidate applied to *with this resume*.
create or replace function app.can_read_resume(object_name text)
returns boolean
language sql stable security definer
set search_path = public, pg_temp
as $$
  select split_part(object_name, '/', 1) = app.uid()
      or app.is_admin()
      or exists (
        select 1
        from public.resumes r
        join public.applications a on a.resume_id = r.id
        where r.storage_path = object_name
          and app.is_job_member(a.job_id)
      )
$$;

create policy luzhire_avatars_read on storage.objects for select to anon, authenticated
  using (bucket_id = 'avatars');
create policy luzhire_avatars_write on storage.objects for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select app.uid()));
create policy luzhire_avatars_update on storage.objects for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select app.uid()));
create policy luzhire_avatars_delete on storage.objects for delete to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select app.uid()));

create policy luzhire_company_media_read on storage.objects for select to anon, authenticated
  using (bucket_id = 'company-media');
create policy luzhire_company_media_write on storage.objects for insert to authenticated
  with check (bucket_id = 'company-media' and app.can_edit_company(app.try_uuid((storage.foldername(name))[1])));
create policy luzhire_company_media_update on storage.objects for update to authenticated
  using (bucket_id = 'company-media' and app.can_edit_company(app.try_uuid((storage.foldername(name))[1])));
create policy luzhire_company_media_delete on storage.objects for delete to authenticated
  using (bucket_id = 'company-media' and app.can_edit_company(app.try_uuid((storage.foldername(name))[1])));

create policy luzhire_resumes_read on storage.objects for select to authenticated
  using (bucket_id = 'resumes' and app.can_read_resume(name));
create policy luzhire_resumes_write on storage.objects for insert to authenticated
  with check (bucket_id = 'resumes' and (storage.foldername(name))[1] = (select app.uid()));
create policy luzhire_resumes_delete on storage.objects for delete to authenticated
  using (bucket_id = 'resumes' and (storage.foldername(name))[1] = (select app.uid()));

create policy luzhire_offer_letters_read on storage.objects for select to authenticated
  using (
    bucket_id = 'offer-letters'
    and (
      app.is_application_candidate(app.try_uuid((storage.foldername(name))[1]))
      or app.is_application_member(app.try_uuid((storage.foldername(name))[1]))
    )
  );
create policy luzhire_offer_letters_write on storage.objects for insert to authenticated
  with check (
    bucket_id = 'offer-letters'
    and app.is_application_member(app.try_uuid((storage.foldername(name))[1]), array['owner', 'recruiter']::public.member_role[])
  );

-- ---------------------------------------------------------------- search
-- Keyset-paginated job search (newest first). SECURITY INVOKER: RLS still applies.
create or replace function public.search_jobs(
  q                  text default null,
  location           text default null,
  remote_only        boolean default false,
  types              public.employment_type[] default null,
  levels             public.experience_level[] default null,
  min_annual_salary  numeric default null,
  skill_slugs        text[] default null,
  posted_within_days int default null,
  company            uuid default null,
  after_published    timestamptz default null,
  after_id           uuid default null,
  page_size          int default 20
)
returns setof public.jobs
language sql stable security invoker
set search_path = public, extensions, pg_temp
as $$
  select j.*
  from public.jobs j
  where j.status = 'published'
    and (
      coalesce(trim(q), '') = ''
      or j.search @@ websearch_to_tsquery('english', q)
      or j.title ilike '%' || trim(q) || '%'
      or j.company_name ilike '%' || trim(q) || '%'
    )
    and (
      coalesce(trim(location), '') = ''
      or j.location_text ilike '%' || trim(location) || '%'
      or (lower(trim(location)) = 'remote' and j.workplace = 'remote')
    )
    and (not coalesce(remote_only, false) or j.workplace = 'remote')
    and (types is null or cardinality(types) = 0 or j.employment_type = any (types))
    and (levels is null or cardinality(levels) = 0 or j.experience_level = any (levels))
    and (
      min_annual_salary is null
      or app.annual_salary(coalesce(j.salary_max, j.salary_min), j.salary_period) >= min_annual_salary
    )
    and (
      skill_slugs is null or cardinality(skill_slugs) = 0
      or exists (
        select 1 from public.job_skills js join public.skills s on s.id = js.skill_id
        where js.job_id = j.id and s.slug = any (skill_slugs)
      )
    )
    and (posted_within_days is null or j.published_at >= now() - make_interval(days => posted_within_days))
    and (company is null or j.company_id = company)
    and (
      after_published is null
      or (j.published_at, j.id) < (after_published, coalesce(after_id, 'ffffffff-ffff-ffff-ffff-ffffffffffff'::uuid))
    )
  order by j.published_at desc, j.id desc
  limit least(greatest(coalesce(page_size, 20), 1), 50)
$$;
grant execute on function public.search_jobs to anon, authenticated;

-- ---------------------------------------------------------------- realtime
-- Postgres Changes (respecting RLS) for per-user live feeds. Employer
-- pipelines switch to Broadcast in Phase 6.
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime add table
      public.notifications, public.applications, public.offers, public.saved_jobs;
  end if;
end
$$;
