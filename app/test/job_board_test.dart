import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:luzhire/core/data/enums.dart';
import 'package:luzhire/core/data/models.dart';
import 'package:luzhire/core/widgets/widgets.dart';
import 'package:luzhire/features/jobs/application/job_board_providers.dart';

import 'support/fakes.dart';
import 'support/job_fakes.dart';

final _vertical = find.byWidgetPredicate(
  (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
);

Future<GoRouter> _pump(
  WidgetTester tester, {
  required String location,
  double width = 1200, // filters | results; the preview pane starts at 1280
  FakeJobsRepository? jobs,
  FakeSavedJobsRepository? saved,
  FakeCompaniesRepository? companies,
  AppRole? signedIn,
}) => pumpLuzHire(
  tester,
  location: location,
  size: Size(width, 900),
  gateway: FakeAuthGateway(
    signedIn: signedIn == null ? null : signedInAs(signedIn),
  ),
  overrides: jobBoardOverrides(jobs: jobs, saved: saved, companies: companies),
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
        find.text("You've seen all the matching jobs."),
        600,
        scrollable: _vertical.first,
      );
      await tester.pumpAndSettle();
      expect(jobs.queries.length, greaterThanOrEqualTo(2));
      expect(find.text("You've seen all the matching jobs."), findsOneWidget);
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

  // Search rows leave out the description (search_jobs returns job cards).
  group('Job detail from search results', () {
    Finder loadingDescription() =>
        find.bySemanticsLabel('Loading the job description');

    testWidgets('the preview pane shows the card at once, then the '
        'description', (tester) async {
      final jobs = FakeJobsRepository();
      await _pump(tester, location: '/jobs', width: 1440, jobs: jobs);
      jobs.holdDetails = Completer<void>();

      await tester.tap(find.text('Flutter Developer 2'));
      await tester.pump();
      expect(find.text('Flutter Developer 2'), findsNWidgets(2));
      expect(find.text('Build the LuzHire mobile app.'), findsOneWidget);
      expect(find.text('₹12–18 L / year'), findsWidgets);
      expect(find.text('Sign in to apply'), findsOneWidget);
      expect(loadingDescription(), findsOneWidget);
      expect(find.text('About the role'), findsNothing);

      jobs.holdDetails!.complete();
      await tester.pumpAndSettle();
      expect(jobs.detailLoads.last, 'job-2');
      expect(loadingDescription(), findsNothing);
      expect(find.text('About the role'), findsOneWidget);
      expect(find.text('Own the job search screens'), findsOneWidget);
      expect(find.text('2+ years of Flutter'), findsOneWidget);
      expect(find.text('Flutter Developer 2'), findsNWidgets(2));
    });

    testWidgets('the job page opened from a card shows it at once', (
      tester,
    ) async {
      final jobs = FakeJobsRepository();
      final router = await _pump(
        tester,
        location: '/jobs',
        width: 375,
        jobs: jobs,
      );
      jobs.holdDetails = Completer<void>();

      await tester.tap(find.text('Flutter Developer 2'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(router.state.uri.path, '/jobs/job-2');
      expect(find.text('Flutter Developer 2'), findsOneWidget);
      expect(find.text('Sign in to apply'), findsOneWidget);
      expect(loadingDescription(), findsOneWidget);
      expect(find.text('Responsibilities'), findsNothing);

      jobs.holdDetails!.complete();
      await tester.pumpAndSettle();
      expect(loadingDescription(), findsNothing);
      expect(find.text('Responsibilities'), findsOneWidget);
      expect(find.text('Health insurance'), findsOneWidget);
    });

    testWidgets('a description that fails to load can be retried', (
      tester,
    ) async {
      final jobs = FakeJobsRepository();
      await _pump(tester, location: '/jobs', width: 375, jobs: jobs);
      jobs.failDetails = true;

      await tester.tap(find.text('Flutter Developer 1'));
      // Riverpod retries a failed load for about 40 s before giving up.
      await tester.pump();
      await tester.pump(const Duration(minutes: 1));
      await tester.pumpAndSettle();
      expect(find.text('Flutter Developer 1'), findsOneWidget);
      expect(find.text("Couldn't load the job description."), findsOneWidget);

      jobs.failDetails = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text("Couldn't load the job description."), findsNothing);
      expect(find.text('Responsibilities'), findsOneWidget);
    });

    test('previews keep the most recent ${JobPreviews.capacity} jobs', () {
      final previews = JobPreviews()
        ..addAll([
          for (var i = 1; i <= JobPreviews.capacity + 1; i++) fakeJob(i),
        ]);
      expect(previews['job-1'], isNull);
      expect(previews['job-2']?.title, 'Flutter Developer 2');
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

    testWidgets('imported companies are listed with their open roles', (
      tester,
    ) async {
      final router = await _pump(
        tester,
        location: '/companies',
        width: 375,
        jobs: FakeJobsRepository([...fakeJobs(3), fakeExternalJob()]),
        companies: FakeCompaniesRepository(externals: [fakeExternalCompany]),
      );
      expect(find.text('Askable'), findsOneWidget);
      expect(find.text('1 open role'), findsOneWidget);
      final logo = tester.widget<LuzLogoSocket>(
        find.byWidgetPredicate(
          (w) => w is LuzLogoSocket && w.name == 'Askable',
        ),
      );
      expect(logo.logoUrl, 'https://remotive.com/job/1/logo');

      await tester.ensureVisible(find.text('Askable'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Askable'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/companies/jobs-at-askable');
      expect(find.text('Remote Flutter Engineer'), findsOneWidget);
      expect(find.text('Flutter Developer 1'), findsNothing);
      expect(find.text('Report'), findsNothing);
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

  testWidgets('home shows the companies hiring now', (tester) async {
    final router = await _pump(
      tester,
      location: '/',
      jobs: FakeJobsRepository([...fakeJobs(3), fakeExternalJob()]),
      companies: FakeCompaniesRepository(externals: [fakeExternalCompany]),
    );
    expect(find.text('Companies hiring now'), findsOneWidget);
    final stripLogo = find.byWidgetPredicate(
      (w) => w is LuzLogoSocket && w.name == 'Askable' && w.size == 56,
    );
    await tester.ensureVisible(stripLogo);
    await tester.pumpAndSettle();
    await tester.tap(stripLogo);
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/companies/jobs-at-askable');
  });

  testWidgets('home shows the latest jobs', (tester) async {
    await _pump(tester, location: '/', width: 1280);
    expect(find.text('Latest jobs'), findsOneWidget);
    expect(find.text('Flutter Developer 1'), findsOneWidget);
    expect(find.text('Flutter Developer 7'), findsNothing);
  });

  group('New jobs banner', () {
    for (final location in ['/jobs', '/']) {
      testWidgets('appears on $location when jobs arrive and reloads', (
        tester,
      ) async {
        final jobs = FakeJobsRepository();
        await _pump(tester, location: location, width: 1280, jobs: jobs);
        expect(find.textContaining('new job'), findsNothing);

        // Nothing new at the first check: still hidden.
        await tester.pump(newJobsPollInterval);
        await tester.pump();
        expect(find.textContaining('new job'), findsNothing);

        jobs.newSince = 3;
        await tester.pump(newJobsPollInterval);
        await tester.pump();
        expect(find.text('3 new jobs · Show'), findsOneWidget);

        final before = jobs.queries.length;
        await tester.ensureVisible(find.text('3 new jobs · Show'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('3 new jobs · Show'));
        await tester.pumpAndSettle();
        expect(jobs.queries.length, greaterThan(before));
        expect(find.textContaining('new job'), findsNothing);
      });
    }

    testWidgets('names a single job in the singular', (tester) async {
      final jobs = FakeJobsRepository()..newSince = 1;
      await _pump(tester, location: '/jobs', jobs: jobs);
      await tester.pump(newJobsPollInterval);
      await tester.pump();
      expect(find.text('1 new job · Show'), findsOneWidget);
    });
  });

  testWidgets('job cards in a grid row share height and line up', (
    tester,
  ) async {
    final short = fakeJob(1, title: 'Writer');
    final long = Job(
      id: 'long',
      slug: 'long',
      title: 'Tier III Service Desk Engineer for Enterprise Customers',
      companyName: 'Unio Digital',
      employmentType: EmploymentType.contract,
      workplace: WorkplaceType.remote,
      status: JobStatus.published,
      location: 'Remote (USA, Canada, UK, Australia, Ireland, Germany)',
      publishedAt: DateTime.utc(2026, 10, 19, 9),
      isExternal: true,
      externalSource: 'remotive',
      externalUrl: 'https://remotive.com/remote-jobs/x-long',
    );
    await _pump(
      tester,
      location: '/',
      width: 1280,
      jobs: FakeJobsRepository([short, long, fakeJob(3)]),
    );
    Rect card(String title) => tester.getRect(
      find
          .ancestor(of: find.text(title), matching: find.byType(LuzSurface))
          .last,
    );
    final a = card('Writer');
    final b = card(long.title);
    expect(a.top, b.top);
    expect(a.height, b.height);
    // The bottom rows sit at the same height on both cards.
    final salaryA = tester.getRect(find.textContaining('/ year').first);
    final salaryB = tester.getRect(find.text('Salary not disclosed').first);
    expect(salaryA.top, closeTo(salaryB.top, 1));
    // A one-line title keeps its company right below it.
    final title = tester.getRect(find.text('Writer'));
    final company = tester.getRect(
      find.descendant(
        of: find
            .ancestor(of: find.text('Writer'), matching: find.byType(Column))
            .first,
        matching: find.text('Nimbus Labs'),
      ),
    );
    expect(company.top - title.bottom, closeTo(2, 1));
    expect(tester.takeException(), isNull);
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
