-- LuzHire · Phase 11 · Remote jobs stay off the hiring map. A remote job's
-- location text often lists where applicants may live ("Remote (Europe,
-- USA, Singapore)"), which is not where the job is. Only on-site and hybrid
-- jobs (and in-person or hybrid events) get a city.

create or replace function app.jobs_geocode()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  -- Shared by jobs (workplace) and events (mode).
  if coalesce(to_jsonb(new) ->> 'workplace', to_jsonb(new) ->> 'mode') in ('remote', 'online') then
    new.city_id := null;
    new.latitude := null;
    new.longitude := null;
    return new;
  end if;
  if tg_op = 'INSERT' or new.location_text is distinct from old.location_text
     or to_jsonb(new) ->> 'workplace' is distinct from to_jsonb(old) ->> 'workplace'
     or to_jsonb(new) ->> 'mode' is distinct from to_jsonb(old) ->> 'mode'
     or new.city_id is null then
    new.city_id := app.city_in(new.location_text);
    select c.latitude, c.longitude into new.latitude, new.longitude
    from public.cities c where c.id = new.city_id;
    if new.city_id is null then
      new.latitude := null;
      new.longitude := null;
    end if;
  end if;
  return new;
end
$$;

drop trigger jobs_geocode on public.jobs;
create trigger jobs_geocode before insert or update of location_text, workplace on public.jobs
  for each row execute function app.jobs_geocode();
drop trigger events_geocode on public.events;
create trigger events_geocode before insert or update of location_text, mode on public.events
  for each row execute function app.jobs_geocode();

update public.jobs set city_id = null, latitude = null, longitude = null
where workplace = 'remote' and city_id is not null;
