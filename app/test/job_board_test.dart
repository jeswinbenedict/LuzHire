import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:luzhire/core/data/enums.dart';
import 'package:luzhire/core/data/models.dart';
import 'package:luzhire/core/widgets/widgets.dart';

import 'support/fakes.dart';
import 'support/job_fakes.dart';

final _vertical = find.byWidgetPredicate(
  (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
);

Future<GoRouter> _pump(
  WidgetTester tester, {
  required String location,
  double width = 1280,
  FakeJobsRepository? jobs,
  FakeSavedJobsRepository? saved,
  AppRole? signedIn,
}) => pumpLuzHire(
  tester,
  location: location,
  size: Size(width, 900),
  gateway: FakeAuthGateway(
    signedIn: signedIn == null ? null : signedInAs(signedIn),
  ),
  overrides: jobBoardOverrides(jobs: jobs, saved: saved),
);

void main() {
  group('Job search', () {
    for (final width in [360.0, 768.0, 1280.0, 1440.0]) {
      testWidgets('lists jobs at ${width.toInt()} px', (tester) async {
        await _pump(tester, location: '/jobs', width: width);
        expect(find.text('Flutter Developer 1'), findsWidgets);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('keyword search is reflected in the URL', (tester) async {
      final router = await _pump(tester, location: '/jobs');
      await tester.enterText(find.byType(TextField).first, 'intern');
      await tester.tap(find.text('Search').last);
      await tester.pumpAndSettle();
      expect(router.state.uri.toString(), '/jobs?q=intern');
      expect(find.text('Design Intern'), findsOneWidget);
      expect(find.text('Flutter Developer 1'), findsNothing);
    });

    testWidgets('filters update the URL and results', (tester) async {
      final router = await _pump(tester, location: '/jobs');
      await tester.tap(find.byType(LuzToggle));
      await tester.pumpAndSettle();
      expect(router.state.uri.queryParameters['remote'], '1');
      expect(find.text('Design Intern'), findsOneWidget);
      expect(find.text('Flutter Developer 1'), findsNothing);

      await tester.tap(find.text('Reset all'));
      await tester.pumpAndSettle();
      expect(router.state.uri.toString(), '/jobs');
    });

    testWidgets('a shared link restores its filters', (tester) async {
      await _pump(tester, location: '/jobs?type=internship');
      expect(find.text('Design Intern'), findsOneWidget);
      expect(find.text('Flutter Developer 2'), findsNothing);
      final internship = tester.widget<LuzCheckbox>(
        find.widgetWithText(LuzCheckbox, 'Internship'),
      );
      expect(internship.value, isTrue);
    });

    testWidgets('loads further pages while scrolling', (tester) async {
      final jobs = FakeJobsRepository();
      await _pump(tester, location: '/jobs', width: 375, jobs: jobs);
      await tester.scrollUntilVisible(
        find.text("You've reached the end."),
        600,
        scrollable: _vertical.first,
      );
      await tester.pumpAndSettle();
      expect(jobs.queries.length, greaterThanOrEqualTo(2));
      expect(find.text("You've reached the end."), findsOneWidget);
    });

    testWidgets('phones open filters in a sheet', (tester) async {
      final router = await _pump(tester, location: '/jobs', width: 375);
      await tester.tap(find.text('Filters'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Internship'));
      await tester.pumpAndSettle();
      expect(router.state.uri.queryParameters['type'], 'internship');
      await tester.tap(find.text('Show results'));
      await tester.pumpAndSettle();
      expect(find.text('Filters (1)'), findsOneWidget);
      expect(find.text('Design Intern'), findsOneWidget);
    });

    testWidgets('shows an empty state with a way out', (tester) async {
      final router = await _pump(
        tester,
        location: '/jobs?q=intern&type=contract',
      );
      expect(find.text('No jobs match this search'), findsOneWidget);
      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();
      expect(router.state.uri.toString(), '/jobs?q=intern');
      expect(find.text('Design Intern'), findsOneWidget);
    });

    testWidgets('wide screens preview the selected job', (tester) async {
      await _pump(tester, location: '/jobs', width: 1440);
      expect(find.text('About the role'), findsOneWidget);
      expect(find.text('Flutter Developer 1'), findsNWidgets(2));

      await tester.tap(find.text('Flutter Developer 2'));
      await tester.pumpAndSettle();
      expect(find.text('Flutter Developer 2'), findsNWidgets(2));
    });
  });

  group('Job detail', () {
    testWidgets('shows the posting and asks visitors to sign in', (
      tester,
    ) async {
      final router = await _pump(tester, location: '/jobs/job-1', width: 375);
      expect(find.text('Flutter Developer 1'), findsOneWidget);
      expect(find.text('Nimbus Labs'), findsWidgets);
      expect(find.text('Verified'), findsOneWidget);
      expect(find.text('Responsibilities'), findsOneWidget);
      expect(find.text('Flutter'), findsWidgets); // skills
      await tester.tap(find.text('Sign in to apply'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/sign-in');
      expect(router.state.uri.queryParameters['from'], '/jobs/job-1');
    });

    testWidgets('lays out on desktop with the apply panel', (tester) async {
      await _pump(tester, location: '/jobs/job-1', width: 1440);
      expect(find.text('₹12–18 L / year'), findsWidgets);
      expect(find.text('Applicants'), findsOneWidget);
      expect(find.text('More from Nimbus Labs'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an unknown job says it is no longer listed', (tester) async {
      await _pump(tester, location: '/jobs/nope');
      expect(find.text('This job is no longer listed'), findsOneWidget);
    });
  });

  group('Saved jobs', () {
    testWidgets('visitors are offered sign-in', (tester) async {
      await _pump(tester, location: '/jobs/job-1');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Sign in to save jobs'), findsOneWidget);
    });

    testWidgets('candidates save a job and find it in Saved', (tester) async {
      final saved = FakeSavedJobsRepository();
      final router = await _pump(
        tester,
        location: '/jobs/job-3',
        saved: saved,
        signedIn: AppRole.candidate,
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(saved.ids, {'job-3'});
      expect(find.text('Saved'), findsOneWidget);

      router.go('/me/saved');
      await tester.pumpAndSettle();
      expect(find.text('Flutter Developer 3'), findsOneWidget);

      await tester.tap(find.byTooltip('Remove from saved jobs'));
      await tester.pumpAndSettle();
      expect(saved.ids, isEmpty);
      expect(find.text('No saved jobs yet'), findsOneWidget);
    });
  });

  group('Companies', () {
    testWidgets('directory links to the company page', (tester) async {
      final router = await _pump(tester, location: '/companies', width: 375);
      expect(find.text('Orbit Works'), findsOneWidget);
      await tester.tap(find.text('Nimbus Labs'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/companies/nimbus-labs');
      expect(find.text('Open roles'), findsOneWidget);
      expect(find.text('Flutter Developer 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('search narrows the directory', (tester) async {
      final router = await _pump(tester, location: '/companies');
      await tester.enterText(find.byType(TextField).first, 'orbit');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(router.state.uri.toString(), '/companies?q=orbit');
      expect(find.text('Orbit Works'), findsOneWidget);
      expect(find.text('Nimbus Labs'), findsNothing);
    });
  });

  testWidgets('home shows the latest jobs', (tester) async {
    await _pump(tester, location: '/', width: 1280);
    expect(find.text('Latest jobs'), findsOneWidget);
    expect(find.text('Flutter Developer 1'), findsOneWidget);
    expect(find.text('Flutter Developer 7'), findsNothing);
  });

  testWidgets('external listings name and link their source', (tester) async {
    final jobs = FakeJobsRepository([
      Job(
        id: 'ext-1',
        publishedAt: DateTime.utc(2026, 10, 19, 10),
        slug: 'ext-1',
        title: 'Remote Flutter Engineer',
        companyName: 'Askable',
        employmentType: EmploymentType.contract,
        workplace: WorkplaceType.remote,
        status: JobStatus.published,
        isExternal: true,
        externalSource: 'remotive',
        externalUrl: 'https://remotive.com/remote-jobs/x-1',
      ),
      Job(
        id: 'ext-2',
        publishedAt: DateTime.utc(2026, 10, 19, 9),
        slug: 'ext-2',
        title: 'Data Analyst',
        companyName: 'Acme',
        employmentType: EmploymentType.fullTime,
        workplace: WorkplaceType.onsite,
        status: JobStatus.published,
        isExternal: true,
        externalSource: 'adzuna',
        externalUrl: 'https://www.adzuna.in/land/ad/1',
      ),
    ]);
    final router = await _pump(tester, location: '/jobs', jobs: jobs);
    expect(find.text('via Remotive'), findsWidgets);
    expect(find.text('Jobs by Adzuna'), findsWidgets);

    router.go('/jobs/ext-1');
    await tester.pumpAndSettle();
    expect(find.text('Apply on Remotive'), findsWidgets);
    expect(find.text('via Remotive'), findsWidgets);
  });
}
