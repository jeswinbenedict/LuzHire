import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/app_config.dart';
import 'core/config/firebase_sdk_loader.dart';

/// Starts Firebase and Supabase when this build has their config. Without it
/// the app still runs (public pages, design gallery) and sign-in shows a
/// "not available in this build" notice.
Future<AppConfig> bootstrapServices() async {
  final config = AppConfig.fromEnvironment();
  if (config.isFirebaseConfigured) {
    await waitForFirebaseSdk();
    await Firebase.initializeApp(options: config.firebaseOptions);
  }
  if (config.isSupabaseConfigured) {
    await Supabase.initialize(
      url: config.supabaseUrl,
      publishableKey: config.supabasePublishableKey,
      accessToken: config.isFirebaseConfigured ? _firebaseAccessToken : null,
    );
  }
  return config;
}

/// Supabase (Third-Party Auth) trusts Firebase ID tokens, but only once they
/// carry `role: authenticated`, which /api/auth/bootstrap sets. Until then
/// requests use the anon key, so RLS treats the user as a visitor.
Future<String?> _firebaseAccessToken() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;
  final result = await user.getIdTokenResult();
  return result.claims?['role'] == 'authenticated' ? result.token : null;
}
