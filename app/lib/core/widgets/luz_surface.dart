import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// A moulded neumorphic surface.
///
/// [depth] > 0 is raised, < 0 is inset (sunken), 0 is flat — see [LuzDepth].
/// Changes to [depth] animate, so a button can sink smoothly when pressed.
/// In OS high-contrast mode, relief is replaced by a visible outline
/// (DESIGN.md §2 rule 7).
class LuzSurface extends StatelessWidget {
  const LuzSurface({
    super.key,
    this.depth = LuzDepth.raisedSm,
    this.radius = LuzRadius.md,
    this.color,
    this.outline,
    this.outlineWidth = 1,
    this.padding,
    this.duration = LuzMotion.press,
    this.child,
  });

  final double depth;
  final double radius;

  /// Fill colour. Defaults to `base` when raised/flat and `sunken` when inset.
  final Color? color;

  /// Optional border, e.g. the 1 px outline required on inputs.
  final Color? outline;
  final double outlineWidth;
  final EdgeInsetsGeometry? padding;
  final Duration duration;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    final highContrast = MediaQuery.highContrastOf(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return TweenAnimationBuilder<double>(
      tween: Tween(end: highContrast ? 0 : depth),
      duration: reduceMotion ? Duration.zero : duration,
      curve: LuzMotion.curve,
      builder: (context, d, child) {
        final fill = color ?? (d < -0.5 ? p.sunken : p.base);
        return CustomPaint(
          painter: LuzReliefPainter(
            depth: d,
            radius: radius,
            fill: fill,
            highlight: p.highlight,
            shade: p.shade,
            outline: highContrast ? (outline ?? p.outline) : outline,
            outlineWidth: highContrast ? 1.5 : outlineWidth,
          ),
          child: child,
        );
      },
      child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
    );
  }
}

/// Paints a two-light neumorphic relief (light from the top-left).
class LuzReliefPainter extends CustomPainter {
  LuzReliefPainter({
    required this.depth,
    required this.radius,
    required this.fill,
    required this.highlight,
    required this.shade,
    this.outline,
    this.outlineWidth = 1,
  });

  final double depth;
  final double radius;
  final Color fill;
  final Color highlight;
  final Color shade;
  final Color? outline;
  final double outlineWidth;

  static double _sigma(double blur) => blur > 0 ? blur * 0.57735 + 0.5 : 0;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Radius.circular(radius.clamp(0, size.shortestSide / 2));
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, r);
    final d = depth.abs();
    final blur = d * 2;

    // Raised: two outer shadows, then the fill on top.
    if (depth > 0.01) {
      for (final (color, offset) in [
        (highlight, Offset(-d, -d)),
        (shade, Offset(d, d)),
      ]) {
        canvas.drawRRect(
          rrect.shift(offset),
          Paint()
            ..color = color
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, _sigma(blur)),
        );
      }
    }

    canvas.drawRRect(rrect, Paint()..color = fill);

    // Inset: shadows painted inside the shape through an even-odd "frame".
    if (depth < -0.01) {
      canvas.save();
      canvas.clipRRect(rrect);
      for (final (color, offset) in [
        (shade, Offset(d, d)), // dark band along the top-left inner edge
        (highlight, Offset(-d, -d)), // light band along the bottom-right
      ]) {
        final frame = Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(rrect.outerRect.inflate(blur * 2 + d))
          ..addRRect(rrect.shift(offset));
        canvas.drawPath(
          frame,
          Paint()
            ..color = color
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, _sigma(blur)),
        );
      }
      canvas.restore();
    }

    if (outline != null) {
      canvas.drawRRect(
        rrect.deflate(outlineWidth / 2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = outlineWidth
          ..color = outline!,
      );
    }
  }

  @override
  bool shouldRepaint(LuzReliefPainter old) =>
      old.depth != depth ||
      old.radius != radius ||
      old.fill != fill ||
      old.highlight != highlight ||
      old.shade != shade ||
      old.outline != outline ||
      old.outlineWidth != outlineWidth;
}
