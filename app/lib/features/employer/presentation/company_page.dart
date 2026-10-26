import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/enums.dart';
import '../../../core/data/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../../candidate/presentation/candidate_widgets.dart'
    show AsyncBlock, runWithToast;
import '../../candidate/presentation/profile_page.dart' show pickFile;
import '../../jobs/application/job_board_providers.dart'
    show currentUidProvider;
import '../application/employer_providers.dart';
import '../data/employer_repository.dart';
import 'employer_common.dart';

const companySizes = [
  '1-10',
  '11-50',
  '51-200',
  '201-500',
  '501-1000',
  '1001-5000',
  '5000+',
];

/// Create (no [company]) or edit a company profile.
class CompanyForm extends ConsumerStatefulWidget {
  const CompanyForm({super.key, this.company, this.readOnly = false});
  final Company? company;
  final bool readOnly;

  @override
  ConsumerState<CompanyForm> createState() => _CompanyFormState();
}

class _CompanyFormState extends ConsumerState<CompanyForm> {
  late final _name = TextEditingController(text: widget.company?.name);
  late final _industry = TextEditingController(text: widget.company?.industry);
  late final _website = TextEditingController(text: widget.company?.website);
  late final _hq = TextEditingController(text: widget.company?.hqLocation);
  late final _about = TextEditingController(text: widget.company?.description);
  late final _benefits = TextEditingController(
    text: widget.company?.benefits.join('\n'),
  );
  late String? _size = widget.company?.sizeRange;
  final _errors = <String, String?>{};
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_name, _industry, _website, _hq, _about, _benefits]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final website = _website.text.trim();
    setState(() {
      _errors
        ..['name'] = _name.text.trim().isEmpty ? 'Enter the company name' : null
        ..['website'] =
            website.isNotEmpty &&
                !RegExp(r'^https?://\S+\.\S+').hasMatch(website)
            ? 'Start with https://'
            : null;
    });
    if (_errors.values.any((e) => e != null)) return;
    String? blank(String v) => v.trim().isEmpty ? null : v.trim();
    final fields = {
      'name': _name.text.trim(),
      'industry': blank(_industry.text),
      'website': blank(website),
      'hq_location': blank(_hq.text),
      'description': blank(_about.text),
      'size_range': _size,
      'benefits': [
        for (final b in _benefits.text.split('\n'))
          if (b.trim().isNotEmpty) b.trim(),
      ],
    };
    setState(() => _busy = true);
    final actions = ref.read(employerActionsProvider);
    await runWithToast(context, () async {
      if (widget.company == null) {
        final c = await actions.createCompany(fields);
        ref.read(selectedCompanyProvider.notifier).select(c.id);
      } else {
        await actions.updateCompany(widget.company!.id, fields);
      }
    }, success: widget.company == null ? 'Company created' : 'Company saved');
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: LuzSpace.md);
    final t = context.luzText;
    final enabled = !widget.readOnly;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LuzTextField(
          label: 'Company name',
          controller: _name,
          error: _errors['name'],
          maxLength: 120,
          enabled: enabled,
        ),
        gap,
        LuzTextField(
          label: 'Industry',
          hint: 'e.g. Software, FinTech',
          controller: _industry,
          enabled: enabled,
        ),
        gap,
        Text('Company size', style: t.label),
        const SizedBox(height: LuzSpace.xs),
        Wrap(
          spacing: LuzSpace.xs,
          runSpacing: LuzSpace.xs,
          children: [
            for (final s in companySizes)
              LuzFilterChip(
                label: s,
                selected: _size == s,
                onSelected: enabled
                    ? (_) => setState(() => _size = _size == s ? null : s)
                    : null,
              ),
          ],
        ),
        gap,
        LuzTextField(
          label: 'Website',
          hint: 'https://',
          controller: _website,
          error: _errors['website'],
          keyboardType: TextInputType.url,
          enabled: enabled,
        ),
        gap,
        LuzTextField(
          label: 'Headquarters',
          hint: 'City, country',
          controller: _hq,
          enabled: enabled,
        ),
        gap,
        LuzTextField(
          label: 'About',
          controller: _about,
          maxLines: 8,
          maxLength: 8000,
          enabled: enabled,
        ),
        gap,
        LuzTextField(
          label: 'Benefits (one per line)',
          controller: _benefits,
          maxLines: 6,
          enabled: enabled,
        ),
        if (enabled) ...[
          gap,
          Align(
            alignment: Alignment.centerRight,
            child: LuzButton.accent(
              label: _busy
                  ? 'Saving…'
                  : widget.company == null
                  ? 'Create company'
                  : 'Save company',
              onPressed: _busy ? null : _save,
            ),
          ),
        ],
      ],
    );
  }
}

