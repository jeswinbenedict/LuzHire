import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/data/enums.dart';
import '../../../core/data/format.dart';
import '../../../core/data/models.dart';
import '../../../core/shell/workspace_page.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../../candidate/presentation/candidate_widgets.dart'
    show AsyncBlock, runWithToast;
import '../../employer/presentation/employer_common.dart'
    show JobStatusChip, companyFacts;
import '../application/admin_providers.dart';

/// Asks for an optional reason before a decline / take-down. Null when the
/// dialog is dismissed.
Future<String?> askReason(
  BuildContext context, {
  required String title,
  required String confirmLabel,
}) => showLuzModal<String>(
  context: context,
  title: title,
  builder: (_) => _ReasonForm(confirmLabel: confirmLabel),
);

/// Owns its controller, so it outlives the dialog's closing animation.
class _ReasonForm extends StatefulWidget {
  const _ReasonForm({required this.confirmLabel});
  final String confirmLabel;

  @override
  State<_ReasonForm> createState() => _ReasonFormState();
}

class _ReasonFormState extends State<_ReasonForm> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      LuzTextField(
        label: 'Reason (shared with the company)',
        controller: _controller,
        maxLines: 4,
        maxLength: 500,
        autofocus: true,
      ),
      const SizedBox(height: LuzSpace.md),
      LuzButton.accent(
        label: widget.confirmLabel,
        expand: true,
        onPressed: () => Navigator.of(context).pop(_controller.text),
      ),
    ],
  );
}

// ---------------------------------------------------------------- overview

