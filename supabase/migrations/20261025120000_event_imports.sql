-- LuzHire · Phase 11 · Imported events: coding contests and hackathons from
-- sources whose terms allow it (Codeforces' public API, Hack Club's open
-- hackathon directory), imported daily by /api/ingest/events with the
-- service role. Candidates register on the organiser's site.

alter table public.events
  add column external_source text,
  add column external_id     text,
  add constraint events_external_unique unique (external_source, external_id),
  -- An imported event names where it came from and links to its page.
  add constraint events_external_complete check (
    external_source is null
    or (external_id is not null and registration_url is not null)
  );

-- Only the import (service role) or an admin creates or re-labels imported
-- events; employers cannot pass their own events off as Codeforces'.
-- Runs as the caller (not SECURITY DEFINER) so app.is_privileged() sees the
-- real role.
create or replace function app.events_external_guard()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if app.is_privileged() then
    return new;
  end if;
  if tg_op = 'INSERT' and (new.external_source is not null or new.external_id is not null) then
    raise exception 'Only the import can add imported events' using errcode = '42501';
  end if;
  if tg_op = 'UPDATE' and (new.external_source is distinct from old.external_source
                           or new.external_id is distinct from old.external_id) then
    raise exception 'The source of an event cannot change' using errcode = '42501';
  end if;
  return new;
end
$$;
create trigger events_external_guard before insert or update on public.events
  for each row execute function app.events_external_guard();
