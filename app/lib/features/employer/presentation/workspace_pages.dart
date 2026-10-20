import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/data/enums.dart';
import '../../../core/data/format.dart';
import '../../../core/data/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../../candidate/presentation/candidate_widgets.dart'
    show AsyncBlock, CalendarTile, runWithToast;
import '../application/employer_providers.dart';
import 'employer_common.dart';
import '../../admin/presentation/admin_people_pages.dart'
    show AnnouncementsBanner;

// ---------------------------------------------------------------- overview

/// /employer: company status, real counts, recent applicants, quick links.
class EmployerOverviewPage extends ConsumerWidget {
  const EmployerOverviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MembershipGate(
    builder: (context, m) {
      final p = context.luz;
      final t = context.luzText;
      final stats = ref.watch(hiringStatsProvider(m.company.id)).value;
      final apps =
          ref.watch(companyApplicationsProvider(m.company.id)).value ??
          const <JobApplication>[];
      final jobs =
          ref.watch(companyJobsProvider(m.company.id)).value ?? const <Job>[];
      final jobById = {for (final j in jobs) j.id: j};
      final profiles =
          ref
              .watch(
                applicantProfilesProvider(
                  idsKey(apps.take(6).map((a) => a.candidateId)),
                ),
              )
              .value ??
          const <String, Profile>{};
      int stage(Set<ApplicationStage> s) => [
        for (final e in (stats?.stages ?? const {}).entries)
          if (s.contains(e.key)) e.value,
      ].fold(0, (a, b) => a + b);

      final tiles = [
        (
          'Open jobs',
          '${stats?.jobs['published'] ?? 0}',
          Icons.work_outline,
          '/employer/jobs',
        ),
        (
          'New applicants',
          '${stage({ApplicationStage.applied})}',
          Icons.inbox_outlined,
          '/employer/pipeline',
        ),
        (
          'In interviews',
          '${stage({ApplicationStage.assessment, ApplicationStage.technicalInterview, ApplicationStage.hrInterview, ApplicationStage.finalReview})}',
          Icons.event_outlined,
          '/employer/interviews',
        ),
        (
          'Offers out',
          '${stage({ApplicationStage.offerIssued})}',
          Icons.mark_email_unread_outlined,
          '/employer/pipeline',
        ),
        (
          'Hired',
          '${stage({ApplicationStage.hired})}',
          Icons.handshake_outlined,
          '/employer/analytics',
        ),
      ];

      return WorkspacePage(
        title: m.company.name,
        subtitle: companyFacts(m.company),
        actions: [
          if (m.role.canEdit)
            LuzButton.accent(
              label: 'Post a job',
              icon: Icons.add,
              onPressed: () => context.go('/employer/jobs/new'),
            ),
        ],
        children: [
          const AnnouncementsBanner(),
          const MyInvitationsCard(),
          if (m.company.verification != Verification.verified)
            LuzCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_outlined, color: p.warning),
                  const SizedBox(width: LuzSpace.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.company.verification == Verification.pending
                              ? 'Verification requested. New jobs wait for an '
                                    'admin review until it is approved.'
                              : 'Your company is not verified, so new jobs '
                                    'wait for an admin review.',
                          style: t.bodySm,
                        ),
                        LuzTextLink(
                          label: 'Company settings',
                          onPressed: () => context.go('/employer/company'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          LayoutBuilder(
            builder: (context, c) {
              final cols = c.maxWidth >= 1000 ? 5 : (c.maxWidth >= 600 ? 3 : 2);
              final w = (c.maxWidth - LuzSpace.sm * (cols - 1)) / cols;
              return Wrap(
                spacing: LuzSpace.sm,
                runSpacing: LuzSpace.sm,
                children: [
                  for (final tile in tiles)
                    SizedBox(
                      width: w,
                      child: _StatTile(
                        label: tile.$1,
                        value: tile.$2,
                        icon: tile.$3,
                        onTap: () => context.go(tile.$4),
                      ),
                    ),
                ],
              );
            },
          ),
          LuzCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Recent applicants', style: t.wsSection),
                const SizedBox(height: LuzSpace.sm),
                if (apps.isEmpty)
                  Text(
                    'No applications yet. They appear here as soon as '
                    'candidates apply.',
                    style: t.bodySm.copyWith(color: p.inkMuted),
                  )
                else
                  LuzDataTable<JobApplication>(
                    rows: apps.take(6).toList(),
                    onRowTap: (a) =>
                        context.go('/employer/pipeline?job=${a.jobId}'),
                    columns: [
                      LuzColumn(
                        label: 'Candidate',
                        flex: 2,
                        cell: (_, a) => Text(
                          profiles[a.candidateId]?.displayName ?? 'Candidate',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      LuzColumn(
                        label: 'Job',
                        flex: 2,
                        cell: (_, a) => Text(
                          jobById[a.jobId]?.title ?? '—',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      LuzColumn(
                        label: 'Stage',
                        flex: 2,
                        cell: (_, a) => Align(
                          alignment: Alignment.centerLeft,
                          child: LuzStatusChip.stage(a.stage),
                        ),
                      ),
                      LuzColumn(
                        label: 'Applied',
                        cell: (_, a) => Text(formatRelative(a.createdAt)),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      );
    },
  );
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    final t = context.luzText;
    return LuzPressable(
      radius: LuzRadius.sm,
      semanticLabel: '$label: $value',
      onPressed: onTap,
      builder: (context, pressed, _) => LuzSurface(
        depth: pressed ? LuzDepth.insetSm : LuzDepth.raisedSm,
        radius: LuzRadius.sm,
        padding: const EdgeInsets.all(LuzSpace.md),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: t.caption.copyWith(color: p.inkMuted)),
                  Text(
                    value,
                    style: t.wsTitle.copyWith(fontFamily: t.mono.fontFamily),
                  ),
                ],
              ),
            ),
            Icon(icon, size: 20, color: p.accent),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- interviews

/// /employer/interviews: every interview across the company's jobs.
class EmployerInterviewsPage extends ConsumerWidget {
  const EmployerInterviewsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MembershipGate(
    builder: (context, m) {
      final apps = ref.watch(companyApplicationsProvider(m.company.id));
      return WorkspacePage(
        subtitle: m.company.name,
        children: [
          AsyncBlock<List<JobApplication>>(
            value: apps,
            onRetry: () =>
                ref.invalidate(companyApplicationsProvider(m.company.id)),
            data: (list) => _InterviewList(
              companyId: m.company.id,
              applications: list,
              canEdit: m.role.canEdit,
            ),
          ),
        ],
      );
    },
  );
}

class _InterviewList extends ConsumerWidget {
  const _InterviewList({
    required this.companyId,
    required this.applications,
    required this.canEdit,
  });
  final String companyId;
  final List<JobApplication> applications;
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.luzText;
    final p = context.luz;
    final interviews = ref.watch(
      employerInterviewsProvider(idsKey(applications.map((a) => a.id))),
    );
    final appById = {for (final a in applications) a.id: a};
    final jobs = {
      for (final j
          in ref.watch(companyJobsProvider(companyId)).value ?? const <Job>[])
        j.id: j,
    };
    final profiles =
        ref
            .watch(
              applicantProfilesProvider(
                idsKey(applications.map((a) => a.candidateId)),
              ),
            )
            .value ??
        const <String, Profile>{};
    return AsyncBlock<List<Interview>>(
      value: interviews,
      onRetry: () => ref.invalidate(employerInterviewsProvider),
      data: (list) {
        if (list.isEmpty) {
          return const LuzEmptyState(
            icon: Icons.event_available_outlined,
            title: 'No interviews scheduled',
            message:
                'Open a candidate in the pipeline and choose '
                '"Schedule interview".',
          );
        }
        final now = DateTime.now();
        final upcoming = list
            .where(
              (i) =>
                  i.status == InterviewStatus.scheduled &&
                  i.endsAt.isAfter(now),
            )
            .toList();
        final past = list.where((i) => !upcoming.contains(i)).toList().reversed;
        Widget row(Interview i) {
          final a = appById[i.applicationId];
          final name = profiles[a?.candidateId]?.displayName ?? 'Candidate';
          return Padding(
            padding: const EdgeInsets.only(bottom: LuzSpace.sm),
            child: LuzSurface(
              depth: LuzDepth.raisedSm,
              radius: LuzRadius.sm,
              padding: const EdgeInsets.all(LuzSpace.sm),
              child: Row(
                children: [
                  CalendarTile(date: i.scheduledAt),
                  const SizedBox(width: LuzSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${DateFormat('h:mm a').format(i.scheduledAt.toLocal())}'
                          ' · ${i.durationMin} min · ${i.mode.label}',
                          style: t.mono.copyWith(color: p.accent),
                        ),
                        Text(name, style: t.wsCardTitle),
                        Text(
                          jobs[i.jobId]?.title ?? '',
                          style: t.caption.copyWith(color: p.inkMuted),
                        ),
                      ],
                    ),
                  ),
                  if (i.status != InterviewStatus.scheduled)
                    LuzStatusChip(
                      label: i.status.label,
                      tone: LuzChipTone.neutral,
                    )
                  else ...[
                    if (i.meetingUrl != null)
                      LuzTextLink(
                        label: 'Join',
                        onPressed: () => launchUrl(
                          Uri.parse(i.meetingUrl!),
                          mode: LaunchMode.externalApplication,
                        ),
                      ),
                    if (canEdit) ...[
                      const SizedBox(width: LuzSpace.sm),
                      LuzTextLink(
                        label: 'Done',
                        onPressed: () => runWithToast(
                          context,
                          () => ref
                              .read(employerActionsProvider)
                              .setInterviewStatus(
                                i.id,
                                InterviewStatus.completed,
                              ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Upcoming (${upcoming.length})', style: t.wsSection),
            const SizedBox(height: LuzSpace.sm),
            if (upcoming.isEmpty)
              Text(
                'Nothing scheduled.',
                style: t.bodySm.copyWith(color: p.muted),
              ),
            for (final i in upcoming) row(i),
            if (past.isNotEmpty) ...[
              const SizedBox(height: LuzSpace.lg),
              Text('Past', style: t.wsSection),
              const SizedBox(height: LuzSpace.sm),
              for (final i in past) row(i),
            ],
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------- analytics

/// /employer/analytics: funnel, weekly applications, time to hire. Real
/// numbers only (public.company_hiring_stats).
class EmployerAnalyticsPage extends ConsumerWidget {
  const EmployerAnalyticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MembershipGate(
    builder: (context, m) {
      final stats = ref.watch(hiringStatsProvider(m.company.id));
      return WorkspacePage(
        subtitle: m.company.name,
        children: [
          AsyncBlock<HiringStats>(
            value: stats,
            onRetry: () => ref.invalidate(hiringStatsProvider(m.company.id)),
            data: (s) => s.totalApplications == 0
                ? const LuzEmptyState(
                    icon: Icons.insights_outlined,
                    title: 'No data yet',
                    message:
                        'Charts fill in as candidates apply and move '
                        'through your pipeline.',
                  )
                : _Charts(stats: s),
          ),
        ],
      );
    },
  );
}

class _Charts extends StatelessWidget {
  const _Charts({required this.stats});
  final HiringStats stats;

  static const funnel = [
    ('Applied', null),
    (
      'Reviewed',
      {
        ApplicationStage.underReview,
        ApplicationStage.shortlisted,
        ApplicationStage.assessment,
        ApplicationStage.technicalInterview,
        ApplicationStage.hrInterview,
        ApplicationStage.finalReview,
        ApplicationStage.offerIssued,
        ApplicationStage.hired,
      },
    ),
    (
      'Interviewed',
      {
        ApplicationStage.assessment,
        ApplicationStage.technicalInterview,
        ApplicationStage.hrInterview,
        ApplicationStage.finalReview,
        ApplicationStage.offerIssued,
        ApplicationStage.hired,
      },
    ),
    ('Offered', {ApplicationStage.offerIssued, ApplicationStage.hired}),
    ('Hired', {ApplicationStage.hired}),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    final t = context.luzText;
    final total = stats.totalApplications;
    // "Reached" counts: everyone currently at or beyond a step. Rejected and
    // withdrawn applications count only as applied (their last stage is not
    // stored on the row).
    int reached(Set<ApplicationStage>? s) => s == null
        ? total
        : [
            for (final e in stats.stages.entries)
              if (s.contains(e.key)) e.value,
          ].fold(0, (a, b) => a + b);
    final weeks = stats.applicationsByWeek;
    final maxWeek = weeks.fold<int>(1, (m, w) => w.count > m ? w.count : m);

    final funnelCard = LuzCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Hiring funnel', style: t.wsSection),
          const SizedBox(height: LuzSpace.md),
          for (final (label, stages) in funnel) ...[
            _Bar(label: label, value: reached(stages), max: total),
            const SizedBox(height: LuzSpace.sm),
          ],
          Text(
            'Rejected: ${stats.stages[ApplicationStage.rejected] ?? 0} · '
            'Withdrawn: ${stats.stages[ApplicationStage.withdrawn] ?? 0}',
            style: t.caption.copyWith(color: p.muted),
          ),
        ],
      ),
    );

    final weeklyCard = LuzCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Applications per week (last 12 weeks)', style: t.wsSection),
          const SizedBox(height: LuzSpace.md),
          if (weeks.isEmpty)
            Text('None in the last 12 weeks.', style: t.bodySm)
          else
            SizedBox(
              height: 160,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final w in weeks)
                    Expanded(
                      child: Semantics(
                        label:
                            'Week of ${DateFormat('d MMM').format(w.week)}: '
                            '${w.count} applications',
                        excludeSemantics: true,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text('${w.count}', style: t.caption),
                              const SizedBox(height: 2),
                              Container(
                                height: 120 * w.count / maxWeek,
                                decoration: BoxDecoration(
                                  color: p.accent,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(4),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
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
    );

    final factsCard = LuzCard(
      child: Wrap(
        spacing: LuzSpace.xl,
        runSpacing: LuzSpace.md,
        children: [
          _Fact('Applications', '$total'),
          _Fact(
            'Average time to hire',
            stats.avgDaysToHire == null
                ? 'No hires yet'
                : '${stats.avgDaysToHire!.toStringAsFixed(1)} days',
          ),
          _Fact('Published jobs', '${stats.jobs['published'] ?? 0}'),
          _Fact('Awaiting review', '${stats.jobs['pending_review'] ?? 0}'),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        factsCard,
        const SizedBox(height: LuzSpace.lg),
        LayoutBuilder(
          builder: (context, c) => c.maxWidth < 900
              ? Column(
                  children: [
                    funnelCard,
                    const SizedBox(height: LuzSpace.lg),
                    weeklyCard,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: funnelCard),
                    const SizedBox(width: LuzSpace.lg),
                    Expanded(child: weeklyCard),
                  ],
                ),
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.label, required this.value, required this.max});
  final String label;
  final int value;
  final int max;

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    final t = context.luzText;
    final pct = max == 0 ? 0.0 : value / max;
    return Semantics(
      label: '$label: $value of $max',
      excludeSemantics: true,
      child: Row(
        children: [
          SizedBox(width: 96, child: Text(label, style: t.bodySm)),
          Expanded(
            child: LuzSurface(
              depth: LuzDepth.insetSm,
              radius: LuzRadius.pill,
              child: SizedBox(
                height: 14,
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: pct.clamp(0.0, 1.0),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: p.accent,
                      borderRadius: BorderRadius.circular(LuzRadius.pill),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 48,
            child: Text('$value', textAlign: TextAlign.right, style: t.mono),
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: context.luzText.caption.copyWith(color: context.luz.inkMuted),
      ),
      Text(
        value,
        style: context.luzText.wsTitle.copyWith(
          fontFamily: context.luzText.mono.fontFamily,
        ),
      ),
    ],
  );
}