/// /admin: platform numbers and the queues that need attention.
class AdminOverviewPage extends ConsumerWidget {
  const AdminOverviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(platformStatsProvider);
    return WorkspacePage(
      subtitle: 'Platform at a glance',
      children: [
        AsyncBlock<PlatformStats>(
          value: stats,
          onRetry: () => ref.invalidate(platformStatsProvider),
          data: (s) => _Overview(stats: s),
        ),
      ],
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.stats});
  final PlatformStats stats;

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    final t = context.luzText;
    final s = stats;
    final queues = [
      (
        'Companies to verify',
        s.companies['pending'] ?? 0,
        Icons.verified_outlined,
        '/admin/verification',
      ),
      (
        'Jobs to review',
        s.jobs['pending_review'] ?? 0,
        Icons.fact_check_outlined,
        '/admin/moderation',
      ),
      (
        'Open reports',
        s.openReports,
        Icons.flag_outlined,
        '/admin/moderation?tab=reports',
      ),
    ];
    final numbers = [
      ('Candidates', s.users['candidate'] ?? 0),
      ('Employers', s.users['employer'] ?? 0),
      ('Admins', s.users['admin'] ?? 0),
      ('Suspended', s.suspended),
      ('Verified companies', s.companies['verified'] ?? 0),
      ('Live jobs', s.jobs['published'] ?? 0),
      ('Applications', s.applications),
    ];
    final maxWeek = s.signupsByWeek.fold<int>(
      1,
      (m, w) => w.count > m ? w.count : m,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, c) {
            final cols = c.maxWidth >= 900 ? 3 : 1;
            final w = (c.maxWidth - LuzSpace.sm * (cols - 1)) / cols;
            return Wrap(
              spacing: LuzSpace.sm,
              runSpacing: LuzSpace.sm,
              children: [
                for (final q in queues)
                  SizedBox(
                    width: w,
                    child: LuzPressable(
                      radius: LuzRadius.sm,
                      semanticLabel: '${q.$1}: ${q.$2}',
                      onPressed: () => context.go(q.$4),
                      builder: (context, pressed, _) => LuzSurface(
                        depth: pressed ? LuzDepth.insetSm : LuzDepth.raisedSm,
                        radius: LuzRadius.sm,
                        outline: q.$2 > 0 ? p.accent : null,
                        padding: const EdgeInsets.all(LuzSpace.md),
                        child: Row(
                          children: [
                            Icon(q.$3, color: p.accent),
                            const SizedBox(width: LuzSpace.sm),
                            Expanded(child: Text(q.$1, style: t.label)),
                            Text(
                              '${q.$2}',
                              style: t.wsTitle.copyWith(
                                fontFamily: t.mono.fontFamily,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: LuzSpace.lg),
        LuzCard(
          child: Wrap(
            spacing: LuzSpace.xl,
            runSpacing: LuzSpace.md,
            children: [
              for (final n in numbers)
                Semantics(
                  label: '${n.$1}: ${n.$2}',
                  excludeSemantics: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(n.$1, style: t.caption.copyWith(color: p.inkMuted)),
                      Text(
                        '${n.$2}',
                        style: t.wsTitle.copyWith(
                          fontFamily: t.mono.fontFamily,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: LuzSpace.lg),
        LuzCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Sign-ups per week (last 12 weeks)', style: t.wsSection),
              const SizedBox(height: LuzSpace.md),
              if (s.signupsByWeek.isEmpty)
                Text('No sign-ups yet.', style: t.bodySm)
              else
                SizedBox(
                  height: 140,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final w in s.signupsByWeek)
                        Expanded(
                          child: Semantics(
                            label:
                                'Week of ${DateFormat('d MMM').format(w.week)}: '
                                '${w.count} sign-ups',
                            excludeSemantics: true,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text('${w.count}', style: t.caption),
                                  Container(
                                    height: 100 * w.count / maxWeek,
                                    decoration: BoxDecoration(
                                      color: p.accent,
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(4),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    DateFormat('d/M').format(w.week),
                                    style: t.caption.copyWith(color: p.muted),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- verification

/// /admin/verification: companies that asked to be verified.
class VerificationQueuePage extends ConsumerWidget {
  const VerificationQueuePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companies = ref.watch(pendingCompaniesProvider);
    final actions = ref.read(adminActionsProvider);
    final t = context.luzText;
    final p = context.luz;
    return WorkspacePage(
      subtitle: 'Companies waiting for verification',
      children: [
        AsyncBlock<List<Company>>(
          value: companies,
          onRetry: () => ref.invalidate(pendingCompaniesProvider),
          data: (list) => list.isEmpty
              ? const LuzEmptyState(
                  icon: Icons.verified_outlined,
                  title: 'Queue is clear',
                  message: 'No company is waiting for verification.',
                )
              : Column(
                  children: [
                    for (final c in list) ...[
                      LuzCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                LuzLogoSocket(name: c.name, size: 44),
                                const SizedBox(width: LuzSpace.sm),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(c.name, style: t.wsSection),
                                      if (companyFacts(c).isNotEmpty)
                                        Text(
                                          companyFacts(c),
                                          style: t.caption.copyWith(
                                            color: p.inkMuted,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if ((c.description ?? '').isNotEmpty) ...[
                              const SizedBox(height: LuzSpace.sm),
                              Text(
                                c.description!,
                                style: t.bodySm,
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: LuzSpace.sm),
                            Wrap(
                              spacing: LuzSpace.sm,
                              runSpacing: LuzSpace.sm,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (c.website != null)
                                  LuzTextLink(
                                    label: Uri.parse(c.website!).host,
                                    onPressed: () => launchUrl(
                                      Uri.parse(c.website!),
                                      mode: LaunchMode.externalApplication,
                                    ),
                                  ),
                                LuzTextLink(
                                  label: 'Public page',
                                  onPressed: () =>
                                      context.go('/companies/${c.slug}'),
                                ),
                                const SizedBox(width: LuzSpace.md),
                                LuzButton.accent(
                                  label: 'Verify',
                                  icon: Icons.verified_outlined,
                                  onPressed: () => runWithToast(
                                    context,
                                    () =>
                                        actions.reviewCompany(c.id, true, null),
                                    success: '${c.name} verified',
                                  ),
                                ),
                                LuzButton(
                                  label: 'Decline',
                                  icon: Icons.block,
                                  onPressed: () async {
                                    final reason = await askReason(
                                      context,
                                      title: 'Decline ${c.name}?',
                                      confirmLabel: 'Decline verification',
                                    );
                                    if (reason == null || !context.mounted) {
                                      return;
                                    }
                                    await runWithToast(
                                      context,
                                      () => actions.reviewCompany(
                                        c.id,
                                        false,
                                        reason,
                                      ),
                                      success: '${c.name} declined',
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: LuzSpace.md),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- moderation

enum _ModTab { jobs, reports }

/// /admin/moderation: jobs waiting for review and user reports.
class ModerationPage extends ConsumerStatefulWidget {
  const ModerationPage({super.key, this.initialTab});
  final String? initialTab;

  @override
  ConsumerState<ModerationPage> createState() => _ModerationPageState();
}

class _ModerationPageState extends ConsumerState<ModerationPage> {
  late _ModTab _tab = widget.initialTab == 'reports'
      ? _ModTab.reports
      : _ModTab.jobs;
  ReportStatus _reportStatus = ReportStatus.open;

  @override
  Widget build(BuildContext context) {
    final jobsCount = ref.watch(pendingJobsProvider).value?.length;
    final openCount = ref
        .watch(reportsProvider(ReportStatus.open))
        .value
        ?.length;
    return WorkspacePage(
      subtitle: 'Keep the job board trustworthy',
      actions: [
        LuzSegmented<_ModTab>(
          segments: [
            (
              value: _ModTab.jobs,
              label: jobsCount == null ? 'Jobs' : 'Jobs ($jobsCount)',
              icon: Icons.fact_check_outlined,
            ),
            (
              value: _ModTab.reports,
              label: openCount == null ? 'Reports' : 'Reports ($openCount)',
              icon: Icons.flag_outlined,
            ),
          ],
          selected: _tab,
          onChanged: (v) => setState(() => _tab = v),
        ),
      ],
      children: [
        if (_tab == _ModTab.jobs)
          const _PendingJobs()
        else ...[
          Align(
            alignment: Alignment.centerLeft,
            child: LuzSegmented<ReportStatus>(
              segments: [
                for (final s in ReportStatus.values)
                  (value: s, label: s.label, icon: null),
              ],
              selected: _reportStatus,
              onChanged: (s) => setState(() => _reportStatus = s),
            ),
          ),
          _Reports(status: _reportStatus),
        ],
      ],
    );
  }
}

class _PendingJobs extends ConsumerWidget {
  const _PendingJobs();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs = ref.watch(pendingJobsProvider);
    final actions = ref.read(adminActionsProvider);
    final t = context.luzText;
    final p = context.luz;
    return AsyncBlock<List<Job>>(
      value: jobs,
      onRetry: () => ref.invalidate(pendingJobsProvider),
      data: (list) => list.isEmpty
          ? const LuzEmptyState(
              icon: Icons.fact_check_outlined,
              title: 'Nothing to review',
              message: 'Jobs from unverified companies appear here.',
            )
          : Column(
              children: [
                for (final j in list) ...[
                  LuzCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(j.title, style: t.wsSection),
                                  Text(
                                    [
                                          j.companyName,
                                          formatPlace(j),
                                          formatSalary(j),
                                        ]
                                        .whereType<String>()
                                        .where((s) => s.isNotEmpty)
                                        .join(' · '),
                                    style: t.caption.copyWith(
                                      color: p.inkMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            JobStatusChip(j.status),
                          ],
                        ),
                        if ((j.summary ?? '').isNotEmpty) ...[
                          const SizedBox(height: LuzSpace.xs),
                          Text(j.summary!, style: t.bodySm),
                        ],
                        if (j.descriptionMd.isNotEmpty) ...[
                          const SizedBox(height: LuzSpace.xs),
                          Text(
                            j.descriptionMd,
                            style: t.bodySm.copyWith(color: p.inkMuted),
                            maxLines: 5,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: LuzSpace.sm),
                        Wrap(
                          spacing: LuzSpace.sm,
                          runSpacing: LuzSpace.sm,
                          children: [
                            LuzButton.accent(
                              label: 'Publish',
                              icon: Icons.public,
                              onPressed: () => runWithToast(
                                context,
                                () => actions.reviewJob(j.id, true, null),
                                success: '${j.title} published',
                              ),
                            ),
                            LuzButton(
                              label: 'Reject',
                              icon: Icons.block,
                              onPressed: () async {
                                final reason = await askReason(
                                  context,
                                  title: 'Reject ${j.title}?',
                                  confirmLabel: 'Reject job',
                                );
                                if (reason == null || !context.mounted) return;
                                await runWithToast(
                                  context,
                                  () => actions.reviewJob(j.id, false, reason),
                                  success: '${j.title} rejected',
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: LuzSpace.md),
                ],
              ],
            ),
    );
  }
}

class _Reports extends ConsumerWidget {
  const _Reports({required this.status});
  final ReportStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(reportsProvider(status));
    final names = ref.watch(reportTargetsProvider(status)).value ?? const {};
    final actions = ref.read(adminActionsProvider);
    final t = context.luzText;
    final p = context.luz;
    return AsyncBlock<List<Report>>(
      value: reports,
      onRetry: () => ref.invalidate(reportsProvider(status)),
      data: (list) => list.isEmpty
          ? LuzEmptyState(
              icon: Icons.flag_outlined,
              title: status == ReportStatus.open
                  ? 'No open reports'
                  : 'No ${status.label.toLowerCase()} reports',
            )
          : Column(
              children: [
                for (final r in list) ...[
                  LuzCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            LuzStatusChip(
                              label: r.targetType,
                              tone: LuzChipTone.neutral,
                              icon: switch (r.targetType) {
                                'job' => Icons.work_outline,
                                'company' => Icons.apartment_outlined,
                                _ => Icons.person_outline,
                              },
                            ),
                            const SizedBox(width: LuzSpace.sm),
                            Expanded(
                              child: Text(
                                names['${r.targetType}:${r.targetId}'] ??
                                    'Removed ${r.targetType}',
                                style: t.wsCardTitle,
                              ),
                            ),
                            Text(
                              formatRelative(r.createdAt),
                              style: t.caption.copyWith(color: p.muted),
                            ),
                          ],
                        ),
                        const SizedBox(height: LuzSpace.xs),
                        Text('“${r.reason}”', style: t.bodySm),
                        if (status == ReportStatus.open) ...[
                          const SizedBox(height: LuzSpace.sm),
                          Wrap(
                            spacing: LuzSpace.sm,
                            runSpacing: LuzSpace.sm,
                            children: [
                              if (r.targetType == 'job')
                                LuzButton.accent(
                                  label: 'Take job down',
                                  icon: Icons.block,
                                  onPressed: () async {
                                    final reason = await askReason(
                                      context,
                                      title: 'Take this job down?',
                                      confirmLabel: 'Take down',
                                    );
                                    if (reason == null || !context.mounted) {
                                      return;
                                    }
                                    await runWithToast(context, () async {
                                      await actions.reviewJob(
                                        r.targetId,
                                        false,
                                        reason,
                                      );
                                      await actions.resolveReport(
                                        r.id,
                                        ReportStatus.actioned,
                                      );
                                    }, success: 'Job taken down');
                                  },
                                ),
                              LuzButton(
                                label: 'Mark actioned',
                                icon: Icons.check,
                                onPressed: () => runWithToast(
                                  context,
                                  () => actions.resolveReport(
                                    r.id,
                                    ReportStatus.actioned,
                                  ),
                                ),
                              ),
                              LuzButton(
                                label: 'Dismiss',
                                icon: Icons.close,
                                onPressed: () => runWithToast(
                                  context,
                                  () => actions.resolveReport(
                                    r.id,
                                    ReportStatus.dismissed,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: LuzSpace.md),
                ],
              ],
            ),
    );
  }
}
