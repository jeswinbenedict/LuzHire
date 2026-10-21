import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:luzhire/core/data/enums.dart';
import 'package:luzhire/core/data/failures.dart';
import 'package:luzhire/core/data/models.dart';
import 'package:luzhire/features/events/data/events_repository.dart';

final _soon = DateTime.now().add(const Duration(days: 5));

Opportunity fakeEvent(
  String slug, {
  EventKind kind = EventKind.walkIn,
  EventMode mode = EventMode.inPerson,
  EventStatus status = EventStatus.published,
  DateTime? startsAt,
  int teamMin = 1,
  int teamMax = 1,
  String? registrationUrl,
  String? companyId = 'co-1',
  int registrationCount = 12,
  int? capacity,
}) => Opportunity(
  id: 'ev-$slug',
  slug: slug,
  kind: kind,
  status: status,
  title: 'Event $slug',
  organizerName: 'Nimbus Labs',
  mode: mode,
  startsAt: startsAt ?? _soon,
  summary: 'Summary of $slug.',
  descriptionMd: '## Agenda\n- Aptitude test\n- Interviews',
  companyId: companyId,
  location: mode == EventMode.online ? null : 'Bengaluru',
  venue: mode == EventMode.online ? null : 'Nimbus campus',
  registrationUrl: registrationUrl,
  eligibility: 'Final-year students',
  prize: kind == EventKind.hackathon ? '₹1,00,000 prize pool' : null,
  teamMin: teamMin,
  teamMax: teamMax,
  registrationCount: registrationCount,
  capacity: capacity,
);

/// A walk-in, a team hackathon, an external competition and a webinar
/// that has already started.
List<Opportunity> fakeEvents() => [
  fakeEvent('walk-in'),
  fakeEvent(
    'hack',
    kind: EventKind.hackathon,
    mode: EventMode.online,
    teamMin: 2,
    teamMax: 4,
  ),
  fakeEvent(
    'contest',
    kind: EventKind.competition,
    mode: EventMode.online,
    registrationUrl: 'https://example.com/contest',
  ),
  fakeEvent(
    'started',
    kind: EventKind.webinar,
    mode: EventMode.online,
    startsAt: DateTime.now().subtract(const Duration(hours: 1)),
  ),
];

/// In-memory events with registrations, like public.events.
class FakeEventsRepository implements EventsRepository {
  FakeEventsRepository([List<Opportunity>? events])
    : events = events ?? fakeEvents();
  final List<Opportunity> events;
  final registrations = <String, String?>{};
  final saved = <(EventDraft, String?, EventStatus)>[];
  final statusChanges = <(String, EventStatus)>[];

  @override
  Future<List<Opportunity>> upcoming(
    EventQuery q, {
    int offset = 0,
    int limit = 12,
  }) async =>
      events
          .where(
            (e) =>
                e.status == EventStatus.published &&
                (q.kinds.isEmpty || q.kinds.contains(e.kind)) &&
                (q.mode == null || q.mode == e.mode),
          )
          .skip(offset)
          .take(limit)
          .toList()
        ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

  @override
  Future<Opportunity?> bySlug(String slug) async =>
      events.where((e) => e.slug == slug).firstOrNull;

  @override
  Future<Opportunity?> byId(String id) async =>
      events.where((e) => e.id == id).firstOrNull;

  @override
  Future<Map<String, String?>> myRegistrations(String uid) async => {
    ...registrations,
  };

  @override
  Future<void> register(String eventId, String uid, {String? teamName}) async {
    final e = events.firstWhere((e) => e.id == eventId);
    if (e.isTeamEvent && teamName == null) {
      throw const AppFailure('Give your team a name', code: '23514');
    }
    registrations[eventId] = teamName;
  }

  @override
  Future<void> withdraw(String eventId, String uid) async =>
      registrations.remove(eventId);

  @override
  Future<List<Opportunity>> companyEvents(String companyId) async =>
      events.where((e) => e.companyId == companyId).toList();

  @override
  Future<List<Opportunity>> all() async => events;

  @override
  Future<Opportunity> save(
    EventDraft d, {
    String? companyId,
    required EventStatus status,
  }) async {
    saved.add((d, companyId, status));
    final e = Opportunity(
      id: d.id ?? 'ev-new-${saved.length}',
      slug: 'new-${saved.length}',
      kind: d.kind,
      status: status,
      title: d.title.trim(),
      organizerName: 'Nimbus Labs',
      mode: d.mode,
      startsAt: d.startsAt,
      companyId: companyId,
      location: d.location,
    );
    events
      ..removeWhere((x) => x.id == e.id)
      ..insert(0, e);
    return e;
  }

  @override
  Future<void> setStatus(String id, EventStatus status) async =>
      statusChanges.add((id, status));

  @override
  Future<void> delete(String id) async => events.removeWhere((e) => e.id == id);

  @override
  Future<List<EventRegistrant>> registrants(String eventId) async => [
    EventRegistrant(
      userId: 'candidate-1',
      name: 'Asha Rao',
      email: 'asha@example.com',
      registeredAt: DateTime.utc(2026, 10, 20),
      headline: 'Flutter developer',
    ),
  ];
}

List<Override> eventOverrides([FakeEventsRepository? repo]) => [
  eventsRepositoryProvider.overrideWithValue(repo ?? FakeEventsRepository()),
];
