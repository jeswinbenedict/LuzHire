import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/failures.dart';
import '../../../core/data/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../application/candidate_providers.dart';
import '../data/profile_repository.dart';
import 'profile_page.dart' show pickFile;

/// Opens the apply form for [job] (sheet on phones, dialog elsewhere).
Future<void> showApplySheet(BuildContext context, Job job) =>
    showLuzModal<void>(
      context: context,
      title: 'Apply: ${job.title}',
      builder: (_) => _ApplyForm(job: job, host: context),
    );

class _ApplyForm extends ConsumerStatefulWidget {
  const _ApplyForm({required this.job, required this.host});
  final Job job;

  /// The page that opened the sheet; the success toast is shown there.
  final BuildContext host;

  @override
  ConsumerState<_ApplyForm> createState() => _ApplyFormState();
}

class _ApplyFormState extends ConsumerState<_ApplyForm> {
  final _cover = TextEditingController();
  String? _resumeId;
  bool _chosen = false; // false until the user picks; defaults to primary
  bool _busy = false;
  bool _uploading = false;
  String? _error;

  static const coverLimit = 6000;

  @override
  void dispose() {
    _cover.dispose();
    super.dispose();
  }

  Future<void> _upload() async {
    setState(() => _uploading = true);
    try {
      final file = await pickFile(const [
        'pdf',
        'docx',
      ], maxBytes: ResumeRepository.maxBytes);
      if (file != null) {
        final r = await ref
            .read(candidateActionsProvider)
            .uploadResume(file.name, file.bytes);
        setState(() {
          _resumeId = r.id;
          _chosen = true;
        });
      }
    } catch (e) {
      setState(() => _error = mapDbError(e).message);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _submit(String? resumeId) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final app = await ref
          .read(candidateActionsProvider)
          .apply(
            jobId: widget.job.id,
            resumeId: resumeId,
            coverLetter: _cover.text,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      final host = widget.host;
      if (!host.mounted) return;
      final router = GoRouter.of(host);
      showLuzToast(
        host,
        'Application sent to ${widget.job.companyName}',
        icon: Icons.check_circle_outline,
        actionLabel: 'Track it',
        onAction: () => router.go('/me/applications/${app.id}'),
      );
    } catch (e) {
      setState(() => _error = mapDbError(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    final t = context.luzText;
    final resumes = ref.watch(myResumesProvider).value ?? const [];
    final primary = resumes.where((r) => r.isPrimary).firstOrNull;
    final selected = _chosen ? _resumeId : primary?.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${widget.job.companyName} will see your profile, the resume you '
          'choose and your cover letter.',
          style: t.body.copyWith(color: p.inkMuted),
        ),
        const SizedBox(height: LuzSpace.lg),
        Text('Resume', style: t.label),
        const SizedBox(height: LuzSpace.xs),
        for (final r in resumes)
          LuzRadio<String?>(
            label: r.isPrimary ? '${r.fileName} (primary)' : r.fileName,
            value: r.id,
            groupValue: selected,
            onChanged: (v) => setState(() {
              _resumeId = v;
              _chosen = true;
            }),
          ),
        LuzRadio<String?>(
          label: 'Apply without a resume',
          value: null,
          groupValue: selected,
          onChanged: (_) => setState(() {
            _resumeId = null;
            _chosen = true;
          }),
        ),
        const SizedBox(height: LuzSpace.xs),
        Align(
          alignment: Alignment.centerLeft,
          child: LuzButton(
            label: _uploading ? 'Uploading…' : 'Upload a resume',
            icon: Icons.upload_file,
            onPressed: _uploading ? null : _upload,
          ),
        ),
        const SizedBox(height: LuzSpace.lg),
        ValueListenableBuilder(
          valueListenable: _cover,
          builder: (context, value, _) => LuzTextField(
            label: 'Cover letter (optional)',
            hint: 'Why this role, and why you',
            controller: _cover,
            maxLines: 10,
            maxLength: coverLimit,
            helper: '${value.text.length} / $coverLimit',
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: LuzSpace.md),
          Semantics(
            liveRegion: true,
            child: Row(
              children: [
                Icon(Icons.error_outline, color: p.danger),
                const SizedBox(width: LuzSpace.xs),
                Expanded(
                  child: Text(_error!, style: t.body.copyWith(color: p.danger)),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: LuzSpace.lg),
        LuzButton.accent(
          label: _busy ? 'Sending…' : 'Send application',
          icon: Icons.send_outlined,
          expand: true,
          onPressed: _busy ? null : () => _submit(selected),
        ),
      ],
    );
  }
}
