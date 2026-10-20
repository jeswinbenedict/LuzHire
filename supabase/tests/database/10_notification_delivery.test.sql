-- Notification delivery: preferences, push tokens and the dispatcher's claim.
begin;
create extension if not exists pgtap with schema extensions;
select plan(19);

insert into public.profiles (id, role, email, display_name, account_status) values
  ('t-na', 'candidate', 't-na@example.com', 'Asha', 'active'),
  ('t-nb', 'candidate', 't-nb@example.com', 'Bala', 'active'),
  ('t-ns', 'candidate', 't-ns@example.com', 'Suspended', 'suspended'),
  ('t-nadm', 'admin', 't-nadm@example.com', 'Admin', 'active');

select is(app.notification_category('interview.rescheduled'), 'interviews'::public.notification_category,
  'interview types map to the interviews group');
select is(app.notification_category('company.invite'), 'team'::public.notification_category,
  'invites map to the team group');
select is(app.notification_category('report.resolved'), 'account'::public.notification_category,
  'anything else maps to the account group');

-- ---------------------------------------------------------------- as Asha
select set_config('request.jwt.claims', '{"sub":"t-na","app_role":"candidate","email_verified":true}', true);
set local role authenticated;

insert into public.notification_preferences (user_id, category, push, email)
values ('t-na', 'applications', true, false);
select is((select count(*)::int from public.notification_preferences), 1,
  'users save their own preferences');
select throws_ok($$insert into public.notification_preferences (user_id, category) values ('t-nb', 'offers')$$,
  '42501', null, 'users cannot write someone else''s preferences');

select lives_ok($$select public.register_push_token('tok-asha-browser-0000000001', 'web')$$,
  'users register a push token');
select lives_ok($$select public.register_push_token('tok-asha-browser-0000000001', 'web')$$,
  're-registering the same token is fine');
select is((select count(*)::int from public.push_tokens), 1, 'and keeps one row');
select throws_ok($$insert into public.push_tokens (token, user_id, platform) values ('tok-direct-insert-000000001', 't-na', 'web')$$,
  '42501', null, 'tokens are only added through register_push_token');
select throws_ok($$select public.register_push_token('short', 'web')$$, '22023', null,
  'malformed tokens are refused');
select throws_ok($$select * from public.claim_notification_deliveries(10)$$, '42501', null,
  'clients cannot claim deliveries');

select lives_ok($$select public.send_test_notification()$$, 'users send themselves a test');
select throws_ok($$select public.send_test_notification()$$, '23514', null,
  'but only once a minute');

-- ---------------------------------------------------------------- as Bala (same browser)
reset role;
select set_config('request.jwt.claims', '{"sub":"t-nb","app_role":"candidate","email_verified":true}', true);
set local role authenticated;
select public.register_push_token('tok-asha-browser-0000000001', 'web');
select is((select user_id from public.push_tokens where token = 'tok-asha-browser-0000000001'), 't-nb',
  'a token moves to whoever signed in on that device last');
reset role;
select is((select count(*)::int from public.push_tokens where user_id = 't-na'), 0,
  'so Asha no longer receives pushes there');

-- ---------------------------------------------------------------- suspended
select set_config('request.jwt.claims', '{"sub":"t-ns","app_role":"candidate","email_verified":true}', true);
set local role authenticated;
select throws_ok($$select public.register_push_token('tok-suspended-device-000001', 'android')$$,
  '42501', null, 'suspended users cannot register devices');
reset role;

-- ---------------------------------------------------------------- dispatcher
insert into public.push_tokens (token, user_id, platform) values ('tok-asha-phone-000000000001', 't-na', 'android');
select app.notify('t-na', 'application.stage', 'Application update', 'Moved to Interview.');
select app.notify('t-na', 'offer.issued', 'You received an offer', 'Nimbus sent an offer.');
select app.notify('t-ns', 'offer.issued', 'You received an offer', 'Hidden.');
select app.notify('t-nb', 'job.published', 'Old', 'Too old.');
update public.notifications set created_at = now() - interval '2 hours' where title = 'Old';

set local role service_role;
create temp table claimed on commit drop as
  select * from public.claim_notification_deliveries(50);
select is(
  (select string_agg(format('%s %s %s %s', type, send_push, send_email, cardinality(tokens)), '; ' order by type)
   from claimed where user_id = 't-na'),
  'application.stage t f 1; offer.issued t t 1; system.test t t 1',
  'claims follow preferences (emails off for applications) and include device tokens');
select is(
  (select format('%s %s', send_push, send_email) from claimed where user_id = 't-ns'),
  'f f',
  'suspended users get no push or email');
select is((select count(*)::int from public.claim_notification_deliveries(50)), 0,
  'each notification is claimed once, and old ones are never sent');
reset role;

select * from finish();
rollback;
