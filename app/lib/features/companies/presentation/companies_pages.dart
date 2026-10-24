import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/data/failures.dart';
import '../../../core/data/models.dart';
import '../../../core/layout/breakpoints.dart';
import '../../../core/layout/content.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../../jobs/application/job_board_providers.dart';
import '../../jobs/data/jobs_repository.dart';
import '../../jobs/presentation/job_search_page.dart' show JobBoardError;
import '../../jobs/presentation/job_widgets.dart';
import '../data/companies_repository.dart';
import '../../../core/router/links.dart';
import '../../admin/presentation/report_button.dart';

String _facts(Company c) => [
  c.industry,
  if (c.sizeRange != null) '${c.sizeRange} people',
  c.hqLocation,
].whereType<String>().where((s) => s.isNotEmpty).join(' · ');

/// /companies: searchable directory of employers.
class CompaniesPage extends ConsumerStatefulWidget {
  const CompaniesPage({super.key, this.query = ''});
  final String query;

  @override
  ConsumerState<CompaniesPage> createState() => _CompaniesPageState();
}

class _CompaniesPageState extends ConsumerState<CompaniesPage> {
  late final _search = TextEditingController(text: widget.query);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _go(String q) => context.go(
    pathWithQuery('/companies', {if (q.trim().isNotEmpty) 'q': q.trim()}),
  );

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    final t = context.luzText;
    final state = ref.watch(companyListProvider(widget.query));
    final notifier = ref.read(companyListProvider(widget.query).notifier);

