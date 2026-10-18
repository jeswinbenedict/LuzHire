import 'package:flutter/material.dart';

import '../layout/input_mode.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'luz_pressable.dart';
import 'luz_surface.dart';
import 'luz_zone.dart';

/// Inset text field with the mandatory 1 px outline (DESIGN.md §2 rule 2).
/// The outline turns orange and thickens while focused, and turns red on error.
class LuzTextField extends StatefulWidget {
  const LuzTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.helper,
    this.error,
    this.prefixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.autofillHints,
    this.enabled = true,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? helper;
  final String? error;
  final IconData? prefixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;
  final bool enabled;

  @override
  State<LuzTextField> createState() => _LuzTextFieldState();
}

class _LuzTextFieldState extends State<LuzTextField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    final t = context.luzText;
    final zone = LuzZone.of(context);
    final hasError = widget.error != null;
    final focused = _focus.hasFocus;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.label, style: t.label.copyWith(color: p.inkMuted)),
        const SizedBox(height: LuzSpace.xs),
        LuzSurface(
          depth: widget.enabled ? LuzDepth.insetSm : LuzDepth.flat,
          radius: zone.inputRadius,
          outline: hasError ? p.danger : (focused ? p.accent : p.outline),
          outlineWidth: (focused || hasError) ? 2 : 1,
          padding: const EdgeInsets.symmetric(horizontal: LuzSpace.md),
          child: SizedBox(
            height: zone.isWorkspace && context.isPointer ? 38 : 50,
            child: Row(
              children: [
                if (widget.prefixIcon != null) ...[
                  Icon(widget.prefixIcon, size: 18, color: p.muted),
                  const SizedBox(width: LuzSpace.sm),
                ],
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focus,
                    enabled: widget.enabled,
                    obscureText: widget.obscureText,
                    keyboardType: widget.keyboardType,
                    textInputAction: widget.textInputAction,
                    onChanged: widget.onChanged,
                    onSubmitted: widget.onSubmitted,
                    autofillHints: widget.autofillHints,
                    style: t.body.copyWith(color: p.ink),
                    decoration: InputDecoration.collapsed(
                      hintText: widget.hint,
                      hintStyle: t.body.copyWith(color: p.muted),
                    ).copyWith(semanticCounterText: ''),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (hasError || widget.helper != null) ...[
          const SizedBox(height: LuzSpace.xxs + 2),
          Row(
            children: [
              if (hasError) ...[
                Icon(Icons.error_outline, size: 16, color: p.danger),
                const SizedBox(width: LuzSpace.xxs),
              ],
              Expanded(
                child: Text(
                  widget.error ?? widget.helper!,
                  style: t.caption.copyWith(
                    color: hasError ? p.danger : p.muted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Physical toggle: inset track, raised knob, orange track when on.
class LuzToggle extends StatelessWidget {
  const LuzToggle({
    super.key,
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String semanticLabel;

  static const _w = 52.0, _h = 30.0, _knob = 24.0;

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    final enabled = onChanged != null;
    return LuzPressable(
      onPressed: enabled ? () => onChanged!(!value) : null,
      radius: LuzRadius.pill,
      semanticLabel: semanticLabel,
      toggled: value,
      builder: (context, pressed, _) => SizedBox(
        width: _w,
        height: _h,
        child: Stack(
          children: [
            Positioned.fill(
              child: LuzSurface(
                depth: LuzDepth.insetSm,
                radius: LuzRadius.pill,
                duration: LuzMotion.toggle,
                color: value && enabled ? LuzBrand.primary : null,
              ),
            ),
            AnimatedAlign(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : LuzMotion.toggle,
              curve: Curves.easeOutBack,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: LuzSurface(
                  depth: enabled ? LuzDepth.raisedXs : LuzDepth.flat,
                  radius: LuzRadius.pill,
                  color: p.base,
                  child: SizedBox.square(
                    dimension: _knob,
                    // Non-colour cue for the on state.
                    child: value
                        ? Icon(Icons.check, size: 14, color: p.ink)
                        : null,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
