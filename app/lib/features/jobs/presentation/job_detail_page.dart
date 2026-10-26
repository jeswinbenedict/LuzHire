import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/data/enums.dart';
import '../../../core/data/failures.dart';
import '../../../core/data/format.dart';
import '../../../core/data/models.dart';
import '../../../core/layout/content.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_state.dart';
import '../../candidate/application/candidate_providers.dart';
import '../../candidate/presentation/apply_sheet.dart';
import '../application/job_board_providers.dart';
import '../data/jobs_repository.dart';
import 'job_search_page.dart' show JobBoardError;
import 'job_widgets.dart';
import '../../admin/presentation/report_button.dart';

/// /jobs/:slug (Stitch: docs/design/stitch/job-detail-*.png).
class JobDetailPage extends StatelessWidget {
  const JobDetailPage({super.key, required this.slug});
  final String slug;

  @override
  Widget build(BuildContext context) => JobDetailView(slug: slug);
}

/// The job itself. [embedded] is the preview pane beside search results:
/// one column, with the apply panel on top. A job opened from search results
/// shows its card fields at once and its description when the full job has
/// loaded.
class JobDetailView extends ConsumerWidget {
  const JobDetailView({super.key, required this.slug, this.embedded = false});

  final String slug;
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final job = ref.watch(jobBySlugProvider(slug));
    final preview = ref.watch(jobPreviewsProvider)[slug];
    if (!job.hasValue && preview != null) {
      return _JobBody(job: preview, embedded: embedded);
    }
    return job.when(
      loading: () => const Center(child: LuzSkeleton(width: 220, height: 16)),
      error: (e, _) => Center(
        child: JobBoardError(
          error: mapDbError(e),
          onRetry: () => ref.invalidate(jobBySlugProvider(slug)),
        ),
      ),
      data: (job) => job == null
          ? Center(
              child: LuzEmptyState(
                icon: Icons.work_off_outlined,
                title: 'This job is no longer listed',
                message: 'It may have been filled or closed by the employer.',
                actionLabel: 'Browse jobs',
                onAction: () => context.go('/jobs'),
              ),
            )
          : _JobBody(job: job, embedded: embedded),
    );
  }
}

class _JobBody extends ConsumerWidget {
  const _JobBody({required this.job, required this.embedded});
  final Job job;
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final main = _MainColumn(job: job, embedded: embedded);
    final panel = _ApplyPanel(job: job);

    if (embedded) {
      // One card, read top to bottom: who and what, how to apply, the role.
      final p = context.luz;
      return ListView(
        padding: jobPanePadding,
        children: [
          LuzCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(job: job, compact: true),
                const SizedBox(height: LuzSpace.md),
                _ApplyPanel(job: job, embedded: true),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: LuzSpace.lg),
                  child: Divider(height: 1, color: p.hairline),
                ),
                main,
              ],
            ),
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 960;
        if (wide) {
          return SingleChildScrollView(
            child: LuzContent(
              vertical: LuzSpace.xl,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _BackLink(),
                  const SizedBox(height: LuzSpace.md),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Header(job: job),
                            const SizedBox(height: LuzSpace.xl),
                            main,
                          ],
                        ),
                      ),
                      const SizedBox(width: LuzSpace.xl),
                      SizedBox(width: 340, child: panel),
                    ],
                  ),
                ],
              ),
            ),
          );
        }
        // Phones and tablets: content scrolls, apply bar stays at the bottom.
        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: LuzContent(
                  vertical: LuzSpace.lg,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _BackLink(),
                      const SizedBox(height: LuzSpace.md),
                      _Header(job: job),
                      const SizedBox(height: LuzSpace.lg),
                      _Facts(job: job, showSalary: true),
                      const SizedBox(height: LuzSpace.lg),
                      main,
                    ],
                  ),
                ),
              ),
            ),
            _ApplyBar(job: job),
          ],
        );
      },
    );
  }
}

class _BackLink extends StatelessWidget {
  @override
  Widget build(BuildContext context) => LuzTextLink(
    label: '← All jobs',
    onPressed: () => context.canPop() ? context.pop() : context.go('/jobs'),
  );
}

