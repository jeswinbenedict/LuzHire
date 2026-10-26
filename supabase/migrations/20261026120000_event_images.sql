-- LuzHire · Phase 11 · Event images: a logo and a banner per event. The
-- events import fills them from its sources (Hack Club's directory sends
-- both; Codeforces contests use the Codeforces icon); the app shows a
-- designed banner when there is none. Links only, https only.

alter table public.events
  add column logo_url   text check (logo_url ~* '^https://'),
  add column banner_url text check (banner_url ~* '^https://');
