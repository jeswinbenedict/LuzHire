import 'package:flutter/widgets.dart';

import '../theme/tokens.dart';

/// The two design zones from DESIGN.md §1.
enum LuzZoneKind {
  /// Public + candidate screens: deep relief, pills, big radii.
  spotlight,

  /// Employer + admin screens: shallow relief, small radii, dense.
  workspace,
}

/// Sets zone defaults (radius, depth, density) for the Luz* widgets below it.
class LuzZone extends InheritedWidget {
  const LuzZone({super.key, required this.kind, required super.child});

  final LuzZoneKind kind;

  static LuzZoneKind of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LuzZone>()?.kind ??
      LuzZoneKind.spotlight;

  @override
  bool updateShouldNotify(LuzZone old) => old.kind != kind;
}

extension LuzZoneDefaults on LuzZoneKind {
  bool get isWorkspace => this == LuzZoneKind.workspace;
  double get buttonRadius => isWorkspace ? LuzRadius.sm : LuzRadius.pill;
  double get buttonDepth => isWorkspace ? LuzDepth.raisedXs : LuzDepth.raisedSm;
  double get cardRadius => isWorkspace ? LuzRadius.md : LuzRadius.lg;
  double get cardDepth => isWorkspace ? LuzDepth.raisedSm : LuzDepth.raisedMd;
  double get inputRadius => isWorkspace ? LuzRadius.sm : LuzRadius.lg;

  /// Dense 38 px controls only in Workspace with a mouse/trackpad;
  /// touch always gets ≥ 48 dp targets (DESIGN.md §10).
  double controlHeight({required bool pointer}) =>
      isWorkspace && pointer ? 38 : 48;
}
