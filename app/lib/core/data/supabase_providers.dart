import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The shared Supabase client. `Supabase.initialize` (with the Firebase ID
/// token as accessToken) runs in bootstrap.dart from Phase 3; tests override
/// this provider.
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);
