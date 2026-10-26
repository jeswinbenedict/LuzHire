import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/admin_people_pages.dart';
import '../../features/admin/presentation/admin_review_pages.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/presentation/account_flow_pages.dart';
import '../../features/auth/presentation/sign_in_page.dart';
import '../../features/auth/presentation/sign_up_page.dart';
import '../../features/candidate/candidate_area.dart';
import '../../features/candidate/presentation/applications_pages.dart';
import '../../features/candidate/presentation/dashboard_page.dart';
import '../../features/candidate/presentation/interviews_page.dart';
import '../../features/candidate/presentation/profile_page.dart';
import '../../features/companies/presentation/companies_pages.dart';
import '../../features/design_gallery/gallery_page.dart';
import '../../features/employer/presentation/company_page.dart';
import '../../features/employer/presentation/jobs_pages.dart';
import '../../features/employer/presentation/pipeline_page.dart';
import '../../features/employer/presentation/workspace_pages.dart';
import '../../features/events/presentation/events_pages.dart';
import '../../features/events/presentation/organizer_pages.dart';
import '../../features/home/home_page.dart';
import '../../features/jobs/data/jobs_repository.dart';
import '../../features/jobs/presentation/hiring_map_page.dart';
import '../../features/jobs/presentation/job_detail_page.dart';
import '../../features/jobs/presentation/job_search_page.dart';
import '../../features/jobs/presentation/saved_jobs_page.dart';
import '../../features/news/presentation/news_admin_page.dart';
import '../../features/news/presentation/news_pages.dart';
import '../../features/notifications/presentation/notification_settings_page.dart';
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
      GoRoute(
        path: '/jobs',
        builder: (_, s) => JobSearchPage(
          query: JobSearchQuery.fromUrlParams(s.uri.queryParameters),
        ),
      ),
      // Before /jobs/:slug, which would otherwise take "map" as a slug.
      GoRoute(path: '/jobs/map', builder: (_, _) => const HiringMapPage()),
      GoRoute(
        path: '/jobs/:slug',
        builder: (_, s) => JobDetailPage(slug: s.pathParameters['slug']!),
      ),
      GoRoute(
        path: '/companies',
        builder: (_, s) =>
            CompaniesPage(query: s.uri.queryParameters['q'] ?? ''),
      ),
      GoRoute(
        path: '/companies/:slug',
        builder: (_, s) => CompanyPage(slug: s.pathParameters['slug']!),
      ),
      GoRoute(
        path: '/events',
        builder: (_, s) => OpportunitiesPage(
          tab: s.uri.queryParameters['type'],
          mode: switch (s.uri.queryParameters['mode']) {
            final String m =>
              EventMode.values.where((x) => x.dbValue == m).firstOrNull,
            null => null,
          },
        ),
      ),
      GoRoute(
        path: '/events/:slug',
        builder: (_, s) => EventDetailPage(slug: s.pathParameters['slug']!),
      ),
      GoRoute(
        path: '/news',
        builder: (_, s) => NewsPage(topic: s.uri.queryParameters['topic']),
      ),
      GoRoute(
        path: '/news/:slug',
        builder: (_, s) => NewsArticlePage(slug: s.pathParameters['slug']!),
      ),
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
      GoRoute(
        path: '/account/notifications',
        builder: (_, _) => const NotificationSettingsPage(),
      ),
      GoRoute(path: '/dev/gallery', builder: (_, _) => const GalleryPage()),
      ShellRoute(
        builder: (context, state, child) =>
            CandidateArea(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: '/me',
            builder: (_, _) => const CandidateDashboardPage(),
          ),
          GoRoute(
            path: '/me/applications',
            builder: (_, _) => const ApplicationsPage(),
          ),
          GoRoute(
            path: '/me/applications/:id',
            builder: (_, s) =>
                ApplicationDetailPage(id: s.pathParameters['id']!),
          ),
          GoRoute(
            path: '/me/notifications',
            builder: (_, _) => const NotificationsPage(),
          ),
          GoRoute(path: '/me/saved', builder: (_, _) => const SavedJobsPage()),
          GoRoute(
            path: '/me/interviews',
            builder: (_, _) => const InterviewsPage(),
          ),
          GoRoute(path: '/me/profile', builder: (_, _) => const ProfilePage()),
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
      _page('/employer', (_) => const EmployerOverviewPage()),
      _page('/employer/jobs', (_) => const EmployerJobsPage()),
      _page('/employer/jobs/new', (_) => const JobEditorPage()),
      _page(
        '/employer/jobs/:id',
        (s) => JobEditorPage(jobId: s.pathParameters['id']),
      ),
      _page(
        '/employer/pipeline',
        (s) => PipelinePage(jobId: s.uri.queryParameters['job']),
      ),
      _page('/employer/interviews', (_) => const EmployerInterviewsPage()),
      _page('/employer/analytics', (_) => const EmployerAnalyticsPage()),
      _page('/employer/company', (_) => const EmployerCompanyPage()),
      _page('/employer/events', (_) => const EmployerEventsPage()),
      _page(
        '/employer/events/new',
        (s) => EventEditorPage(initialKind: _kindParam(s)),
      ),
      _page(
        '/employer/events/:id',
        (s) => EventEditorPage(eventId: s.pathParameters['id']),
      ),
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
      _page('/admin', (_) => const AdminOverviewPage()),
      _page('/admin/verification', (_) => const VerificationQueuePage()),
      _page(
        '/admin/moderation',
        (s) => ModerationPage(initialTab: s.uri.queryParameters['tab']),
      ),
      _page('/admin/users', (_) => const AdminUsersPage()),
      _page('/admin/announcements', (_) => const AnnouncementsAdminPage()),
      _page('/admin/news', (_) => const NewsAdminPage()),
      _page('/admin/events', (_) => const AdminEventsPage()),
      _page(
        '/admin/events/new',
        (s) => EventEditorPage(admin: true, initialKind: _kindParam(s)),
      ),
      _page(
        '/admin/events/:id',
        (s) => EventEditorPage(eventId: s.pathParameters['id'], admin: true),
      ),
      _page('/admin/audit', (_) => const AuditLogPage()),
    ],
  ),
];

/// Workspace pages switch without a transition, like the placeholders did.
GoRoute _page(String path, Widget Function(GoRouterState s) build) => GoRoute(
  path: path,
  pageBuilder: (context, state) =>
      NoTransitionPage(key: state.pageKey, child: build(state)),
);

/// `?kind=webinar` on a new-event link: the type to start the form with.
EventKind? _kindParam(GoRouterState s) {
  final v = s.uri.queryParameters['kind'];
  return v == null
      ? null
      : EventKind.values.where((k) => k.dbValue == v).firstOrNull;
}
