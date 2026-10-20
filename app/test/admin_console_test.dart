import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:luzhire/core/data/enums.dart';
import 'package:luzhire/core/data/models.dart';
import 'package:luzhire/core/shell/workspace_page.dart';
import 'package:luzhire/core/widgets/widgets.dart';

import 'support/admin_fakes.dart';
import 'support/candidate_fakes.dart';
import 'support/employer_fakes.dart';
import 'support/fakes.dart';
import 'support/job_fakes.dart';

class _Harness {
  final admin = FakeAdminRepository();
  late final gov = FakeGovernanceRepository(admin);
  late FakeAccountApi api;
}

Future<GoRouter> _pump(
  WidgetTester tester,
  _Harness h, {
  required String location,
  AppRole? role = AppRole.admin,
  double width = 1440,
}) {
  final gateway = FakeAuthGateway(
    signedIn: role == null ? null : signedInAs(role),
  );
  h.api = FakeAccountApi(gateway);
  return pumpLuzHire(
    tester,
    location: location,
    size: Size(width, 1000),
    gateway: gateway,
    api: h.api,
    overrides: [
      ...jobBoardOverrides(),
      ...CandidateFakes().overrides,
      ...employerOverrides(FakeEmployerRepository()),
      ...adminOverrides(h.admin, h.gov),
    ],
  );
}

Finder _field(String label) => find.descendant(
  of: find.widgetWithText(LuzTextField, label),
  matching: find.byType(TextField),
);

