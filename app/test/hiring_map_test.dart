import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:luzhire/core/data/enums.dart';
import 'package:luzhire/core/data/failures.dart';
import 'package:luzhire/features/jobs/application/location_providers.dart';

import 'support/candidate_fakes.dart';
import 'support/fakes.dart';
import 'support/job_fakes.dart';

Future<GoRouter> _pump(
  WidgetTester tester, {
  required String location,
  double width = 1280,
  FakeJobsRepository? jobs,
  FakeLocationService? device,
  AppRole? signedIn,
}) => pumpLuzHire(
  tester,
  location: location,
  size: Size(width, 1000),
  gateway: FakeAuthGateway(
    signedIn: signedIn == null ? null : signedInAs(signedIn),
  ),
  overrides: [
    ...jobBoardOverrides(jobs: jobs),
    if (signedIn == AppRole.candidate) ...CandidateFakes().overrides,
    locationServiceProvider.overrideWithValue(device ?? FakeLocationService()),
    // No network in tests: draw the map without tiles.
    mapTileUrlProvider.overrideWithValue((_) => null),
  ],
);

void main() {
  group('Hiring map', () {
    for (final width in [375.0, 1440.0]) {
      testWidgets('ranks hiring cities at ${width.toInt()} px', (tester) async {
        await _pump(tester, location: '/jobs/map', width: width);
        expect(find.text('Where hiring is happening'), findsOneWidget);
        expect(find.textContaining('4 open roles in 2 cities'), findsOneWidget);
        expect(find.text('Pune, Maharashtra'), findsOneWidget);
        expect(find.bySemanticsLabel('Pune: 3 open roles'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a city lists its jobs', (tester) async {
      final jobs = FakeJobsRepository();
      await _pump(tester, location: '/jobs/map', jobs: jobs, width: 1440);
      await tester.tap(find.text('Pune, Maharashtra'));
      await tester.pumpAndSettle();
      expect(find.text('Jobs in Pune'), findsOneWidget);
      expect(find.text('Flutter Developer 1'), findsOneWidget);
      expect(jobs.nearCalls.single.radiusKm, 25);
    });

    testWidgets('jobs near me, with a wider radius on request', (tester) async {
      final jobs = FakeJobsRepository();
      await _pump(tester, location: '/jobs/map', jobs: jobs, width: 1440);
      await tester.tap(find.text('Jobs near me'));
      await tester.pumpAndSettle();
      expect(find.text('Within 50 km of you'), findsOneWidget);
      expect(find.text('4 km away'), findsOneWidget);
      expect(find.text('30 km away'), findsOneWidget);
      expect(jobs.nearCalls.last.latitude, 18.6);

      await tester.tap(find.text('25 km'));
      await tester.pumpAndSettle();
      expect(find.text('Within 25 km of you'), findsOneWidget);
      expect(find.text('30 km away'), findsNothing);
    });

    testWidgets('a refused location explains what to do', (tester) async {
      await _pump(
        tester,
        location: '/jobs/map',
        device: FakeLocationService(
          failure: const AppFailure(
            'LuzHire may not use your location.',
            code: 'location_denied',
          ),
        ),
      );
      await tester.tap(find.text('Jobs near me'));
      await tester.pump();
      expect(find.text('LuzHire may not use your location.'), findsOneWidget);
      expect(find.text('Top hiring cities'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('without city-based jobs it points to remote ones', (
      tester,
    ) async {
      final jobs = FakeJobsRepository()..locations = const [];
      final router = await _pump(tester, location: '/jobs/map', jobs: jobs);
      expect(find.text('No city-based jobs yet'), findsOneWidget);
      await tester.tap(find.text('Browse remote jobs'));
      await tester.pumpAndSettle();
      expect(router.state.uri.toString(), '/jobs?remote=1');
    });

    testWidgets('the job board links to the map', (tester) async {
      final router = await _pump(tester, location: '/jobs');
      await tester.tap(find.text('Map'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/jobs/map');
    });
  });

  group('Picked for you', () {
    testWidgets('candidates see jobs matched to their profile, with why', (
      tester,
    ) async {
      await _pump(tester, location: '/', signedIn: AppRole.candidate);
      expect(find.text('Recommended from your profile'), findsOneWidget);
      expect(find.text('Matches 2 of your skills'), findsNWidgets(3));
    });

    testWidgets('visitors do not', (tester) async {
      await _pump(tester, location: '/');
      expect(find.text('Recommended from your profile'), findsNothing);
      expect(find.text('Where is hiring happening?'), findsOneWidget);
    });
  });
}
