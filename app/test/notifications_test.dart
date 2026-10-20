import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:luzhire/core/data/enums.dart';
import 'package:luzhire/core/data/models.dart';
import 'package:luzhire/features/notifications/data/notifications_repository.dart';
import 'package:luzhire/features/notifications/data/push_service.dart';
import 'package:luzhire/features/notifications/domain/notification_links.dart';

import 'support/admin_fakes.dart';
import 'support/candidate_fakes.dart';
import 'support/employer_fakes.dart';
import 'support/fakes.dart';
import 'support/job_fakes.dart';
import 'support/push_fakes.dart';

class _Harness {
  _Harness({FakePushService? push}) : push = push ?? FakePushService();
  final candidate = CandidateFakes();
  final FakePushService push;
  FakeNotificationsRepository get repo => candidate.notifications;
}

Future<GoRouter> _pump(
  WidgetTester tester,
  _Harness h, {
  required String location,
  AppRole role = AppRole.candidate,
  double width = 1280,
}) {
  final gateway = FakeAuthGateway(signedIn: signedInAs(role));
  return pumpLuzHire(
    tester,
    location: location,
    size: Size(width, 1000),
    gateway: gateway,
    overrides: [
      ...jobBoardOverrides(),
      ...h.candidate.overrides,
      ...employerOverrides(FakeEmployerRepository()),
      ...adminOverrides(
        FakeAdminRepository(),
        FakeGovernanceRepository(FakeAdminRepository()),
      ),
      pushServiceProvider.overrideWithValue(h.push),
    ],
  );
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

const _app = '11111111-2222-4333-8444-555555555555';
const _job = '66666666-7777-4888-9999-000000000000';

AppNotification _note(String type, {Json data = const {}}) => AppNotification(
  id: 'n-$type',
  type: type,
  title: 'New application',
  body: 'Asha applied for Flutter Developer',
  data: data,
  createdAt: DateTime.now(),
);

void main() {
  group('notificationLink (mirrors api/_lib/notify/messages.ts)', () {
    test('opens the right screen for each role', () {
      expect(
        notificationLink('application.stage', {
          'application_id': _app,
        }, AppRole.candidate),
        '/me/applications/$_app',
      );
      expect(
        notificationLink('interview.scheduled', {}, AppRole.candidate),
        '/me/interviews',
      );
      expect(
        notificationLink('application.new', {'job_id': _job}, AppRole.employer),
        '/employer/pipeline?job=$_job',
      );
      expect(
        notificationLink('job.rejected', {'job_id': _job}, AppRole.employer),
        '/employer/jobs/$_job',
      );
      expect(
        notificationLink('company.invite', {}, AppRole.employer),
        '/employer/company',
      );
      expect(notificationLink('report.resolved', {}, AppRole.admin), '/admin');
      expect(
        notificationLink('application.stage', {
          'application_id': '../evil',
        }, AppRole.candidate),
        '/me/notifications',
      );
    });

    test('push links become in-app paths', () {
      expect(
        appPathFromLink('https://luzhire.vercel.app/employer/pipeline?job=x'),
        '/employer/pipeline?job=x',
      );
      expect(appPathFromLink('/me/interviews'), '/me/interviews');
      expect(appPathFromLink('https:evil'), isNull);
    });
  });

  group('Settings', () {
    for (final width in [375.0, 1280.0]) {
      testWidgets('lists the groups for the role at ${width.toInt()} px', (
        tester,
      ) async {
        await _pump(
          tester,
          _Harness(),
          location: '/account/notifications',
          width: width,
        );
        expect(find.text('What you receive'), findsOneWidget);
        expect(find.text('Applications'), findsOneWidget);
        expect(find.text('Interviews'), findsOneWidget);
        expect(find.text('Team'), findsNothing); // candidates have no team
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('employers see Team but not Interviews', (tester) async {
      await _pump(
        tester,
        _Harness(),
        location: '/account/notifications',
        role: AppRole.employer,
      );
      expect(find.text('Team'), findsOneWidget);
      expect(find.text('Interviews'), findsNothing);
    });

    testWidgets('a switch saves at once', (tester) async {
      final h = _Harness();
      await _pump(tester, h, location: '/account/notifications');
      final semantics = tester.ensureSemantics();
      await _tap(tester, find.bySemanticsLabel('Applications by email'));
      expect(
        h.repo.prefs[NotificationCategory.applications],
        const ChannelPrefs(email: false),
      );
      semantics.dispose();
    });

    testWidgets('a failed save puts the switch back and says so', (
      tester,
    ) async {
      final h = _Harness()..repo.failWrites = true;
      await _pump(tester, h, location: '/account/notifications');
      final semantics = tester.ensureSemantics();
      await _tap(tester, find.bySemanticsLabel('Offers by push'));
      expect(find.text('Could not save.'), findsOneWidget);
      expect(h.repo.prefs, isEmpty);
      semantics.dispose();
    });

    testWidgets('turns push on and off for this device', (tester) async {
      final h = _Harness();
      await _pump(tester, h, location: '/account/notifications');
      await _tap(tester, find.text('Turn on push notifications'));
      expect(h.push.prompts, 1);
      expect(h.repo.tokens, {'fake-device-token-0000000001': PushPlatform.web});
      expect(find.text('On for this device'), findsOneWidget);

      await _tap(tester, find.text('Turn off on this device'));
      expect(h.repo.tokens, isEmpty);
      expect(find.text('Turn on push notifications'), findsOneWidget);
    });

    testWidgets('explains a blocked permission', (tester) async {
      final h = _Harness(push: FakePushService(answer: PushPermission.denied));
      await _pump(tester, h, location: '/account/notifications');
      await _tap(tester, find.text('Turn on push notifications'));
      expect(h.repo.tokens, isEmpty);
      expect(
        find.textContaining('Notifications are blocked for LuzHire'),
        findsWidgets,
      );
    });

    testWidgets('a registered device shows as on', (tester) async {
      final h = _Harness(
        push: FakePushService(current: PushPermission.granted),
      );
      h.repo.tokens['fake-device-token-0000000001'] = PushPlatform.web;
      await _pump(tester, h, location: '/account/notifications');
      expect(find.text('On for this device'), findsOneWidget);
    });

    testWidgets('browsers without push get an explanation', (tester) async {
      final h = _Harness(push: FakePushService(isSupported: false));
      await _pump(tester, h, location: '/account/notifications');
      expect(
        find.textContaining('This browser can’t show notifications'),
        findsOneWidget,
      );
      expect(find.text('Turn on push notifications'), findsNothing);
    });

    testWidgets('sends a test notification', (tester) async {
      final h = _Harness();
      await _pump(tester, h, location: '/account/notifications');
      await _tap(tester, find.text('Send a test notification'));
      expect(h.repo.tests, 1);
      expect(
        find.text('Test sent. It should arrive in a few seconds.'),
        findsOneWidget,
      );
    });

    testWidgets('signing out removes this device from the account', (
      tester,
    ) async {
      final h = _Harness(
        push: FakePushService(current: PushPermission.granted),
      );
      h.repo.tokens['fake-device-token-0000000001'] = PushPlatform.web;
      await _pump(tester, h, location: '/account');
      await _tap(tester, find.text('Sign out'));
      expect(h.repo.tokens, isEmpty);
    });

    testWidgets('the account page links to the settings', (tester) async {
      final router = await _pump(tester, _Harness(), location: '/account');
      await _tap(tester, find.text('Notification settings'));
      expect(router.state.uri.path, '/account/notifications');
    });
  });

  group('Workspace bell', () {
    testWidgets('shows the unread count and opens the notification', (
      tester,
    ) async {
      final h = _Harness();
      h.repo.push(_note('application.new', data: {'job_id': _job}));
      final router = await _pump(
        tester,
        h,
        location: '/employer/jobs',
        role: AppRole.employer,
        width: 1440,
      );
      expect(find.byTooltip('Notifications, 1 unread'), findsOneWidget);
      expect(find.text('1'), findsWidgets);

      await _tap(tester, find.byTooltip('Notifications, 1 unread'));
      expect(find.text('Asha applied for Flutter Developer'), findsOneWidget);
      await _tap(tester, find.text('New application'));
      expect(router.state.uri.toString(), '/employer/pipeline?job=$_job');
    });

    testWidgets('the panel links to the settings', (tester) async {
      final router = await _pump(
        tester,
        _Harness(),
        location: '/employer/jobs',
        role: AppRole.employer,
        width: 1440,
      );
      await _tap(tester, find.byTooltip('Notifications'));
      expect(find.text('You are all caught up.'), findsOneWidget);
      await _tap(tester, find.text('Settings'));
      expect(router.state.uri.path, '/account/notifications');
    });
  });
}
