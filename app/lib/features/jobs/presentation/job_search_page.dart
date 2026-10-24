import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/failures.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../application/job_board_providers.dart';
import '../data/jobs_repository.dart';
import 'job_detail_page.dart';
import 'job_widgets.dart';
import '../../../core/router/links.dart';

/// Job search (Stitch: docs/design/stitch/jobs-search-*.png). Filters live in
/// the URL, so every search is a shareable link.
///
/// ≥ 1360 px: filters | results | job preview. ≥ 1024 px: filters | results.
/// Below: results, with filters in a bottom sheet.
class JobSearchPage extends ConsumerStatefulWidget {
  const JobSearchPage({super.key, required this.query});

  final JobSearchQuery query;

  static const threePaneWidth = 1360.0;
  static const filterPanelWidth = 1024.0;

  @override
  ConsumerState<JobSearchPage> createState() => _JobSearchPageState();
}

class _JobSearchPageState extends ConsumerState<JobSearchPage> {
  late final _keyword = TextEditingController(text: widget.query.keyword);
  late final _location = TextEditingController(text: widget.query.location);
  String? _selectedSlug;

  @override
  void didUpdateWidget(JobSearchPage old) {
    super.didUpdateWidget(old);
    if (_keyword.text != widget.query.keyword) {
      _keyword.text = widget.query.keyword;
    }
    if (_location.text != widget.query.location) {
      _location.text = widget.query.location;
    }
  }

  @override
  void dispose() {
    _keyword.dispose();
    _location.dispose();
    super.dispose();
  }

  void _go(JobSearchQuery q) =>
      context.go(pathWithQuery('/jobs', q.toUrlParams()));

