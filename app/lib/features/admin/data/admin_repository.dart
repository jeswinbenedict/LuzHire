import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/enums.dart';
import '../../../core/data/failures.dart';
import '../../../core/data/models.dart';
import '../../../core/data/supabase_providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../jobs/data/jobs_repository.dart' show notConfigured;

/// Admin console reads and writes. Every rule (admin only, which states can
/// be reviewed, append-only audit) is enforced in Postgres.
class AdminRepository {
  AdminRepository(this._db);
  final SupabaseClient _db;

  Future<PlatformStats> stats() => guardDb(() async {
    final json = await _db.rpc<dynamic>('admin_platform_stats');
    return PlatformStats.fromJson((json as Map).cast());
  });

  /// Latest daily job imports, newest first.
  Future<List<IngestRun>> ingestRuns() => guardDb(() async {
    final rows = await _db
        .from('ingest_runs')
        .select()
        .order('started_at', ascending: false)
        .limit(5);
    return [for (final r in rows) IngestRun.fromJson(r)];
  });

  /// Newest entries of the error log (app crashes and API errors).
  Future<List<AppErrorEntry>> recentErrors() => guardDb(() async {
    final rows = await _db
        .from('app_errors')
        .select('source, message, route, release, created_at')
        .order('created_at', ascending: false)
        .limit(10);
    return [for (final r in rows) AppErrorEntry.fromJson(r)];
  });

  // ---------------------------------------------------------- reviews

  /// Companies that asked for verification, oldest request first.
  Future<List<Company>> pendingCompanies() => guardDb(() async {
    final rows = await _db
        .from('companies')
        .select()
        .eq('verification', Verification.pending.dbValue)
        .order('updated_at', ascending: true);
    return [for (final r in rows) Company.fromJson(r)];
  });

  Future<void> reviewCompany(
    String id, {
    required bool approve,
    String? note,
  }) => guardDb(
    () => _db.rpc<void>(
      'review_company',
      params: {'company': id, 'approve': approve, 'note': note},
    ),
  );

  /// Jobs waiting for review, oldest first.
  Future<List<Job>> pendingJobs() => guardDb(() async {
    final rows = await _db
        .from('jobs')
        .select()
        .eq('status', JobStatus.pendingReview.dbValue)
        .order('created_at', ascending: true);
    return [for (final r in rows) Job.fromJson(r)];
  });

  Future<void> reviewJob(String id, {required bool approve, String? note}) =>
      guardDb(
        () => _db.rpc<void>(
          'review_job',
          params: {'job': id, 'approve': approve, 'note': note},
        ),
      );

  // ---------------------------------------------------------- reports

  Future<List<Report>> reports(ReportStatus status) => guardDb(() async {
    final rows = await _db
        .from('reports')
        .select()
        .eq('status', status.dbValue)
        .order('created_at', ascending: status != ReportStatus.open)
        .limit(100);
    return [for (final r in rows) Report.fromJson(r)];
  });

  /// Human names for report targets, keyed `type:id` (job title, company or person name).
  Future<Map<String, String>> targetNames(List<Report> reports) => guardDb(
    () async {
      Future<Map<String, String>> load(
        String type,
        String table,
        String column,
      ) async {
        final ids = {
          for (final r in reports)
            if (r.targetType == type) r.targetId,
        };
        if (ids.isEmpty) return const {};
        final rows = await _db
            .from(table)
            .select('id, $column')
            .inFilter('id', ids.toList());
        return {for (final r in rows) '$type:${r['id']}': r[column] as String};
      }

      return {
        ...await load('job', 'jobs', 'title'),
        ...await load('company', 'companies', 'name'),
        ...await load('profile', 'profiles', 'display_name'),
      };
    },
  );

  Future<void> resolveReport(String id, ReportStatus outcome) => guardDb(
    () => _db.rpc<void>(
      'resolve_report',
      params: {'report': id, 'outcome': outcome.dbValue},
    ),
  );

