// Design tokens from /DESIGN.md (accessible neumorphism).
// Keep this file in sync with the DESIGN.md front matter.
import 'package:flutter/material.dart';

/// Brand colours shared by both themes.
abstract final class LuzBrand {
  static const primary = Color(0xFFFE8022); // logo dot
  static const primaryHover = Color(0xFFFF9A4D);
  static const primaryPressed = Color(0xFFE86D12);
  static const onPrimary = Color(0xFF14110F);

  /// Brand orange that passes AA as text on light surfaces.
  static const primaryStrong = Color(0xFF9A3F0A);
}

/// Background / foreground pair for an inset status chip.
@immutable
class LuzChipColors {
  const LuzChipColors(this.background, this.foreground);
  final Color background;
  final Color foreground;

  static LuzChipColors lerp(LuzChipColors a, LuzChipColors b, double t) =>
      LuzChipColors(
        Color.lerp(a.background, b.background, t)!,
        Color.lerp(a.foreground, b.foreground, t)!,
      );
}

enum LuzChipTone { neutral, blue, violet, orange, green, red }

/// Per-theme palette. `base` is THE surface: page and raised elements share it.
@immutable
class LuzPalette {
  const LuzPalette({
    required this.brightness,
    required this.base,
    required this.sunken,
    required this.highlight,
    required this.shade,
    required this.baseTint,
    required this.ink,
    required this.inkMuted,
    required this.muted,
    required this.disabled,
    required this.outline,
    required this.hairline,
    required this.accent,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.chips,
  });

  final Brightness brightness;
  final Color base;
  final Color sunken;
  final Color highlight;
  final Color shade;
  final Color baseTint;
  final Color ink;
  final Color inkMuted;
  final Color muted;
  final Color disabled;
  final Color outline;
  final Color hairline;

  /// Links, focus rings and active indicators (brand orange that passes AA here).
  final Color accent;
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;
  final Map<LuzChipTone, LuzChipColors> chips;

  static const light = LuzPalette(
    brightness: Brightness.light,
    base: Color(0xFFEEECE7),
    sunken: Color(0xFFE4E1DA),
    highlight: Color(0xFFFFFFFF),
    shade: Color(0xFFCBC5BA),
    baseTint: Color(0xFFF7E6D8),
    ink: Color(0xFF14110F),
    inkMuted: Color(0xFF3D4148),
    muted: Color(0xFF5A5F66),
    disabled: Color(0xFF9A9EA6),
    outline: Color(0xFF85817A),
    hairline: Color(0xFFDAD6CE),
    accent: LuzBrand.primaryStrong,
    success: Color(0xFF15803D),
    warning: Color(0xFF854D0E),
    danger: Color(0xFFB91C1C),
    info: Color(0xFF1D4ED8),
    chips: {
      LuzChipTone.neutral: LuzChipColors(Color(0xFFE4E1DA), Color(0xFF4B5058)),
      LuzChipTone.blue: LuzChipColors(Color(0xFFE6EBF7), Color(0xFF1D4ED8)),
      LuzChipTone.violet: LuzChipColors(Color(0xFFECE5F7), Color(0xFF6D28D9)),
      LuzChipTone.orange: LuzChipColors(Color(0xFFFBE4D3), Color(0xFF9A3412)),
      LuzChipTone.green: LuzChipColors(Color(0xFFE3F1E6), Color(0xFF166534)),
      LuzChipTone.red: LuzChipColors(Color(0xFFF6E3E1), Color(0xFFB91C1C)),
    },
  );

  static const dark = LuzPalette(
    brightness: Brightness.dark,
    base: Color(0xFF1D1F23),
    sunken: Color(0xFF16171A),
    highlight: Color(0xFF2A2D33),
    shade: Color(0xFF0E0F11),
    baseTint: Color(0xFF2A1F17),
    ink: Color(0xFFF2F2EF),
    inkMuted: Color(0xFFC9CCD1),
    muted: Color(0xFF9EA2AA),
    disabled: Color(0xFF63676E),
    outline: Color(0xFF6E737B),
    hairline: Color(0xFF2B2E34),
    accent: LuzBrand.primary,
    success: Color(0xFF3DD68C),
    warning: Color(0xFFFACC15),
    danger: Color(0xFFF87171),
    info: Color(0xFF93B4FF),
    chips: {
      LuzChipTone.neutral: LuzChipColors(Color(0xFF202227), Color(0xFFB9BDC4)),
      LuzChipTone.blue: LuzChipColors(Color(0xFF1A2236), Color(0xFF93B4FF)),
      LuzChipTone.violet: LuzChipColors(Color(0xFF241C38), Color(0xFFC4B0FF)),
      LuzChipTone.orange: LuzChipColors(Color(0xFF3A2215), Color(0xFFFFB088)),
      LuzChipTone.green: LuzChipColors(Color(0xFF15291E), Color(0xFF7EE2A8)),
      LuzChipTone.red: LuzChipColors(Color(0xFF331A1A), Color(0xFFFCA5A5)),
    },
  );

  static LuzPalette lerp(LuzPalette a, LuzPalette b, double t) {
    Color c(Color x, Color y) => Color.lerp(x, y, t)!;
    return LuzPalette(
      brightness: t < 0.5 ? a.brightness : b.brightness,
      base: c(a.base, b.base),
      sunken: c(a.sunken, b.sunken),
      highlight: c(a.highlight, b.highlight),
      shade: c(a.shade, b.shade),
      baseTint: c(a.baseTint, b.baseTint),
      ink: c(a.ink, b.ink),
      inkMuted: c(a.inkMuted, b.inkMuted),
      muted: c(a.muted, b.muted),
      disabled: c(a.disabled, b.disabled),
      outline: c(a.outline, b.outline),
      hairline: c(a.hairline, b.hairline),
      accent: c(a.accent, b.accent),
      success: c(a.success, b.success),
      warning: c(a.warning, b.warning),
      danger: c(a.danger, b.danger),
      info: c(a.info, b.info),
      chips: {
        for (final tone in LuzChipTone.values)
          tone: LuzChipColors.lerp(a.chips[tone]!, b.chips[tone]!, t),
      },
    );
  }
}

/// Relief distances in logical pixels (shadow offset; blur = 2 × distance).
/// Positive = raised, negative = inset, 0 = flat.
abstract final class LuzDepth {
  static const double flat = 0;
  static const double raisedXs = 2;
  static const double raisedSm = 4;
  static const double raisedMd = 8;
  static const double raisedLg = 12;
  static const double insetSm = -2;
  static const double insetMd = -4;
}

abstract final class LuzRadius {
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 24;
  static const double xxl = 32;
  static const double pill = 9999;
}

abstract final class LuzSpace {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double section = 96;
  static const double sectionMobile = 56;
}

abstract final class LuzMotion {
  static const press = Duration(milliseconds: 120);
  static const toggle = Duration(milliseconds: 200);
  static const sheet = Duration(milliseconds: 280);
  static const curve = Cubic(0.2, 0, 0, 1);
}

abstract final class LuzBreakpoints {
  static const double medium = 600;
  static const double expanded = 1024;
  static const double large = 1440;
}
