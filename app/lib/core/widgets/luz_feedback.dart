import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'luz_button.dart';
import 'luz_surface.dart';

/// Loading placeholder: a sunken block with a soft shimmer.
/// Use instead of spinners for list loads (DESIGN.md §8).
class LuzSkeleton extends StatefulWidget {
  const LuzSkeleton({
    super.key,
    this.width,
    this.height = 14,
    this.radius = LuzRadius.xs,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  State<LuzSkeleton> createState() => _LuzSkeletonState();
}

class _LuzSkeletonState extends State<LuzSkeleton>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1.5 + 3 * _c.value, 0),
              end: Alignment(-0.5 + 3 * _c.value, 0),
              colors: [p.sunken, p.highlight.withValues(alpha: 0.6), p.sunken],
            ),
          ),
        ),
      ),
    );
  }
}

/// One-sentence empty state with one action (DESIGN.md §8).
class LuzEmptyState extends StatelessWidget {
  const LuzEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    final t = context.luzText;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(LuzSpace.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LuzSurface(
                depth: LuzDepth.insetMd,
                radius: LuzRadius.pill,
                child: SizedBox.square(
                  dimension: 88,
                  child: Icon(icon, size: 36, color: p.accent),
                ),
              ),
              const SizedBox(height: LuzSpace.lg),
              Text(title, style: t.h4, textAlign: TextAlign.center),
              if (message != null) ...[
                const SizedBox(height: LuzSpace.xs),
                Text(
                  message!,
                  style: t.body.copyWith(color: p.muted),
                  textAlign: TextAlign.center,
                ),
              ],
              if (actionLabel != null) ...[
                const SizedBox(height: LuzSpace.lg),
                LuzButton(label: actionLabel!, onPressed: onAction),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Toast: flat ink pill, 4 s, optional Undo (DESIGN.md §8).
void showLuzToast(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
  IconData? icon,
}) {
  final p = context.luz;
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 4),
      width: MediaQuery.sizeOf(context).width >= 600 ? 420 : null,
      content: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: p.base),
            const SizedBox(width: LuzSpace.sm),
          ],
          Expanded(child: Text(message)),
        ],
      ),
      action: actionLabel == null
          ? null
          : SnackBarAction(
              label: actionLabel,
              // Toast is ink-on-light in dark theme, so the orange must darken.
              textColor: p.brightness == Brightness.dark
                  ? LuzBrand.primaryStrong
                  : LuzBrand.primary,
              onPressed: onAction ?? () {},
            ),
    ),
  );
}
