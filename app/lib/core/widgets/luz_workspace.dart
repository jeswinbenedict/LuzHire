import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'luz_surface.dart';

/// Column definition for [LuzDataTable].
class LuzColumn<T> {
  const LuzColumn({
    required this.label,
    required this.cell,
    this.flex = 1,
    this.sortKey,
    this.numeric = false,
  });

  final String label;
  final Widget Function(BuildContext context, T row) cell;
  final int flex;

  /// Enables sorting on this column.
  final Comparable<Object?> Function(T row)? sortKey;
  final bool numeric;
}

/// Workspace table: one raised panel, flat 44 px rows with hairline dividers,
/// hover = sunken, sortable headers (DESIGN.md §8 Workspace / Tables).
/// On compact widths each row renders as a stacked label/value card instead.
class LuzDataTable<T> extends StatefulWidget {
  const LuzDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.onRowTap,
    this.emptyLabel = 'Nothing here yet',
  });

  final List<LuzColumn<T>> columns;
  final List<T> rows;
  final ValueChanged<T>? onRowTap;
  final String emptyLabel;

  @override
  State<LuzDataTable<T>> createState() => _LuzDataTableState<T>();
}

class _LuzDataTableState<T> extends State<LuzDataTable<T>> {
  int? _sortCol;
  bool _asc = true;
  int? _hover;
  int? _focused;

