import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'luz_pressable.dart';
import 'luz_surface.dart';
import 'luz_zone.dart';

/// Segmented control / tabs: an inset tray; the selected segment is raised
/// and carries an orange underline (selection is never relief-only).
class LuzSegmented<T> extends StatelessWidget {
  const LuzSegmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  final List<({T value, String label, IconData? icon})> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    final zone = LuzZone.of(context);
    final radius = zone.isWorkspace ? LuzRadius.sm : LuzRadius.pill;
    return LuzSurface(
      depth: LuzDepth.insetSm,
      radius: radius,
      padding: const EdgeInsets.all(4),
      // Scrolls instead of overflowing on narrow screens / large text.
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final s in segments)
              LuzPressable(
                onPressed: () => onChanged(s.value),
                radius: radius,
                semanticLabel: s.label,
                selected: s.value == selected,
                builder: (context, pressed, _) {
                  final on = s.value == selected;
                  return LuzSurface(
                    depth: on ? LuzDepth.raisedXs : LuzDepth.flat,
                    radius: radius,
                    color: on ? p.base : p.sunken,
                    padding: EdgeInsets.symmetric(
                      horizontal: zone.isWorkspace ? 12 : 16,
                      vertical: zone.isWorkspace ? 7 : 9,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (s.icon != null) ...[
                              Icon(
                                s.icon,
                                size: 16,
                                color: on ? p.ink : p.muted,
                              ),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              s.label,
                              style: context.luzText.label.copyWith(
                                color: on ? p.ink : p.muted,
                                fontWeight: on ? FontWeight.w600 : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        AnimatedContainer(
                          duration: LuzMotion.toggle,
                          width: on ? 18 : 0,
                          height: 2,
                          decoration: BoxDecoration(
                            color: p.accent,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// Inset checkbox well with outline; checked = orange fill + ink tick.
class LuzCheckbox extends StatelessWidget {
  const LuzCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String label;

  @override
  Widget build(BuildContext context) => _LuzCheckRow(
    label: label,
    checked: value,
    onTap: onChanged == null ? null : () => onChanged!(!value),
    round: false,
  );
}

/// Inset radio well; selected = orange fill + ink dot.
class LuzRadio<T> extends StatelessWidget {
  const LuzRadio({
    super.key,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    required this.label,
  });

  final T value;
  final T? groupValue;
  final ValueChanged<T>? onChanged;
  final String label;

  @override
  Widget build(BuildContext context) => _LuzCheckRow(
    label: label,
    checked: value == groupValue,
    onTap: onChanged == null ? null : () => onChanged!(value),
    round: true,
  );
}

class _LuzCheckRow extends StatelessWidget {
  const _LuzCheckRow({
    required this.label,
    required this.checked,
    required this.onTap,
    required this.round,
  });

  final String label;
  final bool checked;
  final VoidCallback? onTap;
  final bool round;

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    final enabled = onTap != null;
    return LuzPressable(
      onPressed: onTap,
      radius: LuzRadius.xs,
      semanticLabel: label,
      toggled: round ? null : checked,
      selected: round ? checked : null,
      builder: (context, pressed, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            LuzSurface(
              depth: LuzDepth.insetSm,
              radius: round ? LuzRadius.pill : 6,
              color: checked && enabled ? LuzBrand.primary : null,
              outline: checked ? null : p.outline,
              duration: LuzMotion.toggle,
              child: SizedBox.square(
                dimension: 22,
                child: checked
                    ? (round
                          ? Center(
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: LuzBrand.onPrimary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.check,
                              size: 16,
                              color: LuzBrand.onPrimary,
                            ))
                    : null,
              ),
            ),
            const SizedBox(width: LuzSpace.sm),
            Flexible(
              child: Text(
                label,
                style: context.luzText.body.copyWith(
                  color: enabled ? p.ink : p.disabled,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Range slider: inset groove, raised thumbs, orange filled segment.
/// Thumbs are focusable and move with arrow keys (Shift = 10 steps).
class LuzRangeSlider extends StatefulWidget {
  const LuzRangeSlider({
    super.key,
    required this.min,
    required this.max,
    required this.values,
    required this.onChanged,
    required this.semanticLabel,
    this.step = 1,
    this.format,
  });

  final double min;
  final double max;
  final RangeValues values;
  final ValueChanged<RangeValues>? onChanged;
  final String semanticLabel;
  final double step;
  final String Function(double value)? format;

  @override
  State<LuzRangeSlider> createState() => _LuzRangeSliderState();
}

class _LuzRangeSliderState extends State<LuzRangeSlider> {
  static const _thumb = 26.0;

  /// Latest value we reported, until the parent rebuilds us with it.
  /// Lets several key repeats inside one frame accumulate correctly.
  RangeValues? _pending;
  RangeValues get _current => _pending ?? widget.values;

  @override
  void didUpdateWidget(LuzRangeSlider old) {
    super.didUpdateWidget(old);
    _pending = null;
  }

  String _fmt(double v) => widget.format?.call(v) ?? v.round().toString();

  double _snap(double v) {
    final s =
        ((v - widget.min) / widget.step).round() * widget.step + widget.min;
    return s.clamp(widget.min, widget.max).toDouble();
  }

  void _set({double? start, double? end}) {
    if (widget.onChanged == null) return;
    var s = _snap(start ?? _current.start);
    var e = _snap(end ?? _current.end);
    if (s > e) {
      if (start != null) {
        s = e;
      } else {
        e = s;
      }
    }
    _pending = RangeValues(s, e);
    widget.onChanged!(_pending!);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    final span = widget.max - widget.min;
    return LayoutBuilder(
      builder: (context, c) {
        final usable = c.maxWidth - _thumb;
        double toX(double v) => (v - widget.min) / span * usable;
        double toV(double x) => widget.min + (x / usable).clamp(0, 1) * span;
        final sx = toX(widget.values.start);
        final ex = toX(widget.values.end);

        Widget thumb(bool isStart) {
          final value = isStart ? _current.start : _current.end;
          final label =
              '${widget.semanticLabel} ${isStart ? 'minimum' : 'maximum'}';
          void nudge(int steps) {
            final v = isStart ? _current.start : _current.end;
            isStart
                ? _set(start: v + steps * widget.step)
                : _set(end: v + steps * widget.step);
          }

          return Positioned(
            left: isStart ? sx : ex,
            top: 0,
            child: Semantics(
              slider: true,
              label: label,
              value: _fmt(value),
              increasedValue: _fmt(_snap(value + widget.step)),
              decreasedValue: _fmt(_snap(value - widget.step)),
              onIncrease: () => nudge(1),
              onDecrease: () => nudge(-1),
              child: Focus(
                onKeyEvent: (node, event) {
                  if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
                    return KeyEventResult.ignored;
                  }
                  final big = HardwareKeyboard.instance.isShiftPressed ? 10 : 1;
                  if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
                      event.logicalKey == LogicalKeyboardKey.arrowUp) {
                    nudge(big);
                    return KeyEventResult.handled;
                  }
                  if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
                      event.logicalKey == LogicalKeyboardKey.arrowDown) {
                    nudge(-big);
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: Builder(
                  builder: (context) {
                    final focused = Focus.of(context).hasFocus;
                    return GestureDetector(
                      onHorizontalDragUpdate: widget.onChanged == null
                          ? null
                          : (d) {
                              final x = (isStart ? sx : ex) + d.delta.dx;
                              isStart ? _set(start: toV(x)) : _set(end: toV(x));
                            },
                      child: Container(
                        decoration: focused
                            ? BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: p.accent, width: 2),
                              )
                            : null,
                        padding: const EdgeInsets.all(1),
                        child: LuzSurface(
                          depth: LuzDepth.raisedXs,
                          radius: LuzRadius.pill,
                          child: const SizedBox.square(dimension: _thumb - 2),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: _thumb,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: _thumb / 2,
                    right: _thumb / 2,
                    top: _thumb / 2 - 5,
                    child: LuzSurface(
                      depth: LuzDepth.insetSm,
                      radius: LuzRadius.pill,
                      child: const SizedBox(height: 10),
                    ),
                  ),
                  Positioned(
                    left: sx + _thumb / 2,
                    width: (ex - sx).clamp(0, usable),
                    top: _thumb / 2 - 3,
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: LuzBrand.primary,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  thumb(true),
                  thumb(false),
                ],
              ),
            ),
            const SizedBox(height: LuzSpace.xs),
            Row(
              children: [
                Text(
                  _fmt(widget.values.start),
                  style: context.luzText.caption.copyWith(color: p.inkMuted),
                ),
                const Spacer(),
                Text(
                  _fmt(widget.values.end),
                  style: context.luzText.caption.copyWith(color: p.inkMuted),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
