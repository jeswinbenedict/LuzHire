import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'luz_button.dart';
import 'luz_pressable.dart' show LuzMinTarget;
import 'luz_surface.dart';
import 'luz_zone.dart';

/// Job-provider hosts whose images carry no CORS headers. Flutter web draws
/// images on a canvas, which needs CORS, so these load through /api/img (a
/// cached same-origin copy). Keep in sync with IMAGE_HOSTS in
/// api/_lib/image-proxy.ts.
const _proxiedImageHosts = {
  'remotive.com',
  'www.remotive.com',
  'cdn.hashnode.com',
  'cdn-images.himalayas.app',
};

/// The URL to load [url] from on this platform.
String networkImageUrl(String url) {
  if (!kIsWeb) return url;
  final uri = Uri.tryParse(url);
  if (uri == null || !_proxiedImageHosts.contains(uri.host)) return url;
  return Uri.base
      .resolveUri(Uri(path: '/api/img', queryParameters: {'u': url}))
      .toString();
}

/// Decodes at the displayed size instead of the source size (less memory).
int _decodeSize(BuildContext context, double logical) =>
    (logical * MediaQuery.devicePixelRatioOf(context)).ceil();

/// Circular avatar set into an inset socket; falls back to initials.
class LuzAvatar extends StatelessWidget {
  const LuzAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 40,
  });

  final String name;
  final String? imageUrl;
  final double size;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty);
    return parts.take(2).map((s) => s[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    return Semantics(
      label: name,
      image: true,
      excludeSemantics: true,
      child: LuzSurface(
        depth: LuzDepth.insetSm,
        radius: LuzRadius.pill,
        padding: const EdgeInsets.all(2),
        child: ClipOval(
          child: SizedBox.square(
            dimension: size - 4,
            child: imageUrl != null
                ? Image.network(
                    networkImageUrl(imageUrl!),
                    fit: BoxFit.cover,
                    cacheWidth: _decodeSize(context, size - 4),
                    errorBuilder: (_, _, _) => _fallback(context, p),
                  )
                : _fallback(context, p),
          ),
        ),
      ),
    );
  }

  Widget _fallback(BuildContext context, LuzPalette p) => ColoredBox(
    color: p.sunken,
    child: Center(
      child: Text(
        _initials,
        style: context.luzText.label.copyWith(
          color: p.accent,
          fontSize: size * 0.36,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

/// Company logo in a rounded inset socket (DESIGN.md §6).
class LuzLogoSocket extends StatelessWidget {
  const LuzLogoSocket({
    super.key,
    required this.name,
    this.logoUrl,
    this.size = 48,
  });

  final String name;
  final String? logoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    final letter = name.isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Semantics(
      label: '$name logo',
      image: true,
      excludeSemantics: true,
      child: LuzSurface(
        depth: LuzDepth.insetSm,
        radius: LuzRadius.sm,
        padding: const EdgeInsets.all(6),
        child: SizedBox.square(
          dimension: size - 12,
          child: logoUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    networkImageUrl(logoUrl!),
                    fit: BoxFit.contain,
                    cacheWidth: _decodeSize(context, size - 12),
                    errorBuilder: (_, _, _) => _letter(context, p, letter),
                  ),
                )
              : _letter(context, p, letter),
        ),
      ),
    );
  }

  Widget _letter(BuildContext context, LuzPalette p, String letter) => Center(
    child: Text(
      letter,
      style: context.luzText.h4.copyWith(color: p.accent, fontSize: size * 0.4),
    ),
  );
}

/// Segmented progress groove (e.g. profile completeness) filling with orange.
class LuzProgressGroove extends StatelessWidget {
  const LuzProgressGroove({
    super.key,
    required this.value,
    required this.label,
    this.segments = 10,
  });

  /// 0.0 – 1.0
  final double value;
  final String label;
  final int segments;

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    final v = value.clamp(0.0, 1.0);
    final filled = (v * segments).round();
    final pct = (v * 100).round();
    return Semantics(
      label: label,
      value: '$pct%',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: context.luzText.label.copyWith(color: p.inkMuted),
                ),
              ),
              Text(
                '$pct%',
                style: context.luzText.label.copyWith(
                  color: p.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: LuzSpace.xs),
          LuzSurface(
            depth: LuzDepth.insetSm,
            radius: LuzRadius.pill,
            padding: const EdgeInsets.all(3),
            child: Row(
              children: [
                for (var i = 0; i < segments; i++) ...[
                  if (i > 0) const SizedBox(width: 3),
                  Expanded(
                    child: AnimatedContainer(
                      duration: LuzMotion.sheet,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i < filled
                            ? LuzBrand.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Hero search well: inset pill with outline, keyword + location fields and
/// an orange Search pill. Stacks into a card on narrow widths.
class LuzSearchBar extends StatefulWidget {
  const LuzSearchBar({
    super.key,
    required this.onSearch,
    this.keywordController,
    this.locationController,
    this.focusNode,
  });

  final void Function(String keyword, String location) onSearch;
  final TextEditingController? keywordController;
  final TextEditingController? locationController;

  /// Focus target for the "/" shortcut.
  final FocusNode? focusNode;

  @override
  State<LuzSearchBar> createState() => _LuzSearchBarState();
}

class _LuzSearchBarState extends State<LuzSearchBar> {
  TextEditingController? _ownKw;
  TextEditingController? _ownLoc;

  TextEditingController get _kw =>
      widget.keywordController ?? (_ownKw ??= TextEditingController());
  TextEditingController get _loc =>
      widget.locationController ?? (_ownLoc ??= TextEditingController());

  @override
  void dispose() {
    _ownKw?.dispose();
    _ownLoc?.dispose();
    super.dispose();
  }

  void _submit([String? _]) =>
      widget.onSearch(_kw.text.trim(), _loc.text.trim());

  Widget _field(
    TextEditingController c,
    String label,
    String hint,
    IconData icon, {
    FocusNode? focus,
  }) {
    final p = context.luz;
    final t = context.luzText;
    // 48 dp tall so the whole row is the touch / semantics target, with the
    // text centred in it (level with the icon and the Search button). A
    // field's decorator puts extra height below the text, so the padding is
    // split evenly from the line's real height at the user's text size.
    final line = TextPainter(
      text: TextSpan(text: hint, style: t.body),
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final padding = ((LuzMinTarget.touch - line.height) / 2).clamp(0.0, 24.0);
    line.dispose();
    return Row(
      children: [
        Icon(icon, size: 20, color: p.muted),
        const SizedBox(width: LuzSpace.sm),
        Expanded(
          child: TextField(
            controller: c,
            focusNode: focus,
            onSubmitted: _submit,
            textInputAction: TextInputAction.search,
            style: t.body.copyWith(color: p.ink),
            decoration: InputDecoration(
              isDense: true,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: padding),
              hintText: hint,
              hintStyle: t.body.copyWith(color: p.muted),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    return LayoutBuilder(
      builder: (context, c) {
        final narrow = c.maxWidth < 640;
        // The hint text doubles as the accessible name of each field.
        final keyword = _field(
          _kw,
          'Job title, skill or company',
          'Job title, skill or company',
          Icons.search,
          focus: widget.focusNode,
        );
        final location = _field(
          _loc,
          'Location',
          'City or "Remote"',
          Icons.place_outlined,
        );
        final button = LuzZone(
          kind: LuzZoneKind.spotlight,
          child: LuzButton.accent(
            label: 'Search',
            icon: Icons.search,
            onPressed: _submit,
            expand: narrow,
          ),
        );

        if (narrow) {
          return LuzSurface(
            depth: LuzDepth.insetMd,
            radius: LuzRadius.xl,
            outline: p.outline,
            padding: const EdgeInsets.all(LuzSpace.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                keyword,
                Divider(height: 1, color: p.hairline),
                location,
                const SizedBox(height: LuzSpace.sm),
                button,
              ],
            ),
          );
        }
        return LuzSurface(
          depth: LuzDepth.insetMd,
          radius: LuzRadius.pill,
          outline: p.outline,
          padding: const EdgeInsets.fromLTRB(LuzSpace.lg, 6, 6, 6),
          child: SizedBox(
            height: 56,
            child: Row(
              children: [
                Expanded(flex: 3, child: keyword),
                Container(
                  width: 1,
                  height: 28,
                  margin: const EdgeInsets.symmetric(horizontal: LuzSpace.md),
                  color: p.hairline,
                ),
                Expanded(flex: 2, child: location),
                const SizedBox(width: LuzSpace.sm),
                button,
              ],
            ),
          ),
        );
      },
    );
  }
}
