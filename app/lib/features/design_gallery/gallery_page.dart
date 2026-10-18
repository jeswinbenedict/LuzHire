import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_mode_provider.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';

/// Phase 1 deliverable: every core component in both zones and both themes.
class GalleryPage extends ConsumerStatefulWidget {
  const GalleryPage({super.key});

  @override
  ConsumerState<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends ConsumerState<GalleryPage> {
  final _filters = <String>{'Remote'};
  bool _saved = false;
  bool _alerts = true;

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    final t = context.luzText;
    final mode = ref.watch(themeModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(LuzSpace.lg),
          children: [
            Row(
              children: [
                Expanded(child: Text('LuzHire design system', style: t.h3)),
                LuzIconButton(
                  icon: isDark
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                  tooltip: isDark
                      ? 'Switch to light theme'
                      : 'Switch to dark theme',
                  onPressed: () => ref
                      .read(themeModeProvider.notifier)
                      .set(isDark ? ThemeMode.light : ThemeMode.dark),
                ),
              ],
            ),
            const SizedBox(height: LuzSpace.xs),
            Text(
              'Accessible neumorphism · theme: ${mode.name}',
              style: t.bodySm.copyWith(color: p.muted),
            ),
            const SizedBox(height: LuzSpace.xl),

            // ---------------- Spotlight ----------------
            _Section(
              title: 'Spotlight zone',
              subtitle: 'Public and candidate screens',
              child: LuzZone(
                kind: LuzZoneKind.spotlight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: LuzSpace.lg,
                      runSpacing: LuzSpace.lg,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        LuzButton.accent(
                          label: 'Search jobs',
                          icon: Icons.search,
                          onPressed: () {},
                        ),
                        LuzButton(label: 'Sign in', onPressed: () {}),
                        const LuzButton(label: 'Disabled', onPressed: null),
                        LuzIconButton(
                          icon: _saved ? Icons.bookmark : Icons.bookmark_border,
                          tooltip: _saved
                              ? 'Remove from saved jobs'
                              : 'Save job',
                          selected: _saved,
                          onPressed: () => setState(() => _saved = !_saved),
                        ),
                        LuzToggle(
                          value: _alerts,
                          semanticLabel: 'Job alerts',
                          onChanged: (v) => setState(() => _alerts = v),
                        ),
                      ],
                    ),
                    const SizedBox(height: LuzSpace.lg),
                    Wrap(
                      spacing: LuzSpace.sm,
                      runSpacing: LuzSpace.sm,
                      children: [
                        for (final f in [
                          'Remote',
                          'Full-time',
                          'Internship',
                          'Entry level',
                        ])
                          LuzFilterChip(
                            label: f,
                            selected: _filters.contains(f),
                            onSelected: (v) => setState(
                              () => v ? _filters.add(f) : _filters.remove(f),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: LuzSpace.lg),
                    const SizedBox(
                      width: 420,
                      child: LuzTextField(
                        label: 'Job title or keyword',
                        hint: 'e.g. Flutter developer',
                        prefixIcon: Icons.search,
                        helper: 'Search across 10,000+ verified roles',
                      ),
                    ),
                    const SizedBox(height: LuzSpace.md),
                    const SizedBox(
                      width: 420,
                      child: LuzTextField(
                        label: 'Email',
                        hint: 'you@example.com',
                        error: 'Enter a valid email address',
                      ),
                    ),
                    const SizedBox(height: LuzSpace.xl),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: _SampleJobCard(saved: _saved),
                    ),
                  ],
                ),
              ),
            ),

            // ---------------- Workspace ----------------
            _Section(
              title: 'Workspace zone',
              subtitle: 'Employer and admin screens',
              child: LuzZone(
                kind: LuzZoneKind.workspace,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: LuzSpace.md,
                      runSpacing: LuzSpace.md,
                      children: [
                        LuzButton.accent(
                          label: 'Post a job',
                          icon: Icons.add,
                          onPressed: () {},
                        ),
                        LuzButton(
                          label: 'Export',
                          icon: Icons.download_outlined,
                          onPressed: () {},
                        ),
                        LuzButton(
                          label: 'Archive',
                          icon: Icons.archive_outlined,
                          onPressed: () {},
                        ),
                      ],
                    ),
                    const SizedBox(height: LuzSpace.lg),
                    Wrap(
                      spacing: LuzSpace.md,
                      runSpacing: LuzSpace.md,
                      children: const [
                        _StatTile(label: 'Open roles', value: '12'),
                        _StatTile(label: 'New applicants', value: '48'),
                        _StatTile(label: 'Interviews this week', value: '7'),
                      ],
                    ),
                    const SizedBox(height: LuzSpace.lg),
                    const SizedBox(
                      width: 320,
                      child: LuzTextField(
                        label: 'Filter candidates',
                        hint: 'Name or skill',
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ---------------- Stages ----------------
            _Section(
              title: 'Application stages',
              subtitle: 'Inset status chips — colour, icon and text',
              child: Wrap(
                spacing: LuzSpace.sm,
                runSpacing: LuzSpace.sm,
                children: [
                  for (final s in ApplicationStage.values)
                    LuzStatusChip.stage(s),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.subtitle,
    required this.child,
  });
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.luzText;
    return Padding(
      padding: const EdgeInsets.only(bottom: LuzSpace.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: t.eyebrow.copyWith(color: context.luz.accent),
          ),
          const SizedBox(height: LuzSpace.xxs),
          Text(subtitle, style: t.bodySm.copyWith(color: context.luz.muted)),
          const SizedBox(height: LuzSpace.lg),
          child,
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = context.luzText;
    return SizedBox(
      width: 180,
      child: LuzCard(
        padding: const EdgeInsets.all(LuzSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: t.caption.copyWith(color: context.luz.muted)),
            const SizedBox(height: LuzSpace.xs),
            Text(value, style: t.wsTitle),
          ],
        ),
      ),
    );
  }
}

class _SampleJobCard extends StatelessWidget {
  const _SampleJobCard({required this.saved});
  final bool saved;

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    final t = context.luzText;
    return LuzCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LuzSurface(
                depth: LuzDepth.insetSm,
                radius: LuzRadius.sm,
                child: SizedBox.square(
                  dimension: 48,
                  child: Center(
                    child: Text('A', style: t.h4.copyWith(color: p.accent)),
                  ),
                ),
              ),
              const SizedBox(width: LuzSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Flutter Developer', style: t.h4),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          'Acme Labs',
                          style: t.bodySm.copyWith(color: p.inkMuted),
                        ),
                        const SizedBox(width: LuzSpace.xs),
                        const LuzStatusChip(
                          label: 'Verified',
                          tone: LuzChipTone.green,
                          icon: Icons.verified_outlined,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const LuzDial(value: 0.86),
            ],
          ),
          const SizedBox(height: LuzSpace.md),
          const Wrap(
            spacing: LuzSpace.xs,
            runSpacing: LuzSpace.xs,
            children: [
              LuzStatusChip(
                label: 'Bengaluru · Hybrid',
                tone: LuzChipTone.neutral,
                icon: Icons.place_outlined,
              ),
              LuzStatusChip(
                label: 'Full-time',
                tone: LuzChipTone.neutral,
                icon: Icons.work_outline,
              ),
              LuzStatusChip(
                label: '₹12–18 L / year',
                tone: LuzChipTone.neutral,
                icon: Icons.payments_outlined,
              ),
            ],
          ),
          const SizedBox(height: LuzSpace.md),
          Text(
            'Build cross-platform hiring tools with Flutter, Supabase and realtime sync. '
            'Sample content for the design gallery.',
            style: t.bodySm.copyWith(color: p.inkMuted),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: LuzSpace.md),
          Row(
            children: [
              Text(
                'Posted 2 hours ago',
                style: t.caption.copyWith(color: p.muted),
              ),
              const Spacer(),
              LuzButton.accent(label: 'Apply', onPressed: () {}),
            ],
          ),
        ],
      ),
    );
  }
}
