import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/brand/luz_logo.dart';
import '../../../core/data/enums.dart';
import '../../../core/data/failures.dart';
import '../../../core/router/auth_redirect.dart';
import '../../../core/shell/shell_common.dart' show ThemeModeSelector;
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../application/auth_controller.dart';
import '../domain/auth_state.dart';
import 'auth_layout.dart';

// ------------------------------------------------------------------ verify email

class VerifyEmailPage extends ConsumerStatefulWidget {
  const VerifyEmailPage({super.key});

  @override
  ConsumerState<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends ConsumerState<VerifyEmailPage> {
  String? _notice;
  LuzChipTone _tone = LuzChipTone.neutral;
  bool _busy = false;
  int _cooldown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    setState(() => _busy = true);
    var verified = false;
    final error = await runAuthAction(() async {
      verified = await ref
          .read(authControllerProvider.notifier)
          .checkEmailVerified();
    });
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (error != null) {
        _notice = error;
        _tone = LuzChipTone.red;
      } else if (!verified) {
        _notice = "We couldn't see the confirmation yet. Open the link in the email, then try again.";
        _tone = LuzChipTone.orange;
      }
    });
  }

  Future<void> _resend() async {
    final error = await runAuthAction(
      ref.read(authControllerProvider.notifier).resendVerification,
    );
    if (!mounted) return;
    setState(() {
      _notice = error ?? 'Sent. Check your inbox and spam folder.';
      _tone = error == null ? LuzChipTone.green : LuzChipTone.red;
      _cooldown = error == null ? 30 : 0;
    });
    _timer?.cancel();
    if (_cooldown > 0) {
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted || _cooldown <= 1) {
          t.cancel();
          if (mounted) setState(() => _cooldown = 0);
          return;
        }
        setState(() => _cooldown--);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final email = switch (auth) {
      NeedsEmailVerification(:final user) => user.email,
      _ => 'your email',
    };
    return AuthLayout(
      title: 'Check your inbox',
      subtitle:
          'We sent a confirmation link to $email. Open it to activate your account.',
      showBrandPanel: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: LuzSurface(
              depth: LuzDepth.insetMd,
              radius: LuzRadius.pill,
              child: SizedBox.square(
                dimension: 88,
                child: Icon(
                  Icons.mark_email_unread_outlined,
                  size: 38,
                  color: context.luz.accent,
                ),
              ),
            ),
          ),
          const SizedBox(height: LuzSpace.lg),
          if (_notice != null) ...[
            AuthNotice(
              message: _notice!,
              tone: _tone,
              icon: Icons.info_outline,
            ),
            const SizedBox(height: LuzSpace.md),
          ],
          LuzButton.accent(
            label: _busy ? 'Checking…' : "I've confirmed my email",
            expand: true,
            onPressed: _busy ? null : _check,
          ),
          const SizedBox(height: LuzSpace.md),
          LuzButton(
            label: _cooldown > 0
                ? 'Resend in ${_cooldown}s'
                : 'Resend the email',
            icon: Icons.refresh,
            expand: true,
            onPressed: _cooldown > 0 ? null : _resend,
          ),
          const SizedBox(height: LuzSpace.lg),
          Center(
            child: LuzTextLink(
              label: 'Use a different account',
              onPressed: () =>
                  ref.read(authControllerProvider.notifier).signOut(),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ forgot password

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _email = TextEditingController();
  String? _emailError;
  String? _error;
  bool _sent = false;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _emailError = validateEmail(_email.text));
    if (_emailError != null) return;
    setState(() => _busy = true);
    final error = await runAuthAction(
      () => ref
          .read(authControllerProvider.notifier)
          .sendPasswordReset(_email.text),
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      // Never reveal whether an account exists for this email.
      final unknownUser = error == null || error.contains('incorrect');
      _sent = unknownUser;
      _error = unknownUser ? null : error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final configured = ref.watch(authControllerProvider.notifier).isConfigured;
    return AuthLayout(
      title: 'Reset your password',
      subtitle: "Enter your email and we'll send you a link to choose a new password.",
      showBrandPanel: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_sent) ...[
            const AuthNotice(
              message: 'If an account exists for that email, a reset link is on its way.',
              icon: Icons.check_circle_outline,
              tone: LuzChipTone.green,
            ),
            const SizedBox(height: LuzSpace.md),
          ],
          if (_error != null) ...[
            AuthNotice(message: _error!, tone: LuzChipTone.red),
            const SizedBox(height: LuzSpace.md),
          ],
          LuzTextField(
            label: 'Email',
            controller: _email,
            hint: 'you@example.com',
            prefixIcon: Icons.mail_outline,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            error: _emailError,
            enabled: configured,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: LuzSpace.lg),
          LuzButton.accent(
            label: _busy ? 'Sending…' : 'Send reset link',
            expand: true,
            onPressed: configured && !_busy ? _submit : null,
          ),
          const SizedBox(height: LuzSpace.lg),
          Center(
            child: LuzTextLink(
              label: 'Back to sign in',
              onPressed: () => context.go('/sign-in'),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ choose role

class ChooseRolePage extends ConsumerStatefulWidget {
  const ChooseRolePage({super.key});

  @override
  ConsumerState<ChooseRolePage> createState() => _ChooseRolePageState();
}

class _ChooseRolePageState extends ConsumerState<ChooseRolePage> {
  AppRole? _role;
  String? _error;
  bool _busy = false;

  Future<void> _continue() async {
    final role = _role;
    if (role == null) {
      setState(() => _error = 'Choose how you will use LuzHire.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await runAuthAction(
      () => ref.read(authControllerProvider.notifier).chooseRole(role),
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'How will you use LuzHire?',
      subtitle: 'You can always contact support to change this later.',
      showBrandPanel: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            AuthNotice(message: _error!, tone: LuzChipTone.red),
            const SizedBox(height: LuzSpace.md),
          ],
          _RoleOption(
            icon: Icons.person_search_outlined,
            title: 'I want to find a job',
            body: 'Build a profile, apply in a few taps and track every application.',
            selected: _role == AppRole.candidate,
            onTap: () => setState(() => _role = AppRole.candidate),
          ),
          const SizedBox(height: LuzSpace.md),
          _RoleOption(
            icon: Icons.business_center_outlined,
            title: 'I want to hire',
            body: 'Create a company page, post jobs and manage your pipeline.',
            selected: _role == AppRole.employer,
            onTap: () => setState(() => _role = AppRole.employer),
          ),
          const SizedBox(height: LuzSpace.lg),
          LuzButton.accent(
            label: _busy ? 'Setting up…' : 'Continue',
            expand: true,
            onPressed: _busy ? null : _continue,
          ),
          const SizedBox(height: LuzSpace.md),
          Center(
            child: LuzTextLink(
              label: 'Sign out',
              onPressed: () =>
                  ref.read(authControllerProvider.notifier).signOut(),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleOption extends StatelessWidget {
  const _RoleOption({
    required this.icon,
    required this.title,
    required this.body,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    return LuzPressable(
      onPressed: onTap,
      radius: LuzRadius.lg,
      semanticLabel: '$title. $body',
      selected: selected,
      builder: (context, pressed, _) => LuzSurface(
        depth: selected || pressed ? LuzDepth.insetSm : LuzDepth.raisedSm,
        radius: LuzRadius.lg,
        outline: selected ? p.accent : null,
        outlineWidth: 2,
        padding: const EdgeInsets.all(LuzSpace.md),
        child: Row(
          children: [
            Icon(icon, color: selected ? p.accent : p.inkMuted, size: 28),
            const SizedBox(width: LuzSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.luzText.wsCardTitle),
                  const SizedBox(height: 2),
                  Text(
                    body,
                    style: context.luzText.bodySm.copyWith(color: p.inkMuted),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? p.accent : p.outline,
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ loading / no access / account

class AuthLoadingPage extends StatelessWidget {
  const AuthLoadingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LuzLogoMark(size: 56),
          SizedBox(height: LuzSpace.lg),
          SizedBox(width: 160, child: LuzSkeleton(height: 10)),
        ],
      ),
    );
  }
}

class NoAccessPage extends ConsumerWidget {
  const NoAccessPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final home = auth is SignedIn ? homeFor(auth.role) : '/';
    return LuzEmptyState(
      icon: Icons.lock_outline,
      title: "You don't have access to this page",
      message: 'It belongs to a different type of account.',
      actionLabel: 'Go to my dashboard',
      onAction: () => context.go(home),
    );
  }
}

class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    if (auth is! SignedIn) return const AuthLoadingPage();
    final user = auth.user;
    final t = context.luzText;
    final p = context.luz;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(LuzSpace.lg),
      child: Center(
        child: ConstrainedBox(
          // Same column as Notification settings, one step deeper.
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Account', style: t.h3),
              const SizedBox(height: LuzSpace.lg),
              LuzCard(
                child: Row(
                  children: [
                    LuzAvatar(name: user.displayName, size: 56),
                    const SizedBox(width: LuzSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.displayName, style: t.h4),
                          Text(
                            user.email,
                            style: t.bodySm.copyWith(color: p.inkMuted),
                          ),
                          const SizedBox(height: LuzSpace.xs),
                          LuzStatusChip(
                            label: switch (auth.role) {
                              AppRole.candidate => 'Job seeker',
                              AppRole.employer => 'Employer',
                              AppRole.admin => 'Administrator',
                            },
                            tone: LuzChipTone.neutral,
                            icon: Icons.badge_outlined,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: LuzSpace.lg),
              LuzCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Appearance', style: t.wsSection),
                    const SizedBox(height: LuzSpace.md),
                    const ThemeModeSelector(),
                  ],
                ),
              ),
              const SizedBox(height: LuzSpace.lg),
              LuzCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Notifications', style: t.wsSection),
                    const SizedBox(height: LuzSpace.xs),
                    Text(
                      'Push on this device, and which updates also arrive '
                      'by push or email.',
                      style: t.bodySm.copyWith(color: p.inkMuted),
                    ),
                    const SizedBox(height: LuzSpace.sm),
                    LuzButton(
                      label: 'Notification settings',
                      icon: Icons.notifications_outlined,
                      onPressed: () => context.go('/account/notifications'),
                    ),
                  ],
                ),
              ),
              if (auth.role != AppRole.admin) ...[
                const SizedBox(height: LuzSpace.lg),
                const _ClaimAdminCard(),
              ],
              const SizedBox(height: LuzSpace.lg),
              LuzButton(
                label: 'Sign out',
                icon: Icons.logout,
                onPressed: () =>
                    ref.read(authControllerProvider.notifier).signOut(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// First-admin setup: works only for a verified email the project owner
/// listed in ADMIN_EMAILS (Vercel). Everyone else gets a clear refusal.
class _ClaimAdminCard extends ConsumerStatefulWidget {
  const _ClaimAdminCard();

  @override
  ConsumerState<_ClaimAdminCard> createState() => _ClaimAdminCardState();
}

class _ClaimAdminCardState extends ConsumerState<_ClaimAdminCard> {
  bool _busy = false;

  Future<void> _claim() async {
    setState(() => _busy = true);
    try {
      await ref.read(authControllerProvider.notifier).claimAdmin();
      if (!mounted) return;
      showLuzToast(context, 'You are now an administrator', icon: Icons.check);
      context.go('/admin');
    } on AppFailure catch (e) {
      if (mounted) showLuzToast(context, e.message, icon: Icons.error_outline);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.luzText;
    final p = context.luz;
    return LuzCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Admin access', style: t.wsSection),
          const SizedBox(height: LuzSpace.xs),
          Text(
            'Only for the LuzHire team: works if the project owner added your '
            'email to the admin list.',
            style: t.bodySm.copyWith(color: p.inkMuted),
          ),
          const SizedBox(height: LuzSpace.sm),
          LuzButton(
            label: _busy ? 'Checking…' : 'Claim admin access',
            icon: Icons.admin_panel_settings_outlined,
            onPressed: _busy ? null : _claim,
          ),
        ],
      ),
    );
  }
}
