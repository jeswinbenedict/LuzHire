import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/enums.dart';
import '../../../core/data/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../../candidate/presentation/profile_page.dart' show pickFile;
import '../application/employer_providers.dart';
import 'employer_common.dart';

String _two(int v) => v.toString().padLeft(2, '0');
String _day(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

/// "2026-10-21" → DateTime (local), or null.
DateTime? parseDay(String v) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(v.trim());
  if (m == null) return null;
  final d = DateTime(
    int.parse(m.group(1)!),
    int.parse(m.group(2)!),
    int.parse(m.group(3)!),
  );
  return _day(d) == v.trim() ? d : null; // rejects 2026-02-31
}

/// "14:30" → (14, 30), or null.
(int, int)? parseTime(String v) {
  final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(v.trim());
  if (m == null) return null;
  final h = int.parse(m.group(1)!), min = int.parse(m.group(2)!);
  return h < 24 && min < 60 ? (h, min) : null;
}

Future<void> showScheduleInterview(
  BuildContext context, {
  required JobApplication application,
  required String candidateName,
}) => showLuzModal<void>(
  context: context,
  title: 'Schedule interview with $candidateName',
  builder: (_) => _ScheduleForm(application: application),
);

class _ScheduleForm extends ConsumerStatefulWidget {
  const _ScheduleForm({required this.application});
  final JobApplication application;

  @override
  ConsumerState<_ScheduleForm> createState() => _ScheduleFormState();
}

class _ScheduleFormState extends ConsumerState<_ScheduleForm> {
  late final _date = TextEditingController(
    text: _day(DateTime.now().add(const Duration(days: 1))),
  );
  final _time = TextEditingController(text: '10:00');
  final _url = TextEditingController();
  final _location = TextEditingController();
  final _notes = TextEditingController();
  InterviewMode _mode = InterviewMode.video;
  int _duration = 45;
  final _errors = <String, String?>{};
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_date, _time, _url, _location, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final day = parseDay(_date.text);
    final time = parseTime(_time.text);
    final at = day == null || time == null
        ? null
        : DateTime(day.year, day.month, day.day, time.$1, time.$2);
    setState(() {
      _errors
        ..['date'] = day == null ? 'Use YYYY-MM-DD' : null
        ..['time'] = time == null ? 'Use HH:MM (24-hour)' : null
        ..['url'] =
            _mode == InterviewMode.video &&
                !RegExp(r'^https?://\S+').hasMatch(_url.text.trim())
            ? 'Add the meeting link (https://…)'
            : null
        ..['location'] =
            _mode == InterviewMode.onsite && _location.text.trim().isEmpty
            ? 'Add the address'
            : null;
      if (at != null && at.isBefore(DateTime.now())) {
        _errors['date'] = 'Pick a time in the future';
      }
    });
    if (_errors.values.any((e) => e != null) || at == null) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(employerActionsProvider)
          .scheduleInterview(
            applicationId: widget.application.id,
            at: at,
            durationMin: _duration,
            mode: _mode,
            meetingUrl: _url.text,
            location: _location.text,
            notes: _notes.text,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _errors['form'] = messageOf(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.luzText;
    const gap = SizedBox(height: LuzSpace.md);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: LuzTextField(
                label: 'Date (YYYY-MM-DD)',
                controller: _date,
                error: _errors['date'],
              ),
            ),
            const SizedBox(width: LuzSpace.sm),
            Expanded(
              child: LuzTextField(
                label: 'Time (your timezone)',
                controller: _time,
                error: _errors['time'],
              ),
            ),
          ],
        ),
        gap,
        Text('Length', style: t.label),
        const SizedBox(height: LuzSpace.xs),
        LuzSegmented<int>(
          segments: [
            for (final m in const [30, 45, 60, 90])
              (value: m, label: '$m min', icon: null),
          ],
          selected: _duration,
          onChanged: (m) => setState(() => _duration = m),
        ),
        gap,
        Text('Format', style: t.label),
        const SizedBox(height: LuzSpace.xs),
        LuzSegmented<InterviewMode>(
          segments: [
            for (final m in InterviewMode.values)
              (value: m, label: m.label, icon: m.icon),
          ],
          selected: _mode,
          onChanged: (m) => setState(() => _mode = m),
        ),
        gap,
        if (_mode == InterviewMode.video)
          LuzTextField(
            label: 'Meeting link',
            hint: 'https://meet.google.com/…',
            controller: _url,
            error: _errors['url'],
            keyboardType: TextInputType.url,
          )
        else if (_mode == InterviewMode.onsite)
          LuzTextField(
            label: 'Address',
            controller: _location,
            error: _errors['location'],
          )
        else
          LuzTextField(
            label: 'Phone details (optional)',
            controller: _location,
          ),
        gap,
        LuzTextField(
          label: 'Private notes for the team (optional)',
          controller: _notes,
          maxLines: 4,
          helper: 'Candidates never see these.',
        ),
        if (_errors['form'] != null) ...[
          gap,
          Text(
            _errors['form']!,
            style: t.body.copyWith(color: context.luz.danger),
          ),
        ],
        gap,
        LuzButton.accent(
          label: _busy ? 'Scheduling…' : 'Schedule interview',
          icon: Icons.event_available_outlined,
          expand: true,
          onPressed: _busy ? null : _submit,
        ),
      ],
    );
  }
}

