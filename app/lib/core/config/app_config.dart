import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Public client configuration, compiled in with
/// `--dart-define-from-file=env/<env>.json` (see env/example.json).
/// Only public values belong here: the Firebase web config, the Supabase URL
/// and publishable (anon) key are designed to be shipped to browsers. Never put service keys here.
@immutable
class AppConfig {
  const AppConfig({
    required this.env,
    required this.supabaseUrl,
    required this.supabasePublishableKey,
    required this.apiBaseUrl,
    required this.firebaseApiKey,
    required this.firebaseProjectId,
    required this.firebaseMessagingSenderId,
    required this.firebaseAuthDomain,
    required this.firebaseStorageBucket,
    required this.firebaseWebAppId,
    required this.firebaseAndroidAppId,
    required this.firebaseIosAppId,
    required this.firebaseIosBundleId,
    this.firebaseVapidKey = '',
  });

  factory AppConfig.fromEnvironment() => const AppConfig(
    env: String.fromEnvironment('APP_ENV', defaultValue: 'local'),
    supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
    supabasePublishableKey: String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
    apiBaseUrl: String.fromEnvironment('API_BASE_URL'),
    firebaseApiKey: String.fromEnvironment('FIREBASE_API_KEY'),
    firebaseProjectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
    firebaseMessagingSenderId: String.fromEnvironment(
      'FIREBASE_MESSAGING_SENDER_ID',
    ),
    firebaseAuthDomain: String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
    firebaseStorageBucket: String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
    firebaseWebAppId: String.fromEnvironment('FIREBASE_WEB_APP_ID'),
    firebaseAndroidAppId: String.fromEnvironment('FIREBASE_ANDROID_APP_ID'),
    firebaseIosAppId: String.fromEnvironment('FIREBASE_IOS_APP_ID'),
    firebaseIosBundleId: String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID'),
    firebaseVapidKey: String.fromEnvironment('FIREBASE_VAPID_KEY'),
  );

  final String env;
  final String supabaseUrl;
  final String supabasePublishableKey;

  /// Base URL of the Vercel API. Empty on web = same origin (`/api/...`).
  final String apiBaseUrl;
  final String firebaseApiKey;
  final String firebaseProjectId;
  final String firebaseMessagingSenderId;
  final String firebaseAuthDomain;
  final String firebaseStorageBucket;
  final String firebaseWebAppId;
  final String firebaseAndroidAppId;
  final String firebaseIosAppId;
  final String firebaseIosBundleId;

  /// Optional public Web Push (VAPID) key from Firebase console → Cloud
  /// Messaging. Empty = the Firebase SDK's built-in key.
  final String firebaseVapidKey;

  static bool _real(String v) => v.isNotEmpty && !v.startsWith('replace-');

  String get _platformAppId {
    if (kIsWeb) return firebaseWebAppId;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => firebaseAndroidAppId,
      TargetPlatform.iOS || TargetPlatform.macOS => firebaseIosAppId,
      _ => firebaseWebAppId,
    };
  }

  bool get isFirebaseConfigured =>
      _real(firebaseApiKey) &&
      _real(firebaseProjectId) &&
      _real(_platformAppId);

  bool get isSupabaseConfigured =>
      _real(supabaseUrl) && _real(supabasePublishableKey);

  /// Auth needs both: Firebase signs in, Supabase stores the profile.
  bool get isAuthConfigured => isFirebaseConfigured && isSupabaseConfigured;

  FirebaseOptions get firebaseOptions => FirebaseOptions(
    apiKey: firebaseApiKey,
    appId: _platformAppId,
    messagingSenderId: firebaseMessagingSenderId,
    projectId: firebaseProjectId,
    authDomain: kIsWeb && firebaseAuthDomain.isNotEmpty
        ? firebaseAuthDomain
        : null,
    storageBucket: firebaseStorageBucket.isEmpty ? null : firebaseStorageBucket,
    iosBundleId: firebaseIosBundleId.isEmpty ? null : firebaseIosBundleId,
  );

  /// Absolute URL for an API path such as `/api/auth/bootstrap`.
  Uri api(String path) {
    if (apiBaseUrl.isEmpty) return Uri.base.resolve(path);
    return Uri.parse(apiBaseUrl).resolve(path);
  }
}
