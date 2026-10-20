import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/enums.dart';
import '../../../core/data/failures.dart';
import '../../../core/data/format.dart';
import '../../../core/data/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../application/job_board_providers.dart';
import '../data/jobs_repository.dart';

import 'package:url_launcher/url_launcher.dart';

/// Job card from the Stitch search/home designs: logo socket, title, company,
/// place, salary (mono) and a save bookmark. [selected] adds the orange
/// indicator used in the two-pane list.
class JobCard extends StatelessWidget {
  const JobCard({super.key, required this.job, this.selected, this.onTap});

  final Job job;
  final bool? selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    final t = context.luzText;
    final salary = formatSalary(job);
    final place = formatPlace(job);
    final isSelected = selected ?? false;

    return LuzPressable(
      radius: LuzRadius.lg,
      selected: selected,
      semanticLabel: '${job.title} at ${job.companyName}',
      onPressed: onTap ?? () => context.go('/jobs/${job.slug}'),
      builder: (context, pressed, hovered) => LuzSurface(
        depth: pressed
            ? LuzDepth.insetSm
            : hovered
            ? LuzDepth.raisedLg
            : LuzDepth.raisedMd,
        radius: LuzRadius.lg,
        outline: isSelected ? p.accent : null,
        outlineWidth: 2,
        padding: const EdgeInsets.all(LuzSpace.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isSelected) ...[
              Container(
                width: 4,
                height: 56,
                decoration: BoxDecoration(
                  color: p.accent,
                  borderRadius: BorderRadius.circular(LuzRadius.pill),
                ),
              ),
              const SizedBox(width: LuzSpace.sm),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LuzLogoSocket(
                        name: job.companyName,
                        logoUrl: job.logoUrl,
                        size: 44,
                      ),
                      const SizedBox(width: LuzSpace.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              job.title,
                              style: t.h4,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              job.companyName,
                              style: t.body.copyWith(color: p.inkMuted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: LuzSpace.xs),
                      SaveJobButton(job: job),
                    ],
                  ),
                  const SizedBox(height: LuzSpace.sm),
                  Wrap(
                    spacing: LuzSpace.xs,
                    runSpacing: LuzSpace.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (place.isNotEmpty)
                        _Meta(icon: Icons.place_outlined, label: place),
                      LuzStatusChip(
                        label: job.employmentType.label,
                        tone: LuzChipTone.neutral,
                      ),
                      if (job.experienceLevel != null)
                        LuzStatusChip(
                          label: job.experienceLevel!.label,
                          tone: LuzChipTone.neutral,
                        ),
                    ],
                  ),
                  const SizedBox(height: LuzSpace.sm),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          salary ?? 'Salary not disclosed',
                          style: salary == null
                              ? t.bodySm.copyWith(color: p.muted)
                              : t.mono.copyWith(
                                  color: p.ink,
                                  fontWeight: FontWeight.w600,
                                ),
                        ),
                      ),
                      if (job.publishedAt != null)
                        Text(
                          formatRelative(job.publishedAt!),
                          style: t.caption.copyWith(color: p.muted),
                        ),
                    ],
                  ),
                  if (job.isExternal &&
                      jobSource(job.externalSource) != null) ...[
                    const SizedBox(height: LuzSpace.xxs),
                    SourceAttribution(
                      source: job.externalSource,
                      compact: true,
                    ),
                  ],
                  if (job.matchReasons.isNotEmpty ||
                      job.distanceKm != null) ...[
                    const SizedBox(height: LuzSpace.xs),
                    Wrap(
                      spacing: LuzSpace.xs,
                      runSpacing: LuzSpace.xxs,
                      children: [
                        if (job.distanceKm != null)
                          LuzStatusChip(
                            label: job.distanceKm! < 1
                                ? 'Under 1 km away'
                                : '${job.distanceKm!.round()} km away',
                            tone: LuzChipTone.blue,
                            icon: Icons.near_me_outlined,
                          ),
                        for (final r in job.matchReasons.take(2))
                          LuzStatusChip(
                            label: r,
                            tone: LuzChipTone.orange,
                            icon: Icons.auto_awesome_outlined,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: p.inkMuted),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            style: context.luzText.bodySm.copyWith(color: p.inkMuted),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Bookmark toggle. Visitors are offered sign-in instead.
class SaveJobButton extends ConsumerWidget {
  const SaveJobButton({super.key, required this.job, this.expanded = false});

  final Job job;

  /// A labelled button ("Save" / "Saved") instead of the icon.
  final bool expanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(isJobSavedProvider(job.id));
    Future<void> toggle() async {
      try {
        await ref.read(savedJobsControllerProvider.notifier).toggle(job.id);
      } on AppFailure catch (e) {
        if (!context.mounted) return;
        if (e.code == 'signed_out') {
          final from = GoRouterState.of(context).uri.toString();
          showLuzToast(
            context,
            'Sign in to save jobs and see them on every device.',
            icon: Icons.bookmark_border,
            actionLabel: 'Sign in',
            onAction: () => context.go(
              Uri(path: '/sign-in', queryParameters: {'from': from}).toString(),
            ),
          );
        } else {
          showLuzToast(context, e.message, icon: Icons.error_outline);
        }
      }
    }

    final icon = saved ? Icons.bookmark : Icons.bookmark_border;
    if (expanded) {
      return LuzButton(
        label: saved ? 'Saved' : 'Save',
        icon: icon,
        onPressed: toggle,
      );
    }
    return LuzIconButton(
      icon: icon,
      tooltip: saved ? 'Remove from saved jobs' : 'Save job',
      selected: saved,
      size: 40,
      onPressed: toggle,
    );
  }
}

/// Search filters (Stitch: left panel on desktop, bottom sheet on phones).
/// Every change is applied at once through [onChanged].
class JobFilters extends ConsumerWidget {
  const JobFilters({super.key, required this.query, required this.onChanged});

  final JobSearchQuery query;
  final ValueChanged<JobSearchQuery> onChanged;

  static const salaryOptions = <num?>[null, 300000, 600000, 1000000, 2000000];
  static const postedOptions = <int>[0, 1, 7, 30];

  static String salaryLabel(num? v) =>
      v == null ? 'Any' : '₹${(v / 100000).round()} L+';

  static String postedLabel(int days) => switch (days) {
    0 => 'Any time',
    1 => 'Past 24 hours',
    7 => 'Past week',
    _ => 'Past month',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.luz;
    final t = context.luzText;
    final skills = ref.watch(skillsProvider).value ?? const [];

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: LuzSpace.lg, bottom: LuzSpace.xs),
      child: Text(
        text.toUpperCase(),
        style: t.eyebrow.copyWith(color: p.inkMuted),
      ),
    );

    Set<T> toggled<T>(Set<T> set, T v) =>
        set.contains(v) ? ({...set}..remove(v)) : {...set, v};

    // Selected skills first, then the rest alphabetically.
    final skillChips = [
      ...skills.where((s) => query.skills.contains(s.slug)),
      ...skills.where((s) => !query.skills.contains(s.slug)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text('Filters', style: t.h4),
              ),
            ),
            if (query.activeFilterCount > 0)
              LuzTextLink(
                label: 'Reset all',
                onPressed: () => onChanged(query.clearFilters()),
              ),
          ],
        ),
        const SizedBox(height: LuzSpace.sm),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Remote only', style: t.label),
                  Text(
                    'Work from anywhere',
                    style: t.bodySm.copyWith(color: p.inkMuted),
                  ),
                ],
              ),
            ),
            LuzToggle(
              value: query.remoteOnly,
              semanticLabel: 'Remote only',
              onChanged: (v) => onChanged(query.copyWith(remoteOnly: v)),
            ),
          ],
        ),
        heading('Job type'),
        for (final type in EmploymentType.values)
          LuzCheckbox(
            label: type.label,
            value: query.types.contains(type),
            onChanged: (_) =>
                onChanged(query.copyWith(types: toggled(query.types, type))),
          ),
        heading('Experience'),
        for (final level in ExperienceLevel.values)
          LuzCheckbox(
            label: level.label,
            value: query.levels.contains(level),
            onChanged: (_) =>
                onChanged(query.copyWith(levels: toggled(query.levels, level))),
          ),
        heading('Salary per year'),
        Wrap(
          spacing: LuzSpace.xs,
          runSpacing: LuzSpace.xs,
          children: [
            for (final v in salaryOptions)
              LuzFilterChip(
                label: salaryLabel(v),
                selected: query.minAnnualSalary == v,
                onSelected: (_) => onChanged(query.withMinSalary(v)),
              ),
          ],
        ),
        heading('Date posted'),
        for (final days in postedOptions)
          LuzRadio<int>(
            label: postedLabel(days),
            value: days,
            groupValue: query.postedWithinDays ?? 0,
            onChanged: (d) =>
                onChanged(query.withPostedWithin(d == 0 ? null : d)),
          ),
        if (skillChips.isNotEmpty) ...[
          heading('Skills'),
          Wrap(
            spacing: LuzSpace.xs,
            runSpacing: LuzSpace.xs,
            children: [
              for (final s in skillChips.take(
                (18).clamp(query.skills.length, skillChips.length),
              ))
                LuzFilterChip(
                  label: s.name,
                  selected: query.skills.contains(s.slug),
                  onSelected: (_) => onChanged(
                    query.copyWith(skills: toggled(query.skills, s.slug)),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// End of a paginated list: loads the next page as soon as it is shown,
/// with a button as the keyboard / slow-network fallback.
class LoadMoreFooter extends StatefulWidget {
  const LoadMoreFooter({
    super.key,
    required this.loading,
    required this.hasMore,
    required this.error,
    required this.onLoadMore,
    required this.isEmpty,
    this.endLabel = "You've reached the end.",
  });

  final bool loading;
  final bool hasMore;
  final AppFailure? error;
  final VoidCallback onLoadMore;
  final bool isEmpty;
  final String endLabel;

  @override
  State<LoadMoreFooter> createState() => _LoadMoreFooterState();
}

class _LoadMoreFooterState extends State<LoadMoreFooter> {
  @override
  void initState() {
    super.initState();
    _autoLoad();
  }

  @override
  void didUpdateWidget(LoadMoreFooter old) {
    super.didUpdateWidget(old);
    _autoLoad();
  }

  void _autoLoad() {
    if (widget.hasMore && !widget.loading && widget.error == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onLoadMore();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    final t = context.luzText;
    if (widget.error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: LuzSpace.lg),
        child: Column(
          children: [
            Text(
              widget.error!.message,
              textAlign: TextAlign.center,
              style: t.body.copyWith(color: p.danger),
            ),
            const SizedBox(height: LuzSpace.sm),
            LuzButton(
              label: 'Try again',
              icon: Icons.refresh,
              onPressed: widget.onLoadMore,
            ),
          ],
        ),
      );
    }
    if (widget.loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: LuzSpace.lg),
        child: Semantics(
          label: 'Loading more',
          child: const Center(child: LuzSkeleton(width: 160, height: 12)),
        ),
      );
    }
    if (widget.hasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: LuzSpace.md),
        child: Center(
          child: LuzButton(label: 'Load more', onPressed: widget.onLoadMore),
        ),
      );
    }
    if (widget.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: LuzSpace.lg),
      child: Center(
        child: Text(widget.endLabel, style: t.bodySm.copyWith(color: p.muted)),
      ),
    );
  }
}

