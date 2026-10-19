import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/data/failures.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../../jobs/presentation/job_search_page.dart' show JobBoardError;

/// Scrollable body for /me/* pages (CandidateArea supplies width + tabs).
class CandidatePage extends StatelessWidget {
  const CandidatePage({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.only(bottom: LuzSpace.xxl),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}

/// Raised card with a heading and an optional trailing action.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.action,
    this.icon,
  });

  final String title;
  final Widget child;
  final Widget? action;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    final t = context.luzText;
    return LuzCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: p.accent),
                const SizedBox(width: LuzSpace.xs),
              ],
              Expanded(
                child: Semantics(header: true, child: Text(title, style: t.h4)),
              ),
              ?action,
            ],
          ),
          const SizedBox(height: LuzSpace.md),
          child,
        ],
      ),
    );
  }
}

/// Renders an [AsyncValue] with a skeleton, an error with retry, or [data].
class AsyncBlock<T> extends StatelessWidget {
  const AsyncBlock({
    super.key,
    required this.value,
    required this.data,
    required this.onRetry,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => value.when(
    skipLoadingOnRefresh: true,
    skipLoadingOnReload: true,
    loading: () => const Padding(
      padding: EdgeInsets.symmetric(vertical: LuzSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LuzSkeleton(width: 220, height: 16),
          SizedBox(height: LuzSpace.sm),
          LuzSkeleton(width: 160),
        ],
      ),
    ),
    error: (e, _) => JobBoardError(error: mapDbError(e), onRetry: onRetry),
    data: data,
  );
}

/// Calendar-page date tile from the Stitch dashboard ("OCT / 24").
class CalendarTile extends StatelessWidget {
  const CalendarTile({super.key, required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    final t = context.luzText;
    final local = date.toLocal();
    return Semantics(
      label: DateFormat('EEEE d MMMM').format(local),
      excludeSemantics: true,
      child: LuzSurface(
        depth: LuzDepth.raisedSm,
        radius: LuzRadius.sm,
        child: SizedBox(
          width: 56,
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 2),
                decoration: BoxDecoration(
                  color: p.ink,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(LuzRadius.sm),
                  ),
                ),
                child: Text(
                  DateFormat('MMM').format(local).toUpperCase(),
                  textAlign: TextAlign.center,
                  style: t.caption.copyWith(color: p.base),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: LuzSpace.xxs),
                child: Text('${local.day}', style: t.h3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Main pipeline milestones with checks for the ones passed (Stitch
/// candidate dashboard). Closed applications show their final chip instead.
class StageStepper extends StatelessWidget {
  const StageStepper({super.key, required this.stage});
  final ApplicationStage stage;

  static const _steps = [
    ('Applied', {ApplicationStage.applied}),
    ('Review', {ApplicationStage.underReview, ApplicationStage.shortlisted}),
    (
      'Interviews',
      {
        ApplicationStage.assessment,
        ApplicationStage.technicalInterview,
        ApplicationStage.hrInterview,
        ApplicationStage.finalReview,
      },
    ),
    ('Offer', {ApplicationStage.offerIssued}),
    ('Hired', {ApplicationStage.hired}),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    final t = context.luzText;
    if (stage == ApplicationStage.rejected ||
        stage == ApplicationStage.withdrawn) {
      return Align(
        alignment: Alignment.centerLeft,
        child: LuzStatusChip.stage(stage),
      );
    }
    final current = _steps.indexWhere((s) => s.$2.contains(stage));
    return Semantics(
      label:
          'Progress: step ${current + 1} of ${_steps.length}, ${stage.label}',
      excludeSemantics: true,
      child: Row(
        children: [
          for (var i = 0; i < _steps.length; i++) ...[
            Expanded(
              child: Column(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < current
                          ? p.success
                          : i == current
                          ? p.accent
                          : p.sunken,
                      border: Border.all(color: p.outline),
                    ),
                    child: i < current
                        ? Icon(Icons.check, size: 14, color: p.base)
                        : null,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _steps[i].$1,
                    style: t.caption.copyWith(
                      color: i == current ? p.ink : p.muted,
                      fontWeight: i == current ? FontWeight.w700 : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Runs [action], showing its [AppFailure] (or [success]) as a toast.
Future<bool> runWithToast(
  BuildContext context,
  Future<void> Function() action, {
  String? success,
}) async {
  try {
    await action();
    if (context.mounted && success != null) {
      showLuzToast(context, success, icon: Icons.check);
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      showLuzToast(context, mapDbError(e).message, icon: Icons.error_outline);
    }
    return false;
  }
}

String formatDay(DateTime d) => DateFormat('d MMM y').format(d.toLocal());

String formatDayTime(DateTime d) =>
    DateFormat('EEE d MMM, h:mm a').format(d.toLocal());
