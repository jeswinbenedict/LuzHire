import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/failures.dart';
import '../../../core/data/models.dart';
import '../../../core/data/supabase_providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../jobs/data/jobs_repository.dart' show notConfigured;

/// In-app notifications are created by database triggers; clients only read
/// them and mark them read (FR-11).
class NotificationsRepository {
  NotificationsRepository(this._db);
  final SupabaseClient _db;

  /// Newest 50 notifications, live.
  Stream<List<AppNotification>> watch(String userId) => _db
      .from('notifications')
      .stream(primaryKey: ['id'])
      .eq('user_id', userId)
      .order('created_at')
      .limit(50)
      .map(
        (rows) => [for (final r in rows.reversed) AppNotification.fromJson(r)],
      );

  Future<void> markRead(String id) => guardDb(
    () => _db
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id),
  );

  Future<void> markAllRead(String userId) => guardDb(
    () => _db
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('user_id', userId)
        .isFilter('read_at', null),
  );

  Future<void> delete(String id) =>
      guardDb(() => _db.from('notifications').delete().eq('id', id));
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>((
  ref,
) {
  if (!ref.watch(appConfigProvider).isSupabaseConfigured) throw notConfigured;
  return NotificationsRepository(ref.watch(supabaseClientProvider));
});
