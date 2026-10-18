-- LuzHire · Phase 2 · Application pipeline, interviews, offers, saved jobs.

create table public.applications (
  id           uuid primary key default gen_random_uuid(),
  job_id       uuid not null references public.jobs on delete cascade,
  candidate_id text not null references public.profiles on delete cascade,
  resume_id    uuid references public.resumes on delete set null,
  cover_letter text check (length(cover_letter) <= 6000),
  stage        public.application_stage not null default 'applied',
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  unique (job_id, candidate_id)              -- FR-06: duplicates impossible, race-free
);
create index applications_candidate_idx on public.applications (candidate_id, created_at desc);
create index applications_job_idx on public.applications (job_id, stage);

-- Allowed moves of the recruitment state machine (FR-08 / Activity diagram 3.8).
create table public.application_stage_transitions (
  from_stage public.application_stage not null,
  to_stage   public.application_stage not null,
  primary key (from_stage, to_stage)
);
insert into public.application_stage_transitions (from_stage, to_stage)
select f::public.application_stage, t::public.application_stage
from (values
  ('applied',             array['under_review', 'shortlisted', 'rejected', 'withdrawn']),
  ('under_review',        array['shortlisted', 'rejected', 'withdrawn']),
  ('shortlisted',         array['assessment', 'technical_interview', 'hr_interview', 'rejected', 'withdrawn']),
  ('assessment',          array['technical_interview', 'hr_interview', 'final_review', 'rejected', 'withdrawn']),
  ('technical_interview', array['hr_interview', 'final_review', 'rejected', 'withdrawn']),
  ('hr_interview',        array['final_review', 'offer_issued', 'rejected', 'withdrawn']),
  ('final_review',        array['offer_issued', 'rejected', 'withdrawn']),
  ('offer_issued',        array['hired', 'rejected', 'withdrawn'])
) as s(f, targets), unnest(targets) as t;

create table public.application_events (
  id             bigint generated always as identity primary key,
  application_id uuid not null references public.applications on delete cascade,
  from_stage     public.application_stage,
  to_stage       public.application_stage not null,
  actor_id       text,
  note           text,
  created_at     timestamptz not null default now()
);
create index application_events_app_idx on public.application_events (application_id, created_at);

create table public.interviews (
  id              uuid primary key default gen_random_uuid(),
  application_id  uuid not null references public.applications on delete cascade,
  scheduled_at    timestamptz not null,                    -- one instant, timezone-safe
  duration_min    int not null default 45 check (duration_min between 10 and 480),
  mode            public.interview_mode not null default 'video',
  meeting_url     text check (meeting_url ~* '^https?://'),
  location        text,
  interviewer_ids text[] not null default '{}',
  notes           text,                                    -- employer-only (see view below)
  feedback        jsonb,
  status          public.interview_status not null default 'scheduled',
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  check (mode <> 'video' or meeting_url is not null or status <> 'scheduled')
);
create index interviews_application_idx on public.interviews (application_id, scheduled_at);

create table public.offers (
  id             uuid primary key default gen_random_uuid(),
  application_id uuid not null unique references public.applications on delete cascade,
  salary         numeric check (salary >= 0),
  currency       char(3),
  salary_period  public.salary_period,
  start_date     date,
  letter_path    text,
  expires_at     timestamptz,
  status         public.offer_status not null default 'issued',
  responded_at   timestamptz,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

create table public.saved_jobs (
  user_id    text not null references public.profiles on delete cascade,
  job_id     uuid not null references public.jobs on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, job_id)
);

create trigger applications_touch before update on public.applications for each row execute function app.touch_updated_at();
create trigger interviews_touch   before update on public.interviews   for each row execute function app.touch_updated_at();
create trigger offers_touch       before update on public.offers       for each row execute function app.touch_updated_at();

-- ---------------------------------------------------------------- helpers
create or replace function app.is_application_member(
  application uuid,
  roles public.member_role[] default array['owner', 'recruiter', 'viewer']::public.member_role[]
)
returns boolean
language sql stable security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.applications a
    where a.id = application and app.is_job_member(a.job_id, roles)
  )
$$;

create or replace function app.is_application_candidate(application uuid)
returns boolean
language sql stable security definer
set search_path = public, pg_temp
as $$
  select exists (select 1 from public.applications a where a.id = application and a.candidate_id = app.uid())
$$;

-- Employers may see a candidate's profile only once that candidate applied to their company.
create or replace function app.can_view_candidate(candidate text)
returns boolean
language sql stable security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.applications a
    where a.candidate_id = candidate and app.is_job_member(a.job_id)
  )
$$;

