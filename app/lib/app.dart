import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/layout/input_mode.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_provider.dart';
import 'features/notifications/application/notification_providers.dart';
import 'features/notifications/data/push_service.dart';

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
      builder: (context, child) => _PushLinks(
        child: LuzInputModeScope(
          // Honour OS text scaling up to 200 % (DESIGN.md §6).
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 2.0,
            child: child!,
          ),
        ),
      ),
    );
  }
}

/// Opens the screen of a push notification the user tapped (Android/iOS;
/// on the web the service worker opens the link), and keeps this device's
/// push registration fresh while signed in.
class _PushLinks extends ConsumerStatefulWidget {
  const _PushLinks({required this.child});
  final Widget child;

  @override
  ConsumerState<_PushLinks> createState() => _PushLinksState();
}

class _PushLinksState extends ConsumerState<_PushLinks> {
  StreamSubscription<String>? _sub;

  @override
  void initState() {
    super.initState();
    final push = ref.read(pushServiceProvider);
    _sub = push.onOpenedLink.listen(_open);
    push.initialLink().then((l) {
      if (l != null) _open(l);
    }, onError: (_) {});
  }

  void _open(String link) {
    final path = appPathFromLink(link);
    if (path != null && mounted) ref.read(routerProvider).go(path);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(pushDeviceProvider);
    return widget.child;
  }
}
