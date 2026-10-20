import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/data/enums.dart';
import '../../../core/data/failures.dart';
import '../../../core/data/format.dart';
import '../../../core/data/models.dart';
import '../../../core/shell/workspace_page.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../../candidate/presentation/candidate_widgets.dart'
    show AsyncBlock, runWithToast;
import '../../jobs/application/job_board_providers.dart'
    show currentUidProvider;
import '../../jobs/presentation/job_search_page.dart' show JobBoardError;
import '../../jobs/presentation/job_widgets.dart' show SimpleMarkdown;
import '../application/admin_providers.dart';

// ---------------------------------------------------------------- users

/// /admin/users: find people, change roles, suspend or reactivate.
class AdminUsersPage extends ConsumerStatefulWidget {
  const AdminUsersPage({super.key});

  @override
  ConsumerState<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends ConsumerState<AdminUsersPage> {
  final _search = TextEditingController();
  UserQuery _query = const UserQuery();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _set({
    String? text,
    AppRole? role,
    AccountStatus? status,
    bool clearRole = false,
    bool clearStatus = false,
  }) => setState(
    () => _query = UserQuery(
      text: text ?? _query.text,
      role: clearRole ? null : role ?? _query.role,
      status: clearStatus ? null : status ?? _query.status,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(usersProvider(_query));
    final me = ref.watch(currentUidProvider);
    return WorkspacePage(
      subtitle: 'Accounts',
      children: [
        LuzCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LuzTextField(
                label: 'Search by name or email',
                controller: _search,
                prefixIcon: Icons.search,
                textInputAction: TextInputAction.search,
                onSubmitted: (v) => _set(text: v),
              ),
              const SizedBox(height: LuzSpace.sm),
              Wrap(
                spacing: LuzSpace.xs,
                runSpacing: LuzSpace.xs,
                children: [
                  for (final r in AppRole.values)
                    LuzFilterChip(
                      label: switch (r) {
                        AppRole.candidate => 'Candidates',
                        AppRole.employer => 'Employers',
                        AppRole.admin => 'Admins',
                      },
                      selected: _query.role == r,
                      onSelected: (_) => _query.role == r
                          ? _set(clearRole: true)
                          : _set(role: r),
                    ),
                  LuzFilterChip(
                    label: 'Suspended',
                    icon: Icons.block,
                    selected: _query.status == AccountStatus.suspended,
                    onSelected: (_) => _query.status == AccountStatus.suspended
                        ? _set(clearStatus: true)
                        : _set(status: AccountStatus.suspended),
                  ),
                ],
              ),
            ],
          ),
        ),
        AsyncBlock<List<Profile>>(
          value: users,
          onRetry: () => ref.invalidate(usersProvider(_query)),
          data: (list) => LuzDataTable<Profile>(
            rows: list,
            emptyLabel: 'No accounts match',
            onRowTap: (u) => u.id == me ? null : _manage(context, u),
            columns: [
              LuzColumn(
                label: 'Name',
                flex: 2,
                sortKey: (u) => u.displayName.toLowerCase(),
                cell: (_, u) => Text(
                  u.id == me ? '${u.displayName} (you)' : u.displayName,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              LuzColumn(
                label: 'Email',
                flex: 3,
                cell: (_, u) => Text(u.email, overflow: TextOverflow.ellipsis),
              ),
              LuzColumn(
                label: 'Role',
                sortKey: (u) => u.role.index,
                cell: (_, u) => Text(u.role.dbValue),
              ),
              LuzColumn(
                label: 'Status',
                flex: 2,
                cell: (_, u) => Align(
                  alignment: Alignment.centerLeft,
                  child: LuzStatusChip(
                    label: u.accountStatus.label,
                    tone: u.accountStatus == AccountStatus.active
                        ? LuzChipTone.green
                        : LuzChipTone.red,
                    icon: u.accountStatus == AccountStatus.active
                        ? Icons.check_circle_outline
                        : Icons.block,
                  ),
                ),
              ),
              LuzColumn(
                label: 'Joined',
                sortKey: (u) => u.createdAt ?? DateTime(0),
                cell: (_, u) => Text(
                  u.createdAt == null ? '—' : formatRelative(u.createdAt!),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _manage(BuildContext context, Profile u) => showLuzModal<void>(
    context: context,
    title: u.displayName,
    builder: (ctx) => _ManageUser(user: u),
  );
}

class _ManageUser extends ConsumerStatefulWidget {
  const _ManageUser({required this.user});
  final Profile user;

  @override
  ConsumerState<_ManageUser> createState() => _ManageUserState();
}

class _ManageUserState extends ConsumerState<_ManageUser> {
  late AppRole _role = widget.user.role;

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final t = context.luzText;
    final p = context.luz;
    final actions = ref.read(adminActionsProvider);
    final suspended = u.accountStatus == AccountStatus.suspended;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(u.email, style: t.bodySm.copyWith(color: p.inkMuted)),
        const SizedBox(height: LuzSpace.md),
        Text('Role', style: t.label),
        const SizedBox(height: LuzSpace.xs),
        LuzSegmented<AppRole>(
          segments: [
            for (final r in AppRole.values)
              (value: r, label: r.dbValue, icon: null),
          ],
          selected: _role,
          onChanged: (r) => setState(() => _role = r),
        ),
        const SizedBox(height: LuzSpace.xs),
        Text(
          'Changing the role signs them out everywhere.',
          style: t.caption.copyWith(color: p.muted),
        ),
        const SizedBox(height: LuzSpace.sm),
        LuzButton(
          label: 'Save role',
          icon: Icons.manage_accounts_outlined,
          onPressed: _role == u.role
              ? null
              : () async {
                  final ok = await runWithToast(
                    context,
                    () => actions.changeRole(u.id, _role),
                    success: '${u.displayName} is now ${_role.dbValue}',
                  );
                  if (ok && context.mounted) Navigator.of(context).pop();
                },
        ),
        const SizedBox(height: LuzSpace.lg),
        Text('Access', style: t.label),
        const SizedBox(height: LuzSpace.xs),
        Text(
          suspended
              ? 'Suspended: cannot sign in or change anything.'
              : 'Suspending blocks sign-in and every change at once.',
          style: t.bodySm,
        ),
        const SizedBox(height: LuzSpace.sm),
        LuzButton.accent(
          label: suspended ? 'Reactivate account' : 'Suspend account',
          icon: suspended ? Icons.lock_open : Icons.block,
          onPressed: () async {
            final ok = await confirmLuz(
              context,
              title: suspended
                  ? 'Reactivate ${u.displayName}?'
                  : 'Suspend ${u.displayName}?',
              message: suspended
                  ? 'They can sign in and use LuzHire again.'
                  : 'They are signed out and cannot sign in until reactivated.',
              confirmLabel: suspended ? 'Reactivate' : 'Suspend',
              icon: suspended ? Icons.lock_open : Icons.block,
            );
            if (!ok || !context.mounted) return;
            final done = await runWithToast(
              context,
              () => actions.setStatus(
                u.id,
                suspended ? AccountStatus.active : AccountStatus.suspended,
              ),
              success: suspended ? 'Account reactivated' : 'Account suspended',
            );
            if (done && context.mounted) Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- announcements

/// /admin/announcements: create, publish, unpublish and delete.
class AnnouncementsAdminPage extends ConsumerWidget {
  const AnnouncementsAdminPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(adminAnnouncementsProvider);
    final t = context.luzText;
    final p = context.luz;
    final actions = ref.read(adminActionsProvider);
    return WorkspacePage(
      subtitle: 'Messages shown across LuzHire',
      actions: [
        LuzButton.accent(
          label: 'New announcement',
          icon: Icons.add,
          onPressed: () => _edit(context, null),
        ),
      ],
      children: [
        AsyncBlock<List<Announcement>>(
          value: list,
          onRetry: () => ref.invalidate(adminAnnouncementsProvider),
          data: (items) => items.isEmpty
              ? const LuzEmptyState(
                  icon: Icons.campaign_outlined,
                  title: 'No announcements yet',
                  message:
                      'Published announcements appear as a banner for '
                      'their audience.',
                )
              : Column(
                  children: [
                    for (final a in items) ...[
                      LuzCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(a.title, style: t.wsSection),
                                ),
                                LuzStatusChip(
                                  label: a.isPublished ? 'Published' : 'Draft',
                                  tone: a.isPublished
                                      ? LuzChipTone.green
                                      : LuzChipTone.neutral,
                                  icon: a.isPublished
                                      ? Icons.campaign_outlined
                                      : Icons.edit_note,
                                ),
                                const SizedBox(width: LuzSpace.xs),
                                LuzStatusChip(
                                  label: a.audience.label,
                                  tone: LuzChipTone.blue,
                                ),
                              ],
                            ),
                            const SizedBox(height: LuzSpace.xs),
                            Text(
                              a.bodyMd,
                              style: t.bodySm,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              a.isPublished
                                  ? 'Published ${formatRelative(a.publishedAt!)}'
                                  : 'Created ${formatRelative(a.createdAt)}',
                              style: t.caption.copyWith(color: p.muted),
                            ),
                            const SizedBox(height: LuzSpace.xs),
                            Wrap(
                              spacing: LuzSpace.md,
                              children: [
                                LuzTextLink(
                                  label: 'Edit',
                                  onPressed: () => _edit(context, a),
                                ),
                                LuzTextLink(
                                  label: 'Delete',
                                  onPressed: () async {
                                    final ok = await confirmLuz(
                                      context,
                                      title: 'Delete "${a.title}"?',
                                      message: 'It disappears for everyone.',
                                      confirmLabel: 'Delete',
                                      icon: Icons.delete_outline,
                                    );
                                    if (ok && context.mounted) {
                                      await runWithToast(
                                        context,
                                        () => actions.deleteAnnouncement(a.id),
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: LuzSpace.md),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _edit(BuildContext context, Announcement? a) =>
      showLuzModal<void>(
        context: context,
        title: a == null ? 'New announcement' : 'Edit announcement',
        builder: (_) => _AnnouncementForm(existing: a),
      );
}

class _AnnouncementForm extends ConsumerStatefulWidget {
  const _AnnouncementForm({this.existing});
  final Announcement? existing;

  @override
  ConsumerState<_AnnouncementForm> createState() => _AnnouncementFormState();
}

class _AnnouncementFormState extends ConsumerState<_AnnouncementForm> {
  late final _title = TextEditingController(text: widget.existing?.title);
  late final _body = TextEditingController(text: widget.existing?.bodyMd);
  late AnnouncementAudience _audience =
      widget.existing?.audience ?? AnnouncementAudience.all;
  late bool _publish = widget.existing?.isPublished ?? true;
  final _errors = <String, String?>{};
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _errors
        ..['title'] = _title.text.trim().isEmpty ? 'Add a title' : null
        ..['body'] = _body.text.trim().isEmpty ? 'Write the message' : null;
    });
    if (_errors.values.any((e) => e != null)) return;
    setState(() => _busy = true);
    final ok = await runWithToast(
      context,
      () => ref
          .read(adminActionsProvider)
          .saveAnnouncement(
            id: widget.existing?.id,
            title: _title.text,
            bodyMd: _body.text,
            audience: _audience,
            publish: _publish,
          ),
      success: _publish ? 'Announcement published' : 'Draft saved',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.luzText;
    const gap = SizedBox(height: LuzSpace.md);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LuzTextField(
          label: 'Title',
          controller: _title,
          error: _errors['title'],
          maxLength: 160,
          autofocus: true,
        ),
        gap,
        LuzTextField(
          label: 'Message (Markdown)',
          controller: _body,
          error: _errors['body'],
          maxLines: 8,
          maxLength: 10000,
        ),
        gap,
        Text('Audience', style: t.label),
        const SizedBox(height: LuzSpace.xs),
        LuzSegmented<AnnouncementAudience>(
          segments: [
            for (final a in AnnouncementAudience.values)
              (value: a, label: a.label, icon: null),
          ],
          selected: _audience,
          onChanged: (a) => setState(() => _audience = a),
        ),
        gap,
        Row(
          children: [
            Expanded(child: Text('Publish now', style: t.label)),
            LuzToggle(
              value: _publish,
              semanticLabel: 'Publish now',
              onChanged: (v) => setState(() => _publish = v),
            ),
          ],
        ),
        gap,
        LuzButton.accent(
          label: _busy ? 'Saving…' : (_publish ? 'Publish' : 'Save draft'),
          expand: true,
          onPressed: _busy ? null : _save,
        ),
      ],
    );
  }
}

/// Banner with the newest published announcement for this user.
class AnnouncementsBanner extends ConsumerWidget {
  const AnnouncementsBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dismissed = ref.watch(dismissedAnnouncementsProvider);
    final list = (ref.watch(activeAnnouncementsProvider).value ?? const [])
        .where((a) => !dismissed.contains(a.id))
        .toList();
    if (list.isEmpty) return const SizedBox.shrink();
    final a = list.first;
    final p = context.luz;
    final t = context.luzText;
    return Padding(
      padding: const EdgeInsets.only(bottom: LuzSpace.lg),
      child: Semantics(
        container: true,
        label: 'Announcement',
        child: LuzSurface(
          depth: LuzDepth.raisedSm,
          radius: LuzRadius.md,
          color: p.baseTint,
          padding: const EdgeInsets.all(LuzSpace.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.campaign_outlined, color: p.accent),
              const SizedBox(width: LuzSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.title, style: t.label),
                    const SizedBox(height: LuzSpace.xxs),
                    SimpleMarkdown(a.bodyMd),
                  ],
                ),
              ),
              LuzIconButton(
                icon: Icons.close,
                tooltip: 'Dismiss announcement',
                size: 36,
                onPressed: () => ref
                    .read(dismissedAnnouncementsProvider.notifier)
                    .dismiss(a.id),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- audit

const _auditTables = [
  'companies',
  'company_members',
  'jobs',
  'profiles',
  'announcements',
  'reports',
];

/// /admin/audit: append-only history of sensitive changes.
class AuditLogPage extends ConsumerStatefulWidget {
  const AuditLogPage({super.key});

  @override
  ConsumerState<AuditLogPage> createState() => _AuditLogPageState();
}

class _AuditLogPageState extends ConsumerState<AuditLogPage> {
  AuditQuery _query = const AuditQuery();
  final _actor = TextEditingController();

  @override
  void dispose() {
    _actor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(auditProvider(_query));
    final controller = ref.read(auditProvider(_query).notifier);
    return WorkspacePage(
      subtitle:
          'Every sensitive change, newest first. Entries cannot be edited.',
      children: [
        LuzCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: LuzSpace.xs,
                runSpacing: LuzSpace.xs,
                children: [
                  LuzFilterChip(
                    label: 'All',
                    selected: _query.table == null,
                    onSelected: (_) => setState(
                      () => _query = AuditQuery(actorId: _query.actorId),
                    ),
                  ),
                  for (final table in _auditTables)
                    LuzFilterChip(
                      label: table,
                      selected: _query.table == table,
                      onSelected: (_) => setState(
                        () => _query = AuditQuery(
                          table: table,
                          actorId: _query.actorId,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: LuzSpace.sm),
              LuzTextField(
                label: 'Actor user id (optional)',
                controller: _actor,
                onSubmitted: (v) => setState(
                  () => _query = AuditQuery(table: _query.table, actorId: v),
                ),
              ),
            ],
          ),
        ),
        entries.when(
          loading: () => const LuzSkeleton(width: 240, height: 16),
          error: (e, _) => JobBoardError(
            error: mapDbError(e),
            onRetry: () => ref.invalidate(auditProvider(_query)),
          ),
          data: (list) => list.isEmpty
              ? const LuzEmptyState(icon: Icons.history, title: 'No entries')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final e in list) _AuditRow(entry: e),
                    if (controller.hasMore)
                      Padding(
                        padding: const EdgeInsets.only(top: LuzSpace.md),
                        child: Center(
                          child: LuzButton(
                            label: 'Load more',
                            onPressed: controller.loadMore,
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _AuditRow extends StatelessWidget {
  const _AuditRow({required this.entry});
  final AuditEntry entry;

  @override
  Widget build(BuildContext context) {
    final t = context.luzText;
    final p = context.luz;
    final e = entry;
    final diff = e.diff == null
        ? null
        : const JsonEncoder.withIndent('  ').convert(e.diff);
    return Padding(
      padding: const EdgeInsets.only(bottom: LuzSpace.xs),
      child: LuzSurface(
        depth: LuzDepth.raisedXs,
        radius: LuzRadius.sm,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: LuzSpace.md),
            title: Text(e.action, style: t.mono.copyWith(color: p.ink)),
            subtitle: Text(
              '${DateFormat('d MMM y, HH:mm').format(e.createdAt.toLocal())}'
              ' · ${e.actorRole ?? 'system'}'
              '${e.actorId == null ? '' : ' ${e.actorId}'}'
              '${e.targetId == null ? '' : ' → ${e.targetId}'}',
              style: t.caption.copyWith(color: p.inkMuted),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(
              LuzSpace.md,
              0,
              LuzSpace.md,
              LuzSpace.md,
            ),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: SelectableText(
                  diff ?? 'No details',
                  style: t.mono.copyWith(color: p.inkMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
