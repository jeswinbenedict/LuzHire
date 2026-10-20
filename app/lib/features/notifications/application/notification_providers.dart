import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/enums.dart';
import '../../../core/data/failures.dart';
import '../../../core/data/models.dart';
import '../../jobs/application/job_board_providers.dart'
    show currentUidProvider;
import '../data/notifications_repository.dart';
import '../data/push_service.dart';

String _uid(Ref ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) {
    throw const AppFailure('Sign in to see this page.', code: 'signed_out');
  }
  return uid;
}

/// Live notifications of the signed-in user (newest first).
final myNotificationsProvider =
    StreamProvider.autoDispose<List<AppNotification>>(
      (ref) => ref.watch(notificationsRepositoryProvider).watch(_uid(ref)),
    );

final unreadNotificationCountProvider = Provider.autoDispose<int>(
  (ref) => (ref.watch(myNotificationsProvider).value ?? const [])
      .where((n) => n.isUnread)
      .length,
);

// ---------------------------------------------------------------- preferences

/// Push/email switches per group, saved as soon as one is flipped.
class NotificationPreferencesController
    extends AsyncNotifier<Map<NotificationCategory, ChannelPrefs>> {
  @override
  Future<Map<NotificationCategory, ChannelPrefs>> build() =>
      ref.watch(notificationsRepositoryProvider).preferences(_uid(ref));

  /// Shows the change at once and rolls it back if saving fails.
  Future<void> set(NotificationCategory category, ChannelPrefs prefs) async {
    final before = state.value;
    if (before == null) return;
    state = AsyncData({...before, category: prefs});
    try {
      await ref
          .read(notificationsRepositoryProvider)
          .setPreference(_uid(ref), category, prefs);
    } catch (_) {
      if (ref.mounted) state = AsyncData(before);
      rethrow;
    }
  }
}

final notificationPreferencesProvider =
    AsyncNotifierProvider.autoDispose<
      NotificationPreferencesController,
      Map<NotificationCategory, ChannelPrefs>
    >(NotificationPreferencesController.new);

// ---------------------------------------------------------------- this device

enum PushStatus {
  /// Firebase isn't set up or the browser cannot show notifications.
  unsupported,

  /// The user blocked notifications for LuzHire in the browser/OS.
  blocked,
  off,
  on,
}

/// Push on this device. The database is the source of truth: the device is
/// "on" when its token is registered to the signed-in user.
class PushDeviceController extends AsyncNotifier<PushStatus> {
  PushService get _push => ref.read(pushServiceProvider);
  NotificationsRepository get _repo =>
      ref.read(notificationsRepositoryProvider);

  @override
  Future<PushStatus> build() async {
    final uid = ref.watch(currentUidProvider);
    final push = ref.watch(pushServiceProvider);
    if (uid == null || !await push.supported()) return PushStatus.unsupported;
    final sub = push.onTokenRefresh.listen((token) async {
      if (state.value != PushStatus.on) return;
      try {
        await _repo.registerPushToken(token, push.platform);
      } catch (_) {
        // Next start registers it again.
      }
    });
    ref.onDispose(sub.cancel);
    switch (await push.permission()) {
      case PushPermission.denied:
        return PushStatus.blocked;
      case PushPermission.notDetermined:
        return PushStatus.off;
      case PushPermission.granted:
        final token = await push.token();
        if (token == null || !await _repo.hasPushToken(token)) {
          return PushStatus.off;
        }
        await _repo.registerPushToken(token, push.platform); // last seen
        return PushStatus.on;
    }
  }

  Future<void> enable() async {
    final permission = await _push.requestPermission();
    if (permission != PushPermission.granted) {
      if (ref.mounted) state = const AsyncData(PushStatus.blocked);
      throw const AppFailure(
        'Notifications are blocked for LuzHire. Allow them in your browser '
        'or phone settings, then try again.',
        code: 'push_blocked',
      );
    }
    final token = await _push.token().catchError((_) => null);
    if (token == null) {
      throw const AppFailure(
        'This device could not be registered for notifications. '
        'Reload the page and try again.',
        code: 'push_token',
      );
    }
    await _repo.registerPushToken(token, _push.platform);
    if (ref.mounted) state = const AsyncData(PushStatus.on);
  }

  Future<void> disable() async {
    final token = await _push.token();
    if (token != null) await _repo.removePushToken(token);
    if (ref.mounted) state = const AsyncData(PushStatus.off);
  }
}

final pushDeviceProvider =
    AsyncNotifierProvider.autoDispose<PushDeviceController, PushStatus>(
      PushDeviceController.new,
    );

/// Before sign-out: stop pushes for the old account on this device. Best
/// effort; sign-out never fails because of it.
Future<void> forgetPushDevice(Ref ref) async {
  try {
    final push = ref.read(pushServiceProvider);
    if (!await push.supported() ||
        await push.permission() != PushPermission.granted) {
      return;
    }
    final token = await push.token();
    if (token != null) {
      await ref.read(notificationsRepositoryProvider).removePushToken(token);
    }
  } catch (_) {
    // Signed out anyway; the token moves to the next account that enables push.
  }
}

// ---------------------------------------------------------------- actions

class NotificationActions {
  NotificationActions(this._ref);
  final Ref _ref;

  NotificationsRepository get _repo =>
      _ref.read(notificationsRepositoryProvider);

  Future<void> markRead(String id) => _repo.markRead(id);

  Future<void> markAllRead() async {
    final uid = _ref.read(currentUidProvider);
    if (uid != null) await _repo.markAllRead(uid);
  }

  Future<void> sendTest() => _repo.sendTest();
}

final notificationActionsProvider = Provider<NotificationActions>(
  NotificationActions.new,
);
