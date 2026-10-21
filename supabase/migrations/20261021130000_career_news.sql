-- LuzHire · Phase 11 · Career news. One table holds two kinds of item:
--   headline  imported once a day from career RSS feeds whose terms allow
--             linked headlines (title, short excerpt, image, link back)
--   article   written by LuzHire admins, read in the app at /news/:slug
-- Visitors read published items; only admins write articles, curate (feature
-- or remove) headlines and see drafts. Imports use the service role.

alter table public.news_articles
  alter column url drop not null,
  alter column published_at set default now(),
  alter column relevance set default 1,
  add column kind        text not null default 'headline' check (kind in ('headline', 'article')),
  add column slug        text unique,
  add column body_md     text check (length(body_md) <= 40000),
  add column author_id   text references public.profiles on delete set null,
  add column author_name text,
  add column is_featured boolean not null default false,
  add column status      text not null default 'published' check (status in ('draft', 'published')),
  add column updated_at  timestamptz not null default now(),
  add constraint news_kind_fields check (
    (kind = 'headline' and url is not null)
    or (kind = 'article' and slug is not null and length(trim(coalesce(body_md, ''))) > 0
        and length(trim(title)) between 4 and 160)
  );

create index news_feed_idx on public.news_articles (status, published_at desc);
create index news_categories_idx on public.news_articles using gin (categories);

-- Articles get a slug and their author; publishing stamps the date.
-- Runs as the caller (not SECURITY DEFINER), so app.uid() is the admin.
create or replace function app.news_before_write()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  new.updated_at := now();
  if new.kind = 'article' then
    if tg_op = 'INSERT' then
      if new.slug is null or new.slug = '' then
        new.slug := app.slugify(new.title) || '-' || right(replace(new.id::text, '-', ''), 6);
      end if;
      new.author_id := coalesce(app.uid(), new.author_id);
      new.author_name := coalesce(
        (select p.display_name from public.profiles p where p.id = new.author_id),
        new.author_name, 'LuzHire');
    elsif new.slug is distinct from old.slug or new.kind is distinct from old.kind then
      raise exception 'The link and kind of an article cannot change' using errcode = '42501';
    end if;
    if new.status = 'published' and (tg_op = 'INSERT' or old.status <> 'published') then
      new.published_at := now();
    end if;
  end if;
  return new;
end
$$;
create trigger news_before_write before insert or update on public.news_articles
  for each row execute function app.news_before_write();

-- Admin changes to articles are audited; the daily import is not.
create trigger news_articles_audit after insert or update on public.news_articles
  for each row when (new.kind = 'article') execute function app.audit();
create trigger news_articles_audit_delete after delete on public.news_articles
  for each row when (old.kind = 'article') execute function app.audit();

-- ---------------------------------------------------------------- RLS
drop policy news_select on public.news_articles;
create policy news_select on public.news_articles for select to anon, authenticated
  using (status = 'published' or (select app.is_admin()));
create policy news_admin_insert on public.news_articles for insert to authenticated
  with check ((select app.is_admin()) and kind = 'article');
create policy news_admin_update on public.news_articles for update to authenticated
  using ((select app.is_admin())) with check ((select app.is_admin()));
create policy news_admin_delete on public.news_articles for delete to authenticated
  using ((select app.is_admin()));
