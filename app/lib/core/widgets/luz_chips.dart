import 'package:flutter/material.dart';

import '../data/enums.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'luz_pressable.dart';
import 'luz_surface.dart';

export '../data/enums.dart' show ApplicationStage;

/// Filter chip: raised when off; sinks with an orange dot when selected
/// (DESIGN.md §2 rule 4: selection is never shown by relief alone).
class LuzFilterChip extends StatelessWidget {
  const LuzFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.icon,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    return LuzPressable(
      onPressed: onSelected == null ? null : () => onSelected!(!selected),
      radius: LuzRadius.pill,
      semanticLabel: label,
      selected: selected,
      builder: (context, pressed, _) => LuzSurface(
        depth: (selected || pressed) ? LuzDepth.insetSm : LuzDepth.raisedXs,
        radius: LuzRadius.pill,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: p.accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: LuzSpace.xs),
            ] else if (icon != null) ...[
              Icon(icon, size: 16, color: p.inkMuted),
              const SizedBox(width: LuzSpace.xs - 2),
            ],
            Text(
              label,
              style: context.luzText.label.copyWith(
                color: p.ink,
                fontWeight: selected ? FontWeight.w600 : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Visual identity of each pipeline stage (DESIGN.md §3): tone + icon.
extension ApplicationStageStyle on ApplicationStage {
  LuzChipTone get tone => switch (this) {
    ApplicationStage.applied ||
    ApplicationStage.withdrawn => LuzChipTone.neutral,
    ApplicationStage.underReview ||
    ApplicationStage.assessment ||
    ApplicationStage.technicalInterview ||
    ApplicationStage.hrInterview => LuzChipTone.blue,
    ApplicationStage.shortlisted ||
    ApplicationStage.finalReview => LuzChipTone.violet,
    ApplicationStage.offerIssued => LuzChipTone.orange,
    ApplicationStage.hired => LuzChipTone.green,
    ApplicationStage.rejected => LuzChipTone.red,
  };

  IconData get icon => switch (this) {
    ApplicationStage.applied => Icons.send_outlined,
    ApplicationStage.underReview => Icons.search,
    ApplicationStage.shortlisted => Icons.star_outline,
    ApplicationStage.assessment => Icons.assignment_outlined,
    ApplicationStage.technicalInterview ||
    ApplicationStage.hrInterview => Icons.event_outlined,
    ApplicationStage.finalReview => Icons.balance_outlined,
    ApplicationStage.offerIssued => Icons.mark_email_unread_outlined,
    ApplicationStage.hired => Icons.handshake_outlined,
    ApplicationStage.rejected => Icons.folder_off_outlined,
    ApplicationStage.withdrawn => Icons.logout,
  };
}

/// Inset status pill: colour + icon + text, never colour alone.
class LuzStatusChip extends StatelessWidget {
  const LuzStatusChip({
    super.key,
    required this.label,
    required this.tone,
    this.icon,
    this.strikethrough = false,
  });

  LuzStatusChip.stage(ApplicationStage stage, {super.key})
    : label = stage.label,
      tone = stage.tone,
      icon = stage.icon,
      strikethrough = stage == ApplicationStage.withdrawn;

  final String label;
  final LuzChipTone tone;
  final IconData? icon;
  final bool strikethrough;

  @override
  Widget build(BuildContext context) {
    final c = context.luz.chips[tone]!;
    return LuzSurface(
      depth: LuzDepth.insetSm,
      radius: LuzRadius.pill,
      color: c.background,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: c.foreground),
            const SizedBox(width: LuzSpace.xxs),
          ],
          Text(
            label,
            style: context.luzText.caption.copyWith(
              color: c.foreground,
              fontWeight: FontWeight.w600,
              decoration: strikethrough ? TextDecoration.lineThrough : null,
            ),
          ),
        ],
      ),
    );
  }
}
