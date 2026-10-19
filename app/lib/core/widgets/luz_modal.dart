import 'package:flutter/material.dart';

import '../layout/breakpoints.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'luz_button.dart';
import 'luz_surface.dart';

/// Adaptive modal: a bottom sheet on phones, a centred dialog elsewhere
/// (ROADMAP Phase 1 — adaptive dialogs).
Future<T?> showLuzModal<T>({
  required BuildContext context,
  required String title,
  required WidgetBuilder builder,
  List<Widget> Function(BuildContext context)? actions,
  bool forceSheet = false,
}) {
  final p = context.luz;
  final scrim = p.brightness == Brightness.dark ? 0.64 : 0.40;
  if (forceSheet || context.breakpoint.isCompact) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: p.ink.withValues(alpha: scrim),
      builder: (ctx) => LuzSheet(
        title: title,
        actions: actions?.call(ctx),
        child: builder(ctx),
      ),
    );
  }
  return showDialog<T>(
    context: context,
    barrierColor: p.ink.withValues(alpha: scrim),
    builder: (ctx) => LuzDialog(
      title: title,
      actions: actions?.call(ctx),
      child: builder(ctx),
    ),
  );
}

/// Confirmation helper (destructive actions use [danger]).
Future<bool> confirmLuz(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  IconData? icon,
}) async {
  final result = await showLuzModal<bool>(
    context: context,
    title: title,
    builder: (ctx) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Icon(icon, color: ctx.luz.danger, size: 28),
          const SizedBox(width: LuzSpace.md),
        ],
        Expanded(
          child: Text(
            message,
            style: ctx.luzText.body.copyWith(color: ctx.luz.inkMuted),
          ),
        ),
      ],
    ),
    actions: (ctx) => [
      LuzButton(label: 'Cancel', onPressed: () => Navigator.of(ctx).pop(false)),
      LuzButton.accent(
        label: confirmLabel,
        onPressed: () => Navigator.of(ctx).pop(true),
      ),
    ],
  );
  return result ?? false;
}

class LuzDialog extends StatelessWidget {
  const LuzDialog({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.maxWidth = 520,
  });

  final String title;
  final Widget child;
  final List<Widget>? actions;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(LuzSpace.lg),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: LuzSurface(
          depth: LuzDepth.raisedLg,
          radius: LuzRadius.xl,
          padding: const EdgeInsets.all(LuzSpace.lg),
          child: _ModalBody(title: title, actions: actions, child: child),
        ),
      ),
    );
  }
}

class LuzSheet extends StatelessWidget {
  const LuzSheet({
    super.key,
    required this.title,
    required this.child,
    this.actions,
  });

  final String title;
  final Widget child;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    return Padding(
      // Lift above the keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: p.base,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(LuzRadius.xxl),
          ),
          boxShadow: [
            BoxShadow(
              color: p.shade,
              blurRadius: 24,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(
          LuzSpace.lg,
          LuzSpace.sm,
          LuzSpace.lg,
          LuzSpace.lg,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: LuzSurface(
                  depth: LuzDepth.insetSm,
                  radius: LuzRadius.pill,
                  child: const SizedBox(width: 44, height: 6),
                ),
              ),
              const SizedBox(height: LuzSpace.md),
              Flexible(
                child: _ModalBody(title: title, actions: actions, child: child),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModalBody extends StatelessWidget {
  const _ModalBody({required this.title, required this.child, this.actions});
  final String title;
  final Widget child;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(header: true, child: Text(title, style: context.luzText.h4)),
        const SizedBox(height: LuzSpace.md),
        Flexible(child: SingleChildScrollView(child: child)),
        if (actions != null && actions!.isNotEmpty) ...[
          const SizedBox(height: LuzSpace.lg),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: LuzSpace.md,
            runSpacing: LuzSpace.md,
            children: actions!,
          ),
        ],
      ],
    );
  }
}
