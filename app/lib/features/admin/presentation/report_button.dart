import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/failures.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../../jobs/application/job_board_providers.dart'
    show currentUidProvider;
import '../application/admin_providers.dart';

/// "Report" link for a job, company or profile. Reports go to the admin
/// moderation queue.
class ReportButton extends ConsumerWidget {
  const ReportButton({
    super.key,
    required this.targetType,
    required this.targetId,
    required this.targetName,
  });

  final String targetType;
  final String targetId;
  final String targetName;

  @override
  Widget build(BuildContext context, WidgetRef ref) => LuzTextLink(
    label: 'Report',
    onPressed: () {
      if (ref.read(currentUidProvider) == null) {
        final from = GoRouterState.of(context).uri.toString();
        showLuzToast(
          context,
          'Sign in to report content.',
          icon: Icons.flag_outlined,
          actionLabel: 'Sign in',
          onAction: () => context.go(
            Uri(path: '/sign-in', queryParameters: {'from': from}).toString(),
          ),
        );
        return;
      }
      showLuzModal<void>(
        context: context,
        title: 'Report $targetName',
        builder: (_) =>
            _ReportForm(type: targetType, id: targetId, host: context),
      );
    },
  );
}

class _ReportForm extends ConsumerStatefulWidget {
  const _ReportForm({required this.type, required this.id, required this.host});
  final String type;
  final String id;
  final BuildContext host;

  @override
  ConsumerState<_ReportForm> createState() => _ReportFormState();
}

class _ReportFormState extends ConsumerState<_ReportForm> {
  final _reason = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_reason.text.trim().length < 3) {
      setState(() => _error = 'Tell us what is wrong');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(adminActionsProvider)
          .report(widget.type, widget.id, _reason.text);
      if (!mounted) return;
      Navigator.of(context).pop();
      if (widget.host.mounted) {
        showLuzToast(
          widget.host,
          'Thanks. Our team will review it.',
          icon: Icons.check,
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = mapDbError(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      LuzTextField(
        label: 'What is wrong?',
        hint: 'e.g. fake job, misleading salary, asks for payment',
        controller: _reason,
        error: _error,
        maxLines: 5,
        maxLength: 2000,
        autofocus: true,
      ),
      const SizedBox(height: LuzSpace.md),
      LuzButton.accent(
        label: _busy ? 'Sending…' : 'Send report',
        icon: Icons.flag_outlined,
        expand: true,
        onPressed: _busy ? null : _send,
      ),
    ],
  );
}
