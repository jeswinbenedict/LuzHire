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
import 'company_page.dart' show CompanyForm;

/// Standard Workspace page: dense title row with actions, scrolling body.
class WorkspacePage extends StatelessWidget {
  const WorkspacePage({
    super.key,
    this.title,
    required this.children,
    this.actions = const [],
    this.subtitle,
    this.scroll = true,
  });

  /// Null when the shell's top bar already names the page.
  final String? title;
  final String? subtitle;
  final List<Widget> actions;
  final List<Widget> children;

  /// False for pages that manage their own scrolling (the kanban board).
  final bool scroll;

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    final t = context.luzText;
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(
        LuzSpace.lg,
        LuzSpace.lg,
        LuzSpace.lg,
        LuzSpace.md,
      ),
      child: Wrap(
        spacing: LuzSpace.md,
        runSpacing: LuzSpace.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (title != null)
                Semantics(header: true, child: Text(title!, style: t.wsTitle)),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: title == null
                      ? t.wsSection.copyWith(color: p.inkMuted)
                      : t.bodySm.copyWith(color: p.inkMuted),
                ),
            ],
          ),
          if (actions.isNotEmpty)
            Wrap(
              spacing: LuzSpace.sm,
              runSpacing: LuzSpace.sm,
              children: actions,
            ),
        ],
      ),
    );
    if (!scroll) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [header, ...children],
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: LuzSpace.xxl),
      children: [
        header,
        for (final c in children)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              LuzSpace.lg,
              0,
              LuzSpace.lg,
              LuzSpace.lg,
            ),
            child: c,
          ),
      ],
    );
  }
}

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