  List<T> get _sorted {
    final i = _sortCol;
    if (i == null) return widget.rows;
    final key = widget.columns[i].sortKey!;
    final list = [...widget.rows]
      ..sort((a, b) => Comparable.compare(key(a), key(b)));
    return _asc ? list : list.reversed.toList();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    final t = context.luzText;
    final rows = _sorted;

    return LuzSurface(
      depth: LuzDepth.raisedSm,
      radius: LuzRadius.md,
      child: LayoutBuilder(
        builder: (context, c) {
          final stacked = c.maxWidth < 600;
          if (rows.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(LuzSpace.xl),
              child: Center(
                child: Text(
                  widget.emptyLabel,
                  style: t.bodySm.copyWith(color: p.muted),
                ),
              ),
            );
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!stacked) _header(context),
              for (var r = 0; r < rows.length; r++) ...[
                if (r > 0 || !stacked) Divider(height: 1, color: p.hairline),
                _row(context, rows[r], r, stacked),
              ],
            ],
          );
        },
      ),
    );
  }

  /// A gap between neighbouring columns, so a right-aligned number never
  /// touches the next column ("3" + "19 Oct" read as "319 Oct").
  Widget _cellPadding(int column, Widget child) => Padding(
    padding: EdgeInsets.only(
      left: column == 0 ? 0 : LuzSpace.sm,
      right: column == widget.columns.length - 1 ? 0 : LuzSpace.sm,
    ),
    child: child,
  );

  Widget _header(BuildContext context) {
    final p = context.luz;
    final t = context.luzText;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: LuzSpace.md),
      child: SizedBox(
        height: 40,
        child: Row(
          children: [
            for (var i = 0; i < widget.columns.length; i++)
              Expanded(
                flex: widget.columns[i].flex,
                child: _cellPadding(
                  i,
                  _HeaderCell(
                    label: widget.columns[i].label,
                    numeric: widget.columns[i].numeric,
                    sortable: widget.columns[i].sortKey != null,
                    sorted: _sortCol == i
                        ? (_asc ? 'ascending' : 'descending')
                        : null,
                    style: t.eyebrow.copyWith(color: p.muted),
                    onTap: widget.columns[i].sortKey == null
                        ? null
                        : () => setState(() {
                            if (_sortCol == i) {
                              _asc = !_asc;
                            } else {
                              _sortCol = i;
                              _asc = true;
                            }
                          }),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, T row, int index, bool stacked) {
    final p = context.luz;
    final t = context.luzText;
    final content = stacked
        ? Padding(
            padding: const EdgeInsets.all(LuzSpace.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final col in widget.columns)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 110,
                          child: Text(
                            col.label,
                            style: t.caption.copyWith(color: p.muted),
                          ),
                        ),
                        Expanded(child: col.cell(context, row)),
                      ],
                    ),
                  ),
              ],
            ),
          )
        : Padding(
            padding: const EdgeInsets.symmetric(horizontal: LuzSpace.md),
            child: SizedBox(
              height: 44,
              child: Row(
                children: [
                  for (final col in widget.columns)
                    Expanded(
                      flex: col.flex,
                      child: _cellPadding(
                        widget.columns.indexOf(col),
                        Align(
                          alignment: col.numeric
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: DefaultTextStyle.merge(
                            style: t.bodySm.copyWith(color: p.ink),
                            overflow: TextOverflow.ellipsis,
                            child: col.cell(context, row),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );

    final tap = widget.onRowTap == null ? null : () => widget.onRowTap!(row);
    // Clickable rows are keyboard stops too: Tab reaches them, Enter or
    // Space opens them, and focus shows as the accent ring (DESIGN.md §2).
    return Semantics(
      button: tap != null,
      child: FocusableActionDetector(
        enabled: tap != null,
        mouseCursor: tap != null ? SystemMouseCursors.click : MouseCursor.defer,
        onShowHoverHighlight: (v) => setState(
          () => _hover = v ? index : (_hover == index ? null : _hover),
        ),
        onShowFocusHighlight: (v) => setState(
          () => _focused = v ? index : (_focused == index ? null : _focused),
        ),
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              tap?.call();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: tap,
          child: AnimatedContainer(
            duration: LuzMotion.press,
            decoration: BoxDecoration(
              color: _hover == index ? p.sunken : Colors.transparent,
              border: _focused == index
                  ? Border.all(color: p.accent, width: 2)
                  : null,
              borderRadius: BorderRadius.circular(LuzRadius.xs),
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({
    required this.label,
    required this.numeric,
    required this.sortable,
    required this.sorted,
    required this.style,
    required this.onTap,
  });

  final String label;
  final bool numeric;
  final bool sortable;
  final String? sorted;
  final TextStyle style;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    final text = Row(
      mainAxisAlignment: numeric
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      children: [
        Flexible(
          child: Text(
            label.toUpperCase(),
            style: style,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (sortable) ...[
          const SizedBox(width: 4),
          Icon(
            sorted == 'descending'
                ? Icons.arrow_downward
                : sorted == 'ascending'
                ? Icons.arrow_upward
                : Icons.unfold_more,
            size: 14,
            color: sorted != null ? p.accent : p.muted,
          ),
        ],
      ],
    );
    if (!sortable) return text;
    return Semantics(
      button: true,
      label: sorted == null ? 'Sort by $label' : '$label, sorted $sorted',
      excludeSemantics: true,
      child: InkWell(onTap: onTap, child: text),
    );
  }
}

/// Kanban stage tray: an inset column holding raised paper cards.
class LuzKanbanColumn extends StatelessWidget {
  const LuzKanbanColumn({
    super.key,
    required this.header,
    required this.count,
    required this.children,
    this.width = 288,
  });

  /// Usually a [LuzStatusChip] for the stage.
  final Widget header;
  final int count;
  final List<Widget> children;
  final double width;

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    return SizedBox(
      width: width,
      child: LuzSurface(
        depth: LuzDepth.insetSm,
        radius: LuzRadius.md,
        padding: const EdgeInsets.all(LuzSpace.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 10),
              child: Row(
                children: [
                  // Long stage names shrink instead of overflowing.
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: header,
                    ),
                  ),
                  const SizedBox(width: LuzSpace.xs),
                  const Spacer(),
                  Text(
                    '$count',
                    style: context.luzText.label.copyWith(color: p.muted),
                  ),
                ],
              ),
            ),
            for (final child in children)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
                child: child,
              ),
            if (children.isEmpty)
              Padding(
                padding: const EdgeInsets.all(LuzSpace.md),
                child: Text(
                  'No candidates',
                  textAlign: TextAlign.center,
                  style: context.luzText.caption.copyWith(color: p.muted),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Headline figures spread evenly across their card (two per row when
/// narrow). Numbers use the figure style; words such as "No hires yet" use
/// plain type so they don't read as a value.
class LuzStatStrip extends StatelessWidget {
  const LuzStatStrip({super.key, required this.stats});
  final List<({String label, String value})> stats;

  static final _number = RegExp(r'^[\d.,]+$');

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    final t = context.luzText;
    Widget stat(({String label, String value}) s) => Semantics(
      label: '${s.label}: ${s.value}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.label, style: t.caption.copyWith(color: p.inkMuted)),
          const SizedBox(height: LuzSpace.xxs),
          Text(
            s.value,
            style: _number.hasMatch(s.value)
                ? t.wsTitle.copyWith(fontFamily: t.mono.fontFamily)
                : t.wsSection.copyWith(color: p.inkMuted),
          ),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, c) {
        final perRow = c.maxWidth >= stats.length * 140
            ? stats.length
            : (c.maxWidth >= 280 ? 2 : 1);
        return Column(
          spacing: LuzSpace.md,
          children: [
            for (var i = 0; i < stats.length; i += perRow)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: LuzSpace.md,
                children: [
                  for (var j = i; j < i + perRow; j++)
                    Expanded(
                      child: j < stats.length
                          ? stat(stats[j])
                          : const SizedBox.shrink(),
                    ),
                ],
              ),
          ],
        );
      },
    );
  }
}

/// Counts per week for the last 12 weeks, oldest first, every week shown
/// (an empty week is a thin baseline), so one busy week is one bar of
/// twelve, not a bar the width of the card.
class LuzWeekBars extends StatelessWidget {
  const LuzWeekBars({
    super.key,
    required this.weeks,
    required this.unit,
    this.barHeight = 100,
    this.now,
  });

  /// Week starts (as `date_trunc('week')` returns them) with their counts.
  final List<({DateTime week, int count})> weeks;

  /// What is counted, plural ("applications", "sign-ups").
  final String unit;
  final double barHeight;

  /// Today, for tests.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    final t = context.luzText;
    final today = now ?? DateTime.now();
    final monday = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(Duration(days: today.weekday - 1));
    final slots = [
      for (var i = 11; i >= 0; i--) monday.subtract(Duration(days: 7 * i)),
    ];
    // Same week if within half a week (UTC week starts vs local days).
    int countFor(DateTime start) => weeks
        .where((w) => w.week.toLocal().difference(start).inHours.abs() < 84)
        .fold(0, (sum, w) => sum + w.count);
    final counts = [for (final s in slots) countFor(s)];
    final max = counts.fold(1, (a, b) => b > a ? b : a);
    final caption = MediaQuery.textScalerOf(context)
        .scale((t.caption.fontSize ?? 12) * (t.caption.height ?? 1.4));

    return LayoutBuilder(
      builder: (context, c) {
        // Narrow: a date under every third bar, so labels never collide.
        final every = c.maxWidth / 12 < 40 ? 3 : 1;
        return SizedBox(
          height: barHeight + 2 * caption + 8,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < 12; i++)
                Expanded(
                  child: Semantics(
                    label:
                        'Week of ${DateFormat('d MMM').format(slots[i])}: '
                        '${counts[i]} $unit',
                    excludeSemantics: true,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            counts[i] == 0 ? '' : '${counts[i]}',
                            style: t.caption,
                            maxLines: 1,
                          ),
                          Container(
                            height: counts[i] == 0
                                ? 2
                                : barHeight * counts[i] / max,
                            decoration: BoxDecoration(
                              color: counts[i] == 0 ? p.hairline : p.accent,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ),
                          Text(
                            (11 - i) % every == 0
                                ? DateFormat('d/M').format(slots[i])
                                : '',
                            style: t.caption.copyWith(color: p.muted),
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.visible,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
