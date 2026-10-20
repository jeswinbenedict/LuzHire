-- Career news: imported headlines and admin-written articles.
begin;
create extension if not exists pgtap with schema extensions;
select plan(9);

insert into public.profiles (id, role, email, display_name) values
  ('t-nw-admin', 'admin', 't-nw-admin@example.com', 'Ada Admin'),
  ('t-nw-cand', 'candidate', 't-nw-cand@example.com', 'Cand');
insert into public.news_articles (source, url, title, summary, published_at, categories, relevance) values
  ('devto', 'https://dev.to/x/qzx-headline', 'Qzx headline', 'Short excerpt.', now() - interval '1 day', '{career-tips}', 0.8);
insert into public.news_articles (kind, source, title, body_md, status, slug) values
  ('article', 'luzhire', 'Qzx draft article', 'Body text', 'draft', 'qzx-draft');

-- ---- visitors
select set_config('request.jwt.claims', '', true);
set local role anon;
select is((select count(*)::int from public.news_articles where title like 'Qzx%'), 1,
  'visitors see published items but not drafts');

-- ---- candidates
reset role;
select set_config('request.jwt.claims', '{"sub":"t-nw-cand","app_role":"candidate","email_verified":true}', true);
set local role authenticated;
select throws_ok(
  $$insert into public.news_articles (kind, source, title, body_md) values ('article', 'luzhire', 'Sneaky post', 'x')$$,
  '42501', null, 'only admins write articles');

-- ---- admins
reset role;
select set_config('request.jwt.claims', '{"sub":"t-nw-admin","app_role":"admin","email_verified":true}', true);
set local role authenticated;
insert into public.news_articles (id, kind, source, title, body_md, categories)
values ('60000000-0000-4000-a000-000000000001', 'article', 'luzhire', 'How to ace a campus drive', '## Prepare', '{career-tips}');
select is(
  (select slug from public.news_articles where id = '60000000-0000-4000-a000-000000000001'),
  'how-to-ace-a-campus-drive-000001',
  'articles get a readable slug'
);
select is(
  (select author_name from public.news_articles where id = '60000000-0000-4000-a000-000000000001'),
  'Ada Admin',
  'articles are signed by the admin who wrote them'
);
select throws_ok(
  $$insert into public.news_articles (source, url, title) values ('devto', 'https://dev.to/x/forged', 'Forged headline')$$,
  '42501', null, 'headlines come only from the import');
select throws_ok(
  $$insert into public.news_articles (kind, source, title, body_md) values ('article', 'luzhire', 'Empty one', '  ')$$,
  '23514', null, 'an article needs a body');
update public.news_articles set published_at = now() - interval '1 year' where slug = 'qzx-draft';
update public.news_articles set status = 'published' where slug = 'qzx-draft';
select ok(
  (select published_at > now() - interval '1 minute' from public.news_articles where slug = 'qzx-draft'),
  'publishing a draft stamps the publish date'
);
select throws_ok(
  $$update public.news_articles set slug = 'other' where slug = 'qzx-draft'$$,
  '42501', null, 'an article keeps its link');

reset role;
select ok(
  (select count(*) >= 1 from public.audit_logs
   where target_table = 'news_articles' and actor_id = 't-nw-admin'),
  'admin changes to articles are audited'
);

select * from finish();
rollback;