/// Placeholder card while the first page loads.
class JobCardSkeleton extends StatelessWidget {
  const JobCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) => const LuzSurface(
    depth: LuzDepth.raisedMd,
    radius: LuzRadius.lg,
    padding: EdgeInsets.all(LuzSpace.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            LuzSkeleton(width: 44, height: 44, radius: LuzRadius.sm),
            SizedBox(width: LuzSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LuzSkeleton(width: 200, height: 16),
                  SizedBox(height: 8),
                  LuzSkeleton(width: 120),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: LuzSpace.md),
        LuzSkeleton(width: 240),
        SizedBox(height: LuzSpace.sm),
        LuzSkeleton(width: 140),
      ],
    ),
  );
}

/// Minimal Markdown for job descriptions: headings (#), bullets (- or *),
/// paragraphs and **bold**. Text only; links and HTML are shown as text.
class SimpleMarkdown extends StatelessWidget {
  const SimpleMarkdown(this.source, {super.key});
  final String source;

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    final t = context.luzText;
    final blocks = <Widget>[];
    final para = <String>[];

    void flush() {
      if (para.isEmpty) return;
      blocks.add(
        Padding(
          padding: const EdgeInsets.only(bottom: LuzSpace.sm),
          child: Text.rich(
            _inline(para.join(' '), t.body.copyWith(color: p.ink)),
          ),
        ),
      );
      para.clear();
    }

