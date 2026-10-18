import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/layout/input_mode.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_provider.dart';

class LuzHireApp extends ConsumerStatefulWidget {
  const LuzHireApp({super.key});

  @override
  ConsumerState<LuzHireApp> createState() => _LuzHireAppState();
}

class _LuzHireAppState extends ConsumerState<LuzHireApp> {
  late final GoRouter _router = createRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'LuzHire',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeModeProvider),
      routerConfig: _router,
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
