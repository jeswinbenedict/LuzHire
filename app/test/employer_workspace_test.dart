import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:luzhire/core/data/enums.dart';
import 'package:luzhire/core/data/models.dart';
import 'package:luzhire/core/widgets/widgets.dart';

import 'support/candidate_fakes.dart';
import 'support/employer_fakes.dart';
import 'support/fakes.dart';
import 'support/job_fakes.dart';

Future<GoRouter> _pump(
  WidgetTester tester,
  FakeEmployerRepository repo, {
  required String location,
  double width = 1440,
}) => pumpLuzHire(
  tester,
  location: location,
  size: Size(width, 1000),
  gateway: FakeAuthGateway(signedIn: signedInAs(AppRole.employer)),
  overrides: [
    ...jobBoardOverrides(),
    ...CandidateFakes().overrides,
    ...employerOverrides(repo),
  ],
);

Finder _field(String label) => find.descendant(
  of: find.widgetWithText(LuzTextField, label),
  matching: find.byType(TextField),
);

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  group('Onboarding', () {
    testWidgets('an employer without a company creates one', (tester) async {
      final repo = FakeEmployerRepository(withCompany: false);
      await _pump(tester, repo, location: '/employer');
      expect(find.text('Set up your company'), findsOneWidget);

      await _tap(tester, find.text('Create company'));
      expect(find.text('Enter the company name'), findsOneWidget);

      await tester.enterText(_field('Company name'), 'Orbit Works');
      await _tap(tester, find.text('Create company'));
      expect(repo.companies.single.name, 'Orbit Works');
      expect(find.text('Overview'), findsWidgets);
    });

    testWidgets('an invited employer accepts and joins', (tester) async {
      final repo = FakeEmployerRepository(withCompany: false);
      repo.invitesList.add(
        CompanyInviteFixture.forEmail('employer@example.com'),
      );
      await _pump(tester, repo, location: '/employer');
      expect(find.text('Join Team Co as recruiter'), findsOneWidget);
      await _tap(tester, find.text('Accept'));
      expect(repo.role, MemberRole.recruiter);
      expect(find.text('Set up your company'), findsNothing);
    });
  });

  group('Jobs', () {
    testWidgets('publishing as an unverified company goes to review', (
      tester,
    ) async {
      final repo = FakeEmployerRepository();
      await _pump(tester, repo, location: '/employer/jobs/new');

      await tester.enterText(_field('Job title'), 'Flutter Engineer');
      await tester.pump();
      // Live preview follows the form.
      expect(find.text('Flutter Engineer'), findsWidgets);

      await _tap(tester, find.text('Publish'));
      expect(repo.jobs.single.status, JobStatus.pendingReview);
      expect(find.textContaining('Sent for review'), findsOneWidget);
      expect(find.text('Pending review'), findsOneWidget);
    });

    testWidgets('validates title and salary range', (tester) async {
      final repo = FakeEmployerRepository();
      await _pump(tester, repo, location: '/employer/jobs/new');
      await tester.enterText(_field('Minimum (₹)'), '900000');
      await tester.enterText(_field('Maximum (₹)'), '500000');
      await _tap(tester, find.text('Save draft'));
      expect(find.text('Enter a job title'), findsOneWidget);
      expect(find.text('Must be at least the minimum'), findsOneWidget);
      expect(repo.jobs, isEmpty);
    });
  });

  group('Pipeline', () {
    testWidgets('moves a candidate from the panel and updates live', (
      tester,
    ) async {
      final repo = FakeEmployerRepository()..seedJob(count: 2);
      await _pump(tester, repo, location: '/employer/pipeline');
      expect(find.text('Candidate 2'), findsOneWidget);
      expect(find.text('Candidate 3'), findsOneWidget);

      await _tap(tester, find.text('Candidate 2'));
      expect(find.text('Go'), findsOneWidget); // skills in the panel
      await _tap(tester, find.widgetWithText(LuzButton, 'Shortlisted'));
      expect(repo.apps.first.stage, ApplicationStage.shortlisted);
      expect(find.text('Candidate 2 moved to Shortlisted'), findsOneWidget);
    });

    testWidgets('drag and drop follows the allowed transitions', (
      tester,
    ) async {
      final repo = FakeEmployerRepository()..seedJob(count: 1);
      // Wide enough that every column is on screen.
      await _pump(tester, repo, location: '/employer/pipeline', width: 3400);

      Future<void> dragTo(String column) async {
        final drag = await tester.startGesture(
          tester.getCenter(find.text('Candidate 2')),
        );
        await tester.pump(const Duration(seconds: 1)); // long-press (touch)
        await drag.moveBy(const Offset(20, 0));
        await tester.pump();
        await drag.moveTo(
          tester.getCenter(find.widgetWithText(LuzKanbanColumn, column)),
        );
        await tester.pump();
        await drag.up();
        await tester.pumpAndSettle();
      }

      await dragTo('Hired'); // Applied → Hired is not allowed
      expect(repo.apps.single.stage, ApplicationStage.applied);

      await dragTo('Under review');
      expect(repo.apps.single.stage, ApplicationStage.underReview);
    });

    testWidgets('schedules an interview with validation', (tester) async {
      final repo = FakeEmployerRepository()
        ..seedJob(count: 1, stage: ApplicationStage.shortlisted);
      await _pump(tester, repo, location: '/employer/pipeline');
      await _tap(tester, find.text('Candidate 2'));
      await _tap(tester, find.text('Schedule interview'));

      await tester.enterText(_field('Date (YYYY-MM-DD)'), '2026-02-31');
      await tester.tap(
        find.widgetWithText(LuzButton, 'Schedule interview').last,
      );
      await tester.pumpAndSettle();
      expect(find.text('Use YYYY-MM-DD'), findsOneWidget);
      expect(find.text('Add the meeting link (https://…)'), findsOneWidget);

      final next = DateTime.now().add(const Duration(days: 3));
      await tester.enterText(
        _field('Date (YYYY-MM-DD)'),
        '${next.year}-${next.month.toString().padLeft(2, '0')}-'
        '${next.day.toString().padLeft(2, '0')}',
      );
      await tester.enterText(
        _field('Meeting link'),
        'https://meet.example.com/x',
      );
      await tester.tap(
        find.widgetWithText(LuzButton, 'Schedule interview').last,
      );
      await tester.pumpAndSettle();
      expect(
        repo.interviewsList.single.meetingUrl,
        'https://meet.example.com/x',
      );
    });

    testWidgets('offers are made from the HR interview stage', (tester) async {
      final repo = FakeEmployerRepository()
        ..seedJob(count: 1, stage: ApplicationStage.hrInterview);
      await _pump(tester, repo, location: '/employer/pipeline');
      await _tap(tester, find.text('Candidate 2'));
      await _tap(tester, find.widgetWithText(LuzButton, 'Make offer'));
      await tester.enterText(_field('Salary'), '1800000');
      await tester.tap(find.text('Send offer'));
      await tester.pumpAndSettle();
      expect(repo.offersList.single.salary, 1800000);
      expect(repo.apps.single.stage, ApplicationStage.offerIssued);
    });

    testWidgets('viewers cannot move candidates', (tester) async {
      final repo = FakeEmployerRepository(role: MemberRole.viewer)
        ..seedJob(count: 1);
      await _pump(tester, repo, location: '/employer/pipeline');
      expect(find.textContaining('view-only access'), findsOneWidget);
      await _tap(tester, find.text('Candidate 2'));
      expect(find.text('Schedule interview'), findsNothing);
      expect(find.widgetWithText(LuzButton, 'Shortlisted'), findsNothing);
    });

    testWidgets('phones show the board and the panel without overflow', (
      tester,
    ) async {
      final repo = FakeEmployerRepository()..seedJob(count: 2);
      await _pump(tester, repo, location: '/employer/pipeline', width: 375);
      await _tap(tester, find.text('Candidate 2'));
      expect(find.text('Move to'.toUpperCase()), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Company & team', () {
    testWidgets('owner invites a teammate and requests verification', (
      tester,
    ) async {
      final repo = FakeEmployerRepository();
      await _pump(tester, repo, location: '/employer/company');

      await _tap(tester, find.text('Request verification'));
      expect(repo.companies.single.verification, Verification.pending);

      await tester.enterText(_field('Email'), 'not-an-email');
      await _tap(tester, find.text('Send invite'));
      expect(find.text('Enter a valid email'), findsOneWidget);

      await tester.enterText(_field('Email'), 'priya@example.com');
      await _tap(tester, find.text('Send invite'));
      expect(repo.invitesList.single.email, 'priya@example.com');
      expect(
        find.textContaining('priya@example.com · Recruiter'),
        findsOneWidget,
      );
    });
  });

  group('Company switcher', () {
    FakeEmployerRepository twoCompanies() => FakeEmployerRepository()
      ..companies.add(
        const Company(
          id: 'co-2',
          name: 'Orbit Works',
          slug: 'orbit-works',
          verification: Verification.verified,
        ),
      );

    testWidgets('is hidden for people in one company', (tester) async {
      await _pump(tester, FakeEmployerRepository(), location: '/employer');
      expect(find.byIcon(Icons.unfold_more), findsNothing);
    });

    for (final width in [1440.0, 800.0, 390.0]) {
      testWidgets('switches the whole workspace at ${width.toInt()} px', (
        tester,
      ) async {
        final router = await _pump(
          tester,
          twoCompanies(),
          location: '/employer',
          width: width,
        );
        // Phones: the switcher sits in the navigation drawer.
        if (width < 600) {
          await _tap(tester, find.byTooltip('Open navigation'));
        }
        expect(find.byIcon(Icons.unfold_more), findsOneWidget);

        await _tap(tester, find.byIcon(Icons.unfold_more));
        expect(find.text('Switch company'), findsOneWidget);
        await _tap(tester, find.text('Orbit Works · Owner'));
        expect(find.text('Switch company'), findsNothing);

        // Every page now shows the picked company.
        router.go('/employer/company');
        await tester.pumpAndSettle();
        expect(find.text('Orbit Works'), findsWidgets);
        expect(find.text('Nimbus Labs'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Analytics', () {
    testWidgets('shows real counts', (tester) async {
      final repo = FakeEmployerRepository()
        ..seedJob(count: 3)
        ..seedJob(title: 'Designer', count: 1, stage: ApplicationStage.hired);
      await _pump(tester, repo, location: '/employer/analytics');
      expect(find.text('Hiring funnel'), findsOneWidget);
      expect(find.text('12.5 days'), findsOneWidget);
      expect(find.text('4'), findsWidgets);
    });

    testWidgets('says so when there is no data', (tester) async {
      final repo = FakeEmployerRepository();
      await _pump(tester, repo, location: '/employer/analytics');
      expect(find.text('No data yet'), findsOneWidget);
    });
  });
}
