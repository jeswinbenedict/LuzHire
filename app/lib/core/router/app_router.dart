import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/candidate/candidate_area.dart';
import '../../features/design_gallery/gallery_page.dart';
import '../../features/home/home_page.dart';
import '../shell/destinations.dart';
import '../shell/shell_common.dart';
import '../shell/spotlight_shell.dart';
import '../shell/workspace_shell.dart';

/// Routes per docs/ROADMAP.md. Pages marked with a phase are placeholders.
/// Role guards (candidate / employer / admin) arrive with auth in Phase 3.
GoRouter createRouter() => GoRouter(
  initialLocation: '/',
  errorBuilder: (context, state) => SpotlightShell(
    location: state.uri.path,
    child: const PlaceholderPage(
      title: 'Page not found',
      phase: '',
      icon: Icons.explore_off_outlined,
      description: 'That page doesn’t exist or has moved.',
    ),
  ),
  routes: [
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
        _placeholder(
          '/news',
          'Career news',
          'Phase 8',
          Icons.newspaper_outlined,
        ),
        _placeholder('/sign-in', 'Sign in', 'Phase 3', Icons.login),
        _placeholder(
          '/sign-up',
          'Create your account',
          'Phase 3',
          Icons.person_add_alt,
        ),
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
  ],
);

GoRoute _placeholder(String path, String title, String phase, IconData icon) =>
    GoRoute(
      path: path,
      pageBuilder: (context, state) => NoTransitionPage(
        key: state.pageKey,
        child: PlaceholderPage(title: title, phase: phase, icon: icon),
      ),
    );
