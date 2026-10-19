import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/data/failures.dart';
import '../../../core/data/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../../jobs/application/job_board_providers.dart';
import '../application/candidate_providers.dart';
import '../data/profile_repository.dart';
import 'candidate_widgets.dart';

/// Picks one file with one of [extensions] and reads it, rejecting files over
/// [maxBytes] before reading. Null when the user cancels.
Future<({String name, Uint8List bytes})?> pickFile(
  List<String> extensions, {
  required int maxBytes,
}) async {
  final file = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: extensions,
  );
  if (file == null) return null;
  final size = file.lengthSync() ?? await file.length();
  if (size != null && size > maxBytes) {
    throw AppFailure(
      'That file is larger than ${maxBytes ~/ (1024 * 1024)} MB.',
    );
  }
  return (name: file.name, bytes: await file.readAsBytes());
}

/// /me/profile: profile builder with live completion (FR-03, FR-04).
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider);
    return AsyncBlock<Profile>(
      value: profile,
      onRetry: () => ref.invalidate(myProfileProvider),
      data: (p) => LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 1000;
          final left = [_StrengthCard(profile: p), _BasicsCard(profile: p)];
          final right = const [
            _ResumesCard(),
            _SkillsCard(),
            _ExperienceCard(),
            _EducationCard(),
          ];
          List<Widget> spaced(List<Widget> ws) => [
            for (final w in ws) ...[w, const SizedBox(height: LuzSpace.lg)],
          ];
          if (!wide) {
            return CandidatePage(children: spaced([...left, ...right]));
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: LuzSpace.xxl),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Column(children: spaced(left))),
                const SizedBox(width: LuzSpace.lg),
                Expanded(child: Column(children: spaced(right))),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------- strength

class _StrengthCard extends ConsumerWidget {
  const _StrengthCard({required this.profile});
  final Profile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.luz;
    final t = context.luzText;
    final skills = ref.watch(mySkillsProvider).value ?? const [];
    final resumes = ref.watch(myResumesProvider).value ?? const [];
    final edu = ref.watch(myEducationsProvider).value ?? const [];
    final exp = ref.watch(myExperiencesProvider).value ?? const [];
    // Same ten items as app.recompute_completion (10 % each).
    final missing = [
      if ((profile.headline ?? '').isEmpty) 'Add a headline',
      if ((profile.bio ?? '').isEmpty) 'Write a short bio',
      if ((profile.location ?? '').isEmpty) 'Add your location',
      if (profile.avatarPath == null) 'Upload a photo',
      if ((profile.phone ?? '').isEmpty) 'Add a phone number',
      if (profile.links.values.every((v) => v.trim().isEmpty)) 'Add a link',
      if (edu.isEmpty) 'Add education',
      if (exp.isEmpty) 'Add experience',
      if (skills.length < 3) 'Add ${3 - skills.length} more skills',
      if (!resumes.any((r) => r.isPrimary)) 'Upload a resume',
    ];

