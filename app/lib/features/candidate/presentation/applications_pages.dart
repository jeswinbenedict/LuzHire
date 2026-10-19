import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/data/enums.dart';
import '../../../core/data/format.dart';
import '../../../core/data/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../application/candidate_providers.dart';
import '../data/applications_repository.dart';
import 'candidate_widgets.dart';
import 'interviews_page.dart' show InterviewCard;

enum _Filter { all, active, offers, closed }

bool _matches(_Filter f, ApplicationStage s) => switch (f) {
  _Filter.all => true,
  _Filter.active => !s.isTerminal && s != ApplicationStage.offerIssued,
  _Filter.offers =>
    s == ApplicationStage.offerIssued || s == ApplicationStage.hired,
  _Filter.closed =>
    s == ApplicationStage.rejected || s == ApplicationStage.withdrawn,
};

/// /me/applications: live tracker (Stitch: candidate dashboard pipeline).
class ApplicationsPage extends ConsumerStatefulWidget {
  const ApplicationsPage({super.key});

  @override
  ConsumerState<ApplicationsPage> createState() => _ApplicationsPageState();
}

class _ApplicationsPageState extends ConsumerState<ApplicationsPage> {
  _Filter _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final apps = ref.watch(myApplicationsProvider);
    return AsyncBlock<List<JobApplication>>(
      value: apps,
      onRetry: () => ref.invalidate(myApplicationsProvider),
      data: (list) {
        if (list.isEmpty) {
          return LuzEmptyState(
            icon: Icons.send_outlined,
            title: 'No applications yet',
            message: 'Apply to a job and follow every stage here, live.',
            actionLabel: 'Browse jobs',
            onAction: () => context.go('/jobs'),
          );
        }
        final shown = list.where((a) => _matches(_filter, a.stage)).toList();
        int count(_Filter f) => list.where((a) => _matches(f, a.stage)).length;
        return CandidatePage(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: LuzSegmented<_Filter>(
                segments: [
                  (
                    value: _Filter.all,
                    label: 'All (${list.length})',
                    icon: null,
                  ),
                  (
                    value: _Filter.active,
                    label: 'In progress (${count(_Filter.active)})',
                    icon: null,
                  ),
                  (
                    value: _Filter.offers,
                    label: 'Offers (${count(_Filter.offers)})',
                    icon: null,
                  ),
                  (
                    value: _Filter.closed,
                    label: 'Closed (${count(_Filter.closed)})',
                    icon: null,
                  ),
                ],
                selected: _filter,
                onChanged: (f) => setState(() => _filter = f),
              ),
            ),
            const SizedBox(height: LuzSpace.lg),
            if (shown.isEmpty)
              Text(
                'Nothing here.',
                style: context.luzText.body.copyWith(color: context.luz.muted),
              )
            else
              ApplicationList(applications: shown),
          ],
        );
      },
    );
  }
}

/// Application tiles with their jobs (shared with the dashboard).
class ApplicationList extends ConsumerWidget {
  const ApplicationList({super.key, required this.applications});
  final List<JobApplication> applications;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs =
        ref
            .watch(
              jobsByIdsProvider(jobIdsKey(applications.map((a) => a.jobId))),
            )
            .value ??
        const <String, Job>{};
    return Column(
      children: [
        for (final a in applications) ...[
          ApplicationTile(application: a, job: jobs[a.jobId]),
          const SizedBox(height: LuzSpace.md),
        ],
      ],
    );
  }
}

