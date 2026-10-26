import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
                child: _HeaderCell(
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
                      child: Align(
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
