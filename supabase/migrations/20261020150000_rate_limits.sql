-- LuzHire · Phase 10 · Fixed-window rate limits for the Vercel API.
-- Vercel Functions keep no state between calls, so the counters live here.
-- Only the server (service role) can count; clients cannot see or call it.

create table app.rate_limits (
  bucket       text not null check (length(bucket) between 1 and 200),
  window_start timestamptz not null,
  hits         int not null default 0 check (hits >= 0),
  primary key (bucket, window_start)
);
create index rate_limits_window_idx on app.rate_limits (window_start);
alter table app.rate_limits enable row level security; -- no policies: no client access
revoke all on app.rate_limits from public, anon, authenticated;

-- Counts one hit for [bucket] (e.g. "bootstrap:203.0.113.7") in the current
-- window and returns true while the caller is within [max_hits].
create or replace function public.rate_limit_hit(bucket text, max_hits int, window_seconds int)
returns boolean
language plpgsql security definer
set search_path = app, pg_temp
as $$
#variable_conflict use_column
declare
  win  int := greatest(1, least(coalesce(window_seconds, 60), 86400));
  slot timestamptz := to_timestamp(floor(extract(epoch from now()) / win) * win);
  n    int;
begin
  if rate_limit_hit.bucket is null or length(rate_limit_hit.bucket) not between 1 and 200 then
    raise exception 'Invalid rate-limit bucket' using errcode = '22023';
  end if;
  insert into app.rate_limits as r (bucket, window_start, hits)
  values (rate_limit_hit.bucket, slot, 1)
  on conflict (bucket, window_start) do update set hits = r.hits + 1
  returning r.hits into n;
  -- Keep the table small: old windows are useless.
  delete from app.rate_limits where window_start < now() - interval '1 day';
  return n <= greatest(coalesce(max_hits, 0), 0);
end
$$;
revoke all on function public.rate_limit_hit(text, int, int) from public, anon, authenticated;
grant execute on function public.rate_limit_hit(text, int, int) to service_role;
