import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/enums.dart';
import '../../../core/data/failures.dart';
import '../../../core/data/models.dart';
import '../../auth/application/auth_controller.dart';
import '../../jobs/application/job_board_providers.dart'
    show currentUidProvider;
import '../data/admin_repository.dart';

final platformStatsProvider = FutureProvider.autoDispose<PlatformStats>(
  (ref) => ref.watch(adminRepositoryProvider).stats(),
);

final ingestRunsProvider = FutureProvider.autoDispose<List<IngestRun>>(
  (ref) => ref.watch(adminRepositoryProvider).ingestRuns(),
);

final pendingCompaniesProvider = FutureProvider.autoDispose<List<Company>>(
  (ref) => ref.watch(adminRepositoryProvider).pendingCompanies(),
);

final pendingJobsProvider = FutureProvider.autoDispose<List<Job>>(
  (ref) => ref.watch(adminRepositoryProvider).pendingJobs(),
);

final reportsProvider = FutureProvider.autoDispose
    .family<List<Report>, ReportStatus>(
      (ref, status) => ref.watch(adminRepositoryProvider).reports(status),
    );

final reportTargetsProvider = FutureProvider.autoDispose
    .family<Map<String, String>, ReportStatus>((ref, status) async {
      final reports = await ref.watch(reportsProvider(status).future);
      return ref.watch(adminRepositoryProvider).targetNames(reports);
    });

@immutable
class UserQuery {
  const UserQuery({this.text = '', this.role, this.status});
  final String text;
  final AppRole? role;
  final AccountStatus? status;

  @override
  bool operator ==(Object other) =>
      other is UserQuery &&
      other.text == text &&
      other.role == role &&
      other.status == status;
  @override
  int get hashCode => Object.hash(text, role, status);
}

final usersProvider = FutureProvider.autoDispose
    .family<List<Profile>, UserQuery>(
      (ref, q) => ref
          .watch(adminRepositoryProvider)
          .users(query: q.text, role: q.role, status: q.status, limit: 50),
    );

final adminAnnouncementsProvider =
    FutureProvider.autoDispose<List<Announcement>>(
      (ref) => ref.watch(adminRepositoryProvider).announcements(),
    );

@immutable
class AuditQuery {
  const AuditQuery({this.table, this.actorId = ''});
  final String? table;
  final String actorId;

  @override
  bool operator ==(Object other) =>
      other is AuditQuery && other.table == table && other.actorId == actorId;
  @override
  int get hashCode => Object.hash(table, actorId);
}

/// Audit entries, newest first, with "load more" (keyset on id).
class AuditController extends Notifier<AsyncValue<List<AuditEntry>>> {
  AuditController(this.query);
  final AuditQuery query;
  bool hasMore = true;
  bool _busy = false;

  @override
  AsyncValue<List<AuditEntry>> build() {
    Future.microtask(loadMore);
    return const AsyncLoading();
  }

  Future<void> loadMore() async {
    if (_busy || !hasMore) return;
    _busy = true;
    final current = state.value ?? const <AuditEntry>[];
    try {
      final page = await ref
          .read(adminRepositoryProvider)
          .audit(
            table: query.table,
            actorId: query.actorId,
            beforeId: current.isEmpty ? null : current.last.id,
          );
      if (!ref.mounted) return;
      hasMore = page.length >= 50;
      state = AsyncData([...current, ...page]);
    } catch (e, st) {
      if (!ref.mounted) return;
      state = current.isEmpty
          ? AsyncError(mapDbError(e), st)
          : AsyncData(current);
    } finally {
      _busy = false;
    }
  }
}

final auditProvider = NotifierProvider.autoDispose
    .family<AuditController, AsyncValue<List<AuditEntry>>, AuditQuery>(
      AuditController.new,
    );

/// Published announcements for the signed-in user (or visitors).
final activeAnnouncementsProvider =
    FutureProvider.autoDispose<List<Announcement>>((ref) {
      ref.watch(currentUidProvider); // audience depends on who is signed in
      return ref.watch(governanceRepositoryProvider).activeAnnouncements();
    });

/// Announcements the user closed this session.
class DismissedAnnouncements extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};
  void dismiss(String id) => state = {...state, id};
}

final dismissedAnnouncementsProvider =
    NotifierProvider<DismissedAnnouncements, Set<String>>(
      DismissedAnnouncements.new,
    );

/// Admin writes. Role and suspension go through the API (Firebase claims and
/// sign-in); everything else is a checked database call.
class AdminActions {
  AdminActions(this._ref);
  final Ref _ref;

  AdminRepository get _repo => _ref.read(adminRepositoryProvider);

  Future<String> _token() async {
    final token = await _ref.read(authGatewayProvider).idToken();
    if (token == null) throw const AppFailure('Sign in again to continue.');
    return token;
  }

  Future<void> reviewCompany(String id, bool approve, String? note) async {
    await _repo.reviewCompany(id, approve: approve, note: note);
    _ref
      ..invalidate(pendingCompaniesProvider)
      ..invalidate(platformStatsProvider);
  }

  Future<void> reviewJob(String id, bool approve, String? note) async {
    await _repo.reviewJob(id, approve: approve, note: note);
    _ref
      ..invalidate(pendingJobsProvider)
      ..invalidate(platformStatsProvider);
  }

  Future<void> resolveReport(String id, ReportStatus outcome) async {
    await _repo.resolveReport(id, outcome);
    _ref
      ..invalidate(reportsProvider)
      ..invalidate(platformStatsProvider);
  }

  Future<void> changeRole(String uid, AppRole role) async {
    await _ref
        .read(accountApiProvider)
        .changeRole(idToken: await _token(), uid: uid, role: role);
    _ref.invalidate(usersProvider);
  }

  Future<void> setStatus(String uid, AccountStatus status) async {
    await _ref
        .read(accountApiProvider)
        .setStatus(idToken: await _token(), uid: uid, status: status);
    _ref
      ..invalidate(usersProvider)
      ..invalidate(platformStatsProvider);
  }

  Future<void> saveAnnouncement({
    String? id,
    required String title,
    required String bodyMd,
    required AnnouncementAudience audience,
    required bool publish,
  }) async {
    final me = _ref.read(currentUidProvider);
    if (me == null) throw const AppFailure('Sign in again to continue.');
    await _repo.saveAnnouncement(
      id: id,
      title: title,
      bodyMd: bodyMd,
      audience: audience,
      publish: publish,
      adminId: me,
    );
    _ref
      ..invalidate(adminAnnouncementsProvider)
      ..invalidate(activeAnnouncementsProvider);
  }

  Future<void> deleteAnnouncement(String id) async {
    await _repo.deleteAnnouncement(id);
    _ref
      ..invalidate(adminAnnouncementsProvider)
      ..invalidate(activeAnnouncementsProvider);
  }

  /// Any signed-in user: report a job, company or profile.
  Future<void> report(String type, String id, String reason) async {
    final me = _ref.read(currentUidProvider);
    if (me == null) {
      throw const AppFailure('Sign in to report content.', code: 'signed_out');
    }
    await _ref
        .read(governanceRepositoryProvider)
        .report(reporterId: me, targetType: type, targetId: id, reason: reason);
  }
}

final adminActionsProvider = Provider<AdminActions>(AdminActions.new);
