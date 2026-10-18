import 'package:flutter/material.dart';

import '../layout/input_mode.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'luz_pressable.dart';
import 'luz_surface.dart';
import 'luz_zone.dart';

enum LuzButtonVariant {
  /// Moulded from the base surface (default primary action).
  neutral,

  /// Lit amber pill; use once per screen for the signature action.
  accent,
}

/// Neumorphic button: raised at rest, sinks while pressed, flat when disabled.
class LuzButton extends StatelessWidget {
  const LuzButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = LuzButtonVariant.neutral,
    this.expand = false,
  });

  const LuzButton.accent({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = false,
  }) : variant = LuzButtonVariant.accent;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final LuzButtonVariant variant;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    final zone = LuzZone.of(context);
    final enabled = onPressed != null;
    final isAccent = variant == LuzButtonVariant.accent;
    final radius = zone.buttonRadius;
    final textStyle = zone.isWorkspace
        ? context.luzText.buttonSm
        : context.luzText.button;

    return LuzPressable(
      onPressed: onPressed,
      radius: radius,
      semanticLabel: label,
      builder: (context, pressed, hovered) {
        final fg = !enabled
            ? p.disabled
            : isAccent
            ? LuzBrand.onPrimary
            : p.ink;
        final fill = !isAccent || !enabled
            ? null
            : pressed
            ? LuzBrand.primaryPressed
            : hovered
            ? LuzBrand.primaryHover
            : LuzBrand.primary;

        final content = Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: zone.isWorkspace ? 16 : 18, color: fg),
              const SizedBox(width: LuzSpace.xs),
            ],
            Flexible(
              child: Text(
                label,
                style: textStyle.copyWith(color: fg),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );

        final surface = LuzSurface(
          depth: !enabled
              ? LuzDepth.flat
              : pressed
              ? LuzDepth.insetSm
              : zone.buttonDepth,
          radius: radius,
          color: fill,
          padding: EdgeInsets.symmetric(horizontal: zone.isWorkspace ? 14 : 24),
          child: SizedBox(
            height: zone.controlHeight(pointer: context.isPointer),
            child: Center(widthFactor: 1, child: content),
          ),
        );

        // Amber surfaces glow instead of casting the grey shadow pair.
        if (isAccent && enabled && !pressed) {
          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              boxShadow: [
                BoxShadow(
                  color: LuzBrand.primary.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: surface,
          );
        }
        return surface;
      },
    );
  }
}

/// Circular moulded icon button. A tooltip is required (DESIGN.md §2 rule 3).
class LuzIconButton extends StatelessWidget {
  const LuzIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
    this.size = 44,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  /// Selected icon buttons sink and turn amber (e.g. a saved bookmark).
  final bool selected;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    final enabled = onPressed != null;
    return LuzPressable(
      onPressed: onPressed,
      radius: LuzRadius.pill,
      tooltip: tooltip,
      semanticLabel: tooltip,
      selected: selected,
      builder: (context, pressed, _) => LuzSurface(
        depth: !enabled
            ? LuzDepth.flat
            : (pressed || selected)
            ? LuzDepth.insetSm
            : LuzDepth.raisedXs,
        radius: LuzRadius.pill,
        child: SizedBox.square(
          dimension: size,
          child: Icon(
            icon,
            size: size * 0.45,
            color: !enabled
                ? p.disabled
                : selected
                ? p.accent
                : p.inkMuted,
          ),
        ),
      ),
    );
  }
}
