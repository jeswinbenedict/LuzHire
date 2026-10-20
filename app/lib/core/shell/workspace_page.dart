import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// Standard Workspace page: dense title row with actions, scrolling body.
class WorkspacePage extends StatelessWidget {
  const WorkspacePage({
    super.key,
    this.title,
    required this.children,
    this.actions = const [],
    this.subtitle,
    this.scroll = true,
  });

  /// Null when the shell's top bar already names the page.
  final String? title;
  final String? subtitle;
  final List<Widget> actions;
  final List<Widget> children;

  /// False for pages that manage their own scrolling (the kanban board).
  final bool scroll;

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    final t = context.luzText;
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(
        LuzSpace.lg,
        LuzSpace.lg,
        LuzSpace.lg,
        LuzSpace.md,
      ),
      child: Wrap(
        spacing: LuzSpace.md,
        runSpacing: LuzSpace.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (title != null)
                Semantics(header: true, child: Text(title!, style: t.wsTitle)),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: title == null
                      ? t.wsSection.copyWith(color: p.inkMuted)
                      : t.bodySm.copyWith(color: p.inkMuted),
                ),
            ],
          ),
          if (actions.isNotEmpty)
            Wrap(
              spacing: LuzSpace.sm,
              runSpacing: LuzSpace.sm,
              children: actions,
            ),
        ],
      ),
    );
    if (!scroll) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [header, ...children],
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: LuzSpace.xxl),
      children: [
        header,
        for (final c in children)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              LuzSpace.lg,
              0,
              LuzSpace.lg,
              LuzSpace.lg,
            ),
            child: c,
          ),
      ],
    );
  }
}
