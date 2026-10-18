import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'luz_surface.dart';
import 'luz_zone.dart';

/// Raised card using the zone's default depth and radius.
/// Wrapped in a RepaintBoundary so long lists stay cheap to repaint.
class LuzCard extends StatelessWidget {
  const LuzCard({
    super.key,
    required this.child,
    this.padding,
    this.depth,
    this.radius,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? depth;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final zone = LuzZone.of(context);
    return RepaintBoundary(
      child: LuzSurface(
        depth: depth ?? zone.cardDepth,
        radius: radius ?? zone.cardRadius,
        padding: padding ?? const EdgeInsets.all(LuzSpace.lg),
        child: child,
      ),
    );
  }
}

/// Match-score dial: inset groove with an amber arc and the value as text.
class LuzDial extends StatelessWidget {
  const LuzDial({
    super.key,
    required this.value,
    this.size = 56,
    this.label = 'match',
  });

  /// 0.0 – 1.0
  final double value;
  final double size;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    final pct = (value.clamp(0, 1) * 100).round();
    return Semantics(
      label: '$pct% $label',
      excludeSemantics: true,
      child: LuzSurface(
        depth: LuzDepth.insetSm,
        radius: LuzRadius.pill,
        child: SizedBox.square(
          dimension: size,
          child: CustomPaint(
            painter: _ArcPainter(
              value.clamp(0, 1).toDouble(),
              LuzBrand.primary,
            ),
            child: Center(
              child: Text(
                '$pct%',
                style: context.luzText.caption.copyWith(
                  color: p.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter(this.value, this.color);
  final double value;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 5.0;
    final rect = (Offset.zero & size).deflate(stroke / 2 + 3);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * value,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.value != value || old.color != color;
}
