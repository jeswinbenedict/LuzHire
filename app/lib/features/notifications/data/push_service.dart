// Push on this device through Firebase Cloud Messaging. On the web the
// browser shows messages through web/firebase-messaging-sw.js; on Android
// and iOS the system shows them and a tap opens the linked screen.
// ignore_for_file: deprecated_member_use
// getToken/onTokenRefresh are deprecated in favour of the brand-new FID
// registration API; the server sends to registration tokens, which FCM
// still fully supports.

import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/enums.dart';
import '../../auth/application/auth_controller.dart';

enum PushPermission { granted, denied, notDetermined }

abstract class PushService {
  /// False when Firebase is not configured or the browser cannot do push
  /// (for example Safari on iPhone outside a Home Screen app).
  Future<bool> supported();
  Future<PushPermission> permission();
  Future<PushPermission> requestPermission();

  /// This device's token; only call once permission is granted.
  Future<String?> token();
  PushPlatform get platform;
  Stream<String> get onTokenRefresh;

  /// Links from notifications the user tapped (Android/iOS).
  Stream<String> get onOpenedLink;
  Future<String?> initialLink();
}

class DisabledPushService implements PushService {
  const DisabledPushService();
  @override
  Future<bool> supported() async => false;
  @override
  Future<PushPermission> permission() async => PushPermission.denied;
  @override
  Future<PushPermission> requestPermission() async => PushPermission.denied;
  @override
  Future<String?> token() async => null;
  @override
  PushPlatform get platform => PushPlatform.web;
  @override
  Stream<String> get onTokenRefresh => const Stream.empty();
  @override
  Stream<String> get onOpenedLink => const Stream.empty();
  @override
  Future<String?> initialLink() async => null;
}

class FirebasePushService implements PushService {
  FirebasePushService({this.vapidKey});

  /// Optional Web Push key from the Firebase console; without it the
  /// Firebase SDK uses its built-in key.
  final String? vapidKey;
  FirebaseMessaging get _fm => FirebaseMessaging.instance;

  static PushPermission _map(AuthorizationStatus s) => switch (s) {
    AuthorizationStatus.authorized ||
    AuthorizationStatus.provisional => PushPermission.granted,
    AuthorizationStatus.denied ||
    AuthorizationStatus.deniedPermanently => PushPermission.denied,
    AuthorizationStatus.notDetermined => PushPermission.notDetermined,
  };

  @override
  Future<bool> supported() async {
    try {
      return await _fm.isSupported();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<PushPermission> permission() async =>
      _map((await _fm.getNotificationSettings()).authorizationStatus);

  @override
  Future<PushPermission> requestPermission() async =>
      _map((await _fm.requestPermission()).authorizationStatus);

  @override
  Future<String?> token() => _fm.getToken(
    vapidKey: kIsWeb && (vapidKey ?? '').isNotEmpty ? vapidKey : null,
  );

  @override
  PushPlatform get platform {
    if (kIsWeb) return PushPlatform.web;
    return defaultTargetPlatform == TargetPlatform.iOS
        ? PushPlatform.ios
        : PushPlatform.android;
  }

  @override
  Stream<String> get onTokenRefresh => _fm.onTokenRefresh;

  static String? _link(RemoteMessage m) {
    final link = m.data['link'];
    return link is String && link.isNotEmpty ? link : null;
  }

  @override
  Stream<String> get onOpenedLink => kIsWeb
      ? const Stream.empty()
      : FirebaseMessaging.onMessageOpenedApp
            .map(_link)
            .where((l) => l != null)
            .cast<String>();

  @override
  Future<String?> initialLink() async {
    if (kIsWeb) return null;
    final m = await _fm.getInitialMessage();
    return m == null ? null : _link(m);
  }
}

final pushServiceProvider = Provider<PushService>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.isFirebaseConfigured) return const DisabledPushService();
  return FirebasePushService(vapidKey: config.firebaseVapidKey);
});

/// The in-app path for a link from a push message (absolute or relative).
String? appPathFromLink(String link) {
  final uri = Uri.tryParse(link);
  if (uri == null || !uri.path.startsWith('/') || uri.path.startsWith('//')) {
    return null;
  }
  return uri.hasQuery ? '${uri.path}?${uri.query}' : uri.path;
}