Future<void> showMakeOffer(
  BuildContext context, {
  required JobApplication application,
  required String candidateName,
}) => showLuzModal<void>(
  context: context,
  title: 'Make an offer to $candidateName',
  builder: (_) => _OfferForm(application: application),
);

class _OfferForm extends ConsumerStatefulWidget {
  const _OfferForm({required this.application});
  final JobApplication application;

  @override
  ConsumerState<_OfferForm> createState() => _OfferFormState();
}

class _OfferFormState extends ConsumerState<_OfferForm> {
  final _salary = TextEditingController();
  final _currency = TextEditingController(text: 'INR');
  final _start = TextEditingController();
  late final _expires = TextEditingController(
    text: _day(DateTime.now().add(const Duration(days: 7))),
  );
  SalaryPeriod _period = SalaryPeriod.year;
  ({String name, Uint8List bytes})? _letter;
  final _errors = <String, String?>{};
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_salary, _currency, _start, _expires]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _attach() async {
    try {
      final f = await pickFile(const ['pdf'], maxBytes: 5 * 1024 * 1024);
      if (f != null) setState(() => _letter = f);
    } catch (e) {
      setState(() => _errors['form'] = messageOf(e));
    }
  }

  Future<void> _submit() async {
    final salary = double.tryParse(_salary.text.replaceAll(',', '').trim());
    final start = _start.text.trim().isEmpty ? null : parseDay(_start.text);
    final expires = _expires.text.trim().isEmpty
        ? null
        : parseDay(_expires.text);
    final currency = _currency.text.trim().toUpperCase();
    setState(() {
      _errors
        ..['salary'] = salary == null || salary <= 0 ? 'Enter the amount' : null
        ..['currency'] = RegExp(r'^[A-Z]{3}$').hasMatch(currency)
            ? null
            : '3-letter code, e.g. INR'
        ..['start'] = _start.text.trim().isNotEmpty && start == null
            ? 'Use YYYY-MM-DD'
            : null
        ..['expires'] = _expires.text.trim().isNotEmpty && expires == null
            ? 'Use YYYY-MM-DD'
            : null
        ..['form'] = null;
    });
    if (_errors.values.any((e) => e != null)) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(employerActionsProvider)
          .makeOffer(
            applicationId: widget.application.id,
            salary: salary!,
            currency: currency,
            period: _period,
            startDate: start,
            // Replies are accepted until the end of that day.
            expiresAt: expires?.add(const Duration(hours: 23, minutes: 59)),
            letter: _letter,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _errors['form'] = messageOf(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.luzText;
    const gap = SizedBox(height: LuzSpace.md);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: LuzTextField(
                label: 'Salary',
                hint: 'e.g. 1800000',
                controller: _salary,
                error: _errors['salary'],
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: LuzSpace.sm),
            Expanded(
              child: LuzTextField(
                label: 'Currency',
                controller: _currency,
                error: _errors['currency'],
                maxLength: 3,
              ),
            ),
          ],
        ),
        const SizedBox(height: LuzSpace.sm),
        LuzSegmented<SalaryPeriod>(
          segments: [
            for (final s in SalaryPeriod.values)
              (value: s, label: 'per ${s.label}', icon: null),
          ],
          selected: _period,
          onChanged: (s) => setState(() => _period = s),
        ),
        gap,
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: LuzTextField(
                label: 'Start date (optional)',
                hint: 'YYYY-MM-DD',
                controller: _start,
                error: _errors['start'],
              ),
            ),
            const SizedBox(width: LuzSpace.sm),
            Expanded(
              child: LuzTextField(
                label: 'Reply by',
                controller: _expires,
                error: _errors['expires'],
              ),
            ),
          ],
        ),
        gap,
        Row(
          children: [
            LuzButton(
              label: _letter == null
                  ? 'Attach offer letter (PDF)'
                  : 'Replace letter',
              icon: Icons.attach_file,
              onPressed: _attach,
            ),
            const SizedBox(width: LuzSpace.sm),
            if (_letter != null)
              Expanded(
                child: Text(
                  _letter!.name,
                  style: t.bodySm,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
        if (_errors['form'] != null) ...[
          gap,
          Text(
            _errors['form']!,
            style: t.body.copyWith(color: context.luz.danger),
          ),
        ],
        gap,
        Text(
          'The candidate is notified at once and can accept or decline in '
          'their portal.',
          style: t.caption.copyWith(color: context.luz.muted),
        ),
        const SizedBox(height: LuzSpace.sm),
        LuzButton.accent(
          label: _busy ? 'Sending…' : 'Send offer',
          icon: Icons.mark_email_unread_outlined,
          expand: true,
          onPressed: _busy ? null : _submit,
        ),
      ],
    );
  }
}
