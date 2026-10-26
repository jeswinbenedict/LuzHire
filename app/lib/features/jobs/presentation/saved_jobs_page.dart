import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/failures.dart';
import '../../../core/layout/content.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../application/job_board_providers.dart';
import 'job_search_page.dart' show JobBoardError;
import 'job_widgets.dart';

/// /me/saved: the signed-in user's bookmarks, synced across devices.
class SavedJobsPage extends ConsumerWidget {
  const SavedJobsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.luz;
    final t = context.luzText;
    final saved = ref.watch(savedJobsProvider);

    // Full width like the other /me pages (candidatePagePadding).
    return LayoutBuilder(
      builder: (context, c) {
        final side = luzContentSide(context, c.maxWidth);
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(side, LuzSpace.md, side, LuzSpace.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Jobs you bookmarked. Closed jobs drop off this list.',
                style: t.body.copyWith(color: p.inkMuted),
              ),
              const SizedBox(height: LuzSpace.xl),
              saved.when(
                loading: () => const JobCardSkeleton(),
                error: (e, _) => JobBoardError(
                  error: mapDbError(e),
                  onRetry: () => ref.invalidate(savedJobIdsProvider),
                ),
                data: (jobs) => jobs.isEmpty
                    ? LuzEmptyState(
                        icon: Icons.bookmark_border,
                        title: 'No saved jobs yet',
                        message: 'Tap the bookmark on any job to keep it here.',
                        actionLabel: 'Browse jobs',
                        onAction: () => context.go('/jobs'),
                      )
                    : LuzGrid(
                        maxColumns: 2,
                        equalHeights: true,
                        children: [
                          for (final j in jobs) JobCard(job: j, uniform: true),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
