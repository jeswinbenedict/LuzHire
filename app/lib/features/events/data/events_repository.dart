import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/enums.dart';
import '../../../core/data/failures.dart';
import '../../../core/data/models.dart';
import '../../../core/data/supabase_providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../jobs/data/jobs_repository.dart' show notConfigured;

/// Which opportunities to list on /events.
@immutable
class EventQuery {
  const EventQuery({this.kinds = const {}, this.mode, this.cityId});

  /// Empty: every kind.
  final Set<EventKind> kinds;
  final EventMode? mode;

  /// Events in one city (from the hiring map).
  final int? cityId;

  @override
  bool operator ==(Object other) =>
      other is EventQuery &&
      setEquals(other.kinds, kinds) &&
      other.mode == mode &&
      other.cityId == cityId;

  @override
  int get hashCode => Object.hash(Object.hashAllUnordered(kinds), mode, cityId);
}

/// Everything an organiser fills in; [toRow] is what is written.
class EventDraft {
  EventDraft({
    this.id,
    this.kind = EventKind.walkIn,
    this.title = '',
    this.summary = '',
    this.descriptionMd = '',
    this.mode = EventMode.inPerson,
    this.venue = '',
    this.location = '',
    DateTime? startsAt,
    this.endsAt,
    this.registrationDeadline,
    this.registrationUrl = '',
    this.eligibility = '',
    this.prize = '',
    this.teamMin = 1,
    this.teamMax = 1,
    this.capacity,
    this.organizerName = '',
  }) : startsAt = startsAt ?? DateTime.now().add(const Duration(days: 7));

  factory EventDraft.from(Opportunity e) => EventDraft(
    id: e.id,
    kind: e.kind,
    title: e.title,
    summary: e.summary ?? '',
    descriptionMd: e.descriptionMd,
    mode: e.mode,
    venue: e.venue ?? '',
    location: e.location ?? '',
    startsAt: e.startsAt,
    endsAt: e.endsAt,
    registrationDeadline: e.registrationDeadline,
    registrationUrl: e.registrationUrl ?? '',
    eligibility: e.eligibility ?? '',
    prize: e.prize ?? '',
    teamMin: e.teamMin,
    teamMax: e.teamMax,
    capacity: e.capacity,
    organizerName: e.organizerName,
  );

  String? id;
  EventKind kind;
  String title;
  String summary;
  String descriptionMd;
  EventMode mode;
  String venue;
  String location;
  DateTime startsAt;
  DateTime? endsAt;
  DateTime? registrationDeadline;
  String registrationUrl;
  String eligibility;
  String prize;
  int teamMin;
  int teamMax;
  int? capacity;

  /// Admin-posted events only; a company's events use the company's name.
  String organizerName;

  String? _orNull(String s) => s.trim().isEmpty ? null : s.trim();

  Json toRow() => {
    'kind': kind.dbValue,
    'title': title.trim(),
    'summary': _orNull(summary),
    'description_md': descriptionMd.trim(),
    'mode': mode.dbValue,
    'venue': mode == EventMode.online ? null : _orNull(venue),
    'location_text': mode == EventMode.online ? null : _orNull(location),
    'starts_at': startsAt.toUtc().toIso8601String(),
    'ends_at': endsAt?.toUtc().toIso8601String(),
    'registration_deadline': registrationDeadline?.toUtc().toIso8601String(),
    'registration_url': _orNull(registrationUrl),
    'eligibility': _orNull(eligibility),
    'prize': _orNull(prize),
    'team_min': teamMin,
    'team_max': teamMax,
    'capacity': capacity,
    'organizer_name': organizerName.trim().isEmpty
        ? 'LuzHire'
        : organizerName.trim(),
  };
}

class EventsRepository {
  EventsRepository(this._db);
  final SupabaseClient _db;

  /// Events with their company's uploaded logo (for events a company posts).
  static const _columns = '*, companies(logo_path)';

  /// An event row: imported events carry their own logo; a company's event
  /// shows the company's logo.
  Opportunity _event(Map<String, dynamic> row) {
    final path = (row['companies'] as Map?)?['logo_path'] as String?;
    if (row['logo_url'] == null && path != null) {
      row = {
        ...row,
        'logo_url': _db.storage.from('company-media').getPublicUrl(path),
      };
    }
    return Opportunity.fromJson(row);
  }

