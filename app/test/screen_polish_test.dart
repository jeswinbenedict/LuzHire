// Layout details found in the visual review of the workspace and detail
// screens (docs/ROADMAP.md, Phase 11): each was visible in a screenshot.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luzhire/core/data/enums.dart';
import 'package:luzhire/core/theme/app_theme.dart';
import 'package:luzhire/core/theme/tokens.dart';
import 'package:luzhire/core/widgets/widgets.dart';

import 'support/admin_fakes.dart';
import 'support/candidate_fakes.dart';
import 'support/employer_fakes.dart';
import 'support/fakes.dart';
import 'support/job_fakes.dart';

Future<void> _pump(
  WidgetTester tester, {
  required String location,
  AppRole? role,
  double width = 1440,
  FakeEmployerRepository? employer,
}) {
  final admin = FakeAdminRepository();
  return pumpLuzHire(
    tester,
    location: location,
    size: Size(width, 1000),
    gateway: FakeAuthGateway(signedIn: role == null ? null : signedInAs(role)),
    overrides: [
      ...jobBoardOverrides(),
      ...CandidateFakes().overrides,
      ...employerOverrides(employer ?? FakeEmployerRepository()),
      ...adminOverrides(admin, FakeGovernanceRepository(admin)),
    ],
  );
}

Widget _app(Widget child, {double width = 800}) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(
    body: Center(
      child: SizedBox(width: width, child: child),
    ),
  ),
);

void main() {
  testWidgets('table columns keep a gap: a count never runs into a date', (
    tester,
  ) async {
    final employer = FakeEmployerRepository(verified: true)
      ..seedJob(title: 'Flutter Developer', count: 3);
    await _pump(
      tester,
      location: '/employer/jobs',
      role: AppRole.employer,
      employer: employer,
    );
    final count = tester.getRect(find.text('3'));
    final date = tester.getRect(find.text('19 Oct 2026'));
    expect(date.left - count.right, greaterThanOrEqualTo(LuzSpace.md));
  });

  testWidgets('the weekly chart always shows the last 12 weeks', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        LuzWeekBars(
          weeks: [(week: DateTime(2026, 10, 12), count: 5)],
          unit: 'sign-ups',
          now: DateTime(2026, 10, 27),
        ),
      ),
    );
    expect(find.bySemanticsLabel(RegExp(r'^Week of ')), findsNWidgets(12));
    expect(find.bySemanticsLabel('Week of 12 Oct: 5 sign-ups'), findsOneWidget);
    expect(find.bySemanticsLabel('Week of 26 Oct: 0 sign-ups'), findsOneWidget);
    expect(find.bySemanticsLabel('Week of 10 Aug: 0 sign-ups'), findsOneWidget);
    // One busy week is one bar of twelve, not the width of the card.
    final bar = tester.getSize(find.text('5'));
    expect(bar.width, lessThan(800 / 6));
    semantics.dispose();
  });

  testWidgets('stat strips spread figures and keep words in plain type', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const LuzStatStrip(
          stats: [
            (label: 'Applications', value: '6'),
            (label: 'Average time to hire', value: 'No hires yet'),
            (label: 'Published jobs', value: '3'),
            (label: 'Awaiting review', value: '0'),
          ],
        ),
      ),
    );
    // Evenly spread: the last figure starts in the last quarter.
    expect(
      tester.getTopLeft(find.text('Awaiting review')).dx,
      greaterThan(tester.getTopLeft(find.byType(LuzStatStrip)).dx + 600),
    );
    expect(tester.widget<Text>(find.text('6')).style?.fontFamily, isNotNull);
    expect(
      tester.widget<Text>(find.text('No hires yet')).style?.fontFamily,
      isNot(tester.widget<Text>(find.text('6')).style?.fontFamily),
    );
  });

  testWidgets('tab controls are as wide as their options', (tester) async {
    await tester.pumpWidget(
      _app(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LuzSegmented<int>(
              segments: const [
                (value: 1, label: 'Articles', icon: null),
                (value: 2, label: 'Headlines', icon: null),
              ],
              selected: 1,
              onChanged: (_) {},
            ),
          ],
        ),
      ),
    );
    final track = tester.getSize(find.byType(LuzSurface).first);
    expect(track.width, lessThan(400));
  });

  testWidgets('phones: the job page shows the salary', (tester) async {
    await _pump(tester, location: '/jobs/job-1', width: 390);
    final row = find.ancestor(
      of: find.text('Salary'),
      matching: find.byType(Row),
    );
    expect(
      find.descendant(of: row.first, matching: find.text('₹12–18 L / year')),
      findsOneWidget,
    );
  });

  testWidgets('phones: the workspace title has room; theme is in the drawer', (
    tester,
  ) async {
    await _pump(
      tester,
      location: '/employer/pipeline',
      role: AppRole.employer,
      width: 390,
    );
    expect(find.byTooltip('Switch to dark theme'), findsNothing);
    // Room for a page title: 126 px here, 78 px while the theme button
    // took 48 px of it ("Pipeline" needs about 95 px).
    expect(tester.getSize(find.text('Pipeline').first).width, greaterThan(110));
    await tester.tap(find.byTooltip('Open navigation'));
    await tester.pumpAndSettle();
    expect(find.text('Dark'), findsOneWidget);
  });

  testWidgets('admin users show roles as words', (tester) async {
    await _pump(tester, location: '/admin/users', role: AppRole.admin);
    expect(find.text('Candidate'), findsOneWidget);
    expect(find.text('candidate'), findsNothing);
  });
}
