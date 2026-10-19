import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/layout/input_mode.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_provider.dart';

class LuzHireApp extends ConsumerWidget {
  const LuzHireApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'LuzHire',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeModeProvider),
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => LuzInputModeScope(
        // Honour OS text scaling up to 200 % (DESIGN.md §6).
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 2.0,
          child: child!,
        ),
      ),
    );
  }
}