class _Header extends ConsumerWidget {
  const _Header({required this.job, this.compact = false});
  final Job job;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.luz;
    final t = context.luzText;
    final company = job.companyId == null
        ? null
        : ref.watch(companyByIdProvider(job.companyId!)).value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LuzLogoSocket(
              name: job.companyName,
              logoUrl: job.logoUrl,
              size: compact ? 44 : 64,
            ),
            const SizedBox(width: LuzSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(job.title, style: compact ? t.h4 : t.h2),
                  ),
                  const SizedBox(height: LuzSpace.xxs),
                  Wrap(
                    spacing: LuzSpace.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (company != null)
                        LuzTextLink(
                          label: job.companyName,
                          onPressed: () =>
                              context.go('/companies/${company.slug}'),
                        )
                      else
                        Text(
                          job.companyName,
                          style: (compact ? t.body : t.bodyLg).copyWith(
                            color: p.inkMuted,
                          ),
                        ),
                      if (company?.isVerified ?? false)
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
          ],
        ),
        const SizedBox(height: LuzSpace.md),
        Wrap(
          spacing: LuzSpace.xs,
          runSpacing: LuzSpace.xs,
          children: [
            LuzStatusChip(
              label: job.employmentType.label,
              tone: LuzChipTone.neutral,
              icon: Icons.work_outline,
            ),
            if (job.experienceLevel != null)
              LuzStatusChip(
                label: job.experienceLevel!.label,
                tone: LuzChipTone.neutral,
                icon: Icons.trending_up,
              ),
            LuzStatusChip(
              label: job.workplace.label,
              tone: LuzChipTone.neutral,
              icon: Icons.home_work_outlined,
            ),
            if ((job.location ?? '').isNotEmpty)
              LuzStatusChip(
                label: job.location!,
                tone: LuzChipTone.neutral,
                icon: Icons.place_outlined,
              ),
          ],
        ),
        if (job.status != JobStatus.published) ...[
          const SizedBox(height: LuzSpace.md),
          LuzStatusChip(
            label: 'Not accepting applications (${job.status.label})',
            tone: LuzChipTone.orange,
            icon: Icons.info_outline,
          ),
        ],
      ],
    );
  }
}

/// The summary leads the page only when it adds something: imported jobs
/// take it from the description's first lines, which follow right below.
bool _showSummary(Job job) {
  final summary = (job.summary ?? '').replaceAll('…', '').trim();
  if (summary.isEmpty) return false;
  String flat(String s) => s
      .replaceAll(RegExp(r'[*#_`>]|^\s*-\s', multiLine: true), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .toLowerCase();
  return !flat(job.descriptionMd).contains(flat(summary));
}

class _MainColumn extends ConsumerWidget {
  const _MainColumn({required this.job, required this.embedded});
  final Job job;
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.luzText;
    final p = context.luz;
    final skills = ref.watch(jobSkillsProvider(job.id)).value ?? const [];

    Widget section(String title, List<Widget> children) => Padding(
      padding: const EdgeInsets.only(bottom: LuzSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(header: true, child: Text(title, style: t.h4)),
          const SizedBox(height: LuzSpace.sm),
          ...children,
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_showSummary(job))
          Padding(
            padding: const EdgeInsets.only(bottom: LuzSpace.lg),
            child: Text(
              job.summary!,
              style: t.bodyLg.copyWith(color: p.inkMuted),
            ),
          ),
        if (!job.hasDetails) _PendingDetails(slug: job.slug),
        if (job.descriptionMd.trim().isNotEmpty)
          section('About the role', [SimpleMarkdown(job.descriptionMd)]),
        if (job.responsibilities.isNotEmpty)
          section('Responsibilities', [
            for (final r in job.responsibilities) BulletLine(r),
          ]),
        if (job.qualifications.isNotEmpty)
          section('Requirements', [
            for (final q in job.qualifications) BulletLine(q),
          ]),
        if (skills.isNotEmpty)
          section('Skills', [
            Wrap(
              spacing: LuzSpace.xs,
              runSpacing: LuzSpace.xs,
              children: [
                for (final s in skills)
                  LuzStatusChip(label: s, tone: LuzChipTone.neutral),
              ],
            ),
          ]),
        if (job.benefits.isNotEmpty)
          section('Benefits', [for (final b in job.benefits) BulletLine(b)]),
        if (job.companyId != null && !embedded) ...[
          _CompanyCard(companyId: job.companyId!),
          const SizedBox(height: LuzSpace.lg),
          _MoreFromCompany(job: job),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: ReportButton(
            targetType: 'job',
            targetId: job.id,
            targetName: job.title,
          ),
        ),
      ],
    );
  }
}

/// Stands in for the description while the full job loads, or offers a retry
/// if it could not be loaded.
class _PendingDetails extends ConsumerWidget {
  const _PendingDetails({required this.slug});
  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.luz;
    final t = context.luzText;
    final full = ref.watch(jobBySlugProvider(slug));
    final failed = full.hasError && !full.isLoading;
    return Padding(
      padding: const EdgeInsets.only(bottom: LuzSpace.lg),
      child: failed
          ? Wrap(
              spacing: LuzSpace.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  "Couldn't load the job description.",
                  style: t.body.copyWith(color: p.inkMuted),
                ),
                LuzTextLink(
                  label: 'Try again',
                  onPressed: () => ref.invalidate(jobBySlugProvider(slug)),
                ),
              ],
            )
          : Semantics(
              container: true,
              label: 'Loading the job description',
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LuzSkeleton(width: 140, height: 18),
                  SizedBox(height: LuzSpace.sm),
                  LuzSkeleton(),
                  SizedBox(height: LuzSpace.xs),
                  LuzSkeleton(),
                  SizedBox(height: LuzSpace.xs),
                  LuzSkeleton(width: 220),
                ],
              ),
            ),
    );
  }
}

