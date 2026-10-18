-- LuzHire · Phase 2 · People (profiles + candidate data) and companies.

-- ---------------------------------------------------------------- profiles
create table public.profiles (
  id                 text primary key check (length(id) between 1 and 128), -- Firebase UID
  role               public.app_role not null,
  email              text not null unique check (email = lower(email)),
  display_name       text not null check (length(trim(display_name)) between 1 and 120),
  avatar_path        text,
  headline           text check (length(headline) <= 160),
  bio                text check (length(bio) <= 4000),
  phone              text check (length(phone) <= 32),
  location           text check (length(location) <= 120),
  links              jsonb not null default '{}'::jsonb, -- {github, linkedin, portfolio}
  preferences        jsonb not null default '{}'::jsonb, -- {theme: system|light|dark, ...}
  account_status     public.account_status not null default 'active',
  profile_completion smallint not null default 0 check (profile_completion between 0 and 100),
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

create table public.educations (
  id          uuid primary key default gen_random_uuid(),
  user_id     text not null references public.profiles on delete cascade,
  institution text not null check (length(trim(institution)) > 0),
  degree      text,
  field       text,
  start_date  date,
  end_date    date,
  grade       text,
  created_at  timestamptz not null default now(),
  check (end_date is null or start_date is null or end_date >= start_date)
);
create index educations_user_idx on public.educations (user_id);

create table public.experiences (
  id          uuid primary key default gen_random_uuid(),
  user_id     text not null references public.profiles on delete cascade,
  company     text not null check (length(trim(company)) > 0),
  title       text not null check (length(trim(title)) > 0),
  start_date  date,
  end_date    date,
  description text check (length(description) <= 4000),
  created_at  timestamptz not null default now(),
  check (end_date is null or start_date is null or end_date >= start_date)
);
create index experiences_user_idx on public.experiences (user_id);

create table public.skills (
  id   serial primary key,
  name text not null check (length(trim(name)) between 1 and 60),
  slug text not null unique
);

create table public.profile_skills (
  user_id  text not null references public.profiles on delete cascade,
  skill_id int  not null references public.skills on delete cascade,
  primary key (user_id, skill_id)
);

create table public.resumes (
  id           uuid primary key default gen_random_uuid(),
  user_id      text not null references public.profiles on delete cascade,
  storage_path text not null unique,  -- object name in the "resumes" bucket: <uid>/<file>
  file_name    text not null,
  parsed       jsonb,                  -- suggestions from /api/resume/parse (Phase 5)
  is_primary   boolean not null default false,
  created_at   timestamptz not null default now(),
  check (split_part(storage_path, '/', 1) = user_id)
);
create unique index resumes_one_primary_idx on public.resumes (user_id) where is_primary;

-- ---------------------------------------------------------------- companies
create table public.companies (
  id           uuid primary key default gen_random_uuid(),
  owner_id     text not null references public.profiles,
  name         text not null check (length(trim(name)) between 1 and 120),
  slug         text not null unique,
  logo_path    text,
  cover_path   text,
  description  text check (length(description) <= 8000),
  industry     text,
  size_range   text check (size_range in ('1-10', '11-50', '51-200', '201-500', '501-1000', '1001-5000', '5000+')),
  website      text check (website ~* '^https?://'),
  hq_location  text,
  benefits     text[] not null default '{}',
  verification public.verification not null default 'unverified',
  verified_at  timestamptz,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index companies_name_trgm on public.companies using gin (name extensions.gin_trgm_ops);

create table public.company_members (
  company_id  uuid not null references public.companies on delete cascade,
  user_id     text not null references public.profiles on delete cascade,
  member_role public.member_role not null,
  created_at  timestamptz not null default now(),
  primary key (company_id, user_id)
);
create index company_members_user_idx on public.company_members (user_id);

-- ---------------------------------------------------------------- membership helpers
-- SECURITY DEFINER so RLS policies can call them without recursive policy checks.
create or replace function app.is_company_member(
  company uuid,
  roles public.member_role[] default array['owner', 'recruiter', 'viewer']::public.member_role[]
)
returns boolean
language sql stable security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.company_members m
    where m.company_id = company
      and m.user_id = app.uid()
      and m.member_role = any (roles)
  )
$$;

create or replace function app.can_edit_company(company uuid)
returns boolean
language sql stable
as $$ select app.is_company_member(company, array['owner', 'recruiter']::public.member_role[]) $$;

-- Two users belong to the same company (team members can see each other).
create or replace function app.shares_company(other text)
returns boolean
language sql stable security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.company_members a
    join public.company_members b on b.company_id = a.company_id
    where a.user_id = app.uid() and b.user_id = other
  )
$$;

