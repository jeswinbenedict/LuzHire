import 'package:flutter/widgets.dart';

import '../theme/tokens.dart';

/// Window size classes from DESIGN.md §10.
enum LuzBreakpoint {
  /// < 600: phones. Single column, bottom navigation / drawer, bottom sheets.
  compact,

  /// 600 – 1023: tablets, small windows. Navigation rail, 2-up grids.
  medium,

  /// 1024 – 1439: laptops. Full sidebar, two-pane layouts, 3-up grids.
  expanded,

  /// ≥ 1440: large desktops. Content is capped; extra space becomes margin.
  large;

  static LuzBreakpoint fromWidth(double width) {
    if (width >= LuzBreakpoints.large) return large;
    if (width >= LuzBreakpoints.expanded) return expanded;
    if (width >= LuzBreakpoints.medium) return medium;
    return compact;
  }

  bool get isCompact => this == compact;
  bool get isMediumOrLarger => index >= medium.index;
  bool get isExpandedOrLarger => index >= expanded.index;

  /// Columns for card grids: 1-up, 2-up, 3-up.
  int get gridColumns => switch (this) {
    compact => 1,
    medium => 2,
    expanded || large => 3,
  };

  /// Horizontal page padding.
  double get gutter => switch (this) {
    compact => LuzSpace.md,
    medium => LuzSpace.lg,
    expanded || large => LuzSpace.xl,
  };

  /// Pick a value per breakpoint, falling back to the next smaller one.
  T pick<T>({required T compact, T? medium, T? expanded, T? large}) =>
      switch (this) {
        LuzBreakpoint.compact => compact,
        LuzBreakpoint.medium => medium ?? compact,
        LuzBreakpoint.expanded => expanded ?? medium ?? compact,
        LuzBreakpoint.large => large ?? expanded ?? medium ?? compact,
      };
}

extension LuzBreakpointContext on BuildContext {
  /// Breakpoint of the whole window (use [LayoutBuilder] for local space).
  LuzBreakpoint get breakpoint =>
      LuzBreakpoint.fromWidth(MediaQuery.sizeOf(this).width);
}
