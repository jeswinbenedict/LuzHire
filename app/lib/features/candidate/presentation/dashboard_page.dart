import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/data/enums.dart';
import '../../../core/data/format.dart';
import '../../../core/data/models.dart';
import '../../../core/layout/content.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../../jobs/application/job_board_providers.dart';
import '../../jobs/application/location_providers.dart'
    show recommendedJobsProvider;
import '../../jobs/presentation/job_widgets.dart' show JobCard;
import '../../notifications/application/notification_providers.dart'
    show unreadNotificationCountProvider;
import '../../notifications/presentation/notification_list.dart';
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

/// One line on where the search stands, most urgent first.
String dashboardSummary({
  required int offers,
  required int interviews,
  required int active,
}) {
  String n(int count, String one) => count == 1 ? '1 $one' : '$count ${one}s';
  if (offers > 0) {
    return 'You have ${n(offers, 'offer')} waiting for your answer.';
  }
  if (interviews > 0) {
    return 'You have ${n(interviews, 'interview')} coming up. Good luck!';
  }
  if (active > 0) {
    return '${n(active, 'application')} in progress. '
        "We'll let you know the moment anything changes.";
  }
  return 'Apply to a few roles that fit you, and follow each one here.';
}

/// /me (Stitch: docs/design/stitch/candidate-dashboard-*.png). Every number
/// is a count of the candidate's own rows.
class CandidateDashboardPage extends ConsumerWidget {
  const CandidateDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider).value;
    final apps = ref.watch(myApplicationsProvider).value ?? const [];
    final interviews = ref.watch(myInterviewsProvider).value ?? const [];
    final offers = ref.watch(myOffersProvider).value ?? const [];
    final saved = ref.watch(savedJobIdsProvider).value ?? const <String>{};
    final steps = ref.watch(profileNextStepsProvider) ?? const [];
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
    final firstName = friendlyName(profile?.displayName ?? '').split(' ').first;

    final stats = [
      _Stat(
        'Active applications',
        active,
        Icons.send_outlined,
        '/me/applications',
      ),
      _Stat(
        'Upcoming interviews',
        upcoming.length,
        Icons.event_outlined,
        '/me/interviews',
      ),
      _Stat('Saved jobs', saved.length, Icons.bookmark_border, '/me/saved'),
      _Stat(
        'Offers to answer',
        awaiting,
        Icons.mark_email_unread_outlined,
        '/me/applications',
      ),
    ];

    final welcome = _WelcomeCard(
      title: firstName.isEmpty ? greeting(now) : '${greeting(now)}, $firstName',
      date: now,
      summary: dashboardSummary(
        offers: awaiting,
        interviews: upcoming.length,
        active: active,
      ),
      profileDone: profile != null && profile.profileCompletion >= 100,
    );

    final applications = SectionCard(
      title: 'Recent applications',
      icon: Icons.send_outlined,
      action: apps.isEmpty
          ? null
          : LuzTextLink(
              label: 'See all',
              onPressed: () => context.go('/me/applications'),
            ),
      child: apps.isEmpty
          ? _InlineEmpty(
              icon: Icons.send_outlined,
              title: 'No applications yet',
              message:
                  'Apply to a job and follow every stage here, from '
                  'application to offer.',
              action: LuzButton.accent(
                label: 'Browse jobs',
                icon: Icons.search,
                onPressed: () => context.go('/jobs'),
              ),
            )
          : ApplicationList(applications: apps.take(3).toList()),
    );

    final interviewsCard = SectionCard(
      title: 'Upcoming interviews',
      icon: Icons.event_outlined,
      action: upcoming.isEmpty
          ? null
          : LuzTextLink(
              label: 'See all',
              onPressed: () => context.go('/me/interviews'),
            ),
      child: upcoming.isEmpty
          ? const _InlineEmpty(
              icon: Icons.event_available_outlined,
              title: 'No interviews scheduled',
              message:
                  'When an employer invites you, the date and joining link '
                  'appear here.',
            )
          : Column(
              spacing: LuzSpace.sm,
              children: [
                for (final i in upcoming.take(2))
                  InterviewCard(interview: i, job: interviewJobs[i.jobId]),
              ],
            ),
    );

    return CandidatePage(
      children: [
        LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 1000;
            final main = [
              if (profile != null && steps.isNotEmpty)
                _ProfileChecklist(profile: profile, steps: steps),
              applications,
              const _JobsForYou(),
            ];
            final side = [interviewsCard, const NotificationsCard(limit: 5)];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                welcome,
                const SizedBox(height: LuzSpace.lg),
                const AnnouncementsBanner(),
                _StatGrid(stats: stats, columns: c.maxWidth >= 720 ? 4 : 2),
                const SizedBox(height: LuzSpace.lg),
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: LuzSpace.lg,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: LuzSpace.lg,
                          children: main,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: LuzSpace.lg,
                          children: side,
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: LuzSpace.lg,
                    // Phones: what is scheduled before the long lists.
                    children: [
                      main.first,
                      interviewsCard,
                      ...main.skip(1),
                      side.last,
                    ],
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Greeting, today's date, one line on where things stand and the two
/// things a candidate does most.
class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({
    required this.title,
    required this.date,
    required this.summary,
    required this.profileDone,
  });

  final String title;
  final DateTime date;
  final String summary;
  final bool profileDone;

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    final t = context.luzText;
    return LuzCard(
      padding: const EdgeInsets.all(LuzSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('EEEE, d MMMM').format(date).toUpperCase(),
            style: t.eyebrow.copyWith(color: p.accent),
          ),
          const SizedBox(height: LuzSpace.xs),
          Semantics(header: true, child: Text(title, style: t.h3)),
          const SizedBox(height: LuzSpace.xs),
          Text(summary, style: t.body.copyWith(color: p.inkMuted)),
          const SizedBox(height: LuzSpace.md),
          Wrap(
            spacing: LuzSpace.sm,
            runSpacing: LuzSpace.sm,
            children: [
              LuzButton.accent(
                label: 'Find jobs',
                icon: Icons.search,
                onPressed: () => context.go('/jobs'),
              ),
              LuzButton(
                label: profileDone ? 'View profile' : 'Complete profile',
                icon: Icons.person_outline,
                onPressed: () => context.go('/me/profile'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat {
  const _Stat(this.label, this.value, this.icon, this.path);
  final String label;
  final int value;
  final IconData icon;
  final String path;
}

/// Four equal tiles in a row, or two rows of two.
class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.stats, required this.columns});
  final List<_Stat> stats;
  final int columns;

  @override
  Widget build(BuildContext context) => Column(
    spacing: LuzSpace.md,
    children: [
      for (var i = 0; i < stats.length; i += columns)
        // Tiles in a row share the tallest one's height.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: LuzSpace.md,
            children: [
              for (final s in stats.skip(i).take(columns))
                Expanded(child: _StatTile(stat: s)),
            ],
          ),
        ),
    ],
  );
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
        // Number and icon on top, the label below in full: fits two
        // tiles across a phone as well as four across a desktop.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${stat.value}',
                    style: t.h3.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: stat.value == 0 ? p.inkMuted : p.ink,
                    ),
                  ),
                ),
                _IconWell(icon: stat.icon, size: 36, color: p.accent),
              ],
            ),
            const SizedBox(height: LuzSpace.xs),
            Text(
              stat.label,
              style: t.bodySm.copyWith(color: p.inkMuted),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}

