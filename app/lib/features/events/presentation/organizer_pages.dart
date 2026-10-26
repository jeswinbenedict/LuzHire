import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/data/enums.dart';
import '../../../core/data/models.dart';
import '../../../core/shell/workspace_page.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../../candidate/presentation/candidate_widgets.dart'
    show AsyncBlock, runWithToast;
import '../../employer/presentation/employer_common.dart' show MembershipGate;
import '../application/events_providers.dart';
import '../data/events_repository.dart';
import 'events_pages.dart' show formatEventWhen;

final _stampFormat = DateFormat('yyyy-MM-dd HH:mm');
String _stamp(DateTime? d) => d == null ? '' : _stampFormat.format(d.toLocal());

/// "2026-10-24 10:00" (local time) → DateTime; null when empty or invalid.
DateTime? _parse(String s) {
  final v = s.trim();
  if (v.isEmpty) return null;
  return DateTime.tryParse(v.length == 10 ? '$v 00:00' : v);
}

// ---------------------------------------------------------------- employer

/// /employer/events: the company's drives, challenges and contests.
class EmployerEventsPage extends ConsumerWidget {
  const EmployerEventsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MembershipGate(
    builder: (context, m) {
      final list = ref.watch(companyOpportunitiesProvider(m.company.id));
      return WorkspacePage(
        subtitle: '${m.company.name}: hiring drives, challenges and contests',
        actions: [
          if (m.role.canEdit)
            LuzButton.accent(
              label: 'New event',
              icon: Icons.add,
              onPressed: () => context.go('/employer/events/new'),
            ),
        ],
        children: [
          AsyncBlock<List<Opportunity>>(
            value: list,
            onRetry: () =>
                ref.invalidate(companyOpportunitiesProvider(m.company.id)),
            data: (items) => items.isEmpty
                ? LuzEmptyState(
                    icon: Icons.event_outlined,
                    title: 'No events yet',
                    message:
                        'Run a walk-in drive, a campus drive or a hiring '
                        'challenge. Candidates register on LuzHire.',
                    actionLabel: m.role.canEdit ? 'New event' : null,
                    onAction: m.role.canEdit
                        ? () => context.go('/employer/events/new')
                        : null,
                  )
                : Column(
                    children: [
                      for (final e in items) ...[
                        OrganizerEventRow(
                          event: e,
                          canEdit: m.role.canEdit,
                          editPath: '/employer/events/${e.id}',
                        ),
                        const SizedBox(height: LuzSpace.md),
                      ],
                    ],
                  ),
          ),
        ],
      );
    },
  );
}

/// One event in an organiser's list, with its actions.
class OrganizerEventRow extends ConsumerWidget {
  const OrganizerEventRow({
    super.key,
    required this.event,
    required this.canEdit,
    required this.editPath,
    this.review = false,
  });
  final Opportunity event;
  final bool canEdit;
  final String editPath;

