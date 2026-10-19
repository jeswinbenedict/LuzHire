import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/layout/breakpoints.dart';
import '../../core/layout/content.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';

/// Phase 1 home: hero + search wired to /jobs. Real content (categories,
/// live job counts) arrives in Phase 4. No invented statistics.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    final t = context.luzText;
    final bp = context.breakpoint;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ColoredBox(
            color: p.baseTint,
            child: LuzContent(
              vertical: bp.pick(
                compact: LuzSpace.xxl,
                expanded: LuzSpace.section,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FIND WORK THAT FITS',
                    style: t.eyebrow.copyWith(color: p.accent),
                  ),
                  const SizedBox(height: LuzSpace.md),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Text(
                      'Verified jobs. One profile. Every application tracked live.',
                      style: bp.isCompact ? t.h2 : t.h1,
                    ),
                  ),
                  const SizedBox(height: LuzSpace.md),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: Text(
                      'Search roles from verified employers, apply in a few taps, '
                      'and watch your application move through each stage in real time.',
                      style: t.bodyLg.copyWith(color: p.inkMuted),
                    ),
                  ),
                  const SizedBox(height: LuzSpace.xl),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 860),
                    child: LuzSearchBar(
                      onSearch: (kw, loc) => context.go(
                        Uri(
                          path: '/jobs',
                          queryParameters: {
                            if (kw.isNotEmpty) 'q': kw,
                            if (loc.isNotEmpty) 'location': loc,
                          },
                        ).toString(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          LuzContent(
            vertical: LuzSpace.xxl,
            child: LuzGrid(
              children: const [
                _Pillar(
                  icon: Icons.verified_outlined,
                  title: 'Verified employers',
                  body: 'Every company is reviewed before its jobs go live.',
                ),
                _Pillar(
                  icon: Icons.bolt_outlined,
                  title: 'Real-time tracking',
                  body: 'Stage changes, interviews and offers appear the moment they happen.',
                ),
                _Pillar(
                  icon: Icons.devices_outlined,
                  title: 'Any device',
                  body: 'The same account on web, Android and iOS, in light or dark.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pillar extends StatelessWidget {
  const _Pillar({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    return LuzCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LuzSurface(
            depth: LuzDepth.insetSm,
            radius: LuzRadius.md,
            child: SizedBox.square(
              dimension: 48,
              child: Icon(icon, color: p.accent),
            ),
          ),
          const SizedBox(height: LuzSpace.md),
          Text(title, style: context.luzText.h4),
          const SizedBox(height: LuzSpace.xs),
          Text(body, style: context.luzText.body.copyWith(color: p.inkMuted)),
        ],
      ),
    );
  }
}