/// /employer/company: profile, verification and team.
class EmployerCompanyPage extends ConsumerWidget {
  const EmployerCompanyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MembershipGate(
    // Switching company: the switcher in the workspace sidebar.
    builder: (context, m) {
      return WorkspacePage(
        title: m.company.name,
        subtitle: companyFacts(m.company),
        children: [
          const MyInvitationsCard(),
          _VerificationCard(membership: m),
          LayoutBuilder(
            builder: (context, c) {
              final profile = LuzCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Company profile', style: context.luzText.wsSection),
                    const SizedBox(height: LuzSpace.md),
                    _LogoRow(membership: m),
                    const SizedBox(height: LuzSpace.md),
                    CompanyForm(
                      key: ValueKey(m.company.id),
                      company: m.company,
                      readOnly: !m.role.canEdit,
                    ),
                  ],
                ),
              );
              final team = _TeamCard(membership: m);
              if (c.maxWidth < 1000) {
                return Column(
                  children: [
                    profile,
                    const SizedBox(height: LuzSpace.lg),
                    team,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: profile),
                  const SizedBox(width: LuzSpace.lg),
                  Expanded(flex: 2, child: team),
                ],
              );
            },
          ),
        ],
      );
    },
  );
}

class _VerificationCard extends ConsumerWidget {
  const _VerificationCard({required this.membership});
  final Membership membership;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = membership.company;
    final p = context.luz;
    final t = context.luzText;
    final (tone, icon, text) = switch (c.verification) {
      Verification.verified => (
        LuzChipTone.green,
        Icons.verified_outlined,
        'Verified. Your jobs are published straight away.',
      ),
      Verification.pending => (
        LuzChipTone.orange,
        Icons.hourglass_top,
        'Verification requested. An admin will review your company soon.',
      ),
      Verification.rejected => (
        LuzChipTone.red,
        Icons.block,
        'Verification was declined. Update your profile and ask again.',
      ),
      Verification.unverified => (
        LuzChipTone.neutral,
        Icons.shield_outlined,
        'Not verified yet. Jobs wait for an admin review before going live.',
      ),
    };
    final canAsk =
        membership.role == MemberRole.owner &&
        (c.verification == Verification.unverified ||
            c.verification == Verification.rejected);
    return LuzCard(
      child: Wrap(
        spacing: LuzSpace.md,
        runSpacing: LuzSpace.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          LuzStatusChip(
            label: switch (c.verification) {
              Verification.verified => 'Verified',
              Verification.pending => 'Pending review',
              Verification.rejected => 'Declined',
              Verification.unverified => 'Unverified',
            },
            tone: tone,
            icon: icon,
          ),
          Text(text, style: t.body.copyWith(color: p.inkMuted)),
          if (canAsk)
            LuzButton.accent(
              label: 'Request verification',
              icon: Icons.verified_outlined,
              onPressed: () => runWithToast(
                context,
                () =>
                    ref.read(employerActionsProvider).requestVerification(c.id),
                success: 'Verification requested',
              ),
            ),
        ],
      ),
    );
  }
}

class _LogoRow extends ConsumerWidget {
  const _LogoRow({required this.membership});
  final Membership membership;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = membership.company;
    String? url;
    if (c.logoPath != null) {
      url = ref.read(employerRepositoryProvider).logoUrl(c.logoPath!);
    }
    return Row(
      children: [
        LuzLogoSocket(name: c.name, logoUrl: url, size: 64),
        const SizedBox(width: LuzSpace.md),
        if (membership.role.canEdit)
          LuzButton(
            label: c.logoPath == null ? 'Upload logo' : 'Change logo',
            icon: Icons.image_outlined,
            onPressed: () => runWithToast(context, () async {
              final file = await pickFile(const [
                'png',
                'jpg',
                'jpeg',
                'webp',
                'svg',
              ], maxBytes: 5 * 1024 * 1024);
              if (file == null) return;
              await ref
                  .read(employerActionsProvider)
                  .uploadLogo(c, file.name, file.bytes);
            }),
          ),
      ],
    );
  }
}

class _TeamCard extends ConsumerStatefulWidget {
  const _TeamCard({required this.membership});
  final Membership membership;

  @override
  ConsumerState<_TeamCard> createState() => _TeamCardState();
}

