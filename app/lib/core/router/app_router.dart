import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/presentation/account_flow_pages.dart';
import '../../features/auth/presentation/sign_in_page.dart';
import '../../features/auth/presentation/sign_up_page.dart';
import '../../features/candidate/candidate_area.dart';
import '../../features/design_gallery/gallery_page.dart';
import '../../features/home/home_page.dart';
import '../data/enums.dart';
import '../shell/destinations.dart';
import '../shell/shell_common.dart';
import '../shell/spotlight_shell.dart';
import '../shell/workspace_shell.dart';
import 'auth_redirect.dart';

/// The app router. Re-evaluates [authRedirect] whenever the auth state
/// changes, so signing in/out moves the user to the right place.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, _) => refresh.value++);
  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) =>
        authRedirect(ref.read(authControllerProvider), state.uri),
    errorBuilder: (context, state) => SpotlightShell(
      location: state.uri.path,
      child: const PlaceholderPage(
        title: 'Page not found',
        phase: '',
        icon: Icons.explore_off_outlined,
        description: 'That page doesn’t exist or has moved.',
      ),
    ),
    routes: _routes,
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

String? _from(GoRouterState s) => safeReturnPath(s.uri.queryParameters['from']);

final _routes = <RouteBase>[
  // ---------- Spotlight: public + candidate ----------
  ShellRoute(
    builder: (context, state, child) =>
        SpotlightShell(location: state.uri.path, child: child),
    routes: [
      GoRoute(path: '/', builder: (_, _) => const HomePage()),
      _placeholder('/jobs', 'Job search', 'Phase 4', Icons.work_outline),
      _placeholder(
        '/companies',
        'Companies',
        'Phase 4',
        Icons.apartment_outlined,
      ),
      _placeholder('/news', 'Career news', 'Phase 8', Icons.newspaper_outlined),
      GoRoute(
        path: '/sign-in',
        builder: (_, s) => SignInPage(from: _from(s)),
      ),
      GoRoute(
        path: '/sign-up',
        builder: (_, s) => SignUpPage(
          from: _from(s),
          initialRole: s.uri.queryParameters['role'] == 'employer'
              ? AppRole.employer
              : AppRole.candidate,
        ),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (_, _) => const ForgotPasswordPage(),
      ),
      GoRoute(path: verifyPath, builder: (_, _) => const VerifyEmailPage()),
      GoRoute(path: chooseRolePath, builder: (_, _) => const ChooseRolePage()),
      GoRoute(path: loadingPath, builder: (_, _) => const AuthLoadingPage()),
      GoRoute(path: noAccessPath, builder: (_, _) => const NoAccessPage()),
      GoRoute(path: '/account', builder: (_, _) => const AccountPage()),
      GoRoute(path: '/dev/gallery', builder: (_, _) => const GalleryPage()),
      ShellRoute(
        builder: (context, state, child) =>
            CandidateArea(location: state.uri.path, child: child),
        routes: [
          _placeholder(
            '/me',
            'Your dashboard',
            'Phase 5',
            Icons.space_dashboard_outlined,
          ),
          _placeholder(
            '/me/applications',
            'Applications',
            'Phase 5',
            Icons.send_outlined,
          ),
          _placeholder(
            '/me/saved',
            'Saved jobs',
            'Phase 4',
            Icons.bookmark_border,
          ),
          _placeholder(
            '/me/interviews',
            'Interviews',
            'Phase 5',
            Icons.event_outlined,
          ),
          _placeholder(
            '/me/profile',
            'Profile & resume',
            'Phase 5',
            Icons.badge_outlined,
          ),
        ],
      ),
    ],
  ),

  // ---------- Workspace: employer ----------
  ShellRoute(
    builder: (context, state, child) => WorkspaceShell(
      title: 'Employer',
      destinations: employerDestinations,
      location: state.uri.path,
      child: child,
    ),
    routes: [
      for (final d in employerDestinations)
        _placeholder(d.path, d.label, 'Phase 6', d.icon),
    ],
  ),

  // ---------- Workspace: admin ----------
  ShellRoute(
    builder: (context, state, child) => WorkspaceShell(
      title: 'Admin',
      destinations: adminDestinations,
      location: state.uri.path,
      child: child,
    ),
    routes: [
      for (final d in adminDestinations)
        _placeholder(d.path, d.label, 'Phase 7', d.icon),
    ],
  ),
];

GoRoute _placeholder(String path, String title, String phase, IconData icon) =>
    GoRoute(
      path: path,
      pageBuilder: (context, state) => NoTransitionPage(
        key: state.pageKey,
        child: PlaceholderPage(title: title, phase: phase, icon: icon),
      ),
    );
