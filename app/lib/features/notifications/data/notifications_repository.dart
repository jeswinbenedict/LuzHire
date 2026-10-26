import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/enums.dart';
import '../../../core/data/failures.dart';
import '../../../core/data/models.dart';
import '../../../core/data/supabase_providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../jobs/data/jobs_repository.dart' show notConfigured;

/// Push and email switches for one notification group. In-app notifications
/// are always kept.
@immutable
class ChannelPrefs {
  const ChannelPrefs({this.push = true, this.email = true});
  final bool push;
  final bool email;

  ChannelPrefs copyWith({bool? push, bool? email}) =>
      ChannelPrefs(push: push ?? this.push, email: email ?? this.email);

  @override
  bool operator ==(Object other) =>
      other is ChannelPrefs && other.push == push && other.email == email;

  @override
  int get hashCode => Object.hash(push, email);
}

/// In-app notifications are created by database triggers; clients only read
/// them and mark them read (FR-11). Preferences and this device's push token
/// decide what /api/notify/dispatch also sends by push and email.
class NotificationsRepository {
  NotificationsRepository(this._db);
  final SupabaseClient _db;

  /// Newest 50 notifications, live.
  Stream<List<AppNotification>> watch(String userId) => _db
      .from('notifications')
      .stream(primaryKey: ['id'])
      .eq('user_id', userId)
      .order('created_at', ascending: false)
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

  /// Every group, with defaults (both on) for groups never changed.
  Future<Map<NotificationCategory, ChannelPrefs>> preferences(String userId) =>
      guardDb(() async {
        final rows = await _db
            .from('notification_preferences')
            .select('category, push, email')
            .eq('user_id', userId);
        return {
          for (final c in NotificationCategory.values) c: const ChannelPrefs(),
          for (final r in rows)
            NotificationCategory.fromDb(r['category'] as String?): ChannelPrefs(
              push: r['push'] as bool,
              email: r['email'] as bool,
            ),
        };
      });

  Future<void> setPreference(
    String userId,
    NotificationCategory category,
    ChannelPrefs prefs,
  ) => guardDb(
    () => _db.from('notification_preferences').upsert({
      'user_id': userId,
      'category': category.dbValue,
      'push': prefs.push,
      'email': prefs.email,
    }),
  );

  /// Is [token] registered to the signed-in user? (RLS hides other users'.)
  Future<bool> hasPushToken(String token) => guardDb(() async {
    final rows = await _db
        .from('push_tokens')
        .select('token')
        .eq('token', token)
        .limit(1);
    return rows.isNotEmpty;
  });

  /// Registers this device for the signed-in user (takes it over from
  /// whoever used it before).
  Future<void> registerPushToken(String token, PushPlatform platform) =>
      guardDb(
        () => _db.rpc(
          'register_push_token',
          params: {'device_token': token, 'device_platform': platform.dbValue},
        ),
      );

  Future<void> removePushToken(String token) =>
      guardDb(() => _db.from('push_tokens').delete().eq('token', token));

  /// A notification to yourself, delivered like any other (push + email).
  Future<void> sendTest() => guardDb(() => _db.rpc('send_test_notification'));
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>((
  ref,
) {
  if (!ref.watch(appConfigProvider).isSupabaseConfigured) throw notConfigured;
  return NotificationsRepository(ref.watch(supabaseClientProvider));
});