    return SectionCard(
      title: 'Profile strength',
      icon: Icons.verified_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LuzProgressGroove(
            value: profile.profileCompletion / 100,
            label: 'Profile strength',
          ),
          if (missing.isNotEmpty) ...[
            const SizedBox(height: LuzSpace.md),
            Text('Next steps', style: t.label.copyWith(color: p.inkMuted)),
            const SizedBox(height: LuzSpace.xs),
            Wrap(
              spacing: LuzSpace.xs,
              runSpacing: LuzSpace.xs,
              children: [
                for (final m in missing.take(4))
                  LuzStatusChip(
                    label: '$m (+10%)',
                    tone: LuzChipTone.orange,
                    icon: Icons.add,
                  ),
              ],
            ),
          ] else ...[
            const SizedBox(height: LuzSpace.sm),
            Text(
              'Your profile is complete. Employers see everything they need.',
              style: t.body.copyWith(color: p.inkMuted),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- basics

class _BasicsCard extends ConsumerStatefulWidget {
  const _BasicsCard({required this.profile});
  final Profile profile;

  @override
  ConsumerState<_BasicsCard> createState() => _BasicsCardState();
}

class _BasicsCardState extends ConsumerState<_BasicsCard> {
  late final _name = TextEditingController(text: widget.profile.displayName);
  late final _headline = TextEditingController(text: widget.profile.headline);
  late final _location = TextEditingController(text: widget.profile.location);
  late final _phone = TextEditingController(text: widget.profile.phone);
  late final _bio = TextEditingController(text: widget.profile.bio);
  late final _links = {
    for (final k in const ['linkedin', 'github', 'portfolio'])
      k: TextEditingController(text: widget.profile.links[k]),
  };
  bool _saving = false;
  String? _nameError;
  final _linkErrors = <String, String>{};

  @override
  void dispose() {
    for (final c in [
      _name,
      _headline,
      _location,
      _phone,
      _bio,
      ..._links.values,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  bool _validate() {
    setState(() {
      _nameError = _name.text.trim().isEmpty ? 'Enter your name' : null;
      _linkErrors.clear();
      for (final e in _links.entries) {
        final v = e.value.text.trim();
        if (v.isNotEmpty && !RegExp(r'^https?://\S+\.\S+').hasMatch(v)) {
          _linkErrors[e.key] = 'Start with https://';
        }
      }
    });
    return _nameError == null && _linkErrors.isEmpty;
  }

  Future<void> _save() async {
    if (!_validate()) return;
    setState(() => _saving = true);
    await runWithToast(
      context,
      () => ref
          .read(candidateActionsProvider)
          .saveBasics(
            displayName: _name.text,
            headline: _headline.text,
            bio: _bio.text,
            location: _location.text,
            phone: _phone.text,
            links: {for (final e in _links.entries) e.key: e.value.text},
          ),
      success: 'Profile saved',
    );
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: LuzSpace.md);
    return SectionCard(
      title: 'About you',
      icon: Icons.badge_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AvatarRow(profile: widget.profile),
          gap,
          LuzTextField(
            label: 'Full name',
            controller: _name,
            error: _nameError,
            maxLength: 120,
            autofillHints: const [AutofillHints.name],
          ),
          gap,
          LuzTextField(
            label: 'Headline',
            hint: 'e.g. Flutter developer · final-year B.Tech',
            controller: _headline,
            maxLength: 160,
          ),
          gap,
          LuzTextField(
            label: 'Location',
            hint: 'City, country',
            controller: _location,
            prefixIcon: Icons.place_outlined,
            maxLength: 120,
          ),
          gap,
          LuzTextField(
            label: 'Phone',
            controller: _phone,
            prefixIcon: Icons.call_outlined,
            keyboardType: TextInputType.phone,
            maxLength: 32,
            autofillHints: const [AutofillHints.telephoneNumber],
          ),
          gap,
          LuzTextField(
            label: 'Bio',
            hint: 'What you do, what you are looking for',
            controller: _bio,
            maxLines: 8,
            maxLength: 4000,
          ),
          gap,
          for (final e in _links.entries) ...[
            LuzTextField(
              label: switch (e.key) {
                'linkedin' => 'LinkedIn',
                'github' => 'GitHub',
                _ => 'Portfolio',
              },
              hint: 'https://',
              controller: e.value,
              prefixIcon: Icons.link,
              keyboardType: TextInputType.url,
              error: _linkErrors[e.key],
            ),
            gap,
          ],
          Align(
            alignment: Alignment.centerRight,
            child: LuzButton.accent(
              label: _saving ? 'Saving…' : 'Save profile',
              icon: Icons.check,
              onPressed: _saving ? null : _save,
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarRow extends ConsumerStatefulWidget {
  const _AvatarRow({required this.profile});
  final Profile profile;

  @override
  ConsumerState<_AvatarRow> createState() => _AvatarRowState();
}

class _AvatarRowState extends ConsumerState<_AvatarRow> {
  bool _busy = false;

  Future<void> _upload() async {
    setState(() => _busy = true);
    await runWithToast(context, () async {
      final file = await pickFile(const [
        'png',
        'jpg',
        'jpeg',
        'webp',
      ], maxBytes: 2 * 1024 * 1024);
      if (file == null) return;
      await ref
          .read(candidateActionsProvider)
          .uploadAvatar(file.name, file.bytes);
    });
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final path = widget.profile.avatarPath;
    String? url;
    if (path != null) {
      try {
        url = ref.read(profileRepositoryProvider).avatarUrl(path);
      } on AppFailure {
        url = null;
      }
    }
    return Row(
      children: [
        LuzAvatar(name: widget.profile.displayName, imageUrl: url, size: 64),
        const SizedBox(width: LuzSpace.md),
        LuzButton(
          label: _busy
              ? 'Uploading…'
              : path == null
              ? 'Upload photo'
              : 'Change photo',
          icon: Icons.photo_camera_outlined,
          onPressed: _busy ? null : _upload,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- resumes

class _ResumesCard extends ConsumerStatefulWidget {
  const _ResumesCard();

  @override
  ConsumerState<_ResumesCard> createState() => _ResumesCardState();
}

class _ResumesCardState extends ConsumerState<_ResumesCard> {
  bool _uploading = false;

  Future<void> _upload() async {
    setState(() => _uploading = true);
    await runWithToast(context, () async {
      final file = await pickFile(const [
        'pdf',
        'docx',
      ], maxBytes: ResumeRepository.maxBytes);
      if (file == null) return;
      await ref
          .read(candidateActionsProvider)
          .uploadResume(file.name, file.bytes);
    }, success: null);
    if (mounted) setState(() => _uploading = false);
  }

  @override
  Widget build(BuildContext context) {
    final resumes = ref.watch(myResumesProvider);
    final p = context.luz;
    final t = context.luzText;
    return SectionCard(
      title: 'Resumes',
      icon: Icons.description_outlined,
      action: LuzButton(
        label: _uploading ? 'Uploading…' : 'Upload',
        icon: Icons.upload_file,
        onPressed: _uploading ? null : _upload,
      ),
      child: AsyncBlock<List<Resume>>(
        value: resumes,
        onRetry: () => ref.invalidate(myResumesProvider),
        data: (list) => list.isEmpty
            ? Text(
                'PDF or Word (.docx), up to 5 MB. Your primary resume is '
                'attached when you apply.',
                style: t.body.copyWith(color: p.inkMuted),
              )
            : Column(children: [for (final r in list) _ResumeRow(resume: r)]),
      ),
    );
  }
}

class _ResumeRow extends ConsumerWidget {
  const _ResumeRow({required this.resume});
  final Resume resume;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.luz;
    final t = context.luzText;
    final actions = ref.read(candidateActionsProvider);
    return Padding(
      padding: const EdgeInsets.only(bottom: LuzSpace.sm),
      child: Row(
        children: [
          Icon(Icons.insert_drive_file_outlined, color: p.inkMuted),
          const SizedBox(width: LuzSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  resume.fileName,
                  style: t.label,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Uploaded ${formatDay(resume.createdAt)}',
                  style: t.caption.copyWith(color: p.muted),
                ),
              ],
            ),
          ),
          if (resume.isPrimary)
            const LuzStatusChip(
              label: 'Primary',
              tone: LuzChipTone.green,
              icon: Icons.star,
            )
          else
            LuzTextLink(
              label: 'Make primary',
              onPressed: () => runWithToast(
                context,
                () => actions.setPrimaryResume(resume.id),
              ),
            ),
          const SizedBox(width: LuzSpace.xs),
          LuzIconButton(
            icon: Icons.open_in_new,
            tooltip: 'View ${resume.fileName}',
            size: 36,
            onPressed: () => runWithToast(context, () async {
              final url = await ref
                  .read(resumeRepositoryProvider)
                  .signedUrl(resume.storagePath);
              await launchUrl(Uri.parse(url));
            }),
          ),
          LuzIconButton(
            icon: Icons.delete_outline,
            tooltip: 'Delete ${resume.fileName}',
            size: 36,
            onPressed: () async {
              final ok = await confirmLuz(
                context,
                title: 'Delete resume?',
                message:
                    '${resume.fileName} will be removed. Applications you '
                    'already sent are not affected.',
                confirmLabel: 'Delete',
                icon: Icons.delete_outline,
              );
              if (ok && context.mounted) {
                await runWithToast(
                  context,
                  () => actions.deleteResume(resume),
                  success: 'Resume deleted',
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- skills

class _SkillsCard extends ConsumerStatefulWidget {
  const _SkillsCard();

  @override
  ConsumerState<_SkillsCard> createState() => _SkillsCardState();
}

class _SkillsCardState extends ConsumerState<_SkillsCard> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _add(String name) async {
    if (name.trim().isEmpty) return;
    final ok = await runWithToast(
      context,
      () => ref.read(candidateActionsProvider).addSkill(name),
    );
    if (ok) _input.clear();
  }

  @override
  Widget build(BuildContext context) {
    final mine = ref.watch(mySkillsProvider);
    final all = ref.watch(skillsProvider).value ?? const [];
    final p = context.luz;
    final t = context.luzText;
    return SectionCard(
      title: 'Skills',
      icon: Icons.bolt_outlined,
      child: AsyncBlock<List<({int id, String name})>>(
        value: mine,
        onRetry: () => ref.invalidate(mySkillsProvider),
        data: (skills) {
          final have = {for (final s in skills) s.name.toLowerCase()};
          final suggestions = all
              .where((s) => !have.contains(s.name.toLowerCase()))
              .take(8);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (skills.isEmpty)
                Text(
                  'Add at least three skills so employers can find you.',
                  style: t.body.copyWith(color: p.inkMuted),
                )
              else
                Wrap(
                  spacing: LuzSpace.xs,
                  runSpacing: LuzSpace.xs,
                  children: [
                    for (final s in skills)
                      InputChip(
                        label: Text(s.name),
                        onDeleted: () => runWithToast(
                          context,
                          () => ref
                              .read(candidateActionsProvider)
                              .removeSkill(s.id),
                        ),
                        deleteButtonTooltipMessage: 'Remove ${s.name}',
                      ),
                  ],
                ),
              const SizedBox(height: LuzSpace.md),
              LuzTextField(
                label: 'Add a skill',
                hint: 'e.g. Flutter, SQL, Figma',
                controller: _input,
                maxLength: 60,
                textInputAction: TextInputAction.done,
                onSubmitted: _add,
                suffix: LuzIconButton(
                  icon: Icons.add,
                  tooltip: 'Add skill',
                  size: 36,
                  onPressed: () => _add(_input.text),
                ),
              ),
              if (suggestions.isNotEmpty) ...[
                const SizedBox(height: LuzSpace.sm),
                Wrap(
                  spacing: LuzSpace.xs,
                  runSpacing: LuzSpace.xs,
                  children: [
                    for (final s in suggestions)
                      LuzFilterChip(
                        label: s.name,
                        icon: Icons.add,
                        selected: false,
                        onSelected: (_) => _add(s.name),
                      ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------- experience / education

String _range(DateTime? start, DateTime? end, {String open = 'Present'}) {
  String m(DateTime d) => '${_months[d.month - 1]} ${d.year}';
  if (start == null && end == null) return '';
  return '${start == null ? '' : m(start)} – ${end == null ? open : m(end)}';
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

class _ExperienceCard extends ConsumerWidget {
  const _ExperienceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(myExperiencesProvider);
    return SectionCard(
      title: 'Experience',
      icon: Icons.work_outline,
      action: LuzButton(
        label: 'Add',
        icon: Icons.add,
        onPressed: () => _editExperience(context, ref, null),
      ),
      child: AsyncBlock<List<Experience>>(
        value: list,
        onRetry: () => ref.invalidate(myExperiencesProvider),
        data: (items) => items.isEmpty
            ? const _Hint('Internships and projects count too.')
            : Column(
                children: [
                  for (final e in items)
                    _TimelineRow(
                      title: e.title,
                      subtitle: e.company,
                      dates: _range(e.startDate, e.endDate),
                      body: e.description,
                      onEdit: () => _editExperience(context, ref, e),
                      onDelete: () => runWithToast(
                        context,
                        () => ref
                            .read(candidateActionsProvider)
                            .deleteExperience(e.id),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _EducationCard extends ConsumerWidget {
  const _EducationCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(myEducationsProvider);
    return SectionCard(
      title: 'Education',
      icon: Icons.school_outlined,
      action: LuzButton(
        label: 'Add',
        icon: Icons.add,
        onPressed: () => _editEducation(context, ref, null),
      ),
      child: AsyncBlock<List<Education>>(
        value: list,
        onRetry: () => ref.invalidate(myEducationsProvider),
        data: (items) => items.isEmpty
            ? const _Hint('Add your degree or current course.')
            : Column(
                children: [
                  for (final e in items)
                    _TimelineRow(
                      title: e.institution,
                      subtitle: [
                        e.degree,
                        e.field,
                      ].whereType<String>().join(', '),
                      dates: _range(e.startDate, e.endDate, open: 'Ongoing'),
                      body: e.grade == null ? null : 'Grade: ${e.grade}',
                      onEdit: () => _editEducation(context, ref, e),
                      onDelete: () => runWithToast(
                        context,
                        () => ref
                            .read(candidateActionsProvider)
                            .deleteEducation(e.id),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: context.luzText.body.copyWith(color: context.luz.inkMuted),
  );
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.title,
    required this.subtitle,
    required this.dates,
    required this.onEdit,
    required this.onDelete,
    this.body,
  });

  final String title;
  final String subtitle;
  final String dates;
  final String? body;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    final t = context.luzText;
    return Padding(
      padding: const EdgeInsets.only(bottom: LuzSpace.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t.label),
                if (subtitle.isNotEmpty)
                  Text(subtitle, style: t.body.copyWith(color: p.inkMuted)),
                if (dates.isNotEmpty)
                  Text(dates, style: t.caption.copyWith(color: p.muted)),
                if ((body ?? '').isNotEmpty) ...[
                  const SizedBox(height: LuzSpace.xxs),
                  Text(body!, style: t.bodySm),
                ],
              ],
            ),
          ),
          LuzIconButton(
            icon: Icons.edit_outlined,
            tooltip: 'Edit $title',
            size: 36,
            onPressed: onEdit,
          ),
          LuzIconButton(
            icon: Icons.delete_outline,
            tooltip: 'Delete $title',
            size: 36,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- edit forms

Future<void> _editExperience(
  BuildContext context,
  WidgetRef ref,
  Experience? existing,
) => showLuzModal<void>(
  context: context,
  title: existing == null ? 'Add experience' : 'Edit experience',
  builder: (ctx) => _ExperienceForm(
    existing: existing,
    onSave: (e) async {
      final ok = await runWithToast(
        ctx,
        () => ref.read(candidateActionsProvider).saveExperience(e),
      );
      if (ok && ctx.mounted) Navigator.of(ctx).pop();
    },
  ),
);

Future<void> _editEducation(
  BuildContext context,
  WidgetRef ref,
  Education? existing,
) => showLuzModal<void>(
  context: context,
  title: existing == null ? 'Add education' : 'Edit education',
  builder: (ctx) => _EducationForm(
    existing: existing,
    onSave: (e) async {
      final ok = await runWithToast(
        ctx,
        () => ref.read(candidateActionsProvider).saveEducation(e),
      );
      if (ok && ctx.mounted) Navigator.of(ctx).pop();
    },
  ),
);

/// "2024-06" ⇄ DateTime(2024, 6) for month fields.
DateTime? _parseMonth(String v) {
  final m = RegExp(r'^(\d{4})-(\d{1,2})$').firstMatch(v.trim());
  if (m == null) return null;
  final month = int.parse(m.group(2)!);
  if (month < 1 || month > 12) return null;
  return DateTime(int.parse(m.group(1)!), month);
}

String _month(DateTime? d) =>
    d == null ? '' : '${d.year}-${d.month.toString().padLeft(2, '0')}';

String? _monthError(String v) =>
    v.trim().isEmpty || _parseMonth(v) != null ? null : 'Use YYYY-MM';

class _ExperienceForm extends StatefulWidget {
  const _ExperienceForm({required this.existing, required this.onSave});
  final Experience? existing;
  final Future<void> Function(Experience) onSave;

  @override
  State<_ExperienceForm> createState() => _ExperienceFormState();
}

class _ExperienceFormState extends State<_ExperienceForm> {
  late final _title = TextEditingController(text: widget.existing?.title);
  late final _company = TextEditingController(text: widget.existing?.company);
  late final _start = TextEditingController(
    text: _month(widget.existing?.startDate),
  );
  late final _end = TextEditingController(
    text: _month(widget.existing?.endDate),
  );
  late final _desc = TextEditingController(text: widget.existing?.description);
  final _errors = <String, String?>{};
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_title, _company, _start, _end, _desc]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final start = _parseMonth(_start.text);
    final end = _parseMonth(_end.text);
    setState(() {
      _errors
        ..['title'] = _title.text.trim().isEmpty ? 'Required' : null
        ..['company'] = _company.text.trim().isEmpty ? 'Required' : null
        ..['start'] = _monthError(_start.text)
        ..['end'] =
            _monthError(_end.text) ??
            (start != null && end != null && end.isBefore(start)
                ? 'Ends before it starts'
                : null);
    });
    if (_errors.values.any((e) => e != null)) return;
    setState(() => _busy = true);
    await widget.onSave(
      Experience(
        id: widget.existing?.id ?? '',
        title: _title.text,
        company: _company.text,
        startDate: start,
        endDate: end,
        description: _desc.text,
      ),
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: LuzSpace.md);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        LuzTextField(
          label: 'Job title',
          controller: _title,
          error: _errors['title'],
          autofocus: true,
        ),
        gap,
        LuzTextField(
          label: 'Company',
          controller: _company,
          error: _errors['company'],
        ),
        gap,
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: LuzTextField(
                label: 'Start (YYYY-MM)',
                hint: '2024-06',
                controller: _start,
                error: _errors['start'],
              ),
            ),
            const SizedBox(width: LuzSpace.sm),
            Expanded(
              child: LuzTextField(
                label: 'End (empty if current)',
                hint: '2025-01',
                controller: _end,
                error: _errors['end'],
              ),
            ),
          ],
        ),
        gap,
        LuzTextField(
          label: 'What you did (optional)',
          controller: _desc,
          maxLines: 6,
          maxLength: 4000,
        ),
        gap,
        LuzButton.accent(
          label: _busy ? 'Saving…' : 'Save',
          onPressed: _busy ? null : _submit,
          expand: true,
        ),
      ],
    );
  }
}

class _EducationForm extends StatefulWidget {
  const _EducationForm({required this.existing, required this.onSave});
  final Education? existing;
  final Future<void> Function(Education) onSave;

  @override
  State<_EducationForm> createState() => _EducationFormState();
}

class _EducationFormState extends State<_EducationForm> {
  late final _school = TextEditingController(
    text: widget.existing?.institution,
  );
  late final _degree = TextEditingController(text: widget.existing?.degree);
  late final _field = TextEditingController(text: widget.existing?.field);
  late final _start = TextEditingController(
    text: _month(widget.existing?.startDate),
  );
  late final _end = TextEditingController(
    text: _month(widget.existing?.endDate),
  );
  late final _grade = TextEditingController(text: widget.existing?.grade);
  final _errors = <String, String?>{};
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_school, _degree, _field, _start, _end, _grade]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final start = _parseMonth(_start.text);
    final end = _parseMonth(_end.text);
    setState(() {
      _errors
        ..['school'] = _school.text.trim().isEmpty ? 'Required' : null
        ..['start'] = _monthError(_start.text)
        ..['end'] =
            _monthError(_end.text) ??
            (start != null && end != null && end.isBefore(start)
                ? 'Ends before it starts'
                : null);
    });
    if (_errors.values.any((e) => e != null)) return;
    setState(() => _busy = true);
    await widget.onSave(
      Education(
        id: widget.existing?.id ?? '',
        institution: _school.text,
        degree: _degree.text,
        field: _field.text,
        startDate: start,
        endDate: end,
        grade: _grade.text,
      ),
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: LuzSpace.md);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        LuzTextField(
          label: 'School or university',
          controller: _school,
          error: _errors['school'],
          autofocus: true,
        ),
        gap,
        LuzTextField(label: 'Degree', hint: 'e.g. B.Tech', controller: _degree),
        gap,
        LuzTextField(
          label: 'Field of study',
          hint: 'e.g. Computer Science',
          controller: _field,
        ),
        gap,
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: LuzTextField(
                label: 'Start (YYYY-MM)',
                controller: _start,
                error: _errors['start'],
              ),
            ),
            const SizedBox(width: LuzSpace.sm),
            Expanded(
              child: LuzTextField(
                label: 'End (YYYY-MM)',
                controller: _end,
                error: _errors['end'],
              ),
            ),
          ],
        ),
        gap,
        LuzTextField(label: 'Grade (optional)', controller: _grade),
        gap,
        LuzButton.accent(
          label: _busy ? 'Saving…' : 'Save',
          onPressed: _busy ? null : _submit,
          expand: true,
        ),
      ],
    );
  }
}