-- Why a job can't take applications right now (null = open).
create or replace function app.job_closed_reason(job uuid)
returns text
language sql stable security definer
set search_path = public, pg_temp
as $$
  select case
    when j.id is null then 'This job does not exist'
    when j.source <> 'native' then 'Apply for this job on the employer''s site'
    when j.status <> 'published' then 'This job is not accepting applications'
    when j.deadline is not null and j.deadline < current_date then 'The application deadline has passed'
  end
  from (select 1) one
  left join public.jobs j on j.id = job
$$;

-- ---------------------------------------------------------------- applications triggers
create or replace function app.applications_before_insert()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  reason text := app.job_closed_reason(new.job_id);
begin
  if reason is not null then
    raise exception '%', reason using errcode = '23514';
  end if;
  if not app.is_privileged() then
    new.stage := 'applied';
    if new.resume_id is not null and not exists (
      select 1 from public.resumes r where r.id = new.resume_id and r.user_id = new.candidate_id
    ) then
      raise exception 'You can only attach your own resume' using errcode = '42501';
    end if;
  end if;
  return new;
end
$$;
create trigger applications_before_insert before insert on public.applications
  for each row execute function app.applications_before_insert();

create or replace function app.applications_after_insert()
returns trigger
language plpgsql security definer
set search_path = public, pg_temp
as $$
declare
  j public.jobs;
  who text;
begin
  select * into j from public.jobs where id = new.job_id;
  update public.jobs set application_count = application_count + 1 where id = new.job_id;
  insert into public.application_events (application_id, from_stage, to_stage, actor_id)
  values (new.id, null, new.stage, app.uid());
  select display_name into who from public.profiles where id = new.candidate_id;
  perform app.notify_company(
    j.company_id, 'application.new', 'New application',
    coalesce(who, 'A candidate') || ' applied for ' || j.title,
    jsonb_build_object('application_id', new.id, 'job_id', j.id)
  );
  perform app.notify(
    new.candidate_id, 'application.submitted', 'Application sent',
    'Your application for ' || j.title || ' at ' || j.company_name || ' was submitted.',
    jsonb_build_object('application_id', new.id, 'job_id', j.id)
  );
  return null;
end
$$;
create trigger applications_after_insert after insert on public.applications
  for each row execute function app.applications_after_insert();

create or replace function app.applications_before_update()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  privileged boolean := app.is_privileged();
begin
  if not privileged and (
       new.job_id is distinct from old.job_id
    or new.candidate_id is distinct from old.candidate_id
    or new.resume_id is distinct from old.resume_id
    or new.cover_letter is distinct from old.cover_letter
    or new.created_at is distinct from old.created_at
  ) then
    raise exception 'A submitted application cannot be edited' using errcode = '42501';
  end if;

  if new.stage is distinct from old.stage then
    if not exists (
      select 1 from public.application_stage_transitions t
      where t.from_stage = old.stage and t.to_stage = new.stage
    ) then
      raise exception 'Cannot move an application from % to %', app.stage_label(old.stage), app.stage_label(new.stage)
        using errcode = '23514';
    end if;
    if not privileged then
      if app.uid() = old.candidate_id then
        if new.stage <> 'withdrawn' then
          raise exception 'Candidates can only withdraw their application' using errcode = '42501';
        end if;
      elsif not app.is_job_member(old.job_id, array['owner', 'recruiter']::public.member_role[]) then
        raise exception 'Only the hiring team can change this application' using errcode = '42501';
      elsif new.stage = 'withdrawn' then
        raise exception 'Only the candidate can withdraw an application' using errcode = '42501';
      end if;
    end if;
  end if;
  return new;
end
$$;
create trigger applications_before_update before update on public.applications
  for each row execute function app.applications_before_update();

create or replace function app.applications_after_update()
returns trigger
language plpgsql security definer
set search_path = public, pg_temp
as $$
declare
  j public.jobs;
  who text;
begin
  if new.stage is not distinct from old.stage then
    return null;
  end if;
  select * into j from public.jobs where id = new.job_id;
  insert into public.application_events (application_id, from_stage, to_stage, actor_id)
  values (new.id, old.stage, new.stage, app.uid());

  if new.stage = 'withdrawn' then
    select display_name into who from public.profiles where id = new.candidate_id;
    perform app.notify_company(
      j.company_id, 'application.withdrawn', 'Application withdrawn',
      coalesce(who, 'A candidate') || ' withdrew from ' || j.title,
      jsonb_build_object('application_id', new.id, 'job_id', j.id)
    );
  else
    perform app.notify(
      new.candidate_id, 'application.stage', 'Application update',
      'Your application for ' || j.title || ' moved to ' || app.stage_label(new.stage) || '.',
      jsonb_build_object('application_id', new.id, 'job_id', j.id, 'stage', new.stage)
    );
  end if;
  return null;