class _TeamCardState extends ConsumerState<_TeamCard> {
  final _email = TextEditingController();
  MemberRole _role = MemberRole.recruiter;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _invite() async {
    final email = _email.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _error = 'Enter a valid email');
      return;
    }
    setState(() => _error = null);
    final ok = await runWithToast(
      context,
      () => ref
          .read(employerActionsProvider)
          .invite(widget.membership.company.id, email, _role),
      success: 'Invitation sent to $email',
    );
    if (ok) _email.clear();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.membership;
    final owner = m.role == MemberRole.owner;
    final me = ref.watch(currentUidProvider);
    final t = context.luzText;
    final p = context.luz;
    final members = ref.watch(membersProvider(m.company.id));
    final invites = (ref.watch(invitesProvider).value ?? const [])
        .where((i) => i.companyId == m.company.id)
        .toList();
    final actions = ref.read(employerActionsProvider);

    return LuzCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Team', style: t.wsSection),
          const SizedBox(height: LuzSpace.sm),
          AsyncBlock<List<CompanyMember>>(
            value: members,
            onRetry: () => ref.invalidate(membersProvider(m.company.id)),
            data: (list) => Column(
              children: [
                for (final member in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: LuzSpace.sm),
                    child: Row(
                      children: [
                        LuzAvatar(name: member.displayName, size: 32),
                        const SizedBox(width: LuzSpace.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                member.userId == me
                                    ? '${member.displayName} (you)'
                                    : member.displayName,
                                style: t.label,
                              ),
                              Text(
                                member.email,
                                style: t.caption.copyWith(color: p.muted),
                              ),
                            ],
                          ),
                        ),
                        if (!owner ||
                            member.role == MemberRole.owner ||
                            member.userId == me)
                          LuzStatusChip(
                            label: member.role.label,
                            tone: LuzChipTone.neutral,
                          )
                        else ...[
                          LuzSegmented<MemberRole>(
                            segments: const [
                              (
                                value: MemberRole.recruiter,
                                label: 'Recruiter',
                                icon: null,
                              ),
                              (
                                value: MemberRole.viewer,
                                label: 'Viewer',
                                icon: null,
                              ),
                            ],
                            selected: member.role,
                            onChanged: (r) => runWithToast(
                              context,
                              () => actions.setMemberRole(
                                m.company.id,
                                member.userId,
                                r,
                              ),
                            ),
                          ),
                          LuzIconButton(
                            icon: Icons.person_remove_outlined,
                            tooltip: 'Remove ${member.displayName}',
                            size: 36,
                            onPressed: () async {
                              final ok = await confirmLuz(
                                context,
                                title: 'Remove ${member.displayName}?',
                                message:
                                    'They lose access to this company\'s jobs '
                                    'and candidates.',
                                confirmLabel: 'Remove',
                                icon: Icons.person_remove_outlined,
                              );
                              if (ok && context.mounted) {
                                await runWithToast(
                                  context,
                                  () => actions.removeMember(
                                    m.company.id,
                                    member.userId,
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (owner) ...[
            const SizedBox(height: LuzSpace.md),
            Text('Invite a teammate', style: t.label),
            const SizedBox(height: LuzSpace.xs),
            LuzTextField(
              label: 'Email',
              controller: _email,
              error: _error,
              keyboardType: TextInputType.emailAddress,
              onSubmitted: (_) => _invite(),
            ),
            const SizedBox(height: LuzSpace.sm),
            Wrap(
              spacing: LuzSpace.sm,
              runSpacing: LuzSpace.sm,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                LuzSegmented<MemberRole>(
                  segments: const [
                    (
                      value: MemberRole.recruiter,
                      label: 'Recruiter',
                      icon: null,
                    ),
                    (value: MemberRole.viewer, label: 'Viewer', icon: null),
                  ],
                  selected: _role,
                  onChanged: (r) => setState(() => _role = r),
                ),
                LuzButton.accent(
                  label: 'Send invite',
                  icon: Icons.person_add_alt,
                  onPressed: _invite,
                ),
              ],
            ),
            const SizedBox(height: LuzSpace.xs),
            Text(
              'Recruiters post jobs and move candidates. Viewers can only look.',
              style: t.caption.copyWith(color: p.muted),
            ),
            if (invites.isNotEmpty) ...[
              const SizedBox(height: LuzSpace.md),
              Text('Pending invitations', style: t.label),
              for (final i in invites)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${i.email} · ${i.role.label}',
                        style: t.bodySm,
                      ),
                    ),
                    LuzTextLink(
                      label: 'Revoke',
                      onPressed: () => runWithToast(
                        context,
                        () => actions.deleteInvite(i.id),
                      ),
                    ),
                  ],
                ),
            ],
          ] else if (!m.role.canEdit) ...[
            const SizedBox(height: LuzSpace.sm),
            const ViewerNotice(),
          ],
        ],
      ),
    );
  }
}
