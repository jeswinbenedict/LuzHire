-- LuzHire · Phase 11 · Opportunities: hiring drives, hackathons and
-- competitions (Unstop-style). Employers post them for their company and
-- admins for anyone; candidates register in the app or on the organiser's
-- site. Like jobs, events from unverified companies wait for review. Events
-- with a place appear on the hiring map.

create type public.event_kind   as enum ('walk_in', 'campus_drive', 'hiring_challenge', 'hackathon', 'competition', 'webinar');
create type public.event_mode   as enum ('in_person', 'online', 'hybrid');
create type public.event_status as enum ('draft', 'pending_review', 'published', 'cancelled', 'rejected');

create table public.events (
  id                    uuid primary key default gen_random_uuid(),
  slug                  text not null unique,
  kind                  public.event_kind not null,
  status                public.event_status not null default 'draft',
  title                 text not null check (length(trim(title)) between 4 and 160),
  summary               text check (length(summary) <= 300),
  description_md        text not null default '' check (length(description_md) <= 20000),
  company_id            uuid references public.companies on delete cascade,
  organizer_name        text not null check (length(trim(organizer_name)) between 1 and 120),
  created_by            text references public.profiles on delete set null,
  mode                  public.event_mode not null,
  venue                 text check (length(venue) <= 200),
  location_text         text check (length(location_text) <= 120),
  city_id               int references public.cities on delete set null,
  latitude              double precision,
  longitude             double precision,
  starts_at             timestamptz not null,
  ends_at               timestamptz,
  registration_deadline timestamptz,
  registration_url      text check (registration_url ~* '^https://'),
  eligibility           text check (length(eligibility) <= 1000),
  prize                 text check (length(prize) <= 300),
  team_min              int not null default 1 check (team_min between 1 and 10),
  team_max              int not null default 1 check (team_max between 1 and 10),
  capacity              int check (capacity > 0),
  registration_count    int not null default 0 check (registration_count >= 0),
  published_at          timestamptz,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  check (team_min <= team_max),
  check (ends_at is null or ends_at >= starts_at),
  check (registration_deadline is null or registration_deadline <= coalesce(ends_at, starts_at)),
  -- A place to go for in-person and hybrid events.
  check (mode = 'online' or length(trim(coalesce(location_text, ''))) > 0)
);
create index events_feed_idx on public.events (status, starts_at);
create index events_company_idx on public.events (company_id);
create index events_city_idx on public.events (city_id) where status = 'published';

create table public.event_registrations (
  event_id   uuid not null references public.events on delete cascade,
  user_id    text not null references public.profiles on delete cascade,
  team_name  text check (length(trim(team_name)) between 1 and 80),
  created_at timestamptz not null default now(),
  primary key (event_id, user_id)
);
create index event_registrations_user_idx on public.event_registrations (user_id);

-- ---------------------------------------------------------------- triggers
-- Runs as the caller (not SECURITY DEFINER), so app.is_privileged() sees the
-- real role.
create or replace function app.events_before_write()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  privileged boolean := app.is_privileged();
  company_verified boolean;
begin
  new.updated_at := now();
  if tg_op = 'INSERT' then
    if new.slug is null or new.slug = '' then
      new.slug := app.slugify(new.title) || '-' || right(replace(new.id::text, '-', ''), 6);
    end if;
    if not privileged then
      new.created_by := app.uid();
      new.registration_count := 0;
    end if;
  elsif not privileged then
    if new.company_id is distinct from old.company_id or new.slug is distinct from old.slug
       or new.created_by is distinct from old.created_by then
      raise exception 'The company, link and author of an event cannot change' using errcode = '42501';
    end if;
    new.registration_count := old.registration_count;
    new.published_at := old.published_at;
  end if;

  if new.company_id is not null then
    select c.name, c.verification = 'verified' into new.organizer_name, company_verified
    from public.companies c where c.id = new.company_id;
  end if;

  if not privileged then
    if new.status = 'rejected' and (tg_op = 'INSERT' or old.status <> 'rejected') then
      raise exception 'Only an admin can reject an event' using errcode = '42501';
    end if;
    if new.status = 'published' and (tg_op = 'INSERT' or old.status <> 'published')
       and not coalesce(company_verified, false) then
      new.status := 'pending_review';
    end if;
  end if;

  if new.status = 'published' and new.published_at is null then
    new.published_at := now();
  end if;
  return new;
end
$$;
create trigger events_before_write before insert or update on public.events
  for each row execute function app.events_before_write();

-- Same geocoding as jobs (location_text → city, latitude, longitude).
create trigger events_geocode before insert or update of location_text on public.events
  for each row execute function app.jobs_geocode();

create trigger events_audit after update of status or delete on public.events
  for each row execute function app.audit();

-- The event a registration is for, locked so two last-minute registrations
-- cannot exceed the capacity. Definer: registrants may not lock (update)
-- events themselves.
create or replace function app.lock_event(event uuid)
returns public.events
language sql security definer
set search_path = public, pg_temp
as $$
  select * from public.events where id = event for update
$$;
revoke execute on function app.lock_event from public, anon;
grant execute on function app.lock_event to authenticated;

