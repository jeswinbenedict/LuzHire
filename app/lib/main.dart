import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Clean URLs (/jobs/123 instead of /#/jobs/123): shareable links, SEO,
  // and matches the SPA rewrite in vercel.json. No-op on mobile.
  usePathUrlStrategy();
  // Firebase + Supabase initialisation is added in Phase 3 (bootstrap.dart).
  runApp(const ProviderScope(child: LuzHireApp()));
}
