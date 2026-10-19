import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'breakpoints.dart';

/// Centers content with the zone's max width and breakpoint gutters.
class LuzContent extends StatelessWidget {
  const LuzContent({
    super.key,
    required this.child,
    this.maxWidth = 1200,
    this.vertical = LuzSpace.lg,
  });

  /// 1200 for Spotlight pages, 1440 for Workspace (DESIGN.md §7).
  final double maxWidth;
  final double vertical;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final gutter = context.breakpoint.gutter;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth + gutter * 2),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: gutter, vertical: vertical),
          child: child,
        ),
      ),
    );
  }
}

/// Responsive grid: 1 / 2 / 3 columns by the available width.
class LuzGrid extends StatelessWidget {
  const LuzGrid({
    super.key,
    required this.children,
    this.spacing = LuzSpace.lg,
    this.maxColumns = 3,
  });

  final List<Widget> children;
  final double spacing;
  final int maxColumns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = LuzBreakpoint.fromWidth(c.maxWidth).gridColumns
            .clamp(1, maxColumns);
        final w = (c.maxWidth - spacing * (cols - 1)) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children) SizedBox(width: w, child: child),
          ],
        );
      },
    );
  }
}

/// List/detail layout. Two panes side by side when there's room (≥ 1024),
/// otherwise only the list — callers push the detail as its own route.
class LuzTwoPane extends StatelessWidget {
  const LuzTwoPane({
    super.key,
    required this.list,
    required this.detail,
    this.listWidth = 420,
    this.gap = LuzSpace.lg,
  });

  final Widget list;

  /// Shown beside the list on wide screens; null shows an empty prompt area.
  final Widget? detail;
  final double listWidth;
  final double gap;

  /// Whether a two-pane layout fits in [width].
  static bool fits(double width) => width >= LuzBreakpoints.expanded;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (!fits(c.maxWidth)) return list;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: listWidth, child: list),
            SizedBox(width: gap),
            Expanded(child: detail ?? const SizedBox.shrink()),
          ],
        );
      },
    );
  }
}
