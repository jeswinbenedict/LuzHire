import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/enums.dart';
import '../../../core/data/format.dart';
import '../../../core/data/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../../jobs/application/job_board_providers.dart';
import '../application/candidate_providers.dart';
import 'applications_pages.dart' show ApplicationList;
import 'candidate_widgets.dart';
import 'interviews_page.dart' show InterviewCard;
import '../../admin/presentation/admin_people_pages.dart'
    show AnnouncementsBanner;

String greeting(DateTime now) => switch (now.hour) {
  < 12 => 'Good morning',
  < 17 => 'Good afternoon',
  _ => 'Good evening',
};

/// /me (Stitch: docs/design/stitch/candidate-dashboard-*.png). Every number
/// is a count of the candidate's own rows.
class CandidateDashboardPage extends ConsumerWidget {
  const CandidateDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.luz;
    final t = context.luzText;
    final profile = ref.watch(myProfileProvider).value;
    final apps = ref.watch(myApplicationsProvider).value ?? const [];
    final interviews = ref.watch(myInterviewsProvider).value ?? const [];
    final offers = ref.watch(myOffersProvider).value ?? const [];
    final saved = ref.watch(savedJobIdsProvider).value ?? const <String>{};
    final now = DateTime.now();
    final upcoming = interviews
        .where(
          (i) => i.status == InterviewStatus.scheduled && i.endsAt.isAfter(now),
        )
        .toList();
    final interviewJobs =
        ref
            .watch(jobsByIdsProvider(jobIdsKey(upcoming.map((i) => i.jobId))))
            .value ??
        const <String, Job>{};
    final active = apps.where((a) => !a.stage.isTerminal).length;
    final awaiting = offers.where((o) => o.awaitingReply).length;
    final firstName = (profile?.displayName ?? '').split(' ').first;

    final stats = [
      _Stat(
        'Active applications',
        '$active',
        Icons.send_outlined,
        '/me/applications',
      ),
      _Stat(
        'Upcoming interviews',
        '${upcoming.length}',
        Icons.event_outlined,
        '/me/interviews',
      ),
      _Stat(
        'Saved jobs',
        '${saved.length}',
        Icons.bookmark_border,
        '/me/saved',
      ),
      _Stat(
        'Offers to answer',
        '$awaiting',
        Icons.mark_email_unread_outlined,
        '/me/applications',
      ),
    ];

    final applications = SectionCard(
      title: 'Recent applications',
      icon: Icons.send_outlined,
      action: LuzTextLink(
        label: 'See all',
        onPressed: () => context.go('/me/applications'),
      ),
      child: apps.isEmpty
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You have not applied anywhere yet.',
                  style: t.body.copyWith(color: p.inkMuted),
                ),
                const SizedBox(height: LuzSpace.sm),
                LuzButton.accent(
                  label: 'Find jobs',
                  icon: Icons.search,
                  onPressed: () => context.go('/jobs'),
                ),
              ],
            )
          : ApplicationList(applications: apps.take(3).toList()),
    );

    final side = Column(
      children: [
        SectionCard(
          title: 'Upcoming interviews',
          icon: Icons.event_outlined,
          child: upcoming.isEmpty
              ? Text(
                  'Nothing scheduled.',
                  style: t.body.copyWith(color: p.inkMuted),
                )
              : Column(
                  children: [
                    for (final i in upcoming.take(2)) ...[
                      InterviewCard(interview: i, job: interviewJobs[i.jobId]),
                      const SizedBox(height: LuzSpace.sm),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: LuzSpace.lg),
        const NotificationsCard(limit: 5),
      ],
    );

    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 1000;
        return CandidatePage(
          children: [
            Text(
              firstName.isEmpty
                  ? greeting(now)
                  : '${greeting(now)}, $firstName',
              style: t.h2,
            ),
            const SizedBox(height: LuzSpace.xs),
            Text(
              "Here's where your job search stands.",
              style: t.body.copyWith(color: p.inkMuted),
            ),
            const SizedBox(height: LuzSpace.lg),
            const AnnouncementsBanner(),
            if (profile != null)
              LuzCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LuzProgressGroove(
                      value: profile.profileCompletion / 100,
                      label: 'Profile strength',
                    ),
                    if (profile.profileCompletion < 100) ...[
                      const SizedBox(height: LuzSpace.sm),
                      LuzTextLink(
                        label: 'Complete your profile →',
                        onPressed: () => context.go('/me/profile'),
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: LuzSpace.lg),
            Wrap(
              spacing: LuzSpace.md,
              runSpacing: LuzSpace.md,
              children: [
                for (final s in stats)
                  SizedBox(
                    width: wide
                        ? (c.maxWidth - 3 * LuzSpace.md) / 4
                        : (c.maxWidth - LuzSpace.md) / 2,
                    child: _StatTile(stat: s),
                  ),
              ],
            ),
            const SizedBox(height: LuzSpace.lg),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: applications),
                  const SizedBox(width: LuzSpace.lg),
                  Expanded(flex: 2, child: side),
                ],
              )
            else ...[
              applications,
              const SizedBox(height: LuzSpace.lg),
              side,
            ],
          ],
        );
      },
    );
  }
}

