import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/data/enums.dart';
import '../../../core/data/format.dart';
import '../../../core/data/models.dart';
import '../../../core/layout/input_mode.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../../candidate/presentation/candidate_widgets.dart'
    show AsyncBlock, runWithToast, formatDay, formatDayTime;
import '../application/employer_providers.dart';
import '../data/employer_repository.dart';
import 'employer_common.dart';
import 'hiring_forms.dart';

/// Board columns, in pipeline order.
const boardStages = [
  ApplicationStage.applied,
  ApplicationStage.underReview,
  ApplicationStage.shortlisted,
  ApplicationStage.assessment,
  ApplicationStage.technicalInterview,
  ApplicationStage.hrInterview,
  ApplicationStage.finalReview,
  ApplicationStage.offerIssued,
  ApplicationStage.hired,
  ApplicationStage.rejected,
  ApplicationStage.withdrawn,
];

/// Stages the hiring team may move to from [from]. Withdrawing belongs to
/// the candidate; "Offer issued" happens by making an offer.
Set<ApplicationStage> teamMoves(
  Map<ApplicationStage, Set<ApplicationStage>> transitions,
  ApplicationStage from,
) => {
  for (final s in transitions[from] ?? const <ApplicationStage>{})
    if (s != ApplicationStage.withdrawn) s,
};

/// `/employer/pipeline?job=ID` (Stitch: employer-pipeline-desktop.png).
class PipelinePage extends ConsumerWidget {
  const PipelinePage({super.key, this.jobId});
  final String? jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => MembershipGate(
    builder: (context, m) {
      final jobs = ref.watch(companyJobsProvider(m.company.id));
      return AsyncBlock<List<Job>>(
        value: jobs,
        onRetry: () => ref.invalidate(companyJobsProvider(m.company.id)),
        data: (list) {
          final usable = list
              .where((j) => j.status != JobStatus.draft)
              .toList();
          if (usable.isEmpty) {
            return WorkspacePage(
              children: [
                LuzEmptyState(
                  icon: Icons.view_kanban_outlined,
                  title: 'No published jobs yet',
                  message: 'Publish a job and its applicants appear here.',
                  actionLabel: m.role.canEdit ? 'Post a job' : null,
                  onAction: m.role.canEdit
                      ? () => context.go('/employer/jobs/new')
                      : null,
                ),
              ],
            );
          }
          final job =
              usable.where((j) => j.id == jobId).firstOrNull ?? usable.first;
          return _Board(key: ValueKey(job.id), job: job, jobs: usable, m: m);
        },
      );
    },
  );
}

class _Board extends ConsumerStatefulWidget {
  const _Board({
    super.key,
    required this.job,
    required this.jobs,
    required this.m,
  });
  final Job job;
  final List<Job> jobs;
  final Membership m;

  @override
  ConsumerState<_Board> createState() => _BoardState();
}

class _BoardState extends ConsumerState<_Board> {
  String? _selected;
  ApplicationStage? _dragFrom;

  Future<void> _move(
    JobApplication app,
    ApplicationStage to,
    String candidateName,
  ) async {
    if (to == ApplicationStage.offerIssued) {
      await showMakeOffer(
        context,
        application: app,
        candidateName: candidateName,
      );
      return;
    }
    await runWithToast(
      context,
      () => ref.read(employerActionsProvider).moveStage(app.id, to),
      success: '$candidateName moved to ${to.label}',
    );
  }