  /// Published events that have not ended, soonest first.
  Future<List<Opportunity>> upcoming(
    EventQuery q, {
    int offset = 0,
    int limit = 12,
  }) => guardDb(() async {
    var f = _db
        .from('events')
        .select(_columns)
        .eq('status', 'published')
        .or(
          'ends_at.gte.${DateTime.now().toUtc().toIso8601String()},'
          'and(ends_at.is.null,starts_at.gte.'
          '${DateTime.now().toUtc().subtract(const Duration(hours: 12)).toIso8601String()})',
        );
    if (q.kinds.isNotEmpty) {
      f = f.inFilter('kind', [for (final k in q.kinds) k.dbValue]);
    }
    if (q.mode != null) f = f.eq('mode', q.mode!.dbValue);
    if (q.cityId != null) f = f.eq('city_id', q.cityId!);
    final rows = await f
        .order('starts_at', ascending: true)
        .order('id', ascending: true)
        .range(offset, offset + limit - 1);
    return [for (final r in rows) _event(r)];
  });

  Future<Opportunity?> bySlug(String slug) => guardDb(() async {
    final row = await _db
        .from('events')
        .select(_columns)
        .eq('slug', slug)
        .maybeSingle();
    return row == null ? null : _event(row);
  });

  Future<Opportunity?> byId(String id) => guardDb(() async {
    final row = await _db
        .from('events')
        .select(_columns)
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : _event(row);
  });

  /// Ids of the events [uid] registered for, with the team name.
  Future<Map<String, String?>> myRegistrations(String uid) => guardDb(() async {
    final rows = await _db
        .from('event_registrations')
        .select('event_id, team_name')
        .eq('user_id', uid);
    return {
      for (final r in rows) r['event_id'] as String: r['team_name'] as String?,
    };
  });

  Future<void> register(String eventId, String uid, {String? teamName}) =>
      guardDb(
        () => _db.from('event_registrations').insert({
          'event_id': eventId,
          'user_id': uid,
          'team_name': teamName,
        }),
      );

  Future<void> withdraw(String eventId, String uid) => guardDb(
    () => _db.from('event_registrations').delete().match({
      'event_id': eventId,
      'user_id': uid,
    }),
  );

  // ---------------------------------------------------------- organisers

  /// A company's events (all statuses), newest start first.
  Future<List<Opportunity>> companyEvents(String companyId) =>
      guardDb(() async {
        final rows = await _db
            .from('events')
            .select(_columns)
            .eq('company_id', companyId)
            .order('starts_at', ascending: false);
        return [for (final r in rows) _event(r)];
      });

  /// Every event (admins), newest first.
  Future<List<Opportunity>> all() => guardDb(() async {
    final rows = await _db
        .from('events')
        .select(_columns)
        .order('created_at', ascending: false)
        .limit(200);
    return [for (final r in rows) _event(r)];
  });

  /// Saves [d] for [companyId] (null: an admin's own event) with [status].
  Future<Opportunity> save(
    EventDraft d, {
    String? companyId,
    required EventStatus status,
  }) => guardDb(() async {
    final row = {...d.toRow(), 'status': status.dbValue};
    final saved = d.id == null
        ? await _db
              .from('events')
              .insert({...row, 'company_id': companyId})
              .select(_columns)
              .single()
        : await _db
              .from('events')
              .update(row)
              .eq('id', d.id!)
              .select(_columns)
              .single();
    return _event(saved);
  });

  Future<void> setStatus(String id, EventStatus status) => guardDb(
    () => _db.from('events').update({'status': status.dbValue}).eq('id', id),
  );

  Future<void> delete(String id) =>
      guardDb(() => _db.from('events').delete().eq('id', id));

  Future<List<EventRegistrant>> registrants(String eventId) =>
      guardDb(() async {
        final rows = await _db.rpc<List<dynamic>>(
          'event_registrants',
          params: {'event': eventId},
        );
        return [
          for (final r in rows) EventRegistrant.fromJson((r as Map).cast()),
        ];
      });
}

final eventsRepositoryProvider = Provider<EventsRepository>((ref) {
  if (!ref.watch(appConfigProvider).isSupabaseConfigured) throw notConfigured;
  return EventsRepository(ref.watch(supabaseClientProvider));
});