  /// Admins: publish or reject an event waiting for review.
  final bool review;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.luzText;
    final p = context.luz;
    final e = event;
    final actions = ref.read(eventActionsProvider);
    final tone = switch (e.status) {
      EventStatus.published => LuzChipTone.green,
      EventStatus.pendingReview => LuzChipTone.orange,
      EventStatus.rejected || EventStatus.cancelled => LuzChipTone.red,
      EventStatus.draft => LuzChipTone.neutral,
    };
    return LuzCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: LuzSpace.xs,
            runSpacing: LuzSpace.xxs,
            children: [
              LuzStatusChip(label: e.status.label, tone: tone),
              LuzStatusChip(
                label: e.kind.label,
                tone: LuzChipTone.blue,
                icon: e.kind.icon,
              ),
              LuzStatusChip(
                label: e.mode.label,
                tone: LuzChipTone.neutral,
                icon: e.mode.icon,
              ),
            ],
          ),
          const SizedBox(height: LuzSpace.xs),
          Text(e.title, style: t.wsSection),
          Text(
            '${formatEventWhen(e)} · ${e.organizerName}',
            style: t.bodySm.copyWith(color: p.inkMuted),
          ),
          Text(
            e.registersInApp
                ? '${e.registrationCount}'
                      '${e.capacity == null ? '' : ' of ${e.capacity}'} '
                      'registered'
                : 'Registration on ${Uri.parse(e.registrationUrl!).host}',
            style: t.caption.copyWith(color: p.muted),
          ),
          const SizedBox(height: LuzSpace.xs),
          Wrap(
            spacing: LuzSpace.md,
            runSpacing: LuzSpace.xxs,
            children: [
              LuzTextLink(
                label: 'View',
                onPressed: () => context.go('/events/${e.slug}'),
              ),
              if (e.registersInApp)
                LuzTextLink(
                  label: 'Registrations',
                  onPressed: () => showLuzModal<void>(
                    context: context,
                    title: 'Registrations: ${e.title}',
                    builder: (_) => _Registrants(event: e),
                  ),
                ),
              if (canEdit) ...[
                LuzTextLink(
                  label: 'Edit',
                  onPressed: () => context.go(editPath),
                ),
                if (review && e.status == EventStatus.pendingReview) ...[
                  LuzTextLink(
                    label: 'Publish',
                    onPressed: () => runWithToast(
                      context,
                      () => actions.setStatus(e.id, EventStatus.published),
                      success: 'Published',
                    ),
                  ),
                  LuzTextLink(
                    label: 'Reject',
                    onPressed: () => runWithToast(
                      context,
                      () => actions.setStatus(e.id, EventStatus.rejected),
                      success: 'Rejected',
                    ),
                  ),
                ],
                if (e.status == EventStatus.published)
                  LuzTextLink(
                    label: 'Cancel event',
                    onPressed: () async {
                      final ok = await confirmLuz(
                        context,
                        title: 'Cancel "${e.title}"?',
                        message:
                            'It disappears from LuzHire. Tell the people who '
                            'registered yourself.',
                        confirmLabel: 'Cancel event',
                        icon: Icons.event_busy_outlined,
                      );
                      if (ok && context.mounted) {
                        await runWithToast(
                          context,
                          () => actions.setStatus(e.id, EventStatus.cancelled),
                          success: 'Event cancelled',
                        );
                      }
                    },
                  ),
                if (e.status == EventStatus.draft || review)
                  LuzTextLink(
                    label: 'Delete',
                    onPressed: () async {
                      final ok = await confirmLuz(
                        context,
                        title: 'Delete "${e.title}"?',
                        message: 'This cannot be undone.',
                        confirmLabel: 'Delete',
                        icon: Icons.delete_outline,
                      );
                      if (ok && context.mounted) {
                        await runWithToast(
                          context,
                          () => actions.delete(e.id),
                          success: 'Deleted',
                        );
                      }
                    },
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Registrants extends ConsumerWidget {
  const _Registrants({required this.event});
  final Opportunity event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(eventRegistrantsProvider(event.id));
    final t = context.luzText;
    final p = context.luz;
    return AsyncBlock<List<EventRegistrant>>(
      value: list,
      onRetry: () => ref.invalidate(eventRegistrantsProvider(event.id)),
      data: (people) => people.isEmpty
          ? Text(
              'Nobody has registered yet.',
              style: t.body.copyWith(color: p.inkMuted),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final r in people)
                  Padding(
                    padding: const EdgeInsets.only(bottom: LuzSpace.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.teamName == null
                              ? r.name
                              : '${r.name} (team ${r.teamName})',
                          style: t.label,
                        ),
                        Text(
                          [
                            r.email,
                            if ((r.headline ?? '').isNotEmpty) r.headline!,
                          ].join(' · '),
                          style: t.bodySm.copyWith(color: p.inkMuted),
                        ),
                      ],
                    ),
                  ),
                LuzButton(
                  label: 'Copy all emails',
                  icon: Icons.copy,
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(
                        text: [for (final r in people) r.email].join(', '),
                      ),
                    );
                    if (context.mounted) {
                      showLuzToast(context, 'Emails copied', icon: Icons.check);
                    }
                  },
                ),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------- editor

/// /employer/events/new, /employer/events/:id (for the current company) and
/// /admin/events/new, /admin/events/:id (admins name the organiser).
class EventEditorPage extends ConsumerWidget {
  const EventEditorPage({
    super.key,
    this.eventId,
    this.admin = false,
    this.initialKind,
  });
  final String? eventId;
  final bool admin;

  /// For a new event: the type to start with (from `?kind=` on the link,
  /// e.g. "Post a webinar").
  final EventKind? initialKind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget form(String? companyId, Opportunity? existing) => _EventForm(
      key: ValueKey(existing?.id),
      existing: existing,
      companyId: companyId,
      admin: admin,
      initialKind: initialKind,
    );
    Widget withEvent(String? companyId) => eventId == null
        ? form(companyId, null)
        : AsyncBlock<Opportunity?>(
            value: ref.watch(eventByIdProvider(eventId!)),
            onRetry: () => ref.invalidate(eventByIdProvider(eventId!)),
            data: (e) => e == null
                ? const LuzEmptyState(
                    icon: Icons.event_busy_outlined,
                    title: 'Event not found',
                  )
                : form(companyId, e),
          );
    if (admin) return withEvent(null);
    return MembershipGate(builder: (context, m) => withEvent(m.company.id));
  }
}

class _EventForm extends ConsumerStatefulWidget {
  const _EventForm({
    super.key,
    required this.existing,
    required this.companyId,
    required this.admin,
    this.initialKind,
  });
  final Opportunity? existing;
  final String? companyId;
  final bool admin;
  final EventKind? initialKind;

  @override
  ConsumerState<_EventForm> createState() => _EventFormState();
}

class _EventFormState extends ConsumerState<_EventForm> {
  late final EventDraft _d = widget.existing == null
      ? EventDraft(
          kind: widget.initialKind ?? EventKind.walkIn,
          // Webinars happen online; drives start as in person.
          mode: widget.initialKind == EventKind.webinar
              ? EventMode.online
              : EventMode.inPerson,
        )
      : EventDraft.from(widget.existing!);
  late final _title = TextEditingController(text: _d.title);
  late final _summary = TextEditingController(text: _d.summary);
  late final _desc = TextEditingController(text: _d.descriptionMd);
  late final _venue = TextEditingController(text: _d.venue);
  late final _location = TextEditingController(text: _d.location);
  late final _starts = TextEditingController(text: _stamp(_d.startsAt));
  late final _ends = TextEditingController(text: _stamp(_d.endsAt));
  late final _deadline = TextEditingController(
    text: _stamp(_d.registrationDeadline),
  );
  late final _url = TextEditingController(text: _d.registrationUrl);
  late final _eligibility = TextEditingController(text: _d.eligibility);
  late final _prize = TextEditingController(text: _d.prize);
  late final _teamMin = TextEditingController(text: '${_d.teamMin}');
  late final _teamMax = TextEditingController(text: '${_d.teamMax}');
  late final _capacity = TextEditingController(text: '${_d.capacity ?? ''}');
  late final _organizer = TextEditingController(text: _d.organizerName);
  final _errors = <String, String?>{};
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [
      _title,
      _summary,
      _desc,
      _venue,
      _location,
      _starts,
      _ends,
      _deadline,
      _url,
      _eligibility,
      _prize,
      _teamMin,
      _teamMax,
      _capacity,
      _organizer,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _teams => const {
    EventKind.hackathon,
    EventKind.competition,
    EventKind.hiringChallenge,
  }.contains(_d.kind);

  bool _validate() {
    final starts = _parse(_starts.text);
    final ends = _parse(_ends.text);
    final deadline = _parse(_deadline.text);
    final min = int.tryParse(_teamMin.text.trim()) ?? 0;
    final max = int.tryParse(_teamMax.text.trim()) ?? 0;
    final cap = _capacity.text.trim();
    final url = _url.text.trim();
    const dateHelp = 'Use YYYY-MM-DD HH:MM';
    setState(() {
      _errors
        ..clear()
        ..['title'] = _title.text.trim().length < 4
            ? 'Use at least 4 characters'
            : null
        ..['location'] =
            _d.mode != EventMode.online && _location.text.trim().isEmpty
            ? 'Say which city it is in'
            : null
        ..['starts'] = starts == null ? dateHelp : null
        ..['ends'] = _ends.text.trim().isNotEmpty && ends == null
            ? dateHelp
            : ends != null && starts != null && ends.isBefore(starts)
            ? 'Must be after the start'
            : null
        ..['deadline'] = _deadline.text.trim().isNotEmpty && deadline == null
            ? dateHelp
            : deadline != null &&
                  starts != null &&
                  deadline.isAfter(ends ?? starts)
            ? 'Must be before the event ends'
            : null
        ..['url'] = url.isNotEmpty && !url.startsWith('https://')
            ? 'Use a full https:// link'
            : null
        ..['team'] = _teams && (min < 1 || max > 10 || min > max)
            ? 'Between 1 and 10, minimum first'
            : null
        ..['capacity'] =
            cap.isNotEmpty && (int.tryParse(cap) == null || int.parse(cap) < 1)
            ? 'A whole number, or empty for no limit'
            : null
        ..['organizer'] =
            widget.admin &&
                widget.existing == null &&
                _organizer.text.trim().isEmpty
            ? 'Who runs it?'
            : null;
    });
    if (_errors.values.any((e) => e != null)) return false;
    _d
      ..title = _title.text
      ..summary = _summary.text
      ..descriptionMd = _desc.text
      ..venue = _venue.text
      ..location = _location.text
      ..startsAt = starts!
      ..endsAt = ends
      ..registrationDeadline = deadline
      ..registrationUrl = url
      ..eligibility = _eligibility.text
      ..prize = _teams || _d.kind == EventKind.competition ? _prize.text : ''
      ..teamMin = _teams ? min : 1
      ..teamMax = _teams ? max : 1
      ..capacity = cap.isEmpty ? null : int.parse(cap)
      ..organizerName = _organizer.text;
    return true;
  }

  Future<void> _save(EventStatus status) async {
    if (!_validate()) return;
    setState(() => _busy = true);
    final ok = await runWithToast(
      context,
      () async {
        final saved = await ref
            .read(eventActionsProvider)
            .save(_d, companyId: widget.companyId, status: status);
        if (saved.status == EventStatus.pendingReview && mounted) {
          showLuzToast(
            context,
            'Sent for review: events from unverified companies are checked '
            'before they are published.',
            icon: Icons.hourglass_top,
          );
        }
      },
      success: status == EventStatus.published ? 'Event saved' : 'Draft saved',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) context.go(widget.admin ? '/admin/events' : '/employer/events');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.luzText;
    const gap = SizedBox(height: LuzSpace.md);
    final existing = widget.existing;
    final keepStatus = existing != null && existing.status != EventStatus.draft;

    Widget row(List<Widget> children) => LayoutBuilder(
      builder: (context, c) => c.maxWidth < 560
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final w in children) ...[w, gap],
              ],
            )
          : Padding(
              padding: const EdgeInsets.only(bottom: LuzSpace.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0) const SizedBox(width: LuzSpace.md),
                    Expanded(child: children[i]),
                  ],
                ],
              ),
            ),
    );

    return WorkspacePage(
      title: existing == null ? 'New event' : 'Edit event',
      subtitle: existing?.title,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: LuzCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Type', style: t.label),
                const SizedBox(height: LuzSpace.xs),
                Wrap(
                  spacing: LuzSpace.xs,
                  runSpacing: LuzSpace.xs,
                  children: [
                    for (final k in EventKind.values)
                      LuzFilterChip(
                        label: k.label,
                        icon: k.icon,
                        selected: _d.kind == k,
                        onSelected: (_) => setState(() => _d.kind = k),
                      ),
                  ],
                ),
                gap,
                LuzTextField(
                  label: 'Title',
                  controller: _title,
                  error: _errors['title'],
                  maxLength: 160,
                ),
                gap,
                if (widget.admin) ...[
                  LuzTextField(
                    label: 'Organiser',
                    controller: _organizer,
                    error: _errors['organizer'],
                    hint: 'For example, a college placement cell',
                    maxLength: 120,
                  ),
                  gap,
                ],
                LuzTextField(
                  label: 'Summary (shown on cards)',
                  controller: _summary,
                  maxLines: 3,
                  maxLength: 300,
                ),
                gap,
                LuzTextField(
                  label: 'Details (Markdown)',
                  controller: _desc,
                  maxLines: 10,
                  maxLength: 20000,
                ),
                gap,
                Text('Where', style: t.label),
                const SizedBox(height: LuzSpace.xs),
                LuzSegmented<EventMode>(
                  segments: [
                    for (final m in EventMode.values)
                      (value: m, label: m.label, icon: m.icon),
                  ],
                  selected: _d.mode,
                  onChanged: (m) => setState(() => _d.mode = m),
                ),
                gap,
                if (_d.mode != EventMode.online)
                  row([
                    LuzTextField(
                      label: 'City',
                      controller: _location,
                      error: _errors['location'],
                      hint: 'Bengaluru',
                      helper: 'Puts the event on the hiring map',
                    ),
                    LuzTextField(
                      label: 'Venue',
                      controller: _venue,
                      hint: 'Campus, building and room',
                    ),
                  ]),
                row([
                  LuzTextField(
                    label: 'Starts',
                    controller: _starts,
                    error: _errors['starts'],
                    hint: 'YYYY-MM-DD HH:MM',
                  ),
                  LuzTextField(
                    label: 'Ends (optional)',
                    controller: _ends,
                    error: _errors['ends'],
                    hint: 'YYYY-MM-DD HH:MM',
                  ),
                ]),
                row([
                  LuzTextField(
                    label: 'Register by (optional)',
                    controller: _deadline,
                    error: _errors['deadline'],
                    hint: 'YYYY-MM-DD HH:MM',
                    helper: 'Empty: until it starts',
                  ),
                  LuzTextField(
                    label: 'Places (optional)',
                    controller: _capacity,
                    error: _errors['capacity'],
                    keyboardType: TextInputType.number,
                    helper: 'Empty: no limit',
                  ),
                ]),
                LuzTextField(
                  label: 'Registration link (optional)',
                  controller: _url,
                  error: _errors['url'],
                  hint: 'https://',
                  helper:
                      'Leave empty to take registrations on LuzHire and see '
                      'who signed up',
                ),
                gap,
                if (_teams) ...[
                  row([
                    LuzTextField(
                      label: 'Smallest team',
                      controller: _teamMin,
                      error: _errors['team'],
                      keyboardType: TextInputType.number,
                    ),
                    LuzTextField(
                      label: 'Largest team',
                      controller: _teamMax,
                      keyboardType: TextInputType.number,
                      helper: '1 for individual entries',
                    ),
                  ]),
                  LuzTextField(
                    label: 'Prizes',
                    controller: _prize,
                    hint: '₹50,000 prize pool and interviews for the top 10',
                    maxLength: 300,
                  ),
                  gap,
                ],
                LuzTextField(
                  label: 'Who can take part (optional)',
                  controller: _eligibility,
                  hint: 'Final-year B.Tech and MCA students, 2026 batch',
                  maxLines: 3,
                  maxLength: 1000,
                ),
                gap,
                Wrap(
                  spacing: LuzSpace.sm,
                  runSpacing: LuzSpace.sm,
                  children: [
                    LuzButton.accent(
                      label: _busy
                          ? 'Saving…'
                          : keepStatus
                          ? 'Save changes'
                          : 'Publish',
                      icon: Icons.check,
                      onPressed: _busy
                          ? null
                          : () => _save(
                              keepStatus
                                  ? existing.status
                                  : EventStatus.published,
                            ),
                    ),
                    if (!keepStatus)
                      LuzButton(
                        label: 'Save draft',
                        onPressed: _busy
                            ? null
                            : () => _save(EventStatus.draft),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- admin

/// /admin/events: review events from unverified companies, post events for
/// any organiser.
class AdminEventsPage extends ConsumerStatefulWidget {
  const AdminEventsPage({super.key});

  @override
  ConsumerState<AdminEventsPage> createState() => _AdminEventsPageState();
}

class _AdminEventsPageState extends ConsumerState<AdminEventsPage> {
  bool _pendingOnly = true;

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(allOpportunitiesProvider);
    return WorkspacePage(
      subtitle: 'Hiring drives, hackathons and competitions',
      actions: [
        LuzButton.accent(
          label: 'New event',
          icon: Icons.add,
          onPressed: () => context.go('/admin/events/new'),
        ),
      ],
      children: [
        LuzSegmented<bool>(
          segments: const [
            (value: true, label: 'Waiting for review', icon: null),
            (value: false, label: 'All events', icon: null),
          ],
          selected: _pendingOnly,
          onChanged: (v) => setState(() => _pendingOnly = v),
        ),
        const SizedBox(height: LuzSpace.lg),
        AsyncBlock<List<Opportunity>>(
          value: list,
          onRetry: () => ref.invalidate(allOpportunitiesProvider),
          data: (all) {
            final items = _pendingOnly
                ? all
                      .where((e) => e.status == EventStatus.pendingReview)
                      .toList()
                : all;
            if (items.isEmpty) {
              return LuzEmptyState(
                icon: Icons.event_available,
                title: _pendingOnly
                    ? 'Nothing waiting for review'
                    : 'No events yet',
              );
            }
            return Column(
              children: [
                for (final e in items) ...[
                  OrganizerEventRow(
                    event: e,
                    canEdit: true,
                    editPath: '/admin/events/${e.id}',
                    review: true,
                  ),
                  const SizedBox(height: LuzSpace.md),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}