  void _pickJob() => showLuzModal<void>(
    context: context,
    title: 'Choose a job',
    builder: (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final j in widget.jobs)
          LuzRadio<String>(
            label: '${j.title} (${j.applicationCount})',
            value: j.id,
            groupValue: widget.job.id,
            onChanged: (id) {
              Navigator.of(ctx).pop();
              context.go('/employer/pipeline?job=$id');
            },
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final apps = ref.watch(jobApplicationsProvider(widget.job.id));
    final transitions =
        ref.watch(transitionsProvider).value ??
        const <ApplicationStage, Set<ApplicationStage>>{};
    final canEdit = widget.m.role.canEdit;
    final list = apps.value ?? const <JobApplication>[];
    final profiles =
        ref
            .watch(
              applicantProfilesProvider(idsKey(list.map((a) => a.candidateId))),
            )
            .value ??
        const <String, Profile>{};
    String nameOf(JobApplication a) =>
        profiles[a.candidateId]?.displayName ?? 'Candidate';
    final selected = list.where((a) => a.id == _selected).firstOrNull;

    final board = AsyncBlock<List<JobApplication>>(
      value: apps,
      onRetry: () => ref.invalidate(jobApplicationsProvider(widget.job.id)),
      data: (_) => Scrollbar(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(
            LuzSpace.lg,
            0,
            LuzSpace.lg,
            LuzSpace.lg,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final stage in boardStages)
                if (stage != ApplicationStage.withdrawn ||
                    list.any((a) => a.stage == stage))
                  Padding(
                    padding: const EdgeInsets.only(right: LuzSpace.sm),
                    child: _Column(
                      stage: stage,
                      apps: list.where((a) => a.stage == stage).toList(),
                      profiles: profiles,
                      selectedId: _selected,
                      canEdit: canEdit,
                      accepts: (a) =>
                          canEdit &&
                          teamMoves(transitions, a.stage).contains(stage),
                      highlight:
                          _dragFrom != null &&
                          teamMoves(transitions, _dragFrom!).contains(stage),
                      onSelect: (a) => setState(() => _selected = a.id),
                      onDragStart: (a) => setState(() => _dragFrom = a.stage),
                      onDragEnd: () => setState(() => _dragFrom = null),
                      onDrop: (a) => _move(a, stage, nameOf(a)),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, c) {
        final sidePanel = c.maxWidth >= 1200;
        Widget? panel;
        if (selected != null) {
          panel = CandidatePanel(
            key: ValueKey(selected.id),
            application: selected,
            job: widget.job,
            canEdit: canEdit,
            transitions: transitions,
            onMove: (to) => _move(selected, to, nameOf(selected)),
            onClose: () => setState(() => _selected = null),
          );
        }
        final header = WorkspacePage(
          title: widget.job.title,
          subtitle: '${list.length} candidates · updates live',
          scroll: false,
          actions: [
            JobStatusChip(widget.job.status),
            LuzButton(
              label: 'Switch job',
              icon: Icons.swap_horiz,
              onPressed: _pickJob,
            ),
            LuzButton(
              label: 'View posting',
              icon: Icons.open_in_new,
              onPressed: () => context.go('/jobs/${widget.job.slug}'),
            ),
          ],
          children: [
            if (!canEdit)
              const Padding(
                padding: EdgeInsets.fromLTRB(
                  LuzSpace.lg,
                  0,
                  LuzSpace.lg,
                  LuzSpace.sm,
                ),
                child: ViewerNotice(),
              ),
            Expanded(child: sidePanel || panel == null ? board : panel),
          ],
        );
        if (!sidePanel || panel == null) return header;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: header),
            SizedBox(width: 440, child: panel),
          ],
        );
      },
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({
    required this.stage,
    required this.apps,
    required this.profiles,
    required this.selectedId,
    required this.canEdit,
    required this.accepts,
    required this.highlight,
    required this.onSelect,
    required this.onDragStart,
    required this.onDragEnd,
    required this.onDrop,
  });

  final ApplicationStage stage;
  final List<JobApplication> apps;
  final Map<String, Profile> profiles;
  final String? selectedId;
  final bool canEdit;
  final bool Function(JobApplication) accepts;
  final bool highlight;
  final ValueChanged<JobApplication> onSelect;
  final ValueChanged<JobApplication> onDragStart;
  final VoidCallback onDragEnd;
  final ValueChanged<JobApplication> onDrop;

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    return DragTarget<JobApplication>(
      onWillAcceptWithDetails: (d) => accepts(d.data),
      onAcceptWithDetails: (d) => onDrop(d.data),
      builder: (context, candidates, _) {
        final hovering = candidates.isNotEmpty;
        return AnimatedContainer(
          duration: LuzMotion.press,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(LuzRadius.md),
            border: Border.all(
              color: hovering
                  ? p.accent
                  : highlight
                  ? p.accent.withValues(alpha: 0.5)
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: LuzKanbanColumn(
            width: 260,
            header: LuzStatusChip.stage(stage),
            count: apps.length,
            children: [
              for (final a in apps)
                _Card(
                  app: a,
                  profile: profiles[a.candidateId],
                  selected: a.id == selectedId,
                  draggable: canEdit && !a.stage.isTerminal,
                  onTap: () => onSelect(a),
                  onDragStart: () => onDragStart(a),
                  onDragEnd: onDragEnd,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.app,
    required this.profile,
    required this.selected,
    required this.draggable,
    required this.onTap,
    required this.onDragStart,
    required this.onDragEnd,
  });

  final JobApplication app;
  final Profile? profile;
  final bool selected;
  final bool draggable;
  final VoidCallback onTap;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    final t = context.luzText;
    final name = profile?.displayName ?? 'Candidate';
    Widget card({bool lifted = false}) => LuzPressable(
      radius: LuzRadius.sm,
      selected: selected,
      semanticLabel: '$name, ${app.stage.label}. Open details',
      onPressed: onTap,
      builder: (context, pressed, hovered) => LuzSurface(
        depth: lifted
            ? LuzDepth.raisedLg
            : pressed
            ? LuzDepth.insetSm
            : LuzDepth.raisedSm,
        radius: LuzRadius.sm,
        outline: selected ? p.accent : null,
        outlineWidth: 2,
        padding: const EdgeInsets.all(LuzSpace.sm),
        child: Row(
          children: [
            LuzAvatar(name: name, size: 32),
            const SizedBox(width: LuzSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: t.wsCardTitle,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if ((profile?.headline ?? '').isNotEmpty)
                    Text(
                      profile!.headline!,
                      style: t.caption.copyWith(color: p.inkMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  Text(
                    'Applied ${formatRelative(app.createdAt)}',
                    style: t.caption.copyWith(color: p.muted),
                  ),
                ],
              ),
            ),
            if (app.resumeId != null)
              Tooltip(
                message: 'Resume attached',
                child: Icon(
                  Icons.description_outlined,
                  size: 16,
                  color: p.muted,
                ),
              ),
          ],
        ),
      ),
    );

    if (!draggable) return card();
    final feedback = Material(
      color: Colors.transparent,
      child: SizedBox(width: 240, child: card(lifted: true)),
    );
    final ghost = Opacity(opacity: 0.4, child: card());
    // Touch: long-press to drag (a plain drag scrolls the board).
    return context.isPointer
        ? Draggable<JobApplication>(
            data: app,
            feedback: feedback,
            childWhenDragging: ghost,
            onDragStarted: onDragStart,
            onDragEnd: (_) => onDragEnd(),
            child: card(),
          )
        : LongPressDraggable<JobApplication>(
            data: app,
            feedback: feedback,
            childWhenDragging: ghost,
            onDragStarted: onDragStart,
            onDragEnd: (_) => onDragEnd(),
            child: card(),
          );
  }
}

/// Candidate drawer: profile, resume, history, interviews, offer and moves.
class CandidatePanel extends ConsumerWidget {
  const CandidatePanel({
    super.key,
    required this.application,
    required this.job,
    required this.canEdit,
    required this.transitions,
    required this.onMove,
    required this.onClose,
  });

  final JobApplication application;
  final Job job;
  final bool canEdit;
  final Map<ApplicationStage, Set<ApplicationStage>> transitions;
  final ValueChanged<ApplicationStage> onMove;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.luz;
    final t = context.luzText;
    final a = application;
    final detail = ref.watch(candidateDetailProvider(a.candidateId));
    final interviews =
        ref.watch(employerInterviewsProvider(a.id)).value ??
        const <Interview>[];
    final offer =
        (ref.watch(employerOffersProvider(a.id)).value ?? const <Offer>[])
            .firstOrNull;
    final events = ref.watch(employerEventsProvider(a.id)).value ?? const [];
    final moves = teamMoves(transitions, a.stage);
    final name = detail.value?.profile.displayName ?? 'Candidate';
    final actions = ref.read(employerActionsProvider);

    Widget section(String title, List<Widget> children) => Padding(
      padding: const EdgeInsets.only(top: LuzSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title.toUpperCase(),
            style: t.eyebrow.copyWith(color: p.inkMuted),
          ),
          const SizedBox(height: LuzSpace.xs),
          ...children,
        ],
      ),
    );

    return LuzSurface(
      depth: LuzDepth.raisedMd,
      radius: 0,
      child: ListView(
        padding: const EdgeInsets.all(LuzSpace.lg),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LuzAvatar(name: name, size: 48),
              const SizedBox(width: LuzSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(name, style: t.wsTitle),
                    ),
                    if ((detail.value?.profile.headline ?? '').isNotEmpty)
                      Text(
                        detail.value!.profile.headline!,
                        style: t.bodySm.copyWith(color: p.inkMuted),
                      ),
                    if ((detail.value?.profile.location ?? '').isNotEmpty)
                      Text(
                        detail.value!.profile.location!,
                        style: t.caption.copyWith(color: p.muted),
                      ),
                  ],
                ),
              ),
              LuzIconButton(
                icon: Icons.close,
                tooltip: 'Close',
                size: 36,
                onPressed: onClose,
              ),
            ],
          ),
          const SizedBox(height: LuzSpace.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: LuzStatusChip.stage(a.stage),
          ),
          if (canEdit && !a.stage.isTerminal) ...[
            section('Move to', [
              Wrap(
                spacing: LuzSpace.xs,
                runSpacing: LuzSpace.xs,
                children: [
                  for (final s in boardStages)
                    if (moves.contains(s))
                      LuzButton(
                        label: s == ApplicationStage.offerIssued
                            ? 'Make offer'
                            : s.label,
                        icon: s.icon,
                        onPressed: s == ApplicationStage.rejected
                            ? () async {
                                final ok = await confirmLuz(
                                  context,
                                  title: 'Reject $name?',
                                  message:
                                      'They are told their application did not '
                                      'move forward.',
                                  confirmLabel: 'Reject',
                                  icon: s.icon,
                                );
                                if (ok) onMove(s);
                              }
                            : () => onMove(s),
                      ),
                ],
              ),
              const SizedBox(height: LuzSpace.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: LuzButton.accent(
                  label: 'Schedule interview',
                  icon: Icons.event_available_outlined,
                  onPressed: () => showScheduleInterview(
                    context,
                    application: a,
                    candidateName: name,
                  ),
                ),
              ),
            ]),
          ],
          section('Application', [
            Text(
              'Applied ${formatDay(a.createdAt)} for ${job.title}',
              style: t.bodySm,
            ),
            const SizedBox(height: LuzSpace.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: a.resumeId == null
                  ? Text(
                      'No resume attached',
                      style: t.bodySm.copyWith(color: p.muted),
                    )
                  : LuzTextLink(
                      label: 'Open resume',
                      onPressed: () => runWithToast(context, () async {
                        final url = await ref
                            .read(employerRepositoryProvider)
                            .resumeUrl(a);
                        if (url != null) await launchUrl(Uri.parse(url));
                      }),
                    ),
            ),
            if ((a.coverLetter ?? '').isNotEmpty) ...[
              const SizedBox(height: LuzSpace.xs),
              Text('Cover letter', style: t.label),
              Text(a.coverLetter!, style: t.bodySm),
            ],
          ]),
          if (offer != null)
            section('Offer', [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      formatMoney(
                            offer.salary,
                            offer.salary,
                            offer.currency,
                            offer.salaryPeriod,
                          ) ??
                          'Offer',
                      style: t.wsCardTitle.copyWith(
                        fontFamily: t.mono.fontFamily,
                      ),
                    ),
                  ),
                  LuzStatusChip(
                    label: offer.awaitingReply
                        ? 'Awaiting reply'
                        : offer.status.label,
                    tone: offer.status == OfferStatus.accepted
                        ? LuzChipTone.green
                        : offer.status == OfferStatus.issued
                        ? LuzChipTone.orange
                        : LuzChipTone.neutral,
                  ),
                ],
              ),
              if (canEdit && offer.status == OfferStatus.issued)
                Align(
                  alignment: Alignment.centerLeft,
                  child: LuzTextLink(
                    label: 'Withdraw offer',
                    onPressed: () => runWithToast(
                      context,
                      () => actions.withdrawOffer(offer.id),
                      success: 'Offer withdrawn',
                    ),
                  ),
                ),
            ]),
          if (interviews.isNotEmpty)
            section('Interviews', [
              for (final i in interviews)
                _InterviewRow(interview: i, canEdit: canEdit),
            ]),
          AsyncBlock<CandidateDetail>(
            value: detail,
            onRetry: () =>
                ref.invalidate(candidateDetailProvider(a.candidateId)),
            data: (d) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if ((d.profile.bio ?? '').isNotEmpty)
                  section('About', [Text(d.profile.bio!, style: t.bodySm)]),
                if (d.skills.isNotEmpty)
                  section('Skills', [
                    Wrap(
                      spacing: LuzSpace.xs,
                      runSpacing: LuzSpace.xs,
                      children: [
                        for (final s in d.skills)
                          LuzStatusChip(label: s, tone: LuzChipTone.neutral),
                      ],
                    ),
                  ]),
                if (d.experiences.isNotEmpty)
                  section('Experience', [
                    for (final e in d.experiences)
                      Padding(
                        padding: const EdgeInsets.only(bottom: LuzSpace.xs),
                        child: Text(
                          '${e.title} · ${e.company}',
                          style: t.bodySm,
                        ),
                      ),
                  ]),
                if (d.educations.isNotEmpty)
                  section('Education', [
                    for (final e in d.educations)
                      Padding(
                        padding: const EdgeInsets.only(bottom: LuzSpace.xs),
                        child: Text(
                          [
                            e.institution,
                            e.degree,
                            e.field,
                          ].whereType<String>().join(' · '),
                          style: t.bodySm,
                        ),
                      ),
                  ]),
                if (d.profile.links.isNotEmpty)
                  section('Links', [
                    Wrap(
                      spacing: LuzSpace.md,
                      children: [
                        for (final l in d.profile.links.entries)
                          LuzTextLink(
                            label: l.key,
                            onPressed: () => launchUrl(
                              Uri.parse(l.value),
                              mode: LaunchMode.externalApplication,
                            ),
                          ),
                      ],
                    ),
                  ]),
              ],
            ),
          ),
          if (events.isNotEmpty)
            section('History', [
              for (final e in events.reversed)
                Padding(
                  padding: const EdgeInsets.only(bottom: LuzSpace.xxs),
                  child: Row(
                    children: [
                      Icon(e.toStage.icon, size: 14, color: p.accent),
                      const SizedBox(width: LuzSpace.xs),
                      Expanded(
                        child: Text(
                          e.fromStage == null
                              ? 'Applied'
                              : 'Moved to ${e.toStage.label}',
                          style: t.bodySm,
                        ),
                      ),
                      Text(
                        formatDayTime(e.createdAt),
                        style: t.caption.copyWith(color: p.muted),
                      ),
                    ],
                  ),
                ),
            ]),
        ],
      ),
    );
  }
}

