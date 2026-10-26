import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/enums.dart';
import '../../../core/data/failures.dart';
import '../../../core/data/models.dart';
import '../../jobs/application/job_board_providers.dart'
    show currentUidProvider;
import '../data/events_repository.dart';

@immutable
class EventListState {
  const EventListState({
    this.items = const [],
    this.loading = false,
    this.hasMore = true,
    this.error,
  });
  final List<Opportunity> items;
  final bool loading;
  final bool hasMore;
  final AppFailure? error;
  bool get isInitialLoad => loading && items.isEmpty;
}

/// Upcoming events for one [EventQuery], soonest first.
class EventListController extends Notifier<EventListState> {
  EventListController(this.query);
  final EventQuery query;
  static const pageSize = 12;
  bool _inFlight = false;

  @override
  EventListState build() {
    Future.microtask(loadMore);
    return const EventListState(loading: true);
  }

  Future<void> loadMore() async {
    if (_inFlight || !state.hasMore) return;
    _inFlight = true;
    state = EventListState(items: state.items, loading: true);
    try {
      final page = await ref
          .read(eventsRepositoryProvider)
          .upcoming(query, offset: state.items.length, limit: pageSize);
      if (!ref.mounted) return;
      state = EventListState(
        items: [...state.items, ...page],
        hasMore: page.length >= pageSize,
      );
    } catch (e) {
      if (!ref.mounted) return;
      state = EventListState(
        items: state.items,
        hasMore: state.hasMore,
        error: mapDbError(e),
      );
    } finally {
      _inFlight = false;
    }
  }
}

final eventListProvider = NotifierProvider.autoDispose
    .family<EventListController, EventListState, EventQuery>(
      EventListController.new,
    );

/// How many upcoming events there are of each kind.
final upcomingEventKindsProvider = FutureProvider.autoDispose<List<EventKind>>(
  (ref) => ref.watch(eventsRepositoryProvider).upcomingKinds(),
);

final eventBySlugProvider = FutureProvider.autoDispose
    .family<Opportunity?, String>(
      (ref, slug) => ref.watch(eventsRepositoryProvider).bySlug(slug),
    );

final eventByIdProvider = FutureProvider.autoDispose
    .family<Opportunity?, String>(
      (ref, id) => ref.watch(eventsRepositoryProvider).byId(id),
    );

/// Event id → team name for the signed-in user's registrations.
final myEventRegistrationsProvider =
    FutureProvider.autoDispose<Map<String, String?>>((ref) {
      final uid = ref.watch(currentUidProvider);
      if (uid == null) return const {};
      return ref.watch(eventsRepositoryProvider).myRegistrations(uid);
    });

final companyOpportunitiesProvider = FutureProvider.autoDispose
    .family<List<Opportunity>, String>(
      (ref, companyId) =>
          ref.watch(eventsRepositoryProvider).companyEvents(companyId),
    );

final allOpportunitiesProvider = FutureProvider.autoDispose<List<Opportunity>>(
  (ref) => ref.watch(eventsRepositoryProvider).all(),
);

final eventRegistrantsProvider = FutureProvider.autoDispose
    .family<List<EventRegistrant>, String>(
      (ref, eventId) =>
          ref.watch(eventsRepositoryProvider).registrants(eventId),
    );

/// Writes; each refreshes what shows the change.
class EventActions {
  EventActions(this._ref);
  final Ref _ref;
  EventsRepository get _repo => _ref.read(eventsRepositoryProvider);

  void _refresh() {
    _ref
      ..invalidate(eventListProvider)
      ..invalidate(eventBySlugProvider)
      ..invalidate(eventByIdProvider)
      ..invalidate(companyOpportunitiesProvider)
      ..invalidate(allOpportunitiesProvider)
      ..invalidate(myEventRegistrationsProvider);
  }

  Future<void> register(Opportunity e, {String? teamName}) async {
    final uid = _ref.read(currentUidProvider);
    if (uid == null) {
      throw const AppFailure('Sign in to register.', code: 'signed_out');
    }
    await _repo.register(e.id, uid, teamName: teamName);
    _refresh();
  }

  Future<void> withdraw(Opportunity e) async {
    final uid = _ref.read(currentUidProvider);
    if (uid == null) return;
    await _repo.withdraw(e.id, uid);
    _refresh();
  }

  Future<Opportunity> save(
    EventDraft d, {
    String? companyId,
    required EventStatus status,
  }) async {
    final saved = await _repo.save(d, companyId: companyId, status: status);
    _refresh();
    return saved;
  }

  Future<void> setStatus(String id, EventStatus status) async {
    await _repo.setStatus(id, status);
    _refresh();
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    _refresh();
  }
}

final eventActionsProvider = Provider<EventActions>(EventActions.new);
