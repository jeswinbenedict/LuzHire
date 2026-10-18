import 'package:flutter/material.dart';

import 'tokens.dart';

/// Exposes the LuzHire palette through the Material theme.
@immutable
class LuzTokens extends ThemeExtension<LuzTokens> {
  const LuzTokens(this.palette);
  final LuzPalette palette;

  @override
  LuzTokens copyWith({LuzPalette? palette}) =>
      LuzTokens(palette ?? this.palette);

  @override
  LuzTokens lerp(covariant LuzTokens? other, double t) => other == null
      ? this
      : LuzTokens(LuzPalette.lerp(palette, other.palette, t));
}

extension LuzContext on BuildContext {
  /// The active LuzHire palette (light or dark).
  LuzPalette get luz => Theme.of(this).extension<LuzTokens>()!.palette;

  /// Shortcut for the LuzHire text styles.
  LuzText get luzText => LuzText(Theme.of(this).textTheme);
}

/// Font families bundled in assets/fonts (OFL).
abstract final class LuzFonts {
  static const display = 'PlusJakartaSans';
  static const ui = 'Inter';
  static const mono = 'JetBrainsMono';
}

/// Variable fonts need the `wght` axis set explicitly alongside fontWeight.
TextStyle _style(
  String family,
  double size,
  int weight,
  double height, [
  double letterSpacing = 0,
]) => TextStyle(
  fontFamily: family,
  fontSize: size,
  fontWeight: FontWeight.values[(weight ~/ 100) - 1],
  fontVariations: [FontVariation('wght', weight.toDouble())],
  height: height,
  letterSpacing: letterSpacing,
);

/// Named styles from DESIGN.md that don't map 1:1 to Material's TextTheme.
class LuzText {
  const LuzText(this._t);
  final TextTheme _t;

  TextStyle get display => _t.displayLarge!;
  TextStyle get h1 => _t.displayMedium!;
  TextStyle get h2 => _t.displaySmall!;
  TextStyle get h3 => _t.headlineMedium!;
  TextStyle get h4 => _t.headlineSmall!;
  TextStyle get wsTitle => _t.titleLarge!;
  TextStyle get wsSection => _t.titleMedium!;
  TextStyle get wsCardTitle => _t.titleSmall!;
  TextStyle get bodyLg => _t.bodyLarge!;
  TextStyle get body => _t.bodyMedium!;
  TextStyle get bodySm => _t.bodySmall!;
  TextStyle get label => _t.labelLarge!;
  TextStyle get caption => _t.labelSmall!;
  TextStyle get button => _style(LuzFonts.ui, 15, 600, 1);
  TextStyle get buttonSm => _style(LuzFonts.ui, 13, 600, 1);
  TextStyle get eyebrow => _style(LuzFonts.ui, 12, 600, 1.3, 0.6);
  TextStyle get mono => _style(LuzFonts.mono, 13, 400, 1.5);
}

abstract final class AppTheme {
  static ThemeData light() => _build(LuzPalette.light);
  static ThemeData dark() => _build(LuzPalette.dark);

  static TextTheme _textTheme(LuzPalette p, {required bool compact}) {
    final s = compact ? 0.625 : 1.0; // mobile display scale (64 → 40)
    return TextTheme(
      displayLarge: _style(LuzFonts.display, 64 * s, 800, 1.05, -1.5),
      displayMedium: _style(LuzFonts.display, compact ? 34 : 48, 800, 1.1, -1),
      displaySmall: _style(
        LuzFonts.display,
        compact ? 28 : 36,
        700,
        1.15,
        -0.5,
      ),
      headlineMedium: _style(
        LuzFonts.display,
        compact ? 22 : 28,
        700,
        1.2,
        -0.3,
      ),
      headlineSmall: _style(
        LuzFonts.display,
        compact ? 19 : 22,
        700,
        1.25,
        -0.2,
      ),
      titleLarge: _style(LuzFonts.ui, 24, 600, 1.25, -0.4),
      titleMedium: _style(LuzFonts.ui, 18, 600, 1.3, -0.2),
      titleSmall: _style(LuzFonts.ui, 15, 600, 1.35, -0.1),
      bodyLarge: _style(LuzFonts.ui, 18, 400, 1.6),
      bodyMedium: _style(LuzFonts.ui, 16, 400, 1.55),
      bodySmall: _style(LuzFonts.ui, 14, 400, 1.5),
      labelLarge: _style(LuzFonts.ui, 14, 500, 1.3),
      labelMedium: _style(LuzFonts.ui, 13, 500, 1.3),
      labelSmall: _style(LuzFonts.ui, 12, 500, 1.4),
    ).apply(bodyColor: p.ink, displayColor: p.ink);
  }

  /// Text theme scaled for compact (< 600 px) screens.
  static TextTheme compactTextTheme(LuzPalette p) =>
      _textTheme(p, compact: true);

  static ThemeData _build(LuzPalette p) {
    final isDark = p.brightness == Brightness.dark;
    final scheme = ColorScheme(
      brightness: p.brightness,
      primary: LuzBrand.primary,
      onPrimary: LuzBrand.onPrimary,
      secondary: p.accent,
      onSecondary: isDark ? LuzBrand.onPrimary : Colors.white,
      error: p.danger,
      onError: isDark ? p.base : Colors.white,
      surface: p.base,
      onSurface: p.ink,
      onSurfaceVariant: p.muted,
      surfaceContainerLowest: p.sunken,
      surfaceContainerLow: p.sunken,
      surfaceContainer: p.base,
      surfaceContainerHigh: p.base,
      surfaceContainerHighest: p.base,
      outline: p.outline,
      outlineVariant: p.hairline,
      inverseSurface: p.ink,
      onInverseSurface: p.base,
      shadow: p.shade,
    );

    final text = _textTheme(p, compact: false);
    return ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.base,
      canvasColor: p.base,
      fontFamily: LuzFonts.ui,
      textTheme: text,
      dividerColor: p.hairline,
      focusColor: p.accent.withValues(alpha: 0.12),
      hoverColor: p.ink.withValues(alpha: 0.04),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: p.accent,
        selectionColor: LuzBrand.primary.withValues(alpha: 0.35),
        selectionHandleColor: p.accent,
      ),
      iconTheme: IconThemeData(color: p.inkMuted, size: 20),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: p.ink,
          borderRadius: BorderRadius.circular(LuzRadius.xs),
        ),
        textStyle: text.labelMedium!.copyWith(color: p.base),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.ink,
        contentTextStyle: text.bodySmall!.copyWith(color: p.base),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LuzRadius.md),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.base,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LuzRadius.xl),
        ),
      ),
      extensions: [LuzTokens(p)],
    );
  }
}
