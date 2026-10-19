import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'app.dart';
import 'bootstrap.dart';
import 'features/auth/application/auth_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Clean URLs (/jobs/123 instead of /#/jobs/123): shareable links, SEO,
  // and matches the SPA rewrite in vercel.json. No-op on mobile.
  usePathUrlStrategy();
  final config = await bootstrapServices();
  runApp(
    ProviderScope(
      overrides: [appConfigProvider.overrideWithValue(config)],
      child: const LuzHireApp(),
    ),
  );
}
