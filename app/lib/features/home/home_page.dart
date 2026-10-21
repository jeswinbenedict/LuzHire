import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/layout/breakpoints.dart';
import '../../core/layout/content.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../jobs/application/job_board_providers.dart';
import '../jobs/data/jobs_repository.dart';
import '../jobs/presentation/job_widgets.dart';
import '../jobs/application/location_providers.dart';
import '../auth/application/auth_controller.dart';
import '../auth/domain/auth_state.dart';
import '../../core/data/enums.dart';
import '../companies/data/companies_repository.dart';
import '../news/presentation/news_pages.dart' show HomeNewsSection;
import '../companies/presentation/companies_pages.dart' show openRolesLabel;
import '../../core/data/failures.dart';
import '../../core/data/models.dart';
import '../../core/router/links.dart';
import '../admin/presentation/admin_people_pages.dart' show AnnouncementsBanner;

/// Public home, translated from the Stitch design `docs/design/stitch/
/// home-desktop.png` / `home-mobile.png`.
/// The latest-jobs section shows real postings only and hides itself when
/// there are none. No invented statistics.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static const popularSearches = [
    'Flutter developer',
    'Data analyst',
    'Product designer',
    'Backend engineer',
    'Internship',
    'Remote',
  ];

  static void _search(BuildContext context, String keyword, [String? loc]) {
    context.go(
      pathWithQuery('/jobs', {
        if (keyword.isNotEmpty) 'q': keyword,
        if (loc != null && loc.isNotEmpty) 'location': loc,
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LuzContent(vertical: 0, child: AnnouncementsBanner()),
          _Hero(),
          _PickedForYou(),
          _LatestJobs(),
          _MapInvite(),
          _HiringCompanies(),
          HomeNewsSection(),
          _Disciplines(),
          _EmployerBand(),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    final t = context.luzText;
    final bp = context.breakpoint;
    final centered = !bp.isCompact;
    final align = centered
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start;
    final textAlign = centered ? TextAlign.center : TextAlign.start;

    return LuzContent(
      vertical: bp.pick(compact: LuzSpace.xl, expanded: LuzSpace.section),
      child: Column(
        crossAxisAlignment: align,
        children: [
          LuzSurface(
            depth: LuzDepth.raisedXs,
            radius: LuzRadius.pill,
            padding: const EdgeInsets.symmetric(
              horizontal: LuzSpace.sm,
              vertical: LuzSpace.xxs + 2,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_outlined, size: 16, color: p.accent),
                const SizedBox(width: LuzSpace.xs),
                Flexible(
                  child: Text(
                    'Verified employers only',
                    style: t.caption.copyWith(color: p.ink),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: LuzSpace.lg),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Text(
              'Find work that fits your life',
              textAlign: textAlign,
              style: bp.isCompact ? t.h2 : t.display,
            ),
          ),
          const SizedBox(height: LuzSpace.md),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Text(
              'Search roles from verified employers, apply in a few taps, '
              'and watch every application move through its stages in real time.',
              textAlign: textAlign,
              style: t.bodyLg.copyWith(color: p.inkMuted),
            ),
          ),
          const SizedBox(height: LuzSpace.xl),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: LuzSearchBar(
              onSearch: (kw, loc) => HomePage._search(context, kw, loc),
            ),
          ),
          const SizedBox(height: LuzSpace.lg),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Wrap(
              alignment: centered ? WrapAlignment.center : WrapAlignment.start,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: LuzSpace.xs,
              runSpacing: LuzSpace.xs,
              children: [
                Text('Popular:', style: t.label.copyWith(color: p.inkMuted)),
                for (final q in HomePage.popularSearches)
                  LuzFilterChip(
                    label: q,
                    selected: false,
                    onSelected: (_) => HomePage._search(context, q),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Signed-in candidates: jobs ranked from their profile, with the reasons.
class _PickedForYou extends ConsumerWidget {
  const _PickedForYou();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    if (auth is! SignedIn || auth.user.appRole != AppRole.candidate) {
      return const SizedBox.shrink();
    }
    final jobs = (ref.watch(recommendedJobsProvider).value ?? const [])
        .where((j) => j.matchReasons.any((r) => r != 'New this week'))
        .take(6)
        .toList();
    final p = context.luz;
    final t = context.luzText;
    return LuzContent(
      vertical: LuzSpace.xl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PICKED FOR YOU', style: t.eyebrow.copyWith(color: p.accent)),
          const SizedBox(height: LuzSpace.xs),
          Text('Recommended from your profile', style: t.h3),
          const SizedBox(height: LuzSpace.lg),
          if (jobs.isEmpty)
            LuzCard(
              child: Wrap(
                spacing: LuzSpace.md,
                runSpacing: LuzSpace.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Add your skills, headline and city to get jobs matched '
                    'to you.',
                    style: t.body.copyWith(color: p.inkMuted),
                  ),
                  LuzTextLink(
                    label: 'Complete your profile →',
                    onPressed: () => context.go('/me/profile'),
                  ),
                ],
              ),
            )
          else
            LuzGrid(children: [for (final j in jobs) JobCard(job: j)]),
        ],
      ),
    );
  }
}

/// Invitation to the hiring map.
class _MapInvite extends StatelessWidget {
  const _MapInvite();

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    final t = context.luzText;
    return LuzContent(
      vertical: LuzSpace.lg,
      child: LuzCard(
        child: Wrap(
          spacing: LuzSpace.lg,
          runSpacing: LuzSpace.md,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.map_outlined, color: p.accent, size: 36),
                const SizedBox(width: LuzSpace.md),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Where is hiring happening?', style: t.h4),
                      Text(
                        'See open roles city by city, and jobs near you.',
                        style: t.body.copyWith(color: p.inkMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            LuzButton.accent(
              label: 'Open the hiring map',
              icon: Icons.arrow_forward,
              onPressed: () => context.go('/jobs/map'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Newest six published jobs (Stitch: "featured roles" grid).
class _LatestJobs extends ConsumerWidget {
  const _LatestJobs();

  static const query = JobSearchQuery(pageSize: 6);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs = ref.watch(jobSearchProvider(query)).jobs;
    if (jobs.isEmpty) return const SizedBox.shrink();
    final p = context.luz;
    final t = context.luzText;
    return LuzContent(
      vertical: LuzSpace.xl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('JUST POSTED', style: t.eyebrow.copyWith(color: p.accent)),
          const SizedBox(height: LuzSpace.xs),
          // Wraps under the heading when large text leaves no room.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: LuzSpace.md,
            children: [
              Text('Latest jobs', style: t.h3),
              LuzTextLink(
                label: 'See all jobs →',
                onPressed: () => context.go('/jobs'),
              ),
            ],
          ),
          const SizedBox(height: LuzSpace.lg),
          LuzGrid(children: [for (final j in jobs) JobCard(job: j)]),
        ],
      ),
    );
  }
}

/// Logos of the companies with the most open roles; each opens its page.
class _HiringCompanies extends ConsumerWidget {
  const _HiringCompanies();

  static const shown = 8;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companies = ref
        .watch(companyListProvider(''))
        .companies
        .where((c) => (c.openJobs ?? 0) > 0)
        .take(shown)
        .toList();
    if (companies.isEmpty) return const SizedBox.shrink();
    final p = context.luz;
    final t = context.luzText;
    String? logo(Company c) {
      try {
        return ref.watch(companiesRepositoryProvider).logoUrl(c);
      } on AppFailure {
        return null;
      }
    }

    return LuzContent(
      vertical: LuzSpace.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('HIRING NOW', style: t.eyebrow.copyWith(color: p.accent)),
          const SizedBox(height: LuzSpace.xs),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: LuzSpace.md,
            children: [
              Text('Companies hiring now', style: t.h3),
              LuzTextLink(
                label: 'All companies →',
                onPressed: () => context.go('/companies'),
              ),
            ],
          ),
          const SizedBox(height: LuzSpace.lg),
          Wrap(
            spacing: LuzSpace.md,
            runSpacing: LuzSpace.md,
            children: [
              for (final c in companies)
                SizedBox(
                  width: 132,
                  child: LuzPressable(
                    radius: LuzRadius.lg,
                    semanticLabel: '${c.name}, ${openRolesLabel(c.openJobs!)}',
                    onPressed: () => context.go('/companies/${c.slug}'),
                    builder: (context, pressed, hovered) => LuzSurface(
                      depth: pressed
                          ? LuzDepth.insetSm
                          : hovered
                          ? LuzDepth.raisedLg
                          : LuzDepth.raisedMd,
                      radius: LuzRadius.lg,
                      padding: const EdgeInsets.all(LuzSpace.sm),
                      child: Column(
                        children: [
                          LuzLogoSocket(
                            name: c.name,
                            logoUrl: logo(c),
                            size: 56,
                          ),
                          const SizedBox(height: LuzSpace.xs),
                          Text(
                            c.name,
                            style: t.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            openRolesLabel(c.openJobs!),
                            style: t.caption.copyWith(color: p.inkMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Discipline {
  const _Discipline(this.icon, this.title, this.skills, this.query);
  final IconData icon;
  final String title;
  final String skills;
  final String query;
}

class _Disciplines extends StatelessWidget {
  const _Disciplines();

  static const items = [
    _Discipline(
      Icons.code,
      'Software engineering',
      'Flutter, Go, Java, cloud, distributed systems',
      'software engineer',
    ),
    _Discipline(
      Icons.insights_outlined,
      'Data & AI',
      'Analytics, machine learning, data engineering',
      'data',
    ),
    _Discipline(
      Icons.space_dashboard_outlined,
      'Product management',
      'Product, growth and technical PM roles',
      'product manager',
    ),
    _Discipline(
      Icons.palette_outlined,
      'UI/UX design',
      'Design systems, interaction, user research',
      'designer',
    ),
    _Discipline(
      Icons.trending_up,
      'Growth & marketing',
      'Performance, content, developer relations',
      'marketing',
    ),
    _Discipline(
      Icons.account_balance_outlined,
      'Finance & FinTech',
      'Payments, risk, accounting and operations',
      'finance',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    final t = context.luzText;
    return LuzContent(
      vertical: LuzSpace.xl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('DISCOVER', style: t.eyebrow.copyWith(color: p.accent)),
          const SizedBox(height: LuzSpace.xs),
          Text('Explore by discipline', style: t.h3),
          const SizedBox(height: LuzSpace.lg),
          LuzGrid(children: [for (final d in items) _DisciplineTile(d)]),
        ],
      ),
    );
  }
}

class _DisciplineTile extends StatelessWidget {
  const _DisciplineTile(this.d);
  final _Discipline d;

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    final t = context.luzText;
    return LuzPressable(
      radius: LuzRadius.lg,
      semanticLabel: 'Search ${d.title} jobs',
      onPressed: () => HomePage._search(context, d.query),
      builder: (context, pressed, hovered) => LuzSurface(
        depth: pressed
            ? LuzDepth.insetSm
            : hovered
            ? LuzDepth.raisedLg
            : LuzDepth.raisedMd,
        radius: LuzRadius.lg,
        padding: const EdgeInsets.all(LuzSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LuzSurface(
              depth: LuzDepth.insetSm,
              radius: LuzRadius.md,
              child: SizedBox.square(
                dimension: 44,
                child: Icon(d.icon, color: p.accent),
              ),
            ),
            const SizedBox(height: LuzSpace.md),
            Text(d.title, style: t.h4),
            const SizedBox(height: LuzSpace.xxs),
            // Two lines reserved so tiles in a row keep the same height.
            ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.textScalerOf(
                  context,
                ).scale((t.body.fontSize ?? 14) * (t.body.height ?? 1.5) * 2),
              ),
              child: Text(d.skills, style: t.body.copyWith(color: p.inkMuted)),
            ),
            const SizedBox(height: LuzSpace.sm),
            Row(
              children: [
                Flexible(
                  child: Text(
                    'Browse jobs',
                    style: t.label.copyWith(color: p.ink),
                  ),
                ),
                const SizedBox(width: LuzSpace.xxs),
                Icon(Icons.arrow_forward, size: 16, color: p.ink),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmployerBand extends StatelessWidget {
  const _EmployerBand();

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    final t = context.luzText;
    final bp = context.breakpoint;
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('FOR EMPLOYERS', style: t.eyebrow.copyWith(color: p.accent)),
        const SizedBox(height: LuzSpace.xs),
        Text('Hiring? Post a role in minutes.', style: t.h3),
        const SizedBox(height: LuzSpace.xs),
        Text(
          'Verified company profile, a realtime hiring pipeline, interviews '
          'and offers in one workspace.',
          style: t.body.copyWith(color: p.inkMuted),
        ),
      ],
    );
    final actions = Wrap(
      spacing: LuzSpace.sm,
      runSpacing: LuzSpace.sm,
      children: [
        LuzButton(
          label: 'Post a job',
          variant: LuzButtonVariant.accent,
          onPressed: () => context.go('/sign-up?role=employer'),
        ),
        LuzButton(
          label: 'Explore the workspace',

          onPressed: () => context.go('/employer'),
        ),
      ],
    );

    return LuzContent(
      vertical: LuzSpace.xxl,
      child: LuzSurface(
        depth: LuzDepth.raisedMd,
        radius: LuzRadius.xl,
        color: p.baseTint,
        padding: EdgeInsets.all(
          bp.pick(compact: LuzSpace.lg, expanded: LuzSpace.xl),
        ),
        child: bp.isCompact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  copy,
                  const SizedBox(height: LuzSpace.lg),
                  actions,
                ],
              )
            : Row(
                children: [
                  Expanded(child: copy),
                  const SizedBox(width: LuzSpace.xl),
                  actions,
                ],
              ),
      ),
    );
  }
}
