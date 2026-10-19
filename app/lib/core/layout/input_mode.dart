import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// How the user is interacting right now. Drives density and hover affordances
/// (DESIGN.md §10: 38 px controls on pointer devices only, ≥ 48 dp on touch).
enum LuzInputMode { touch, pointer }

/// Tracks whether a mouse is connected and exposes [LuzInputMode] to the tree.
/// Updates live when a mouse/trackpad is plugged in or removed.
class LuzInputModeScope extends StatefulWidget {
  const LuzInputModeScope({super.key, required this.child, this.forcedMode});

  final Widget child;

  /// Force a mode (tests, gallery previews).
  final LuzInputMode? forcedMode;

  static LuzInputMode of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_LuzInputModeData>()?.mode ??
      _platformDefault;

  static LuzInputMode get _platformDefault => switch (defaultTargetPlatform) {
    TargetPlatform.android ||
    TargetPlatform.iOS ||
    TargetPlatform.fuchsia => LuzInputMode.touch,
    _ => LuzInputMode.pointer,
  };

  @override
  State<LuzInputModeScope> createState() => _LuzInputModeScopeState();
}

class _LuzInputModeScopeState extends State<LuzInputModeScope> {
  MouseTracker get _tracker => RendererBinding.instance.mouseTracker;
  late bool _mouse = _tracker.mouseIsConnected;

  @override
  void initState() {
    super.initState();
    _tracker.addListener(_onChange);
  }

  @override
  void dispose() {
    _tracker.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    final connected = _tracker.mouseIsConnected;
    if (connected != _mouse && mounted) setState(() => _mouse = connected);
  }

  @override
  Widget build(BuildContext context) {
    final mode =
        widget.forcedMode ??
        (_mouse ? LuzInputMode.pointer : LuzInputModeScope._platformDefault);
    return _LuzInputModeData(mode: mode, child: widget.child);
  }
}

class _LuzInputModeData extends InheritedWidget {
  const _LuzInputModeData({required this.mode, required super.child});
  final LuzInputMode mode;

  @override
  bool updateShouldNotify(_LuzInputModeData old) => old.mode != mode;
}

extension LuzInputModeContext on BuildContext {
  LuzInputMode get inputMode => LuzInputModeScope.of(this);
  bool get isPointer => inputMode == LuzInputMode.pointer;

  /// Apple platforms use ⌘ for shortcuts; everything else uses Ctrl.
  bool get usesCommandKey =>
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.iOS;
}
