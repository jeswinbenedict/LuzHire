import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/enums.dart';
import '../../../core/data/format.dart';
import '../../../core/data/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../../candidate/presentation/candidate_widgets.dart'
    show AsyncBlock, runWithToast;
import '../../jobs/application/job_board_providers.dart' show jobSkillsProvider;
import '../../jobs/presentation/job_widgets.dart' show JobCard;
import '../application/employer_providers.dart';
import '../data/employer_repository.dart';
import 'employer_common.dart';

/// /employer/jobs: every job of the company with its status and actions.
class EmployerJobsPage extends ConsumerWidget {
  const EmployerJobsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MembershipGate(
    builder: (context, m) {
      final jobs = ref.watch(companyJobsProvider(m.company.id));
      return WorkspacePage(
        subtitle: m.company.name,
        actions: [
          if (m.role.canEdit)
            LuzButton.accent(
              label: 'Post a job',
              icon: Icons.add,
              onPressed: () => context.go('/employer/jobs/new'),
            ),
        ],
        children: [
          AsyncBlock<List<Job>>(
            value: jobs,
            onRetry: () => ref.invalidate(companyJobsProvider(m.company.id)),
            data: (list) => list.isEmpty
                ? LuzEmptyState(
                    icon: Icons.work_outline,
                    title: 'No jobs yet',
                    message:
                        'Post your first role to start receiving '
                        'applications.',
                    actionLabel: m.role.canEdit ? 'Post a job' : null,
                    onAction: m.role.canEdit
                        ? () => context.go('/employer/jobs/new')
                        : null,
                  )
                : LuzDataTable<Job>(
                    rows: list,
                    onRowTap: (j) => context.go(
                      m.role.canEdit
                          ? '/employer/jobs/${j.id}'
                          : '/employer/pipeline?job=${j.id}',
                    ),
                    columns: [
                      LuzColumn(
                        label: 'Title',
                        flex: 3,
                        sortKey: (j) => j.title.toLowerCase(),
                        cell: (_, j) => Text(
                          j.title,
                          overflow: TextOverflow.ellipsis,
                          style: context.luzText.label,
                        ),
                      ),
                      LuzColumn(
                        label: 'Status',
                        flex: 2,
                        sortKey: (j) => j.status.index,
                        cell: (_, j) => Align(
                          alignment: Alignment.centerLeft,
                          child: JobStatusChip(j.status),
                        ),
                      ),
                      LuzColumn(
                        label: 'Applicants',
                        numeric: true,
                        sortKey: (j) => j.applicationCount,
                        cell: (_, j) => Text('${j.applicationCount}'),
                      ),
                      LuzColumn(
                        label: 'Posted',
                        flex: 2,
                        sortKey: (j) => j.publishedAt ?? DateTime(0),
                        cell: (_, j) => Text(
                          j.publishedAt == null
                              ? '—'
                              : formatRelative(j.publishedAt!),
                        ),
                      ),
                      LuzColumn(
                        label: 'Pipeline',
                        cell: (_, j) => LuzTextLink(
                          label: 'Open',
                          onPressed: () =>
                              context.go('/employer/pipeline?job=${j.id}'),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      );
    },
  );
}

/// /employer/jobs/new and /employer/jobs/:id: the job editor.
class JobEditorPage extends ConsumerWidget {
  const JobEditorPage({super.key, this.jobId});
  final String? jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => MembershipGate(
    builder: (context, m) {
      if (!m.role.canEdit) {
        return const WorkspacePage(title: 'Job', children: [ViewerNotice()]);
      }
      if (jobId == null) {
        return _Editor(
          draft: JobDraft(companyId: m.company.id),
          m: m,
        );
      }
      final jobs = ref.watch(companyJobsProvider(m.company.id));
      return AsyncBlock<List<Job>>(
        value: jobs,
        onRetry: () => ref.invalidate(companyJobsProvider(m.company.id)),
        data: (list) {
          final job = list.where((j) => j.id == jobId).firstOrNull;
          if (job == null) {
            return const LuzEmptyState(
              icon: Icons.search_off,
              title: 'Job not found',
            );
          }
          final skills = ref.watch(jobSkillsProvider(job.id));
          return AsyncBlock<List<String>>(
            value: skills,
            onRetry: () => ref.invalidate(jobSkillsProvider(job.id)),
            data: (s) => _Editor(
              key: ValueKey(job.id),
              draft: JobDraft.fromJob(job, skills: s),
              job: job,
              m: m,
            ),
          );
        },
      );
    },
  );
}

class _Editor extends ConsumerStatefulWidget {
  const _Editor({super.key, required this.draft, required this.m, this.job});
  final JobDraft draft;
  final Job? job;
  final Membership m;

  @override
  ConsumerState<_Editor> createState() => _EditorState();
}

class _EditorState extends ConsumerState<_Editor> {
  late final JobDraft d = widget.draft;
  late final _title = TextEditingController(text: d.title);
  late final _summary = TextEditingController(text: d.summary);
  late final _desc = TextEditingController(text: d.descriptionMd);
  late final _location = TextEditingController(text: d.location);
  late final _min = TextEditingController(text: _n(d.salaryMin));
  late final _max = TextEditingController(text: _n(d.salaryMax));
  late final _resp = TextEditingController(text: d.responsibilities.join('\n'));
  late final _qual = TextEditingController(text: d.qualifications.join('\n'));
  late final _benefits = TextEditingController(text: d.benefits.join('\n'));
  late final _skills = TextEditingController(text: d.skills.join(', '));
  late final _deadline = TextEditingController(text: dbDate(d.deadline) ?? '');
  final _errors = <String, String?>{};
  bool _busy = false;

  static String _n(double? v) => v == null ? '' : v.toStringAsFixed(0);

  List<TextEditingController> get _all => [
    _title,
    _summary,
    _desc,
    _location,
    _min,
    _max,
    _resp,
    _qual,
    _benefits,
    _skills,
    _deadline,
  ];

  @override
  void initState() {
    super.initState();
    for (final c in _all) {
      c.addListener(_sync);
    }
  }

  @override
  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> _lines(TextEditingController c) => [
    for (final l in c.text.split('\n'))
      if (l.trim().isNotEmpty) l.trim(),
  ];

  /// Copies the fields into the draft so the preview stays live.
  void _sync() => setState(() {
    d
      ..title = _title.text
      ..summary = _summary.text
      ..descriptionMd = _desc.text
      ..location = _location.text
      ..salaryMin = double.tryParse(_min.text.replaceAll(',', ''))
      ..salaryMax = double.tryParse(_max.text.replaceAll(',', ''))
      ..responsibilities = _lines(_resp)
      ..qualifications = _lines(_qual)
      ..benefits = _lines(_benefits)
      ..skills = [
        for (final s in _skills.text.split(','))
          if (s.trim().isNotEmpty) s.trim(),
      ]
      ..deadline = DateTime.tryParse(_deadline.text.trim());
  });

  bool _validate() {
    _sync();
    final min = d.salaryMin, max = d.salaryMax;
    setState(() {
      _errors
        ..['title'] = d.title.trim().length < 2 ? 'Enter a job title' : null
        ..['min'] = _min.text.trim().isNotEmpty && min == null
            ? 'Numbers only'
            : null
        ..['max'] = _max.text.trim().isNotEmpty && max == null
            ? 'Numbers only'
            : (min != null && max != null && max < min)
            ? 'Must be at least the minimum'
            : null
        ..['deadline'] = _deadline.text.trim().isNotEmpty && d.deadline == null
            ? 'Use YYYY-MM-DD'
            : null;
    });
    return _errors.values.every((e) => e == null);
  }

  Future<void> _save(JobStatus status) async {
    if (!_validate()) return;
    setState(() => _busy = true);
    try {
      final saved = await ref.read(employerActionsProvider).saveJob(d, status);
      if (!mounted) return;
      final message = switch (saved.status) {
        JobStatus.published => 'Published. It is live on the job board.',
        JobStatus.pendingReview =>
          'Sent for review. It goes live once an admin approves it '
              '(verified companies skip this step).',
        _ => 'Draft saved',
      };
      showLuzToast(context, message, icon: Icons.check);
      context.go('/employer/jobs');
    } catch (e) {
      if (mounted) {
        showLuzToast(context, messageOf(e), icon: Icons.error_outline);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.luzText;
    final p = context.luz;
    const gap = SizedBox(height: LuzSpace.md);
    final job = widget.job;
    final form = LuzCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LuzTextField(
            label: 'Job title',
            controller: _title,
            error: _errors['title'],
            maxLength: 160,
          ),
          gap,
          LuzTextField(
            label: 'One-line summary',
            controller: _summary,
            maxLength: 400,
          ),
          gap,
          Text('Employment type', style: t.label),
          const SizedBox(height: LuzSpace.xs),
          Wrap(
            spacing: LuzSpace.xs,
            runSpacing: LuzSpace.xs,
            children: [
              for (final e in EmploymentType.values)
                LuzFilterChip(
                  label: e.label,
                  selected: d.employmentType == e,
                  onSelected: (_) => setState(() => d.employmentType = e),
                ),
            ],
          ),
          gap,
          Text('Experience level', style: t.label),
          const SizedBox(height: LuzSpace.xs),
          Wrap(
            spacing: LuzSpace.xs,
            runSpacing: LuzSpace.xs,
            children: [
              for (final e in ExperienceLevel.values)
                LuzFilterChip(
                  label: e.label,
                  selected: d.experienceLevel == e,
                  onSelected: (_) => setState(
                    () => d.experienceLevel = d.experienceLevel == e ? null : e,
                  ),
                ),
            ],
          ),
          gap,
          Text('Workplace', style: t.label),
          const SizedBox(height: LuzSpace.xs),
          LuzSegmented<WorkplaceType>(
            segments: [
              for (final w in WorkplaceType.values)
                (value: w, label: w.label, icon: null),
            ],
            selected: d.workplace,
            onChanged: (w) => setState(() => d.workplace = w),
          ),
          gap,
          LuzTextField(
            label: 'Location',
            hint: 'e.g. Bengaluru, IN',
            controller: _location,
            prefixIcon: Icons.place_outlined,
          ),
          gap,
          Text('Salary (optional)', style: t.label),
          const SizedBox(height: LuzSpace.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: LuzTextField(
                  label: 'Minimum (₹)',
                  controller: _min,
                  error: _errors['min'],
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: LuzSpace.sm),
              Expanded(
                child: LuzTextField(
                  label: 'Maximum (₹)',
                  controller: _max,
                  error: _errors['max'],
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: LuzSpace.sm),
          LuzSegmented<SalaryPeriod>(
            segments: [
              for (final s in SalaryPeriod.values)
                (value: s, label: 'per ${s.label}', icon: null),
            ],
            selected: d.salaryPeriod,
            onChanged: (s) => setState(() => d.salaryPeriod = s),
          ),
          gap,
          LuzTextField(
            label: 'Description (Markdown: ## headings, - bullets, **bold**)',
            controller: _desc,
            maxLines: 14,
            maxLength: 30000,
          ),
          gap,
          LuzTextField(
            label: 'Responsibilities (one per line)',
            controller: _resp,
            maxLines: 6,
          ),
          gap,
          LuzTextField(
            label: 'Requirements (one per line)',
            controller: _qual,
            maxLines: 6,
          ),
          gap,
          LuzTextField(
            label: 'Benefits (one per line)',
            controller: _benefits,
            maxLines: 4,
          ),
          gap,
          LuzTextField(
            label: 'Skills (comma separated)',
            hint: 'Flutter, Dart, Firebase',
            controller: _skills,
          ),
          gap,
          LuzTextField(
            label: 'Apply by (YYYY-MM-DD, optional)',
            controller: _deadline,
            error: _errors['deadline'],
          ),
        ],
      ),
    );

    final draftOnly =
        job == null ||
        job.status == JobStatus.draft ||
        job.status == JobStatus.rejected;
    final buttons = Wrap(
      spacing: LuzSpace.sm,
      runSpacing: LuzSpace.sm,
      children: [
        LuzButton.accent(
          label: _busy
              ? 'Saving…'
              : job?.status == JobStatus.published
              ? 'Save changes'
              : 'Publish',
          icon: Icons.public,
          onPressed: _busy
              ? null
              : () => _save(
                  job?.status == JobStatus.published ||
                          job?.status == JobStatus.pendingReview
                      ? job!.status
                      : JobStatus.published,
                ),
        ),
        if (draftOnly)
          LuzButton(
            label: 'Save draft',
            icon: Icons.save_outlined,
            onPressed: _busy ? null : () => _save(JobStatus.draft),
          ),
        if (job != null) _StatusActions(job: job),
      ],
    );

    final preview = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('PREVIEW', style: t.eyebrow.copyWith(color: p.inkMuted)),
        const SizedBox(height: LuzSpace.xs),
        IgnorePointer(child: JobCard(job: d.preview(widget.m.company.name))),
        const SizedBox(height: LuzSpace.sm),
        Text(
          'This is how the job appears in search results.',
          style: t.caption.copyWith(color: p.muted),
        ),
      ],
    );

    return WorkspacePage(
      title: job == null ? 'Post a job' : 'Edit job',
      subtitle: job == null ? widget.m.company.name : job.title,
      actions: [
        if (job != null) JobStatusChip(job.status),
        LuzButton(
          label: 'Back to jobs',
          icon: Icons.arrow_back,
          onPressed: () => context.go('/employer/jobs'),
        ),
      ],
      children: [
        LayoutBuilder(
          builder: (context, c) {
            if (c.maxWidth < 1000) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  preview,
                  const SizedBox(height: LuzSpace.lg),
                  form,
                  const SizedBox(height: LuzSpace.lg),
                  buttons,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: form),
                const SizedBox(width: LuzSpace.lg),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      preview,
                      const SizedBox(height: LuzSpace.lg),
                      buttons,
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Close / reopen / archive / delete, as the job's status allows.
class _StatusActions extends ConsumerWidget {
  const _StatusActions({required this.job});
  final Job job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = ref.read(employerActionsProvider);
    Future<void> set(JobStatus s, String done) async {
      final ok = await runWithToast(
        context,
        () => actions.setJobStatus(job, s),
        success: done,
      );
      if (ok && context.mounted) context.go('/employer/jobs');
    }

    return Wrap(
      spacing: LuzSpace.sm,
      children: [
        if (job.status == JobStatus.published)
          LuzButton(
            label: 'Close applications',
            icon: Icons.lock_outline,
            onPressed: () => set(JobStatus.closed, 'Job closed'),
          ),
        if (job.status == JobStatus.closed)
          LuzButton(
            label: 'Reopen',
            icon: Icons.lock_open,
            onPressed: () => set(JobStatus.published, 'Job reopened'),
          ),
        if (job.status == JobStatus.closed)
          LuzButton(
            label: 'Archive',
            icon: Icons.archive_outlined,
            onPressed: () => set(JobStatus.archived, 'Job archived'),
          ),
        if (job.status == JobStatus.draft)
          LuzButton(
            label: 'Delete draft',
            icon: Icons.delete_outline,
            onPressed: () async {
              final ok = await confirmLuz(
                context,
                title: 'Delete this draft?',
                message: 'This cannot be undone.',
                confirmLabel: 'Delete',
                icon: Icons.delete_outline,
              );
              if (!ok || !context.mounted) return;
              final done = await runWithToast(
                context,
                () => actions.deleteJob(job),
                success: 'Draft deleted',
              );
              if (done && context.mounted) context.go('/employer/jobs');
            },
          ),
      ],
    );
  }
}
