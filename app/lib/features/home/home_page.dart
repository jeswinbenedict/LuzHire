import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/layout/breakpoints.dart';
import '../../core/layout/content.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';

/// Public home, translated from the Stitch design `docs/design/stitch/
/// home-desktop.png` / `home-mobile.png`. Live counts, featured jobs and the
/// "new jobs" banner need data and arrive in Phase 4. No invented statistics.
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
      Uri(
        path: '/jobs',
        queryParameters: {
          if (keyword.isNotEmpty) 'q': keyword,
          if (loc != null && loc.isNotEmpty) 'location': loc,
        },
      ).toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [_Hero(), _Disciplines(), _EmployerBand()],
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
                Text(
                  'Verified employers only',
                  style: t.caption.copyWith(color: p.ink),
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
                Text('Browse jobs', style: t.label.copyWith(color: p.ink)),
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