class _InterviewRow extends ConsumerWidget {
  const _InterviewRow({required this.interview, required this.canEdit});
  final Interview interview;
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.luzText;
    final p = context.luz;
    final i = interview;
    final actions = ref.read(employerActionsProvider);
    return Padding(
      padding: const EdgeInsets.only(bottom: LuzSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(i.mode.icon, size: 16, color: p.accent),
              const SizedBox(width: LuzSpace.xs),
              Expanded(
                child: Text(
                  '${DateFormat('EEE d MMM, h:mm a').format(i.scheduledAt.toLocal())}'
                  ' · ${i.durationMin} min',
                  style: t.bodySm,
                ),
              ),
              LuzStatusChip(label: i.status.label, tone: LuzChipTone.blue),
            ],
          ),
          if ((i.notes ?? '').isNotEmpty)
            Text(
              'Notes: ${i.notes}',
              style: t.caption.copyWith(color: p.inkMuted),
            ),
          if (canEdit && i.status == InterviewStatus.scheduled)
            Wrap(
              spacing: LuzSpace.md,
              children: [
                LuzTextLink(
                  label: 'Mark completed',
                  onPressed: () => runWithToast(
                    context,
                    () => actions.setInterviewStatus(
                      i.id,
                      InterviewStatus.completed,
                    ),
                  ),
                ),
                LuzTextLink(
                  label: 'No-show',
                  onPressed: () => runWithToast(
                    context,
                    () => actions.setInterviewStatus(
                      i.id,
                      InterviewStatus.noShow,
                    ),
                  ),
                ),
                LuzTextLink(
                  label: 'Cancel',
                  onPressed: () => runWithToast(
                    context,
                    () => actions.setInterviewStatus(
                      i.id,
                      InterviewStatus.cancelled,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