-- Registrations: only candidates, only for open events that register in
-- the app, before the deadline and while there is room.
create or replace function app.event_registrations_before_insert()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  e public.events := app.lock_event(new.event_id);
begin
  if e.id is null or e.status <> 'published' then
    raise exception 'This event is not open for registration' using errcode = '23514';
  end if;
  if not app.is_privileged() and app.role() is distinct from 'candidate' then
    raise exception 'Only candidates can register for events' using errcode = '42501';
  end if;
  if e.registration_url is not null then
    raise exception 'Register on the organiser''s site for this event' using errcode = '23514';
  end if;
  if coalesce(e.registration_deadline, e.starts_at) < now() then
    raise exception 'Registration for this event has closed' using errcode = '23514';
  end if;
  if e.capacity is not null and e.registration_count >= e.capacity then
    raise exception 'This event is full' using errcode = '23514';
  end if;
  if e.team_max > 1 and new.team_name is null then
    raise exception 'Give your team a name' using errcode = '23514';
  end if;
  if e.team_max = 1 then
    new.team_name := null;
  end if;
  new.created_at := now();
  return new;
end
$$;
create trigger event_registrations_before_insert before insert on public.event_registrations
  for each row execute function app.event_registrations_before_insert();

-- Keeps events.registration_count right; definer so registrants (who cannot
-- update events) still move the count.
create or replace function app.event_registrations_count()
returns trigger
language plpgsql security definer
set search_path = public, pg_temp
as $$
begin
  update public.events
  set registration_count = (select count(*) from public.event_registrations r
                            where r.event_id = coalesce(new.event_id, old.event_id))
  where id = coalesce(new.event_id, old.event_id);
  return null;
end
$$;
create trigger event_registrations_count after insert or delete on public.event_registrations
  for each row execute function app.event_registrations_count();

-- ---------------------------------------------------------------- RLS
alter table public.events enable row level security;
alter table public.event_registrations enable row level security;

create policy events_select on public.events for select to anon, authenticated
  using (status = 'published' or created_by = app.uid()
         or (company_id is not null and app.is_company_member(company_id))
         or (select app.is_admin()));
create policy events_insert on public.events for insert to authenticated
  with check ((select app.is_admin())
              or (company_id is not null
                  and app.is_company_member(company_id, array['owner', 'recruiter']::public.member_role[])));
create policy events_update on public.events for update to authenticated
  using ((select app.is_admin())
         or (company_id is not null
             and app.is_company_member(company_id, array['owner', 'recruiter']::public.member_role[])))
  with check ((select app.is_admin())
              or (company_id is not null
                  and app.is_company_member(company_id, array['owner', 'recruiter']::public.member_role[])));
create policy events_delete on public.events for delete to authenticated
  using ((select app.is_admin())
         or (status = 'draft' and company_id is not null
             and app.is_company_member(company_id, array['owner', 'recruiter']::public.member_role[])));

create policy event_registrations_select on public.event_registrations for select to authenticated
  using (user_id = app.uid() or (select app.is_admin())
         or exists (select 1 from public.events e
                    where e.id = event_id and e.company_id is not null
                      and app.is_company_member(e.company_id)));
create policy event_registrations_insert on public.event_registrations for insert to authenticated
  with check (user_id = app.uid());
create policy event_registrations_delete on public.event_registrations for delete to authenticated
  using (user_id = app.uid()
         and exists (select 1 from public.events e where e.id = event_id and e.starts_at > now()));

create policy events_active_insert on public.events as restrictive for insert to authenticated
  with check ((select app.is_active()));
create policy events_active_update on public.events as restrictive for update to authenticated
  using ((select app.is_active())) with check ((select app.is_active()));
create policy events_active_delete on public.events as restrictive for delete to authenticated
  using ((select app.is_active()));
create policy event_registrations_active_insert on public.event_registrations as restrictive
  for insert to authenticated with check ((select app.is_active()));
create policy event_registrations_active_delete on public.event_registrations as restrictive
  for delete to authenticated using ((select app.is_active()));

-- Who registered, for the event's hiring team and admins only.
create or replace function public.event_registrants(event uuid)
returns table (user_id text, display_name text, email text, headline text,
               team_name text, registered_at timestamptz)
language sql stable security definer
set search_path = public, pg_temp
as $$
  select r.user_id, p.display_name, p.email, p.headline, r.team_name, r.created_at
  from public.event_registrations r
  join public.profiles p on p.id = r.user_id
  join public.events e on e.id = r.event_id
  where r.event_id = event
    and (app.is_admin() or (e.company_id is not null and app.is_company_member(e.company_id)))
  order by r.created_at
$$;
revoke execute on function public.event_registrants from public, anon;
grant execute on function public.event_registrants to authenticated;

-- ---------------------------------------------------------------- map
-- Cities with open roles or upcoming in-person events.
drop view public.hiring_locations;
create view public.hiring_locations with (security_invoker = true) as
  with j as (
    select city_id, count(*)::int as open_jobs, count(distinct lower(company_name))::int as companies
    from public.jobs where status = 'published' and city_id is not null group by city_id
  ),
  e as (
    select city_id, count(*)::int as events
    from public.events
    where status = 'published' and city_id is not null and mode <> 'online'
      and coalesce(ends_at, starts_at) >= now()
    group by city_id
  )
  select c.id as city_id, c.name, c.state, c.country_code, c.latitude, c.longitude,
         coalesce(j.open_jobs, 0) as open_jobs,
         coalesce(j.companies, 0) as companies,
         coalesce(e.events, 0) as events
  from public.cities c
  left join j on j.city_id = c.id
  left join e on e.city_id = c.id
  where j.city_id is not null or e.city_id is not null;
grant select on public.hiring_locations to anon, authenticated;