-- ---------------------------------------------------------------- triggers
create trigger profiles_touch  before update on public.profiles  for each row execute function app.touch_updated_at();
create trigger companies_touch before update on public.companies for each row execute function app.touch_updated_at();

-- Users may not change their own role, status or email (set only by the
-- auth bootstrap API with the service role, or by admins).
create or replace function app.profiles_guard()
returns trigger
language plpgsql
as $$
begin
  if not app.is_privileged() and (
       new.role is distinct from old.role
    or new.account_status is distinct from old.account_status
    or new.email is distinct from old.email
    or new.id is distinct from old.id
    or new.profile_completion is distinct from old.profile_completion
  ) then
    raise exception 'You cannot change role, account status, email or completion of a profile'
      using errcode = '42501';
  end if;
  return new;
end
$$;
create trigger profiles_guard before update on public.profiles
  for each row execute function app.profiles_guard();

-- Company slug + owner membership + verification only by admins.
create or replace function app.companies_before_write()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'INSERT' then
    if new.slug is null or new.slug = '' then
      new.slug := app.slugify(new.name) || '-' || right(replace(new.id::text, '-', ''), 6);
    end if;
    if not app.is_privileged() then
      new.verification := 'unverified';
      new.verified_at := null;
    end if;
  else
    if not app.is_privileged() then
      if new.owner_id is distinct from old.owner_id then
        raise exception 'Only an admin can transfer company ownership' using errcode = '42501';
      end if;
      -- Owners may request verification (unverified/rejected -> pending); nothing else.
      if new.verification is distinct from old.verification
         and not (new.verification = 'pending' and old.verification in ('unverified', 'rejected')) then
        raise exception 'Only an admin can change verification status' using errcode = '42501';
      end if;
      new.verified_at := old.verified_at;
    end if;
  end if;
  if new.verification = 'verified' and new.verified_at is null then
    new.verified_at := now();
  end if;
  return new;
end
$$;
create trigger companies_before_write before insert or update on public.companies
  for each row execute function app.companies_before_write();

create or replace function app.companies_after_insert()
returns trigger
language plpgsql security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.company_members (company_id, user_id, member_role)
  values (new.id, new.owner_id, 'owner')
  on conflict (company_id, user_id) do update set member_role = 'owner';
  return new;
end
$$;
create trigger companies_after_insert after insert on public.companies
  for each row execute function app.companies_after_insert();

-- ---------------------------------------------------------------- profile completion
-- 10 checks × 10 %: headline, bio, location, avatar, phone, a link,
-- an education, an experience, ≥ 3 skills, a primary resume.
create or replace function app.recompute_completion(target text)
returns void
language plpgsql security definer
set search_path = public, pg_temp
as $$
declare
  p public.profiles;
  score int := 0;
begin
  select * into p from public.profiles where id = target;
  if not found or p.role <> 'candidate' then
    return;
  end if;
  score := score
    + (case when coalesce(trim(p.headline), '') <> '' then 10 else 0 end)
    + (case when coalesce(trim(p.bio), '') <> '' then 10 else 0 end)
    + (case when coalesce(trim(p.location), '') <> '' then 10 else 0 end)
    + (case when p.avatar_path is not null then 10 else 0 end)
    + (case when coalesce(trim(p.phone), '') <> '' then 10 else 0 end)
    + (case when exists (select 1 from jsonb_each_text(p.links) l where trim(l.value) <> '') then 10 else 0 end)
    + (case when exists (select 1 from public.educations e where e.user_id = target) then 10 else 0 end)
    + (case when exists (select 1 from public.experiences x where x.user_id = target) then 10 else 0 end)
    + (case when (select count(*) from public.profile_skills s where s.user_id = target) >= 3 then 10 else 0 end)
    + (case when exists (select 1 from public.resumes r where r.user_id = target and r.is_primary) then 10 else 0 end);
  update public.profiles set profile_completion = score
  where id = target and profile_completion is distinct from score;
end
$$;

create or replace function app.completion_trigger()
returns trigger
language plpgsql security definer
set search_path = public, pg_temp
as $$
begin
  if tg_table_name = 'profiles' then
    perform app.recompute_completion(new.id);
  else
    perform app.recompute_completion(coalesce(new.user_id, old.user_id));
  end if;
  return null;
end
$$;

create trigger profiles_completion after insert or update of headline, bio, location, avatar_path, phone, links
  on public.profiles for each row execute function app.completion_trigger();
create trigger educations_completion after insert or delete on public.educations
  for each row execute function app.completion_trigger();
create trigger experiences_completion after insert or delete on public.experiences
  for each row execute function app.completion_trigger();
create trigger profile_skills_completion after insert or delete on public.profile_skills
  for each row execute function app.completion_trigger();
create trigger resumes_completion after insert or update of is_primary or delete on public.resumes
  for each row execute function app.completion_trigger();