end
$$;
create trigger applications_after_update after update of stage on public.applications
  for each row execute function app.applications_after_update();

-- ---------------------------------------------------------------- interviews
create or replace function app.interviews_after_write()
returns trigger
language plpgsql security definer
set search_path = public, pg_temp
as $$
declare
  a public.applications;
  title text;
  heading text;
  kind text;
begin
  select * into a from public.applications where id = new.application_id;
  select j.title into title from public.jobs j where j.id = a.job_id;
  if tg_op = 'INSERT' then
    kind := 'interview.scheduled'; heading := 'Interview scheduled';
  elsif new.status = 'cancelled' and old.status <> 'cancelled' then
    kind := 'interview.cancelled'; heading := 'Interview cancelled';
  elsif new.scheduled_at <> old.scheduled_at then
    kind := 'interview.rescheduled'; heading := 'Interview rescheduled';
  else
    return null;
  end if;
  perform app.notify(
    a.candidate_id, kind, heading,
    heading || ' for ' || title || '.',
    jsonb_build_object('interview_id', new.id, 'application_id', a.id, 'scheduled_at', new.scheduled_at)
  );
  return null;
end
$$;
create trigger interviews_after_write after insert or update on public.interviews
  for each row execute function app.interviews_after_write();

-- Candidates never get table access to interviews (RLS: hiring team only),
-- because the rows carry the team's private notes and feedback. They read
-- this view instead: owner-privileged, but hard-filtered to their own rows
-- and without notes/feedback/interviewer columns.
create view public.candidate_interviews as
select i.id, i.application_id, a.job_id, i.scheduled_at, i.duration_min, i.mode,
       i.meeting_url, i.location, i.status, i.created_at, i.updated_at
from public.interviews i
join public.applications a on a.id = i.application_id
where a.candidate_id = app.uid();

revoke all on public.candidate_interviews from anon;
grant select on public.candidate_interviews to authenticated;

-- ---------------------------------------------------------------- offers
create or replace function app.offers_before_write()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if app.is_privileged() then
    return new;
  end if;
  if app.is_application_candidate(coalesce(new.application_id, old.application_id))
     and not app.is_application_member(new.application_id, array['owner', 'recruiter']::public.member_role[]) then
    if tg_op = 'INSERT' then
      raise exception 'Candidates cannot create offers' using errcode = '42501';
    end if;
    if old.status <> 'issued' or new.status not in ('accepted', 'declined')
       or (to_jsonb(new) - array['status', 'responded_at', 'updated_at'])
          is distinct from (to_jsonb(old) - array['status', 'responded_at', 'updated_at']) then
      raise exception 'You can only accept or decline an open offer' using errcode = '42501';
    end if;
    if old.expires_at is not null and old.expires_at < now() then
      raise exception 'This offer has expired' using errcode = '23514';
    end if;
    new.responded_at := now();
  end if;
  return new;
end
$$;
create trigger offers_before_write before insert or update on public.offers
  for each row execute function app.offers_before_write();

create or replace function app.offers_after_write()
returns trigger
language plpgsql security definer
set search_path = public, pg_temp
as $$
declare
  a public.applications;
  j public.jobs;
  who text;
begin
  select * into a from public.applications where id = new.application_id;
  select * into j from public.jobs where id = a.job_id;
  if tg_op = 'INSERT' then
    if a.stage <> 'offer_issued' then
      update public.applications set stage = 'offer_issued' where id = a.id;
    end if;
    perform app.notify(a.candidate_id, 'offer.issued', 'You received an offer',
      j.company_name || ' sent you an offer for ' || j.title || '.',
      jsonb_build_object('offer_id', new.id, 'application_id', a.id));
  elsif new.status is distinct from old.status and new.status in ('accepted', 'declined') then
    select display_name into who from public.profiles where id = a.candidate_id;
    if new.status = 'accepted' then
      update public.applications set stage = 'hired' where id = a.id and stage = 'offer_issued';
    end if;
    perform app.notify_company(j.company_id, 'offer.' || new.status::text,
      'Offer ' || new.status::text,
      coalesce(who, 'The candidate') || ' ' || new.status::text || ' the offer for ' || j.title || '.',
      jsonb_build_object('offer_id', new.id, 'application_id', a.id));
  end if;
  return null;
end
$$;
create trigger offers_after_write after insert or update on public.offers
  for each row execute function app.offers_after_write();
