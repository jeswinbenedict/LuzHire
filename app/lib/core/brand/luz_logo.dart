import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// Official LuzHire logo (brand/luzhire-logo-official.png), rebuilt as a
/// vector so it stays sharp at every size. Geometry is on a 264-unit grid
/// and was fitted to the official artwork (< 1 % pixel difference).
///
/// Rules (DESIGN.md §2a): never recolour, stretch, emboss or add relief to
/// the mark; keep clear space of ¼ mark height around it.
abstract final class LuzLogoSpec {
  static const tile = Color(0xFF131314);
  static const letter = Color(0xFFFFFFFF);
  static const dot = Color(0xFFFE8022);

  /// Wordmark cap height ≈ 0.55 × mark; Inter cap height ≈ 0.727 em.
  static const wordmarkFontScale = 0.75;

  /// Gap between mark and wordmark ≈ 0.26 × mark.
  static const gapScale = 0.26;

  static Path letterPath(double scale) {
    final s = scale;
    return Path()
      ..moveTo(55.5 * s, 68.5 * s)
      ..lineTo(55.5 * s, 161.5 * s)
      // outer bottom-left corner
      ..arcToPoint(
        Offset(105.5 * s, 211.5 * s),
        radius: Radius.circular(50 * s),
        clockwise: false,
      )
      ..lineTo(161.38 * s, 211.5 * s)
      // foot end curves around the dot
      ..arcToPoint(
        Offset(155.09 * s, 171.5 * s),
        radius: Radius.circular(38 * s),
      )
      ..lineTo(107.5 * s, 171.5 * s)
      // inner corner fillet
      ..arcToPoint(Offset(95.5 * s, 159.5 * s), radius: Radius.circular(12 * s))
      ..lineTo(95.5 * s, 68.5 * s)
      // rounded top of the stem
      ..arcToPoint(
        Offset(55.5 * s, 68.5 * s),
        radius: Radius.circular(20 * s),
        clockwise: false,
      )
      ..close();
  }
}

/// The square brand mark (tile + L + dot).
class LuzLogoMark extends StatelessWidget {
  const LuzLogoMark({super.key, this.size = 34});
  final double size;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _MarkPainter(edge: isDark)),
    );
  }
}

class _MarkPainter extends CustomPainter {
  _MarkPainter({required this.edge});

  /// Hairline edge so the near-black tile stays defined on graphite.
  final bool edge;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 264;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(64 * s),
    );
    canvas.drawRRect(rrect, Paint()..color = LuzLogoSpec.tile);
    if (edge) {
      canvas.drawRRect(
        rrect.deflate(0.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.white.withValues(alpha: 0.12),
      );
    }
    canvas.drawPath(
      LuzLogoSpec.letterPath(s),
      Paint()
        ..color = LuzLogoSpec.letter
        ..isAntiAlias = true,
    );
    canvas.drawCircle(
      Offset(190 * s, 186.5 * s),
      30 * s,
      Paint()..color = LuzLogoSpec.dot,
    );
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.edge != edge;
}

/// Full logo: mark + "LuzHire" wordmark, in the official proportions.
/// The wordmark uses ink (light theme) or reversed ink (dark theme).
class LuzLogo extends StatelessWidget {
  const LuzLogo({
    super.key,
    this.size = 34,
    this.showWordmark = true,
    this.onTap,
    this.semanticLabel = 'LuzHire home',
  });

  /// Height of the square mark; the wordmark scales with it.
  final double size;
  final bool showWordmark;
  final VoidCallback? onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        LuzLogoMark(size: size),
        if (showWordmark) ...[
          SizedBox(width: size * LuzLogoSpec.gapScale),
          Text(
            'LuzHire',
            maxLines: 1,
            softWrap: false,
            // The logo never scales with OS text size: it is artwork.
            textScaler: TextScaler.noScaling,
            style: context.luzText.label.copyWith(
              fontSize: size * LuzLogoSpec.wordmarkFontScale,
              fontWeight: FontWeight.w500,
              fontVariations: const [FontVariation('wght', 500)],
              letterSpacing: -0.01 * size,
              height: 1,
              color: context.luz.ink,
            ),
          ),
        ],
      ],
    );

    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: LuzSpace.xxs),
            // Never overflow: in a tight slot the whole logo scales down
            // proportionally instead of clipping or wrapping the wordmark.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}
