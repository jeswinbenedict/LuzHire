import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/enums.dart';
import '../../../core/data/failures.dart';
import '../../../core/data/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_state.dart';
import '../../candidate/presentation/candidate_widgets.dart'
    show AsyncBlock, runWithToast;
import '../application/employer_providers.dart';
import '../data/employer_repository.dart';
import 'company_page.dart' show CompanyForm;
import '../../../core/shell/workspace_page.dart';

export '../../../core/shell/workspace_page.dart';

/// Resolves the current company. Without one, shows onboarding: pending
/// invitations and the "create your company" form.
class MembershipGate extends ConsumerWidget {
  const MembershipGate({super.key, required this.builder});
  final Widget Function(BuildContext context, Membership membership) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(currentMembershipProvider);
    return AsyncBlock<Membership?>(
      value: m,
      onRetry: () => ref.invalidate(myCompaniesProvider),
      data: (membership) => membership == null
          ? const _Onboarding()
          : builder(context, membership),
    );
  }
}

class _Onboarding extends ConsumerWidget {
  const _Onboarding();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.luz;
    final t = context.luzText;
    return WorkspacePage(
      title: 'Set up your company',
      subtitle: 'Jobs are posted on behalf of a company profile.',
      children: [
        const MyInvitationsCard(),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: LuzCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Create a company', style: t.wsSection),
                const SizedBox(height: LuzSpace.xs),
                Text(
                  'You become its owner. Jobs from unverified companies go '
                  'to a short review before they are published.',
                  style: t.bodySm.copyWith(color: p.inkMuted),
                ),
                const SizedBox(height: LuzSpace.md),
                const CompanyForm(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Invitations addressed to the signed-in user, with accept / decline.
class MyInvitationsCard extends ConsumerWidget {
  const MyInvitationsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invites = ref.watch(invitesProvider).value ?? const [];
    final email = ref.watch(myEmailProvider);
    final mine = invites.where((i) => i.email == email).toList();
    if (mine.isEmpty) return const SizedBox.shrink();
    final t = context.luzText;
    final actions = ref.read(employerActionsProvider);
    return LuzCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Invitations', style: t.wsSection),
          const SizedBox(height: LuzSpace.sm),
          for (final i in mine)
            Padding(
              padding: const EdgeInsets.only(bottom: LuzSpace.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Join ${i.companyName ?? 'a company'} as '
                      '${i.role.label.toLowerCase()}',
                      style: t.body,
                    ),
                  ),
                  LuzButton.accent(
                    label: 'Accept',
                    onPressed: () => runWithToast(
                      context,
                      () => actions.acceptInvite(i.id),
                      success: 'Welcome to ${i.companyName ?? 'the team'}',
                    ),
                  ),
                  const SizedBox(width: LuzSpace.xs),
                  LuzButton(
                    label: 'Decline',
                    onPressed: () =>
                        runWithToast(context, () => actions.deleteInvite(i.id)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The signed-in user's email (lower case), for matching invitations.
final myEmailProvider = Provider<String?>((ref) {
  final auth = ref.watch(authControllerProvider);
  return auth is SignedIn ? auth.user.email.toLowerCase() : null;
});

/// Small status chip for job states (icon + text, never colour alone).
class JobStatusChip extends StatelessWidget {
  const JobStatusChip(this.status, {super.key});
  final JobStatus status;

  @override
  Widget build(BuildContext context) => LuzStatusChip(
    label: status.label,
    tone: switch (status) {
      JobStatus.published => LuzChipTone.green,
      JobStatus.pendingReview => LuzChipTone.orange,
      JobStatus.draft => LuzChipTone.neutral,
      JobStatus.rejected => LuzChipTone.red,
      JobStatus.closed || JobStatus.archived => LuzChipTone.neutral,
    },
    icon: switch (status) {
      JobStatus.published => Icons.public,
      JobStatus.pendingReview => Icons.hourglass_top,
      JobStatus.draft => Icons.edit_note,
      JobStatus.rejected => Icons.block,
      JobStatus.closed || JobStatus.archived => Icons.lock_outline,
    },
  );
}

/// Read-only notice for viewers.
class ViewerNotice extends StatelessWidget {
  const ViewerNotice({super.key});

  @override
  Widget build(BuildContext context) => Text(
    'You have view-only access. Ask an owner to make you a recruiter to edit.',
    style: context.luzText.bodySm.copyWith(color: context.luz.inkMuted),
  );
}

/// Shows [e] as a readable message.
String messageOf(Object e) => mapDbError(e).message;

/// Company display helper.
String companyFacts(Company c) => [
  c.industry,
  if (c.sizeRange != null) '${c.sizeRange} people',
  c.hqLocation,
].whereType<String>().where((s) => s.isNotEmpty).join(' · ');

/// The company the workspace is showing, with a way to switch. Only shown
/// to people in more than one company; lives in the workspace sidebar (or
/// the top bar when the sidebar is a rail), so every page can switch.
class CompanySwitcher extends ConsumerWidget {
  const CompanySwitcher({super.key, this.compact = false});

  /// Top bar: a smaller pill with the name capped at 180 px.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(myCompaniesProvider).value ?? const <Membership>[];
    final current = ref.watch(currentMembershipProvider).value;
    if (all.length < 2 || current == null) return const SizedBox.shrink();
    final p = context.luz;
    final t = context.luzText;
    final c = current.company;
    return LuzPressable(
      radius: LuzRadius.sm,
      semanticLabel: 'Company: ${c.name}. Switch company',
      tooltip: 'Switch company',
      onPressed: () => _pick(context, ref, all, c.id),
      builder: (context, pressed, hovered) => LuzSurface(
        depth: pressed ? LuzDepth.insetSm : LuzDepth.raisedSm,
        radius: LuzRadius.sm,
        outline: p.outline,
        padding: const EdgeInsets.fromLTRB(6, 6, 10, 6),
        child: Row(
          mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
          children: [
            LuzLogoSocket(
              name: c.name,
              logoUrl: _logo(ref, c),
              size: compact ? 28 : 32,
            ),
            const SizedBox(width: LuzSpace.sm),
            Flexible(
              fit: compact ? FlexFit.loose : FlexFit.tight,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: compact ? 180 : double.infinity,
                ),
                child: Text(
                  c.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodySm.copyWith(
                    color: p.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: LuzSpace.xs),
            Icon(Icons.unfold_more, size: 18, color: p.inkMuted),
          ],
        ),
      ),
    );
  }

  static String? _logo(WidgetRef ref, Company c) => c.logoPath == null
      ? null
      : ref.read(employerRepositoryProvider).logoUrl(c.logoPath!);

  static void _pick(
    BuildContext context,
    WidgetRef ref,
    List<Membership> all,
    String currentId,
  ) {
    showLuzModal<void>(
      context: context,
      title: 'Switch company',
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final m in all)
            LuzRadio<String>(
              value: m.company.id,
              groupValue: currentId,
              label: '${m.company.name} · ${m.role.label}',
              onChanged: (id) {
                ref.read(selectedCompanyProvider.notifier).select(id);
                Navigator.of(ctx).pop();
              },
            ),
        ],
      ),
    );
  }
}