class ApplicationTile extends StatelessWidget {
  const ApplicationTile({super.key, required this.application, this.job});
  final JobApplication application;
  final Job? job;

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    final t = context.luzText;
    final title = job?.title ?? 'Job no longer listed';
    return LuzPressable(
      radius: LuzRadius.lg,
      semanticLabel: '$title, ${application.stage.label}',
      onPressed: () => context.go('/me/applications/${application.id}'),
      builder: (context, pressed, hovered) => LuzSurface(
        depth: pressed
            ? LuzDepth.insetSm
            : hovered
            ? LuzDepth.raisedLg
            : LuzDepth.raisedMd,
        radius: LuzRadius.lg,
        padding: const EdgeInsets.all(LuzSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LuzLogoSocket(
                  name: job?.companyName ?? '?',
                  logoUrl: job?.logoUrl,
                  size: 44,
                ),
                const SizedBox(width: LuzSpace.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: t.h4, maxLines: 2),
                      if (job != null)
                        Text(
                          [
                            job!.companyName,
                            formatPlace(job!),
                          ].where((s) => s.isNotEmpty).join(' · '),
                          style: t.bodySm.copyWith(color: p.inkMuted),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: LuzSpace.xs),
                LuzStatusChip.stage(application.stage),
              ],
            ),
            const SizedBox(height: LuzSpace.md),
            StageStepper(stage: application.stage),
            const SizedBox(height: LuzSpace.sm),
            Text(
              'Applied ${formatDay(application.createdAt)} · updated '
              '${formatRelative(application.updatedAt)}',
              style: t.caption.copyWith(color: p.muted),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- detail

/// /me/applications/:id: stage, timeline, interviews, offer, withdraw.
class ApplicationDetailPage extends ConsumerWidget {
  const ApplicationDetailPage({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apps = ref.watch(myApplicationsProvider);
    return AsyncBlock<List<JobApplication>>(
      value: apps,
      onRetry: () => ref.invalidate(myApplicationsProvider),
      data: (list) {
        final app = list.where((a) => a.id == id).firstOrNull;
        if (app == null) {
          return LuzEmptyState(
            icon: Icons.search_off,
            title: 'Application not found',
            actionLabel: 'All applications',
            onAction: () => context.go('/me/applications'),
          );
        }
        return _Detail(app: app);
      },
    );
  }
}

class _Detail extends ConsumerWidget {
  const _Detail({required this.app});
  final JobApplication app;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.luz;
    final t = context.luzText;
    final job = ref.watch(jobsByIdsProvider(app.jobId)).value?[app.jobId];
    final offer = (ref.watch(myOffersProvider).value ?? const <Offer>[])
        .where((o) => o.applicationId == app.id)
        .firstOrNull;
    final interviews =
        (ref.watch(myInterviewsProvider).value ?? const <Interview>[])
            .where((i) => i.applicationId == app.id)
            .toList();
    final resumes = ref.watch(myResumesProvider).value ?? const <Resume>[];
    final resume = resumes.where((r) => r.id == app.resumeId).firstOrNull;

    return CandidatePage(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: LuzTextLink(
            label: '← All applications',
            onPressed: () => context.go('/me/applications'),
          ),
        ),
        const SizedBox(height: LuzSpace.md),
        LuzCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: LuzSpace.sm,
                runSpacing: LuzSpace.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      job?.title ?? 'Job no longer listed',
                      style: t.h3,
                    ),
                  ),
                  LuzStatusChip.stage(app.stage),
                ],
              ),
              if (job != null) ...[
                const SizedBox(height: LuzSpace.xxs),
                Wrap(
                  spacing: LuzSpace.sm,
                  children: [
                    Text(
                      job.companyName,
                      style: t.body.copyWith(color: p.inkMuted),
                    ),
                    LuzTextLink(
                      label: 'View job',
                      onPressed: () => context.go('/jobs/${job.slug}'),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: LuzSpace.lg),
              StageStepper(stage: app.stage),
              const SizedBox(height: LuzSpace.sm),
              Semantics(
                liveRegion: true,
                child: Text(
                  'Updates from the employer appear here instantly.',
                  style: t.caption.copyWith(color: p.muted),
                ),
              ),
            ],
          ),
        ),
        if (offer != null) ...[
          const SizedBox(height: LuzSpace.lg),
          _OfferCard(offer: offer),
        ],
        if (interviews.isNotEmpty) ...[
          const SizedBox(height: LuzSpace.lg),
          SectionCard(
            title: 'Interviews',
            icon: Icons.event_outlined,
            child: Column(
              children: [
                for (final i in interviews) ...[
                  InterviewCard(interview: i, job: job),
                  const SizedBox(height: LuzSpace.sm),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: LuzSpace.lg),
        SectionCard(
          title: 'Timeline',
          icon: Icons.history,
          child: _Timeline(applicationId: app.id),
        ),
        const SizedBox(height: LuzSpace.lg),
        SectionCard(
          title: 'What you sent',
          icon: Icons.description_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                app.resumeId == null
                    ? 'No resume attached'
                    : resume?.fileName ?? 'Resume (since deleted)',
                style: t.label,
              ),
              const SizedBox(height: LuzSpace.sm),
              Text(
                (app.coverLetter ?? '').isEmpty
                    ? 'No cover letter'
                    : app.coverLetter!,
                style: t.body.copyWith(
                  color: (app.coverLetter ?? '').isEmpty ? p.muted : p.ink,
                ),
              ),
            ],
          ),
        ),
        if (!app.stage.isTerminal) ...[
          const SizedBox(height: LuzSpace.lg),
          Align(
            alignment: Alignment.centerLeft,
            child: LuzButton(
              label: 'Withdraw application',
              icon: Icons.logout,
              onPressed: () async {
                final ok = await confirmLuz(
                  context,
                  title: 'Withdraw this application?',
                  message:
                      'The employer is told you withdrew. You cannot apply '
                      'to this job again.',
                  confirmLabel: 'Withdraw',
                  icon: Icons.logout,
                );
                if (ok && context.mounted) {
                  await runWithToast(
                    context,
                    () => ref.read(candidateActionsProvider).withdraw(app.id),
                    success: 'Application withdrawn',
                  );
                }
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _Timeline extends ConsumerWidget {
  const _Timeline({required this.applicationId});
  final String applicationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.luz;
    final t = context.luzText;
    return AsyncBlock<List<ApplicationEvent>>(
      value: ref.watch(applicationEventsProvider(applicationId)),
      onRetry: () => ref.invalidate(applicationEventsProvider(applicationId)),
      data: (events) => Column(
        children: [
          for (final e in events.reversed)
            Padding(
              padding: const EdgeInsets.only(bottom: LuzSpace.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(e.toStage.icon, size: 18, color: p.accent),
                  const SizedBox(width: LuzSpace.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.fromStage == null
                              ? 'Application sent'
                              : 'Moved to ${e.toStage.label}',
                          style: t.label,
                        ),
                        if ((e.note ?? '').isNotEmpty)
                          Text(e.note!, style: t.bodySm),
                      ],
                    ),
                  ),
                  Text(
                    formatDayTime(e.createdAt),
                    style: t.caption.copyWith(color: p.muted),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _OfferCard extends ConsumerWidget {
  const _OfferCard({required this.offer});
  final Offer offer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.luz;
    final t = context.luzText;
    final pay = formatMoney(
      offer.salary,
      offer.salary,
      offer.currency,
      offer.salaryPeriod,
    );
    Future<void> respond(bool accept) async {
      final ok = await confirmLuz(
        context,
        title: accept ? 'Accept this offer?' : 'Decline this offer?',
        message: accept
            ? 'The employer is told straight away and your application is '
                  'marked as hired.'
            : 'The employer is told you declined. This cannot be undone.',
        confirmLabel: accept ? 'Accept offer' : 'Decline offer',
        icon: accept ? Icons.handshake_outlined : Icons.close,
      );
      if (ok && context.mounted) {
        await runWithToast(
          context,
          () => ref
              .read(candidateActionsProvider)
              .respondToOffer(offer.id, accept: accept),
          success: accept
              ? 'Offer accepted. Congratulations!'
              : 'Offer declined',
        );
      }
    }

    return SectionCard(
      title: 'Offer',
      icon: Icons.mark_email_unread_outlined,
      action: LuzStatusChip(
        label: offer.status.label,
        tone: switch (offer.status) {
          OfferStatus.issued => LuzChipTone.orange,
          OfferStatus.accepted => LuzChipTone.green,
          _ => LuzChipTone.neutral,
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (pay != null)
            Text(pay, style: t.h3.copyWith(fontFamily: t.mono.fontFamily)),
          if (offer.startDate != null)
            Text('Start date: ${formatDay(offer.startDate!)}', style: t.body),
          if (offer.expiresAt != null && offer.awaitingReply)
            Text(
              'Reply by ${formatDayTime(offer.expiresAt!)}',
              style: t.body.copyWith(color: p.inkMuted),
            ),
          if (offer.letterPath != null) ...[
            const SizedBox(height: LuzSpace.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: LuzTextLink(
                label: 'Open offer letter (PDF)',
                onPressed: () => runWithToast(context, () async {
                  final url = await ref
                      .read(applicationsRepositoryProvider)
                      .offerLetterUrl(offer.letterPath!);
                  await launchUrl(Uri.parse(url));
                }),
              ),
            ),
          ],
          if (offer.awaitingReply) ...[
            const SizedBox(height: LuzSpace.lg),
            Wrap(
              spacing: LuzSpace.sm,
              runSpacing: LuzSpace.sm,
              children: [
                LuzButton.accent(
                  label: 'Accept offer',
                  icon: Icons.handshake_outlined,
                  onPressed: () => respond(true),
                ),
                LuzButton(
                  label: 'Decline',
                  icon: Icons.close,
                  onPressed: () => respond(false),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
