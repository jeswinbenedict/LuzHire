import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:luzhire/core/data/enums.dart';
import 'package:luzhire/core/data/models.dart';
import 'package:luzhire/core/widgets/widgets.dart';
import 'package:luzhire/features/events/presentation/events_pages.dart';

import 'support/admin_fakes.dart';
import 'support/candidate_fakes.dart';
import 'support/employer_fakes.dart';
import 'support/event_fakes.dart';
import 'support/fakes.dart';
import 'support/job_fakes.dart';

Future<GoRouter> _pump(
  WidgetTester tester, {
  required String location,
  double width = 1280,
  FakeEventsRepository? events,
  AppRole? signedIn,
}) => pumpLuzHire(
  tester,
  location: location,
  size: Size(width, 1000),
  gateway: FakeAuthGateway(
    signedIn: signedIn == null ? null : signedInAs(signedIn),
  ),
  overrides: [
    ...jobBoardOverrides(),
    ...eventOverrides(events),
    ...CandidateFakes().overrides,
    ...employerOverrides(FakeEmployerRepository(verified: true)),
    ...adminOverrides(FakeAdminRepository()),
  ],
);

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

void main() {
  test('imported events with no deadline say when they run', () {
    Opportunity hackathon(String start, String end) => Opportunity.fromJson({
      'id': 'h',
      'slug': 'h',
      'kind': 'hackathon',
      'status': 'published',
      'title': 'Founding-100',
      'organizer_name': 'Founding-100',
      'mode': 'online',
      'starts_at': start,
      'ends_at': end,
      'registration_url': 'https://founding.example',
      'external_source': 'hackclub',
    });
    final now = DateTime.utc(2026, 10, 26, 12);
    final running = hackathon('2026-10-22T18:00:00Z', '2026-10-31T18:00:00Z');
    expect(registrationState(running, now).label, 'Happening now');
    expect(registrationState(running, now).open, isTrue);
    final later = hackathon('2026-11-08T10:00:00Z', '2026-11-09T10:00:00Z');
    expect(registrationState(later, now).label, 'Starts in 12 days');
    final over = hackathon('2026-10-01T10:00:00Z', '2026-10-02T10:00:00Z');
    expect(registrationState(over, now).label, 'Ended');
  });

  group('/events', () {
    for (final width in [360.0, 1440.0]) {
      testWidgets('lists opportunities at ${width.toInt()} px', (tester) async {
        await _pump(tester, location: '/events', width: width);
        expect(
          find.text('Hiring drives, hackathons and competitions'),
          findsOneWidget,
        );
        expect(find.text('Event walk-in'), findsOneWidget);
        expect(find.text('Event hack'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('tabs filter by type and live in the URL', (tester) async {
      final router = await _pump(tester, location: '/events');
      await tester.tap(find.text('Hackathons'));
      await tester.pumpAndSettle();
      expect(router.state.uri.toString(), '/events?type=hackathons');
      expect(find.text('Event hack'), findsOneWidget);
      expect(find.text('Event walk-in'), findsNothing);
      expect(find.text('₹1,00,000 prize pool'), findsOneWidget);
    });

    testWidgets('cards show the registration deadline', (tester) async {
      await _pump(tester, location: '/events?type=webinars');
      expect(find.text('Registration closed'), findsOneWidget);
    });

    testWidgets('visitors are asked to sign in to register', (tester) async {
      final router = await _pump(tester, location: '/events/walk-in');
      expect(find.text('Nimbus campus, Bengaluru'), findsOneWidget);
      expect(find.text('Aptitude test'), findsOneWidget);
      await _tapVisible(tester, find.text('Sign in to register'));
      expect(router.state.uri.path, '/sign-in');
      expect(router.state.uri.queryParameters['from'], '/events/walk-in');
    });

    testWidgets('candidates register and can cancel', (tester) async {
      final events = FakeEventsRepository();
      await _pump(
        tester,
        location: '/events/walk-in',
        events: events,
        signedIn: AppRole.candidate,
      );
      await _tapVisible(tester, find.text('Register'));
      expect(events.registrations, {'ev-walk-in': null});
      expect(find.text("You're registered"), findsWidgets);

      await _tapVisible(tester, find.text('Cancel my registration'));
      await tester.tap(find.text('Cancel registration'));
      await tester.pumpAndSettle();
      expect(events.registrations, isEmpty);
    });

    testWidgets('teams register with a team name', (tester) async {
      final events = FakeEventsRepository();
      await _pump(
        tester,
        location: '/events/hack',
        events: events,
        signedIn: AppRole.candidate,
        width: 1440,
      );
      expect(find.text('2–4 people'), findsOneWidget);
      await _tapVisible(tester, find.text('Register'));
      await tester.tap(find.text('Register team'));
      await tester.pumpAndSettle();
      expect(find.text('Give your team a name'), findsOneWidget);
      await tester.enterText(_field('Team name'), 'Null Pointers');
      await tester.tap(find.text('Register team'));
      await tester.pumpAndSettle();
      expect(events.registrations, {'ev-hack': 'Null Pointers'});
      expect(find.text('Registered as team Null Pointers'), findsOneWidget);
    });

    testWidgets('external events send candidates to the organiser', (
      tester,
    ) async {
      await _pump(
        tester,
        location: '/events/contest',
        signedIn: AppRole.candidate,
      );
      expect(find.text("Register on the organiser's site"), findsOneWidget);
      expect(find.text('Register'), findsNothing);
    });

    testWidgets('an empty tab shows what is coming up instead', (tester) async {
      final events = FakeEventsRepository([
        fakeEvent('hack', kind: EventKind.hackathon, mode: EventMode.online),
        fakeEvent(
          'contest',
          kind: EventKind.competition,
          mode: EventMode.online,
          registrationUrl: 'https://example.com/contest',
        ),
      ]);
      final router = await _pump(
        tester,
        location: '/events?type=hiring',
        events: events,
      );
      expect(find.text('No hiring drives listed right now'), findsOneWidget);
      expect(find.text('Coming up on LuzHire'), findsOneWidget);
      expect(find.text('Hiring? Post on LuzHire'), findsOneWidget);
      await _tapVisible(tester, find.text('1 hackathon'));
      expect(router.state.uri.queryParameters['type'], 'hackathons');
    });

    testWidgets('employers can post the missing kind of event', (tester) async {
      final events = FakeEventsRepository([
        fakeEvent('hack', kind: EventKind.hackathon, mode: EventMode.online),
      ]);
      final router = await _pump(
        tester,
        location: '/events?type=webinars',
        events: events,
        signedIn: AppRole.employer,
      );
      expect(find.text('No webinars listed right now'), findsOneWidget);
      await _tapVisible(tester, find.text('Post a webinar'));
      expect(router.state.uri.path, '/employer/events/new');
      expect(router.state.uri.queryParameters['kind'], 'webinar');
    });

    testWidgets('home shows upcoming opportunities', (tester) async {
      await _pump(tester, location: '/');
      expect(find.text('Drives and contests coming up'), findsOneWidget);
      expect(find.byType(EventCard), findsNWidgets(3));
    });
  });

  group('Organisers', () {
    testWidgets('employers post a walk-in drive', (tester) async {
      final events = FakeEventsRepository([]);
      final router = await _pump(
        tester,
        location: '/employer/events',
        events: events,
        signedIn: AppRole.employer,
        width: 1440,
      );
      expect(find.text('No events yet'), findsOneWidget);
      await tester.tap(find.text('New event').first);
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/employer/events/new');

      await _tapVisible(tester, find.text('Publish'));
      expect(find.text('Use at least 4 characters'), findsOneWidget);
      expect(find.text('Say which city it is in'), findsOneWidget);
      expect(events.saved, isEmpty);

      await tester.enterText(_field('Title'), 'Walk-in for Flutter devs');
      await tester.enterText(_field('City'), 'Pune');
      await tester.enterText(_field('Starts'), '2030-01-15 10:00');
      await tester.enterText(_field('Places (optional)'), '50');
      await _tapVisible(tester, find.text('Publish'));
      final (draft, companyId, status) = events.saved.single;
      expect(draft.title, 'Walk-in for Flutter devs');
      expect(draft.location, 'Pune');
      expect(draft.capacity, 50);
      expect(draft.startsAt, DateTime(2030, 1, 15, 10));
      expect(companyId, 'co-1');
      expect(status, EventStatus.published);
      expect(router.state.uri.path, '/employer/events');
      expect(find.text('Walk-in for Flutter devs'), findsOneWidget);
    });

    testWidgets('employers see who registered', (tester) async {
      await _pump(
        tester,
        location: '/employer/events',
        signedIn: AppRole.employer,
        width: 1440,
      );
      await tester.tap(find.text('Registrations').first);
      await tester.pumpAndSettle();
      expect(find.text('Asha Rao'), findsOneWidget);
      expect(find.text('Copy all emails'), findsOneWidget);
    });

    testWidgets('admins publish events waiting for review', (tester) async {
      final events = FakeEventsRepository([
        fakeEvent('pending', status: EventStatus.pendingReview),
      ]);
      await _pump(
        tester,
        location: '/admin/events',
        events: events,
        signedIn: AppRole.admin,
        width: 1440,
      );
      expect(find.text('Event pending'), findsOneWidget);
      await tester.tap(find.text('Publish'));
      await tester.pumpAndSettle();
      expect(events.statusChanges, [('ev-pending', EventStatus.published)]);
    });
  });

  testWidgets('phones keep five tabs and move News to the menu', (
    tester,
  ) async {
    final router = await _pump(tester, location: '/', width: 375);
    expect(find.text('Events'), findsOneWidget);
    expect(find.text('News'), findsNothing);
    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('News'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/news');
  });
}