/// An icon set into the surface (DESIGN.md: inset = "a place").
class _IconWell extends StatelessWidget {
  const _IconWell({required this.icon, required this.size, this.color});
  final IconData icon;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => LuzSurface(
    depth: LuzDepth.insetSm,
    radius: LuzRadius.pill,
    child: SizedBox.square(
      dimension: size,
      child: Icon(icon, size: size * 0.45, color: color ?? context.luz.muted),
    ),
  );
}

/// An empty section: what will appear here and, optionally, how to start.
class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    final t = context.luzText;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _IconWell(icon: icon, size: 48),
        const SizedBox(width: LuzSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: t.wsCardTitle),
              const SizedBox(height: LuzSpace.xxs),
              Text(message, style: t.bodySm.copyWith(color: p.inkMuted)),
              if (action != null) ...[
                const SizedBox(height: LuzSpace.md),
                Align(alignment: Alignment.centerLeft, child: action),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// What is still missing from the profile, as steps that each add 10 %.
class _ProfileChecklist extends StatelessWidget {
  const _ProfileChecklist({required this.profile, required this.steps});
  final Profile profile;
  final List<ProfileStepItem> steps;

  static const _shown = 4;

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    final t = context.luzText;
    final pct = profile.profileCompletion;
    return SectionCard(
      title: 'Finish your profile',
      icon: Icons.task_alt,
      action: LuzTextLink(
        label: 'Open profile',
        onPressed: () => context.go('/me/profile'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              LuzDial(value: pct / 100, size: 64, label: 'profile complete'),
              const SizedBox(width: LuzSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$pct% complete', style: t.wsCardTitle),
                    const SizedBox(height: LuzSpace.xxs),
                    Text(
                      'Each step adds 10%. Complete profiles get better job '
                      'matches and stand out to employers.',
                      style: t.bodySm.copyWith(color: p.inkMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: LuzSpace.md),
          for (final s in steps.take(_shown)) _StepRow(item: s),
          if (steps.length > _shown)
            Padding(
              padding: const EdgeInsets.only(top: LuzSpace.xs),
              child: Text(
                '${steps.length - _shown} more on your profile page',
                style: t.caption.copyWith(color: p.inkMuted),
              ),
            ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.item});
  final ProfileStepItem item;

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    final t = context.luzText;
    return LuzPressable(
      radius: LuzRadius.sm,
      semanticLabel: '${item.label}, adds 10%',
      onPressed: () => context.go('/me/profile'),
      builder: (context, pressed, hovered) => LuzSurface(
        depth: pressed || hovered ? LuzDepth.insetSm : LuzDepth.flat,
        radius: LuzRadius.sm,
        padding: const EdgeInsets.symmetric(
          horizontal: LuzSpace.sm,
          vertical: LuzSpace.xs,
        ),
        child: Row(
          children: [
            _IconWell(icon: _icon(item.step), size: 36, color: p.accent),
            const SizedBox(width: LuzSpace.md),
            Expanded(child: Text(item.label, style: t.body)),
            const LuzStatusChip(label: '+10%', tone: LuzChipTone.orange),
            const SizedBox(width: LuzSpace.xs),
            Icon(Icons.chevron_right, size: 20, color: p.muted),
          ],
        ),
      ),
    );
  }

  static IconData _icon(ProfileStep step) => switch (step) {
    ProfileStep.resume => Icons.description_outlined,
    ProfileStep.skills => Icons.psychology_outlined,
    ProfileStep.headline => Icons.badge_outlined,
    ProfileStep.location => Icons.place_outlined,
    ProfileStep.experience => Icons.work_outline,
    ProfileStep.education => Icons.school_outlined,
    ProfileStep.bio => Icons.notes,
    ProfileStep.photo => Icons.add_a_photo_outlined,
    ProfileStep.phone => Icons.phone_outlined,
    ProfileStep.link => Icons.link,
  };
}

/// Jobs matched to the profile; until it has skills or a city, the newest
/// jobs, with a nudge to add them.
class _JobsForYou extends ConsumerWidget {
  const _JobsForYou();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.luz;
    final t = context.luzText;
    final all = ref.watch(recommendedJobsProvider).value ?? const <Job>[];
    if (all.isEmpty) return const SizedBox.shrink();
    final matched = all.any(
      (j) => j.matchReasons.any((r) => r != 'New this week'),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: LuzSpace.md,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome_outlined, size: 20, color: p.accent),
                const SizedBox(width: LuzSpace.xs),
                Flexible(
                  child: Semantics(
                    header: true,
                    child: Text(
                      matched ? 'Recommended for you' : 'New this week',
                      style: t.h4,
                    ),
                  ),
                ),
              ],
            ),
            LuzTextLink(
              label: 'See all jobs',
              onPressed: () => context.go('/jobs'),
            ),
          ],
        ),
        if (!matched) ...[
          const SizedBox(height: LuzSpace.xxs),
          Text(
            'Add your skills and city to get jobs matched to you.',
            style: t.bodySm.copyWith(color: p.inkMuted),
          ),
        ],
        const SizedBox(height: LuzSpace.md),
        // Two across: four jobs. One column (phones): two, so the cards
        // below stay in reach.
        LayoutBuilder(
          builder: (context, c) => LuzGrid(
            maxColumns: 2,
            spacing: LuzSpace.md,
            equalHeights: true,
            children: [
              for (final j in all.take(c.maxWidth < 600 ? 2 : 4))
                JobCard(job: j, uniform: true),
            ],
          ),
        ),
      ],
    );
  }
}

/// Live notification list with mark-read (FR-11). Tapping one opens its
/// screen (the related application, interviews, ...).
class NotificationsCard extends ConsumerWidget {
  const NotificationsCard({super.key, this.limit});
  final int? limit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationCountProvider);
    return SectionCard(
      title: unread == 0 ? 'Notifications' : 'Notifications ($unread new)',
      icon: Icons.notifications_none,
      action: const MarkAllReadLink(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NotificationList(
            limit: limit,
            footer: Align(
              alignment: Alignment.centerLeft,
              child: LuzTextLink(
                label: 'See all notifications',
                onPressed: () => context.go('/me/notifications'),
              ),
            ),
          ),
          const SizedBox(height: LuzSpace.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: LuzTextLink(
              label: 'Notification settings',
              onPressed: () => context.go(notificationSettingsPath),
            ),
          ),
        ],
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