    for (final raw in source.split('\n')) {
      final line = raw.trimRight();
      final trimmed = line.trimLeft();
      final heading = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(trimmed);
      final bullet = RegExp(r'^[-*•]\s+(.*)$').firstMatch(trimmed);
      if (trimmed.isEmpty) {
        flush();
      } else if (heading != null) {
        flush();
        blocks.add(
          Padding(
            padding: const EdgeInsets.only(
              top: LuzSpace.sm,
              bottom: LuzSpace.xs,
            ),
            child: Semantics(
              header: true,
              child: Text(heading.group(2)!, style: t.h4),
            ),
          ),
        );
      } else if (bullet != null) {
        flush();
        blocks.add(BulletLine(bullet.group(1)!));
      } else {
        para.add(trimmed);
      }
    }
    flush();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks,
    );
  }

  static TextSpan _inline(String text, TextStyle style) {
    final spans = <TextSpan>[];
    final parts = text.split('**');
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isEmpty) continue;
      spans.add(
        TextSpan(
          text: parts[i],
          style: i.isOdd ? const TextStyle(fontWeight: FontWeight.w700) : null,
        ),
      );
    }
    return TextSpan(style: style, children: spans);
  }
}

/// One bullet point with an orange dot.
class BulletLine extends StatelessWidget {
  const BulletLine(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    final t = context.luzText;
    return Padding(
      padding: const EdgeInsets.only(bottom: LuzSpace.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8, right: LuzSpace.sm),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: p.accent,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: Text.rich(
              SimpleMarkdown._inline(text, t.body.copyWith(color: p.ink)),
            ),
          ),
        ],
      ),
    );
  }
}

/// "via Remotive" / "Jobs by Adzuna": names and links the provider of an
/// external listing, as their terms require.
class SourceAttribution extends StatelessWidget {
  const SourceAttribution({
    super.key,
    required this.source,
    this.compact = false,
  });
  final String? source;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final info = jobSource(source);
    if (info == null) return const SizedBox.shrink();
    final p = context.luz;
    final t = context.luzText;
    final text = Text(
      info.label,
      style: (compact ? t.caption : t.bodySm).copyWith(color: p.inkMuted),
    );
    if (info.url.isEmpty) return text;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.open_in_new, size: compact ? 12 : 16, color: p.inkMuted),
        const SizedBox(width: 4),
        LuzTextLink(
          label: info.label,
          style: compact ? t.caption : t.bodySm,
          onPressed: () => launchUrl(
            Uri.parse(info.url),
            mode: LaunchMode.externalApplication,
          ),
        ),
      ],
    );
  }
}