/// Salary, apply, save and share, plus the key facts (Stitch: sticky panel).
class _ApplyPanel extends StatelessWidget {
  const _ApplyPanel({required this.job, this.embedded = false});
  final Job job;

  /// Inside the search preview's single card: no card of its own, and the
  /// apply and save buttons side by side.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    final t = context.luzText;
    final salary = formatSalary(job);
    if (embedded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('SALARY', style: t.eyebrow.copyWith(color: p.inkMuted)),
              const SizedBox(width: LuzSpace.sm),
              Expanded(
                child: Text(
                  salary ?? 'Not disclosed',
                  style: salary == null
                      ? t.bodySm.copyWith(color: p.muted)
                      : t.mono.copyWith(
                          color: p.ink,
                          fontWeight: FontWeight.w600,
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: LuzSpace.sm),
          Row(
            children: [
              Expanded(flex: 3, child: ApplyButton(job: job)),
              const SizedBox(width: LuzSpace.sm),
              Expanded(flex: 2, child: SaveJobButton(job: job, expanded: true)),
              const SizedBox(width: LuzSpace.sm),
              _ShareButton(job: job),
            ],
          ),
          const SizedBox(height: LuzSpace.md),
          _Facts(job: job),
        ],
      );
    }
    return LuzCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('SALARY', style: t.eyebrow.copyWith(color: p.inkMuted)),
          const SizedBox(height: LuzSpace.xxs),
          Text(
            salary ?? 'Not disclosed',
            style: salary == null
                ? t.body.copyWith(color: p.muted)
                : t.h3.copyWith(fontFamily: t.mono.fontFamily),
          ),
          const SizedBox(height: LuzSpace.lg),
          ApplyButton(job: job),
          const SizedBox(height: LuzSpace.sm),
          Row(
            children: [
              Expanded(child: SaveJobButton(job: job, expanded: true)),
              const SizedBox(width: LuzSpace.sm),
              _ShareButton(job: job),
            ],
          ),
          const SizedBox(height: LuzSpace.lg),
          _Facts(job: job),
        ],
      ),
    );
  }
}

/// Posted, deadline and applicant count. Every number comes from the job row.
class _Facts extends StatelessWidget {
  const _Facts({required this.job, this.showSalary = false});
  final Job job;

  /// Phones: no apply panel shows the salary, so it leads the facts.
  final bool showSalary;

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    final t = context.luzText;
    final deadline = job.deadline;
    final daysLeft = deadline?.difference(DateTime.now()).inDays;

    Widget fact(IconData icon, String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: LuzSpace.sm),
      child: Row(
        children: [
          Icon(icon, size: 18, color: p.inkMuted),
          const SizedBox(width: LuzSpace.sm),
          Expanded(
            child: Text(label, style: t.bodySm.copyWith(color: p.inkMuted)),
          ),
          const SizedBox(width: LuzSpace.sm),
          // Wraps with large text instead of running off the screen.
          Flexible(
            child: Text(value, style: t.label, textAlign: TextAlign.end),
          ),
        ],
      ),
    );

    return Column(
      children: [
        if (showSalary)
          fact(
            Icons.payments_outlined,
            'Salary',
            formatSalary(job) ?? 'Not disclosed',
          ),
        if (job.publishedAt != null)
          fact(Icons.schedule, 'Posted', formatRelative(job.publishedAt!)),
        if (deadline != null)
          fact(
            Icons.event_outlined,
            'Apply by',
            daysLeft != null && daysLeft >= 0 && daysLeft <= 14
                ? '${DateFormat('d MMM').format(deadline.toLocal())} '
                      '(${daysLeft == 0 ? 'today' : '$daysLeft days left'})'
                : DateFormat('d MMM y').format(deadline.toLocal()),
          ),
        if (!job.isExternal)
          fact(Icons.groups_outlined, 'Applicants', '${job.applicationCount}'),
        if (job.isExternal && jobSource(job.externalSource) != null)
          Padding(
            padding: const EdgeInsets.only(bottom: LuzSpace.sm),
            child: SourceAttribution(source: job.externalSource),
          ),
      ],
    );
  }
}