class _Stat {
  const _Stat(this.label, this.value, this.icon, this.path);
  final String label;
  final String value;
  final IconData icon;
  final String path;
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.stat});
  final _Stat stat;

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    final t = context.luzText;
    return LuzPressable(
      radius: LuzRadius.md,
      semanticLabel: '${stat.label}: ${stat.value}',
      onPressed: () => context.go(stat.path),
      builder: (context, pressed, hovered) => LuzSurface(
        depth: pressed ? LuzDepth.insetSm : LuzDepth.raisedSm,
        radius: LuzRadius.md,
        padding: const EdgeInsets.all(LuzSpace.md),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stat.label,
                    style: t.bodySm.copyWith(color: p.inkMuted),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    stat.value,
                    style: t.h3.copyWith(fontFamily: t.mono.fontFamily),
                  ),
                ],
              ),
            ),
            Icon(stat.icon, color: p.accent),
          ],
        ),
      ),
    );
  }
}

/// Live notification list with mark-read (FR-11). Tapping one opens the
/// related application.
class NotificationsCard extends ConsumerWidget {
  const NotificationsCard({super.key, this.limit});
  final int? limit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.luz;
    final t = context.luzText;
    final value = ref.watch(myNotificationsProvider);
    final unread = (value.value ?? const []).where((n) => n.isUnread).length;
    final actions = ref.read(candidateActionsProvider);
    return SectionCard(
      title: unread == 0 ? 'Notifications' : 'Notifications ($unread new)',
      icon: Icons.notifications_none,
      action: unread == 0
          ? null
          : LuzTextLink(
              label: 'Mark all read',
              onPressed: () =>
                  runWithToast(context, actions.markAllNotificationsRead),
            ),
      child: AsyncBlock<List<AppNotification>>(
        value: value,
        onRetry: () => ref.invalidate(myNotificationsProvider),
        data: (all) {
          final list = limit == null ? all : all.take(limit!).toList();
          if (list.isEmpty) {
            return Text(
              'You are all caught up.',
              style: t.body.copyWith(color: p.inkMuted),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final n in list)
                Semantics(
                  label: n.isUnread ? 'Unread' : null,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(LuzRadius.sm),
                    onTap: () {
                      if (n.isUnread) actions.markNotificationRead(n.id);
                      final appId = n.data['application_id'];
                      if (appId is String) {
                        context.go('/me/applications/$appId');
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: LuzSpace.xs,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: n.isUnread
                                    ? p.accent
                                    : Colors.transparent,
                              ),
                            ),
                          ),
                          const SizedBox(width: LuzSpace.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  n.title,
                                  style: t.label.copyWith(
                                    fontWeight: n.isUnread
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                                if ((n.body ?? '').isNotEmpty)
                                  Text(n.body!, style: t.bodySm),
                                Text(
                                  formatRelative(n.createdAt),
                                  style: t.caption.copyWith(color: p.muted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (limit != null && all.length > limit!)
                Align(
                  alignment: Alignment.centerLeft,
                  child: LuzTextLink(
                    label: 'See all notifications',
                    onPressed: () => context.go('/me/notifications'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// /me/notifications: the full list.
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) =>
      const CandidatePage(children: [NotificationsCard()]);
}
