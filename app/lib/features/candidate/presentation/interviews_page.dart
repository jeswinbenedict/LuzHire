import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/data/enums.dart';
import '../../../core/data/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../application/candidate_providers.dart';
import 'candidate_widgets.dart';

/// Google Calendar "add event" link (works on every platform).
Uri calendarLink(Interview i, {Job? job}) {
  String stamp(DateTime d) =>
      '${DateFormat("yyyyMMdd'T'HHmmss").format(d.toUtc())}Z';
  return Uri.https('calendar.google.com', '/calendar/render', {
    'action': 'TEMPLATE',
    'text':
        'Interview: ${job?.title ?? 'LuzHire'}'
        '${job == null ? '' : ' at ${job.companyName}'}',
    'dates': '${stamp(i.scheduledAt)}/${stamp(i.endsAt)}',
    'details': [
      '${i.mode.label} interview booked through LuzHire.',
      if (i.meetingUrl != null) 'Join: ${i.meetingUrl}',
    ].join('\n'),
    if (i.location != null) 'location': i.location!,
  });
}

/// /me/interviews: upcoming first, then past.
class InterviewsPage extends ConsumerWidget {
  const InterviewsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final interviews = ref.watch(myInterviewsProvider);
    return AsyncBlock<List<Interview>>(
      value: interviews,
      onRetry: () => ref.invalidate(myInterviewsProvider),
      data: (list) {
        if (list.isEmpty) {
          return LuzEmptyState(
            icon: Icons.event_available_outlined,
            title: 'No interviews yet',
            message:
                'When an employer books an interview it appears here, with a '
                'link to add it to your calendar.',
            actionLabel: 'See applications',
            onAction: () => context.go('/me/applications'),
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
        final jobs =
            ref
                .watch(jobsByIdsProvider(jobIdsKey(list.map((i) => i.jobId))))
                .value ??
            const <String, Job>{};
        final t = context.luzText;
        return CandidatePage(
          children: [
            Text('Upcoming', style: t.h4),
            const SizedBox(height: LuzSpace.sm),
            if (upcoming.isEmpty)
              Text(
                'Nothing scheduled.',
                style: t.body.copyWith(color: context.luz.muted),
              ),
            for (final i in upcoming) ...[
              InterviewCard(interview: i, job: jobs[i.jobId]),
              const SizedBox(height: LuzSpace.md),
            ],
            if (past.isNotEmpty) ...[
              const SizedBox(height: LuzSpace.lg),
              Text('Past', style: t.h4),
              const SizedBox(height: LuzSpace.sm),
              for (final i in past) ...[
                InterviewCard(interview: i, job: jobs[i.jobId]),
                const SizedBox(height: LuzSpace.md),
              ],
            ],
          ],
        );
      },
    );
  }
}

class InterviewCard extends StatelessWidget {
  const InterviewCard({super.key, required this.interview, this.job});
  final Interview interview;
  final Job? job;

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    final t = context.luzText;
    final i = interview;
    final upcoming =
        i.status == InterviewStatus.scheduled &&
        i.endsAt.isAfter(DateTime.now());
    final time =
        '${DateFormat('EEE d MMM · h:mm a').format(i.scheduledAt.toLocal())}'
        ' – ${DateFormat('h:mm a').format(i.endsAt.toLocal())}';
    return LuzSurface(
      depth: LuzDepth.raisedSm,
      radius: LuzRadius.md,
      padding: const EdgeInsets.all(LuzSpace.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CalendarTile(date: i.scheduledAt),
          const SizedBox(width: LuzSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(time, style: t.mono.copyWith(color: p.accent)),
                const SizedBox(height: 2),
                Text(job?.title ?? 'Interview', style: t.label),
                if (job != null)
                  Text(
                    job!.companyName,
                    style: t.bodySm.copyWith(color: p.inkMuted),
                  ),
                const SizedBox(height: LuzSpace.xs),
                Wrap(
                  spacing: LuzSpace.xs,
                  runSpacing: LuzSpace.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    LuzStatusChip(
                      label: i.mode.label,
                      tone: LuzChipTone.blue,
                      icon: i.mode.icon,
                    ),
                    if (i.status != InterviewStatus.scheduled)
                      LuzStatusChip(
                        label: i.status.label,
                        tone: i.status == InterviewStatus.completed
                            ? LuzChipTone.green
                            : LuzChipTone.neutral,
                      ),
                    if ((i.location ?? '').isNotEmpty)
                      Text(i.location!, style: t.bodySm),
                  ],
                ),
                if (upcoming) ...[
                  const SizedBox(height: LuzSpace.sm),
                  Wrap(
                    spacing: LuzSpace.md,
                    runSpacing: LuzSpace.xs,
                    children: [
                      if (i.meetingUrl != null)
                        LuzTextLink(
                          label: 'Join meeting',
                          onPressed: () => launchUrl(
                            Uri.parse(i.meetingUrl!),
                            mode: LaunchMode.externalApplication,
                          ),
                        ),
                      LuzTextLink(
                        label: 'Add to calendar',
                        onPressed: () => launchUrl(
                          calendarLink(i, job: job),
                          mode: LaunchMode.externalApplication,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