    return SingleChildScrollView(
      child: LuzContent(
        vertical: LuzSpace.xl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(header: true, child: Text('Companies', style: t.h2)),
            const SizedBox(height: LuzSpace.xs),
            Text(
              'Every company with open roles: employers on LuzHire and the '
              'companies behind jobs we import. Verified companies have been '
              'reviewed by our team.',
              style: t.body.copyWith(color: p.inkMuted),
            ),
            const SizedBox(height: LuzSpace.lg),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: LuzTextField(
                label: 'Search companies',
                hint: 'Company name',
                controller: _search,
                prefixIcon: Icons.search,
                textInputAction: TextInputAction.search,
                onSubmitted: _go,
              ),
            ),
            const SizedBox(height: LuzSpace.xl),
            if (state.isInitialLoad)
              LuzGrid(
                children: [
                  for (var i = 0; i < 6; i++) const _CompanyCardSkeleton(),
                ],
              )
            else if (state.companies.isEmpty && state.error != null)
              JobBoardError(error: state.error!, onRetry: notifier.loadMore)
            else if (state.companies.isEmpty)
              LuzEmptyState(
                icon: Icons.apartment_outlined,
                title: widget.query.isEmpty
                    ? 'No companies yet'
                    : 'No companies match "${widget.query}"',
                message: widget.query.isEmpty
                    ? 'Companies appear here as soon as they have open roles.'
                    : 'Check the spelling or try a shorter name.',
                actionLabel: widget.query.isEmpty ? null : 'Show all',
                onAction: widget.query.isEmpty ? null : () => _go(''),
              )
            else ...[
              LuzGrid(
                children: [
                  for (final c in state.companies) CompanyCard(company: c),
                ],
              ),
              LoadMoreFooter(
                loading: state.loading,
                hasMore: state.hasMore,
                error: state.error,
                onLoadMore: notifier.loadMore,
                isEmpty: false,
                endLabel: '',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class CompanyCard extends ConsumerWidget {
  const CompanyCard({super.key, required this.company});
  final Company company;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.luz;
    final t = context.luzText;
    String? logo;
    try {
      logo = ref.watch(companiesRepositoryProvider).logoUrl(company);
    } on AppFailure {
      logo = null;
    }
    final facts = _facts(company);
    return LuzPressable(
      radius: LuzRadius.lg,
      semanticLabel: company.name,
      onPressed: () => context.go('/companies/${company.slug}'),
      builder: (context, pressed, hovered) => LuzSurface(
        depth: pressed
            ? LuzDepth.insetSm
            : hovered
            ? LuzDepth.raisedLg
            : LuzDepth.raisedMd,
        radius: LuzRadius.lg,
        padding: const EdgeInsets.all(LuzSpace.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LuzLogoSocket(name: company.name, logoUrl: logo, size: 52),
            const SizedBox(width: LuzSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    company.name,
                    style: t.h4,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (company.isVerified) ...[
                    const SizedBox(height: LuzSpace.xxs),
                    const LuzStatusChip(
                      label: 'Verified',
                      tone: LuzChipTone.green,
                      icon: Icons.verified_outlined,
                    ),
                  ],
                  if (facts.isNotEmpty) ...[
                    const SizedBox(height: LuzSpace.xs),
                    Text(
                      facts,
                      style: t.bodySm.copyWith(color: p.inkMuted),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (company.openJobs != null) ...[
                    const SizedBox(height: LuzSpace.xs),
                    Text(
                      openRolesLabel(company.openJobs!),
                      style: t.label.copyWith(
                        color: company.openJobs! > 0 ? p.accent : p.muted,
                      ),
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

String openRolesLabel(int n) => switch (n) {
  0 => 'No open roles',
  1 => '1 open role',
  _ => '$n open roles',
};

class _CompanyCardSkeleton extends StatelessWidget {
  const _CompanyCardSkeleton();

  @override
  Widget build(BuildContext context) => const LuzSurface(
    depth: LuzDepth.raisedMd,
    radius: LuzRadius.lg,
    padding: EdgeInsets.all(LuzSpace.lg),
    child: Row(
      children: [
        LuzSkeleton(width: 52, height: 52, radius: LuzRadius.sm),
        SizedBox(width: LuzSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LuzSkeleton(width: 160, height: 16),
              SizedBox(height: 8),
              LuzSkeleton(width: 100),
            ],
          ),
        ),
      ],
    ),
  );
}

/// /companies/:slug: profile plus open roles.
class CompanyPage extends ConsumerWidget {
  const CompanyPage({super.key, required this.slug});
  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final company = ref.watch(companyBySlugProvider(slug));
    return company.when(
      loading: () => const Center(child: LuzSkeleton(width: 220, height: 16)),
      error: (e, _) => Center(
        child: JobBoardError(
          error: mapDbError(e),
          onRetry: () => ref.invalidate(companyBySlugProvider(slug)),
        ),
      ),
      data: (c) => c == null
          ? Center(
              child: LuzEmptyState(
                icon: Icons.apartment_outlined,
                title: 'Company not found',
                actionLabel: 'All companies',
                onAction: () => context.go('/companies'),
              ),
            )
          : _CompanyBody(company: c),
    );
  }
}

class _CompanyBody extends ConsumerWidget {
  const _CompanyBody({required this.company});
  final Company company;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.luz;
    final t = context.luzText;
    final bp = context.breakpoint;
    String? logo;
    try {
      logo = ref.watch(companiesRepositoryProvider).logoUrl(company);
    } on AppFailure {
      logo = null;
    }
    final query = company.isExternal
        ? JobSearchQuery(employer: company.name)
        : JobSearchQuery(companyId: company.id);
    final jobs = ref.watch(jobSearchProvider(query));
    final facts = _facts(company);

    final about = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if ((company.description ?? '').isNotEmpty) ...[
          Semantics(header: true, child: Text('About', style: t.h4)),
          const SizedBox(height: LuzSpace.sm),
          SimpleMarkdown(company.description!),
          const SizedBox(height: LuzSpace.lg),
        ],
        if (company.benefits.isNotEmpty) ...[
          Semantics(header: true, child: Text('Benefits', style: t.h4)),
          const SizedBox(height: LuzSpace.sm),
          for (final b in company.benefits) BulletLine(b),
        ],
      ],
    );

    return SingleChildScrollView(
      child: LuzContent(
        vertical: LuzSpace.xl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LuzTextLink(
              label: '← All companies',
              onPressed: () => context.go('/companies'),
            ),
            const SizedBox(height: LuzSpace.md),
            LuzCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LuzLogoSocket(
                    name: company.name,
                    logoUrl: logo,
                    size: bp.isCompact ? 56 : 80,
                  ),
                  const SizedBox(width: LuzSpace.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            company.name,
                            style: bp.isCompact ? t.h3 : t.h2,
                          ),
                        ),
                        const SizedBox(height: LuzSpace.xs),
                        Wrap(
                          spacing: LuzSpace.xs,
                          runSpacing: LuzSpace.xs,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (company.isVerified)
                              const LuzStatusChip(
                                label: 'Verified',
                                tone: LuzChipTone.green,
                                icon: Icons.verified_outlined,
                              ),
                            if (facts.isNotEmpty)
                              Text(
                                facts,
                                style: t.body.copyWith(color: p.inkMuted),
                              ),
                            if (company.isExternal)
                              Text(
                                'Roles imported from job boards',
                                style: t.body.copyWith(color: p.inkMuted),
                              ),
                          ],
                        ),
                        if (!company.isExternal)
                          ReportButton(
                            targetType: 'company',
                            targetId: company.id,
                            targetName: company.name,
                          ),
                        if (company.website != null) ...[
                          const SizedBox(height: LuzSpace.xs),
                          LuzTextLink(
                            label: Uri.parse(company.website!).host,
                            onPressed: () => launchUrl(
                              Uri.parse(company.website!),
                              mode: LaunchMode.externalApplication,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: LuzSpace.xl),
            if (company.description != null || company.benefits.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: LuzSpace.xl),
                child: about,
              ),
            Semantics(header: true, child: Text('Open roles', style: t.h3)),
            const SizedBox(height: LuzSpace.md),
            if (jobs.isInitialLoad)
              const JobCardSkeleton()
            else if (jobs.jobs.isEmpty && jobs.error != null)
              JobBoardError(
                error: jobs.error!,
                onRetry: ref.read(jobSearchProvider(query).notifier).loadMore,
              )
            else if (jobs.jobs.isEmpty)
              Text(
                '${company.name} has no open roles right now.',
                style: t.body.copyWith(color: p.inkMuted),
              )
            else ...[
              LuzGrid(
                maxColumns: 2,
                equalHeights: true,
                children: [
                  for (final j in jobs.jobs) JobCard(job: j, uniform: true),
                ],
              ),
              LoadMoreFooter(
                loading: jobs.loading,
                hasMore: jobs.hasMore,
                error: jobs.error,
                onLoadMore: ref
                    .read(jobSearchProvider(query).notifier)
                    .loadMore,
                isEmpty: false,
                endLabel: '',
              ),
            ],
          ],
        ),
      ),
    );
  }
}