/// Apply: external jobs open the source site; native jobs open the apply
/// form for candidates, show the stage once applied, and ask visitors to
/// sign in.
class ApplyButton extends ConsumerWidget {
  const ApplyButton({super.key, required this.job});
  final Job job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final open = job.status == JobStatus.published;

    if (job.isExternal && job.externalUrl != null) {
      return LuzButton.accent(
        label:
            'Apply on ${jobSource(job.externalSource)?.name ?? 'company site'}',
        icon: Icons.open_in_new,
        expand: true,
        onPressed: open
            ? () => launchUrl(
                Uri.parse(job.externalUrl!),
                mode: LaunchMode.externalApplication,
              )
            : null,
      );
    }

    final role = auth is SignedIn ? auth.user.appRole : null;
    final here = '/jobs/${job.slug}';
    final pastDeadline =
        job.deadline != null &&
        job.deadline!.isBefore(DateUtils.dateOnly(DateTime.now()));

    if (auth is SignedIn && role == AppRole.candidate) {
      final existing = ref.watch(myApplicationForJobProvider(job.id));
      if (existing != null) {
        return LuzButton(
          label: 'Applied · ${existing.stage.label}',
          icon: Icons.check_circle_outline,
          expand: true,
          onPressed: () => context.go('/me/applications/${existing.id}'),
        );
      }
      return LuzButton.accent(
        label: pastDeadline ? 'Applications closed' : 'Apply now',
        icon: Icons.send_outlined,
        expand: true,
        onPressed: open && !pastDeadline
            ? () => showApplySheet(context, job)
            : null,
      );
    }

    return LuzButton.accent(
      label: auth is SignedIn ? 'Candidates apply here' : 'Sign in to apply',
      icon: Icons.send_outlined,
      expand: true,
      onPressed: !open || auth is SignedIn
          ? null
          : () => context.go(
              Uri(path: '/sign-in', queryParameters: {'from': here}).toString(),
            ),
    );
  }
}

class _ShareButton extends StatelessWidget {
  const _ShareButton({required this.job});
  final Job job;

  @override
  Widget build(BuildContext context) => LuzIconButton(
    icon: Icons.link,
    tooltip: 'Copy link',
    onPressed: () async {
      final link = '${Uri.base.origin}/jobs/${job.slug}';
      await Clipboard.setData(ClipboardData(text: link));
      if (context.mounted) {
        showLuzToast(context, 'Link copied', icon: Icons.check);
      }
    },
  );
}

/// Phones: apply + save pinned to the bottom (Stitch mobile design).
class _ApplyBar extends StatelessWidget {
  const _ApplyBar({required this.job});
  final Job job;

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.base,
        border: Border(top: BorderSide(color: p.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(LuzSpace.sm),
          child: Row(
            children: [
              SaveJobButton(job: job),
              const SizedBox(width: LuzSpace.sm),
              Expanded(child: ApplyButton(job: job)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompanyCard extends ConsumerWidget {
  const _CompanyCard({required this.companyId});
  final String companyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final company = ref.watch(companyByIdProvider(companyId)).value;
    if (company == null) return const SizedBox.shrink();
    final p = context.luz;
    final t = context.luzText;
    final facts = [
      company.industry,
      if (company.sizeRange != null) '${company.sizeRange} people',
      company.hqLocation,
    ].whereType<String>().where((s) => s.isNotEmpty).join(' · ');

    return LuzCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ABOUT THE COMPANY',
            style: t.eyebrow.copyWith(color: p.inkMuted),
          ),
          const SizedBox(height: LuzSpace.sm),
          Text(company.name, style: t.h4),
          if (facts.isNotEmpty) ...[
            const SizedBox(height: LuzSpace.xxs),
            Text(facts, style: t.bodySm.copyWith(color: p.inkMuted)),
          ],
          if ((company.description ?? '').isNotEmpty) ...[
            const SizedBox(height: LuzSpace.sm),
            Text(
              company.description!,
              style: t.body,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: LuzSpace.sm),
          LuzTextLink(
            label: 'View company →',
            onPressed: () => context.go('/companies/${company.slug}'),
          ),
        ],
      ),
    );
  }
}

class _MoreFromCompany extends ConsumerWidget {
  const _MoreFromCompany({required this.job});
  final Job job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final others = ref
        .watch(
          jobSearchProvider(
            JobSearchQuery(companyId: job.companyId, pageSize: 4),
          ),
        )
        .jobs
        .where((j) => j.id != job.id)
        .take(3)
        .toList();
    if (others.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            'More from ${job.companyName}',
            style: context.luzText.h4,
          ),
        ),
        const SizedBox(height: LuzSpace.sm),
        for (final j in others) ...[
          JobCard(job: j),
          const SizedBox(height: LuzSpace.sm),
        ],
      ],
    );
  }
}
