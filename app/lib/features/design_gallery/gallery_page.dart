import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/layout/breakpoints.dart';
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
  String _tab = 'all';
  bool _remoteOnly = true;
  String _type = 'full_time';
  RangeValues _salary = const RangeValues(6, 18);

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    final t = context.luzText;
    final mode = ref.watch(themeModeProvider);

    return ListView(
      padding: EdgeInsets.all(context.breakpoint.gutter),
      children: [
        Text('LuzHire design system', style: t.h3),
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
                      tooltip: _saved ? 'Remove from saved jobs' : 'Save job',
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

        // ---------------- Selection ----------------
        _Section(
          title: 'Selection & input',
          subtitle: 'Segmented tabs, checkbox, radio, range slider',
          child: Wrap(
            spacing: LuzSpace.xxl,
            runSpacing: LuzSpace.lg,
            children: [
              LuzSegmented<String>(
                segments: const [
                  (value: 'all', label: 'All', icon: null),
                  (value: 'remote', label: 'Remote', icon: Icons.public),
                  (
                    value: 'onsite',
                    label: 'On-site',
                    icon: Icons.apartment_outlined,
                  ),
                ],
                selected: _tab,
                onChanged: (v) => setState(() => _tab = v),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  LuzCheckbox(
                    value: _remoteOnly,
                    label: 'Remote only',
                    onChanged: (v) => setState(() => _remoteOnly = v),
                  ),
                  LuzRadio<String>(
                    value: 'full_time',
                    groupValue: _type,
                    label: 'Full-time',
                    onChanged: (v) => setState(() => _type = v),
                  ),
                  LuzRadio<String>(
                    value: 'internship',
                    groupValue: _type,
                    label: 'Internship',
                    onChanged: (v) => setState(() => _type = v),
                  ),
                ],
              ),
              SizedBox(
                width: 300,
                child: LuzRangeSlider(
                  min: 0,
                  max: 40,
                  values: _salary,
                  semanticLabel: 'Salary range',
                  format: (v) => '₹${v.round()} L',
                  onChanged: (v) => setState(() => _salary = v),
                ),
              ),
            ],
          ),
        ),

        // ---------------- Display ----------------
        const _Section(
          title: 'Identity & progress',
          subtitle: 'Avatar, logo socket, completeness groove',
          child: Wrap(
            spacing: LuzSpace.xl,
            runSpacing: LuzSpace.lg,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              LuzAvatar(name: 'Asha Verma', size: 48),
              LuzLogoSocket(name: 'Northwind'),
              SizedBox(
                width: 280,
                child: LuzProgressGroove(
                  value: 0.7,
                  label: 'Profile completeness',
                ),
              ),
            ],
          ),
        ),

        // ---------------- Feedback ----------------
        _Section(
          title: 'Feedback',
          subtitle: 'Skeletons, empty state, toast, adaptive modal',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(
                width: 360,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LuzSkeleton(width: 220, height: 18),
                    SizedBox(height: 10),
                    LuzSkeleton(height: 12),
                    SizedBox(height: 8),
                    LuzSkeleton(width: 280, height: 12),
                  ],
                ),
              ),
              const SizedBox(height: LuzSpace.lg),
              Wrap(
                spacing: LuzSpace.md,
                runSpacing: LuzSpace.md,
                children: [
                  LuzButton(
                    label: 'Show toast',
                    icon: Icons.notifications_none,
                    onPressed: () => showLuzToast(
                      context,
                      'Job saved to your list',
                      icon: Icons.bookmark,
                      actionLabel: 'Undo',
                    ),
                  ),
                  LuzButton(
                    label: 'Open modal',
                    icon: Icons.open_in_new,
                    onPressed: () => confirmLuz(
                      context,
                      title: 'Delete this draft?',
                      message: 'The draft job and its notes will be removed. This can’t be undone.',
                      confirmLabel: 'Delete draft',
                      icon: Icons.delete_outline,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: LuzSpace.md),
              const LuzEmptyState(
                icon: Icons.bookmark_border,
                title: 'No saved jobs yet',
                message: 'Tap the bookmark on any job to keep it here.',
              ),
            ],
          ),
        ),

        // ---------------- Workspace data ----------------
        _Section(
          title: 'Workspace data',
          subtitle: 'Sortable table (stacks on phones) and kanban trays',
          child: LuzZone(
            kind: LuzZoneKind.workspace,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LuzDataTable<_Applicant>(
                  columns: [
                    LuzColumn(
                      label: 'Candidate',
                      flex: 3,
                      sortKey: (r) => r.name,
                      cell: (c, r) => Row(
                        children: [
                          LuzAvatar(name: r.name, size: 30),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              r.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    LuzColumn(
                      label: 'Stage',
                      flex: 3,
                      cell: (c, r) => LuzStatusChip.stage(r.stage),
                    ),
                    LuzColumn(
                      label: 'Match',
                      flex: 2,
                      numeric: true,
                      sortKey: (r) => r.match,
                      cell: (c, r) => Text('${r.match}%'),
                    ),
                  ],
                  rows: _sampleApplicants,
                ),
                const SizedBox(height: LuzSpace.lg),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final stage in const [
                        ApplicationStage.applied,
                        ApplicationStage.shortlisted,
                        ApplicationStage.technicalInterview,
                      ]) ...[
                        LuzKanbanColumn(
                          header: LuzStatusChip.stage(stage),
                          count: _sampleApplicants
                              .where((a) => a.stage == stage)
                              .length,
                          children: [
                            for (final a in _sampleApplicants.where(
                              (a) => a.stage == stage,
                            ))
                              LuzCard(
                                padding: const EdgeInsets.all(LuzSpace.sm),
                                depth: LuzDepth.raisedXs,
                                child: Row(
                                  children: [
                                    LuzAvatar(name: a.name, size: 32),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(a.name, style: t.wsCardTitle),
                                    ),
                                    Text(
                                      '${a.match}%',
                                      style: t.caption.copyWith(color: p.muted),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: LuzSpace.md),
                      ],
                    ],
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
              for (final s in ApplicationStage.values) LuzStatusChip.stage(s),
            ],
          ),
        ),
      ],
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

/// Sample rows for the gallery only (not real data).
class _Applicant {
  const _Applicant(this.name, this.stage, this.match);
  final String name;
  final ApplicationStage stage;
  final int match;
}

const _sampleApplicants = [
  _Applicant('Asha Verma', ApplicationStage.applied, 82),
  _Applicant('Rahul Iyer', ApplicationStage.shortlisted, 91),
  _Applicant('Meera Nair', ApplicationStage.technicalInterview, 76),
  _Applicant('Karthik Rao', ApplicationStage.applied, 68),
];