  void _openFilters() {
    showLuzModal<void>(
      context: context,
      title: 'Filters',
      forceSheet: true,
      builder: (ctx) => _LiveFilters(initial: widget.query, onChanged: _go),
      actions: (ctx) => [
        LuzButton.accent(
          label: 'Show results',
          onPressed: () => Navigator.of(ctx).pop(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = widget.query;
    final search = ref.watch(jobSearchProvider(query));
    final notifier = ref.read(jobSearchProvider(query).notifier);

    return LayoutBuilder(
      builder: (context, c) {
        final threePane = c.maxWidth >= JobSearchPage.threePaneWidth;
        final withFilters = c.maxWidth >= JobSearchPage.filterPanelWidth;
        final selected = threePane
            ? (_selectedSlug != null &&
                      search.jobs.any((j) => j.slug == _selectedSlug)
                  ? _selectedSlug
                  : search.jobs.firstOrNull?.slug)
            : null;

        final header = _Header(
          keyword: _keyword,
          location: _location,
          query: query,
          showFilterButton: !withFilters,
          onSearch: (kw, loc) =>
              _go(query.copyWith(keyword: kw.trim(), location: loc.trim())),
          onOpenFilters: _openFilters,
        );

        final results = _Results(
          state: search,
          query: query,
          selectedSlug: selected,
          onSelect: threePane
              ? (slug) => setState(() => _selectedSlug = slug)
              : null,
          onLoadMore: notifier.loadMore,
          onClearFilters: () => _go(query.clearFilters()),
          leading: withFilters ? const [] : [header],
          padding: withFilters
              ? jobPanePadding
              : const EdgeInsets.all(LuzSpace.md),
        );

        if (!withFilters) return results;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                LuzSpace.lg,
                LuzSpace.lg,
                LuzSpace.lg,
                0,
              ),
              child: header,
            ),
            // Each pane pads its own cards (jobPanePadding), so the three columns
            // start on one line and their outer edges meet the header's.
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 280 + 2 * LuzSpace.lg,
                    child: SingleChildScrollView(
                      padding: jobPanePadding,
                      child: LuzCard(
                        child: JobFilters(query: query, onChanged: _go),
                      ),
                    ),
                  ),
                  if (threePane) ...[
                    SizedBox(width: 408 + 2 * LuzSpace.lg, child: results),
                    Expanded(
                      child: selected == null
                          ? const SizedBox.shrink()
                          : JobDetailView(
                              key: ValueKey(selected),
                              slug: selected,
                              embedded: true,
                            ),
                    ),
                  ] else
                    Expanded(child: results),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Filters inside the sheet: keeps its own copy so checkboxes respond at once
/// while the page behind updates its URL.
class _LiveFilters extends StatefulWidget {
  const _LiveFilters({required this.initial, required this.onChanged});
  final JobSearchQuery initial;
  final ValueChanged<JobSearchQuery> onChanged;

  @override
  State<_LiveFilters> createState() => _LiveFiltersState();
}

class _LiveFiltersState extends State<_LiveFilters> {
  late JobSearchQuery _q = widget.initial;

  @override
  Widget build(BuildContext context) => JobFilters(
    query: _q,
    onChanged: (q) {
      setState(() => _q = q);
      widget.onChanged(q);
    },
  );
}

class _Header extends StatelessWidget {
  const _Header({
    required this.keyword,
    required this.location,
    required this.query,
    required this.showFilterButton,
    required this.onSearch,
    required this.onOpenFilters,
  });

  final TextEditingController keyword;
  final TextEditingController location;
  final JobSearchQuery query;
  final bool showFilterButton;
  final void Function(String keyword, String location) onSearch;
  final VoidCallback onOpenFilters;

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    final t = context.luzText;
    final n = query.activeFilterCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(header: true, child: Text('Find jobs', style: t.h3)),
        const SizedBox(height: LuzSpace.sm),
        LuzSearchBar(
          keywordController: keyword,
          locationController: location,
          onSearch: onSearch,
        ),
        const SizedBox(height: LuzSpace.sm),
        Row(
          children: [
            Expanded(
              child: Text(
                'Sorted by newest',
                style: t.bodySm.copyWith(color: p.inkMuted),
              ),
            ),
            // Phones: icon only, so the row fits beside "Filters (n)".
            if (showFilterButton)
              LuzIconButton(
                icon: Icons.map_outlined,
                tooltip: 'Hiring map',
                onPressed: () => context.go('/jobs/map'),
              )
            else
              LuzButton(
                label: 'Map',
                icon: Icons.map_outlined,
                onPressed: () => context.go('/jobs/map'),
              ),
            const SizedBox(width: LuzSpace.xs),
            if (showFilterButton)
              LuzButton(
                label: n == 0 ? 'Filters' : 'Filters ($n)',
                icon: Icons.tune,
                onPressed: onOpenFilters,
              ),
          ],
        ),
      ],
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({
    required this.state,
    required this.query,
    required this.selectedSlug,
    required this.onSelect,
    required this.onLoadMore,
    required this.onClearFilters,
    required this.leading,
    required this.padding,
  });

  final JobSearchState state;
  final JobSearchQuery query;
  final String? selectedSlug;
  final ValueChanged<String>? onSelect;
  final VoidCallback onLoadMore;
  final VoidCallback onClearFilters;
  final List<Widget> leading;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      for (final w in leading) ...[w, const SizedBox(height: LuzSpace.md)],
      if (state.isInitialLoad)
        for (var i = 0; i < 4; i++) const JobCardSkeleton()
      else if (state.jobs.isEmpty && state.error != null)
        JobBoardError(error: state.error!, onRetry: onLoadMore)
      else if (state.jobs.isEmpty)
        LuzEmptyState(
          icon: Icons.search_off,
          title: 'No jobs match this search',
          message: query.activeFilterCount > 0
              ? 'Try removing a filter or searching for a broader keyword.'
              : 'New roles are added all the time. Try another keyword or location.',
          actionLabel: query.activeFilterCount > 0 ? 'Clear filters' : null,
          onAction: query.activeFilterCount > 0 ? onClearFilters : null,
        )
      else ...[
        for (final job in state.jobs)
          JobCard(
            job: job,
            selected: onSelect == null ? null : job.slug == selectedSlug,
            onTap: onSelect == null ? null : () => onSelect!(job.slug),
          ),
        LoadMoreFooter(
          loading: state.loading,
          hasMore: state.hasMore,
          error: state.error,
          onLoadMore: onLoadMore,
          isEmpty: state.jobs.isEmpty,
        ),
      ],
    ];

    return ListView.separated(
      padding: padding,
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: LuzSpace.md),
      itemBuilder: (_, i) => items[i],
    );
  }
}

/// Load failure. Builds without Supabase config get no pointless retry.
class JobBoardError extends StatelessWidget {
  const JobBoardError({super.key, required this.error, required this.onRetry});
  final AppFailure error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final unavailable = error.code == 'not_configured';
    return LuzEmptyState(
      icon: unavailable
          ? Icons.construction_outlined
          : Icons.cloud_off_outlined,
      title: unavailable ? 'Not available in this build' : "Couldn't load",
      message: error.message,
      actionLabel: unavailable ? null : 'Try again',
      onAction: unavailable ? null : onRetry,
    );
  }
}