  // ---------------------------------------------------------- users

  /// One page of users, newest first, matching [query] in name or email.
  Future<List<Profile>> users({
    String query = '',
    AppRole? role,
    AccountStatus? status,
    int offset = 0,
    int limit = 25,
  }) => guardDb(() async {
    var filter = _db.from('profiles').select();
    final q = query.trim().replaceAll(RegExp(r'[%_\\,()]'), '');
    if (q.isNotEmpty) {
      filter = filter.or('display_name.ilike.%$q%,email.ilike.%$q%');
    }
    if (role != null) filter = filter.eq('role', role.dbValue);
    if (status != null) filter = filter.eq('account_status', status.dbValue);
    final rows = await filter
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return [for (final r in rows) Profile.fromJson(r)];
  });

  // ---------------------------------------------------------- announcements

  Future<List<Announcement>> announcements() => guardDb(() async {
    final rows = await _db
        .from('announcements')
        .select()
        .order('created_at', ascending: false);
    return [for (final r in rows) Announcement.fromJson(r)];
  });

  Future<void> saveAnnouncement({
    String? id,
    required String title,
    required String bodyMd,
    required AnnouncementAudience audience,
    required bool publish,
    required String adminId,
  }) => guardDb(() async {
    final row = {
      'title': title.trim(),
      'body_md': bodyMd.trim(),
      'audience': audience.dbValue,
      'published_at': publish ? DateTime.now().toUtc().toIso8601String() : null,
    };
    if (id == null) {
      await _db.from('announcements').insert({...row, 'created_by': adminId});
    } else {
      await _db.from('announcements').update(row).eq('id', id);
    }
  });

  Future<void> deleteAnnouncement(String id) =>
      guardDb(() => _db.from('announcements').delete().eq('id', id));

  // ---------------------------------------------------------- audit log

  /// Newest entries first; pass the last id seen as [beforeId] for more.
  Future<List<AuditEntry>> audit({
    String? table,
    String? actorId,
    int? beforeId,
    int limit = 50,
  }) => guardDb(() async {
    var filter = _db.from('audit_logs').select();
    if (table != null) filter = filter.eq('target_table', table);
    if (actorId != null && actorId.trim().isNotEmpty) {
      filter = filter.eq('actor_id', actorId.trim());
    }
    if (beforeId != null) filter = filter.lt('id', beforeId);
    final rows = await filter.order('id', ascending: false).limit(limit);
    return [for (final r in rows) AuditEntry.fromJson(r)];
  });
}

/// What every signed-in user can do: report content and read announcements.
class GovernanceRepository {
  GovernanceRepository(this._db);
  final SupabaseClient _db;

  Future<void> report({
    required String reporterId,
    required String targetType,
    required String targetId,
    required String reason,
  }) => guardDb(
    () => _db.from('reports').insert({
      'reporter_id': reporterId,
      'target_type': targetType,
      'target_id': targetId,
      'reason': reason.trim(),
    }),
  );

  /// Published announcements the caller may see (RLS filters by audience).
  Future<List<Announcement>> activeAnnouncements() => guardDb(() async {
    final rows = await _db
        .from('announcements')
        .select()
        .not('published_at', 'is', null)
        .lte('published_at', DateTime.now().toUtc().toIso8601String())
        .order('published_at', ascending: false)
        .limit(3);
    return [for (final r in rows) Announcement.fromJson(r)];
  });
}

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  if (!ref.watch(appConfigProvider).isSupabaseConfigured) throw notConfigured;
  return AdminRepository(ref.watch(supabaseClientProvider));
});

final governanceRepositoryProvider = Provider<GovernanceRepository>((ref) {
  if (!ref.watch(appConfigProvider).isSupabaseConfigured) throw notConfigured;
  return GovernanceRepository(ref.watch(supabaseClientProvider));
});
