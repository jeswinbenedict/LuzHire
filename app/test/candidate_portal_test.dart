import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:luzhire/core/data/enums.dart';
import 'package:luzhire/core/data/models.dart';
import 'package:luzhire/core/theme/tokens.dart';
import 'package:luzhire/core/widgets/widgets.dart';
import 'package:luzhire/features/candidate/presentation/dashboard_page.dart'
    show dashboardSummary;

import 'support/candidate_fakes.dart';
import 'support/fakes.dart';
import 'support/job_fakes.dart';

Future<GoRouter> _pump(
  WidgetTester tester,
  CandidateFakes fakes, {
  required String location,
  double width = 1280,
}) => pumpLuzHire(
  tester,
  location: location,
  size: Size(width, 1000),
  gateway: FakeAuthGateway(signedIn: signedInAs(AppRole.candidate)),
  overrides: [...jobBoardOverrides(), ...fakes.overrides],
);

/// The TextField inside the LuzTextField labelled [label].
Finder _field(String label) => find.descendant(
  of: find.widgetWithText(LuzTextField, label),
  matching: find.byType(TextField),
);

Future<void> _tapVisible(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<String> _applyTo(CandidateFakes f, String jobId) async =>
    (await f.applications.apply(candidateId: 'candidate-1', jobId: jobId)).id;

void main() {
  group('Apply flow', () {
    testWidgets('candidate applies with their primary resume', (tester) async {
      final f = CandidateFakes();
      await f.resumes.upload('candidate-1', 'asha.pdf', Uint8List(10));
      await _pump(tester, f, location: '/jobs/job-1');

      await tester.tap(find.text('Apply now'));
      await tester.pumpAndSettle();
      expect(find.text('asha.pdf (primary)'), findsOneWidget);
      await tester.enterText(
        find.byType(TextField).last,
        'I build Flutter apps.',
      );
      await tester.tap(find.text('Send application'));
      await tester.pumpAndSettle();

      final app = f.applications.apps.single;
      expect(app.jobId, 'job-1');
      expect(app.resumeId, 'res-1');
      expect(app.coverLetter, 'I build Flutter apps.');
      expect(find.text('Application sent to Nimbus Labs'), findsOneWidget);
      expect(find.text('Applied · Applied'), findsOneWidget);
    });

    testWidgets('a database error is shown in the form', (tester) async {
      final f = CandidateFakes();
      await _applyTo(f, 'job-2'); // already applied, but the UI does not know
      f.applications.apps.clear();
      await _pump(tester, f, location: '/jobs/job-2');
      f.applications.apps.add(
        JobApplication(
          id: 'x',
          jobId: 'job-2',
          candidateId: 'candidate-1',
          stage: ApplicationStage.applied,
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
      );
      await tester.tap(find.text('Apply now'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send application'));
      await tester.pumpAndSettle();
      expect(find.textContaining('already applied'), findsOneWidget);
    });
  });

  group('Application tracker', () {
    testWidgets('employer stage changes appear live', (tester) async {
      final f = CandidateFakes();
      final id = await _applyTo(f, 'job-1');
      await _pump(tester, f, location: '/me/applications/$id');
      expect(find.text('Flutter Developer 1'), findsOneWidget);
      expect(find.text('Applied'), findsWidgets);

      f.applications.setStage(id, ApplicationStage.shortlisted);
      await tester.pumpAndSettle();
      expect(find.text('Shortlisted'), findsOneWidget);
      expect(find.text('Moved to Shortlisted'), findsOneWidget);
    });

    testWidgets('lists applications with filters at phone width', (
      tester,
    ) async {
      final f = CandidateFakes();
      await _applyTo(f, 'job-1');
      final closed = await _applyTo(f, 'job-2');
      f.applications.setStage(closed, ApplicationStage.rejected);
      await _pump(tester, f, location: '/me/applications', width: 375);
      expect(find.text('Flutter Developer 1'), findsOneWidget);
      expect(find.text('Flutter Developer 2'), findsOneWidget);

      await _tapVisible(tester, find.text('Closed (1)'));
      expect(find.text('Flutter Developer 1'), findsNothing);
      expect(find.text('Flutter Developer 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('candidate can withdraw after confirming', (tester) async {
      final f = CandidateFakes();
      final id = await _applyTo(f, 'job-1');
      await _pump(tester, f, location: '/me/applications/$id');
      await tester.scrollUntilVisible(
        find.text('Withdraw application'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Withdraw application'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Withdraw').last);
      await tester.pumpAndSettle();
      expect(f.applications.apps.single.stage, ApplicationStage.withdrawn);
      expect(find.text('Withdraw application'), findsNothing);
    });

    testWidgets('accepting an offer marks the application hired', (
      tester,
    ) async {
      final f = CandidateFakes();
      final id = await _applyTo(f, 'job-1');
      f.applications.setStage(id, ApplicationStage.offerIssued);
      f.applications.offerList.add(
        Offer(
          id: 'off-1',
          applicationId: id,
          status: OfferStatus.issued,
          salary: 1800000,
          currency: 'INR',
          salaryPeriod: SalaryPeriod.year,
        ),
      );
      await _pump(tester, f, location: '/me/applications/$id');
      expect(find.text('₹18 L / year'), findsOneWidget);
      await tester.tap(find.text('Accept offer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Accept offer').last);
      await tester.pumpAndSettle();
      expect(f.applications.offerList.single.status, OfferStatus.accepted);
      expect(f.applications.apps.single.stage, ApplicationStage.hired);
      expect(find.text('Hired'), findsWidgets);
    });
  });

  group('Interviews', () {
    testWidgets('shows upcoming interviews with calendar links', (
      tester,
    ) async {
      final f = CandidateFakes();
      final id = await _applyTo(f, 'job-1');
      f.applications.interviewList.add(
        Interview(
          id: 'int-1',
          applicationId: id,
          jobId: 'job-1',
          scheduledAt: DateTime.now().add(const Duration(days: 2)),
          durationMin: 45,
          mode: InterviewMode.video,
          status: InterviewStatus.scheduled,
          meetingUrl: 'https://meet.example.com/abc',
        ),
      );
      await _pump(tester, f, location: '/me/interviews', width: 375);
      expect(find.text('Video call'), findsOneWidget);
      expect(find.text('Join meeting'), findsOneWidget);
      expect(find.text('Add to calendar'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Profile', () {
    testWidgets('saving basics raises completion', (tester) async {
      final f = CandidateFakes();
      await _pump(tester, f, location: '/me/profile');
      expect(find.textContaining('Add a headline'), findsOneWidget);

      await tester.enterText(_field('Headline'), 'Flutter developer');
      await _tapVisible(tester, find.text('Save profile'));
      expect(f.profile.profile.headline, 'Flutter developer');
      expect(find.textContaining('Add a headline'), findsNothing);
      expect(find.text('Profile saved'), findsOneWidget);
    });

    testWidgets('rejects an empty name and bad links', (tester) async {
      final f = CandidateFakes();
      await _pump(tester, f, location: '/me/profile');
      await tester.enterText(_field('Full name'), '');
      await tester.enterText(_field('GitHub'), 'github.com/asha');
      await _tapVisible(tester, find.text('Save profile'));
      expect(find.text('Enter your name'), findsOneWidget);
      expect(find.text('Start with https://'), findsOneWidget);
      expect(f.profile.profile.displayName, 'Asha Verma');
    });

    testWidgets('adds skills and experience', (tester) async {
      final f = CandidateFakes();
      await _pump(tester, f, location: '/me/profile', width: 1440);

      await tester.tap(find.text('Flutter').first); // suggestion chip
      await tester.pumpAndSettle();
      expect(f.profile.skillList.map((s) => s.name), ['Flutter']);

      await _tapVisible(tester, find.text('Add').first);
      await tester.enterText(_field('Job title'), 'Intern');
      await tester.enterText(_field('Company'), 'Orbit Works');
      await tester.enterText(_field('Start (YYYY-MM)'), '2025-13');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Use YYYY-MM'), findsOneWidget);

      await tester.enterText(_field('Start (YYYY-MM)'), '2025-05');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(f.profile.experienceList.single.title, 'Intern');
      expect(find.text('Orbit Works'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('dashboard shows real counts and notifications', (tester) async {
    final f = CandidateFakes();
    await _applyTo(f, 'job-1');
    f.notifications.push(
      AppNotification(
        id: 'n1',
        type: 'application.submitted',
        title: 'Application sent',
        body: 'Your application for Flutter Developer 1 was submitted.',
        createdAt: DateTime.now(),
      ),
    );
    final semantics = tester.ensureSemantics();
    await _pump(tester, f, location: '/me', width: 375);
    expect(find.textContaining('Asha'), findsWidgets);
    expect(
      find.bySemanticsLabel(RegExp('Active applications: 1')),
      findsOneWidget,
    );
    semantics.dispose();
    expect(find.text('Notifications (1 new)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('Dashboard', () {
    CandidateFakes newCandidate() => CandidateFakes()
      ..profile.profile = const Profile(
        id: 'candidate-1',
        role: AppRole.candidate,
        email: 'candidate@example.com',
        displayName: 'JESWIN BENEDICT',
      );

    testWidgets('a new candidate gets a greeting, steps and empty states', (
      tester,
    ) async {
      final router = await _pump(
        tester,
        newCandidate(),
        location: '/me',
        width: 1440,
      );
      expect(find.textContaining(', Jeswin'), findsOneWidget);
      expect(find.textContaining('JESWIN'), findsNothing);
      expect(find.text('No applications yet'), findsOneWidget);
      expect(find.text('No interviews scheduled'), findsOneWidget);
      expect(find.text('Finish your profile'), findsOneWidget);
      expect(find.text('0% complete'), findsOneWidget);
      // Most useful first, four at a time, the rest counted.
      expect(find.text('Upload a resume'), findsOneWidget);
      expect(find.text('Add 3 more skills'), findsOneWidget);
      expect(find.text('6 more on your profile page'), findsOneWidget);
      expect(find.text('+10%'), findsNWidgets(4));
      expect(find.text('Recommended for you'), findsOneWidget);

      await _tapVisible(tester, find.text('Add a headline'));
      expect(router.state.uri.path, '/me/profile');
    });

    testWidgets('steps disappear as the profile fills in', (tester) async {
      final f = newCandidate();
      await f.resumes.upload('candidate-1', 'cv.pdf', Uint8List(10));
      for (final s in ['Dart', 'Flutter', 'SQL']) {
        await f.profile.addSkill('candidate-1', s);
      }
      await _pump(tester, f, location: '/me', width: 1440);
      expect(find.text('Upload a resume'), findsNothing);
      expect(find.textContaining('more skill'), findsNothing);
      expect(find.text('Add a headline'), findsOneWidget);
      expect(find.text('20% complete'), findsOneWidget);
    });

    testWidgets('lines up with the title and tabs above it', (tester) async {
      await _pump(tester, newCandidate(), location: '/me', width: 1440);
      final welcome = find
          .ancestor(
            of: find.textContaining(', Jeswin'),
            matching: find.byType(LuzCard),
          )
          .first;
      expect(
        tester.getTopLeft(welcome).dx,
        tester.getTopLeft(find.text('My LuzHire')).dx,
      );
      // The page scrolls full width: its scrollbar sits at the window edge.
      final scroll = find
          .ancestor(of: welcome, matching: find.byType(Scrollable))
          .first;
      expect(tester.getTopRight(scroll).dx, 1440);
    });

    testWidgets('phone tiles give the label a line of its own', (tester) async {
      await _pump(tester, newCandidate(), location: '/me', width: 375);
      for (final label in [
        'Active applications',
        'Upcoming interviews',
        'Saved jobs',
        'Offers to answer',
      ]) {
        final tile = find.byWidgetPredicate(
          (w) => w is LuzPressable && w.semanticLabel == '$label: 0',
        );
        final text = find.descendant(of: tile, matching: find.text(label));
        // At the tile's inner edge (16 px padding), not beside the icon,
        // and allowed two lines instead of being cut short.
        expect(
          tester.getTopLeft(text).dx - tester.getTopLeft(tile).dx,
          LuzSpace.md,
          reason: label,
        );
        expect(tester.widget<Text>(text).maxLines, 2, reason: label);
      }
      expect(tester.takeException(), isNull);
    });

    test('the summary line names the most urgent thing', () {
      expect(
        dashboardSummary(offers: 1, interviews: 2, active: 3),
        'You have 1 offer waiting for your answer.',
      );
      expect(
        dashboardSummary(offers: 0, interviews: 2, active: 3),
        'You have 2 interviews coming up. Good luck!',
      );
      expect(
        dashboardSummary(offers: 0, interviews: 0, active: 1),
        startsWith('1 application in progress.'),
      );
      expect(
        dashboardSummary(offers: 0, interviews: 0, active: 0),
        startsWith('Apply to a few roles'),
      );
    });
  });

  group('Command menu', () {
    Future<List<String>> menuItems(WidgetTester tester, AppRole? role) async {
      await pumpLuzHire(
        tester,
        gateway: FakeAuthGateway(
          signedIn: role == null ? null : signedInAs(role),
        ),
        overrides: [...jobBoardOverrides(), ...CandidateFakes().overrides],
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      final dialog = find.ancestor(
        of: find.text('Go to…'),
        matching: find.byType(LuzDialog),
      );
      return [
        for (final t in tester.widgetList<Text>(
          find.descendant(of: dialog, matching: find.byType(Text)),
        ))
          t.data ?? '',
      ];
    }

    testWidgets('visitors only see public pages', (tester) async {
      final items = await menuItems(tester, null);
      expect(items, containsAll(['Jobs', 'Companies']));
      expect(items, isNot(contains('Pipeline')));
      expect(items, isNot(contains('Profile & resume')));
      expect(items, isNot(contains('My LuzHire')));
    });

    testWidgets('candidates see their portal but not the workspace', (
      tester,
    ) async {
      final items = await menuItems(tester, AppRole.candidate);
      expect(items, contains('Profile & resume'));
      expect(items, isNot(contains('Pipeline')));
    });

    testWidgets('employers see the workspace but not the candidate portal', (
      tester,
    ) async {
      final items = await menuItems(tester, AppRole.employer);
      expect(items, contains('Pipeline'));
      expect(items, isNot(contains('Profile & resume')));
      expect(items, isNot(contains('My LuzHire')));
    });
  });
}