/// The page's own list (the sidebar scrolls too).
final _pageScroll = find
    .descendant(
      of: find.byType(WorkspacePage),
      matching: find.byType(Scrollable),
    )
    .first;

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  for (final width in [375.0, 1440.0]) {
    testWidgets('overview shows the queues at ${width.toInt()} px', (
      tester,
    ) async {
      await _pump(tester, _Harness(), location: '/admin', width: width);
      expect(find.text('Companies to verify'), findsOneWidget);
      expect(find.text('Jobs to review'), findsOneWidget);
      expect(find.text('Open reports'), findsOneWidget);
      expect(find.text('21'), findsOneWidget); // applications
      expect(tester.takeException(), isNull);
    });
  }

  group('Verification', () {
    testWidgets('verifies a company and clears the queue', (tester) async {
      final h = _Harness();
      await _pump(tester, h, location: '/admin/verification');
      expect(find.text('Pending Co'), findsOneWidget);
      await _tap(tester, find.text('Verify'));
      expect(h.admin.decisions, ['company:co-p:true:']);
      expect(find.text('Queue is clear'), findsOneWidget);
    });

    testWidgets('declines with a reason', (tester) async {
      final h = _Harness();
      await _pump(tester, h, location: '/admin/verification');
      await _tap(tester, find.text('Decline'));
      await tester.enterText(
        _field('Reason (shared with the company)'),
        'Website does not match',
      );
      await _tap(tester, find.text('Decline verification'));
      expect(h.admin.decisions, ['company:co-p:false:Website does not match']);
    });
  });

  group('Moderation', () {
    testWidgets('publishes a job waiting for review', (tester) async {
      final h = _Harness();
      await _pump(tester, h, location: '/admin/moderation');
      expect(find.text('Support Engineer'), findsOneWidget);
      await _tap(tester, find.text('Publish'));
      expect(h.admin.decisions, ['job:job-p:true:']);
      expect(find.text('Nothing to review'), findsOneWidget);
    });

    testWidgets('takes a reported job down and resolves the report', (
      tester,
    ) async {
      final h = _Harness();
      await _pump(tester, h, location: '/admin/moderation?tab=reports');
      expect(find.text('Data Entry (work from home)'), findsOneWidget);
      expect(find.text('“Asks candidates to pay a fee”'), findsOneWidget);

      await _tap(tester, find.text('Take job down'));
      await tester.enterText(
        _field('Reason (shared with the company)'),
        'Charging candidates',
      );
      await _tap(tester, find.text('Take down'));
      expect(h.admin.decisions, ['job:job-x:false:Charging candidates']);
      expect(h.admin.reportList.single.status, ReportStatus.actioned);
      expect(find.text('No open reports'), findsOneWidget);
    });

    testWidgets('dismisses a report', (tester) async {
      final h = _Harness();
      await _pump(tester, h, location: '/admin/moderation?tab=reports');
      await _tap(tester, find.text('Dismiss'));
      expect(h.admin.reportList.single.status, ReportStatus.dismissed);
    });
  });

  group('Users', () {
    testWidgets('suspends a user after confirming', (tester) async {
      final h = _Harness();
      await _pump(tester, h, location: '/admin/users');
      expect(find.text('Test admin (you)'), findsOneWidget);
      await _tap(tester, find.text('Asha Verma'));
      await _tap(tester, find.text('Suspend account'));
      await _tap(tester, find.text('Suspend').last);
      expect(h.api.adminCalls, [('u-2', 'suspended')]);
    });

    testWidgets('changes a role', (tester) async {
      final h = _Harness();
      await _pump(tester, h, location: '/admin/users');
      await _tap(tester, find.text('Asha Verma'));
      await _tap(tester, find.text('employer').last);
      await _tap(tester, find.text('Save role'));
      expect(h.api.adminCalls, [('u-2', 'employer')]);
    });

    testWidgets('your own row cannot be managed', (tester) async {
      final h = _Harness();
      await _pump(tester, h, location: '/admin/users');
      await _tap(tester, find.text('Test admin (you)'));
      expect(find.text('Suspend account'), findsNothing);
    });
  });

  testWidgets('a published announcement reaches the banner', (tester) async {
    final h = _Harness();
    final router = await _pump(tester, h, location: '/admin/announcements');
    await _tap(tester, find.text('New announcement'));
    await _tap(tester, find.text('Publish'));
    expect(find.text('Add a title'), findsOneWidget);

    await tester.enterText(_field('Title'), 'Placement week');
    await tester.enterText(
      _field('Message (Markdown)'),
      'Top companies are hiring **this week**.',
    );
    await _tap(tester, find.text('Publish'));
    expect(h.admin.announcementList.single.title, 'Placement week');

    router.go('/');
    await tester.pumpAndSettle();
    expect(find.text('Placement week'), findsOneWidget);
    await _tap(tester, find.byTooltip('Dismiss announcement'));
    expect(find.text('Placement week'), findsNothing);
  });

  testWidgets('audit log pages and filters', (tester) async {
    final h = _Harness();
    await _pump(tester, h, location: '/admin/audit');
    expect(find.text('jobs.update'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('Load more'),
      500,
      scrollable: _pageScroll,
    );
    await _tap(tester, find.text('Load more'));
    expect(find.text('Load more'), findsNothing); // all 60 loaded

    await tester.scrollUntilVisible(
      find.widgetWithText(LuzFilterChip, 'companies'),
      -500,
      scrollable: _pageScroll,
    );
    await _tap(tester, find.widgetWithText(LuzFilterChip, 'companies'));
    expect(find.text('jobs.update'), findsNothing);
    expect(find.text('companies.update'), findsWidgets);
  });

  group('Reporting', () {
    testWidgets('a signed-in candidate reports a job', (tester) async {
      final h = _Harness();
      await _pump(tester, h, location: '/jobs/job-1', role: AppRole.candidate);
      await _tap(tester, find.text('Report'));
      await _tap(tester, find.text('Send report'));
      expect(find.text('Tell us what is wrong'), findsOneWidget);
      await tester.enterText(_field('What is wrong?'), 'Duplicate posting');
      await _tap(tester, find.text('Send report'));
      expect(h.gov.reports, ['job:job-1:Duplicate posting']);
      expect(find.text('Thanks. Our team will review it.'), findsOneWidget);
    });

    testWidgets('visitors are asked to sign in', (tester) async {
      final h = _Harness();
      await _pump(tester, h, location: '/jobs/job-1', role: null);
      await _tap(tester, find.text('Report'));
      expect(find.text('Sign in to report content.'), findsOneWidget);
      expect(h.gov.reports, isEmpty);
    });
  });

  group('First admin', () {
    testWidgets('an employer on the admin list claims admin', (tester) async {
      final h = _Harness();
      final router = await _pump(
        tester,
        h,
        location: '/account',
        role: AppRole.employer,
      );
      h.api.adminEmails = {'employer@example.com'};
      await _tap(tester, find.text('Claim admin access'));
      expect(router.state.uri.path, '/admin');
      expect(find.text('Companies to verify'), findsOneWidget);
    });

    testWidgets('anyone else is refused and keeps their role', (tester) async {
      final h = _Harness();
      final router = await _pump(
        tester,
        h,
        location: '/account',
        role: AppRole.candidate,
      );
      await _tap(tester, find.text('Claim admin access'));
      expect(
        find.text('This account is not on the admin list.'),
        findsOneWidget,
      );
      expect(router.state.uri.path, '/account');
      router.go('/admin');
      await tester.pumpAndSettle();
      expect(router.state.uri.path, isNot('/admin'));
    });
  });

  testWidgets('overview shows the latest job imports', (tester) async {
    final h = _Harness();
    h.admin.runs.addAll([
      IngestRun(
        source: 'remotive',
        startedAt: DateTime.now(),
        fetched: 10,
        inserted: 7,
        updated: 3,
        skipped: 0,
        closed: 1,
      ),
      IngestRun(
        source: 'adzuna',
        startedAt: DateTime.now(),
        fetched: 0,
        inserted: 0,
        updated: 0,
        skipped: 0,
        closed: 0,
        error: 'api.adzuna.com answered 401',
      ),
    ]);
    await _pump(tester, h, location: '/admin');
    await tester.scrollUntilVisible(
      find.text('Job imports'),
      300,
      scrollable: _pageScroll,
    );
    expect(
      find.text('remotive: 7 new, 3 updated, 1 closed, 0 skipped'),
      findsOneWidget,
    );
    expect(find.text('adzuna: api.adzuna.com answered 401'), findsOneWidget);
  });
}
