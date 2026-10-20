import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../layout/input_mode.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// Gives a small control a 48 × 48 dp hit area on touch devices (DESIGN.md
/// §10, WCAG target size) without changing how it looks; mouse layouts keep
/// their compact size. Use inside a [LuzPressable] builder so the tappable
/// and semantic area grows with it.
class LuzMinTarget extends StatelessWidget {
  const LuzMinTarget({super.key, required this.child});
  final Widget child;

  static const touch = 48.0;

  @override
  Widget build(BuildContext context) {
    if (context.isPointer) return child;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: touch, minHeight: touch),
      child: Align(widthFactor: 1, heightFactor: 1, child: child),
    );
  }
}

/// Shared interaction shell for moulded controls: keyboard activation,
/// hover/press tracking, a visible focus ring, and button semantics.
///
/// [builder] receives the current pressed / hovered state so the control
/// can sink (raised → inset) while pressed.
class LuzPressable extends StatefulWidget {
  const LuzPressable({
    super.key,
    required this.onPressed,
    required this.builder,
    required this.radius,
    this.semanticLabel,
    this.tooltip,
    this.selected,
    this.toggled,
    this.autofocus = false,
  });

  final VoidCallback? onPressed;
  final Widget Function(BuildContext context, bool pressed, bool hovered)
  builder;
  final double radius;
  final String? semanticLabel;
  final String? tooltip;
  final bool? selected;
  final bool? toggled;
  final bool autofocus;

  @override
  State<LuzPressable> createState() => _LuzPressableState();
}

class _LuzPressableState extends State<LuzPressable> {
  bool _pressed = false;
  bool _hovered = false;
  bool _focused = false;

  bool get _enabled => widget.onPressed != null;

  void _setPressed(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  void _activate() {
    if (!_enabled) return;
    widget.onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    Widget result = FocusableActionDetector(
      enabled: _enabled,
      autofocus: widget.autofocus,
      mouseCursor: _enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onShowHoverHighlight: (v) => setState(() => _hovered = v),
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            _activate();
            return null;
          },
        ),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _enabled ? (_) => _setPressed(true) : null,
        onTapUp: _enabled ? (_) => _setPressed(false) : null,
        onTapCancel: _enabled ? () => _setPressed(false) : null,
        onTap: _enabled ? _activate : null,
        child: DecoratedBox(
          // Focus ring: 2 px accent, 3 px offset (DESIGN.md §2 rule 5).
          position: DecorationPosition.foreground,
          decoration: _focused
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(
                    widget.radius >= LuzRadius.pill
                        ? LuzRadius.pill
                        : widget.radius + 3,
                  ),
                  border: Border.all(
                    color: p.accent,
                    width: 2,
                    strokeAlign: BorderSide.strokeAlignOutside + 1.5,
                  ),
                )
              : const BoxDecoration(),
          child: widget.builder(context, _pressed, _hovered),
        ),
      ),
    );

    result = Semantics(
      button: true,
      enabled: _enabled,
      selected: widget.selected,
      toggled: widget.toggled,
      label: widget.semanticLabel,
      child: result,
    );

    if (widget.tooltip != null) {
      result = Tooltip(message: widget.tooltip!, child: result);
    }
    return result;
  }
}
