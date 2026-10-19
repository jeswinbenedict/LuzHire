import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/brand/luz_logo.dart';
import '../../../core/data/failures.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../application/auth_controller.dart';

/// Shared frame for auth screens: brand panel + form card on wide screens,
/// a single centred column on phones.
class AuthLayout extends ConsumerWidget {
  const AuthLayout({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.showBrandPanel = true,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final bool showBrandPanel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configured = ref.watch(authControllerProvider.notifier).isConfigured;
    final t = context.luzText;
    final p = context.luz;

    final form = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: LuzCard(
        padding: const EdgeInsets.all(LuzSpace.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(header: true, child: Text(title, style: t.h3)),
            if (subtitle != null) ...[
              const SizedBox(height: LuzSpace.xs),
              Text(subtitle!, style: t.body.copyWith(color: p.inkMuted)),
            ],
            const SizedBox(height: LuzSpace.lg),
            if (!configured) ...[
              const AuthNotice(
                icon: Icons.info_outline,
                message: 'Sign-in is not available in this build yet. It turns on once Firebase and Supabase are configured.',
              ),
              const SizedBox(height: LuzSpace.lg),
            ],
            child,
          ],
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, c) {
        final wide = showBrandPanel && c.maxWidth >= 900;
        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: c.maxWidth < 600 ? LuzSpace.md : LuzSpace.xl,
            vertical: LuzSpace.xl,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Expanded(child: _BrandPanel()),
                        const SizedBox(width: LuzSpace.xxl),
                        form,
                      ],
                    )
                  : Center(child: form),
            ),
          ),
        );
      },
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    final t = context.luzText;
    final p = context.luz;
    Widget point(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(bottom: LuzSpace.md),
      child: Row(
        children: [
          LuzSurface(
            depth: LuzDepth.insetSm,
            radius: LuzRadius.sm,
            child: SizedBox.square(
              dimension: 40,
              child: Icon(icon, size: 20, color: p.accent),
            ),
          ),
          const SizedBox(width: LuzSpace.md),
          Expanded(
            child: Text(text, style: t.body.copyWith(color: p.inkMuted)),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const LuzLogo(size: 40),
        const SizedBox(height: LuzSpace.xl),
        Text('One account for your whole job search.', style: t.h2),
        const SizedBox(height: LuzSpace.lg),
        point(
          Icons.verified_outlined,
          'Apply to roles from verified employers.',
        ),
        point(
          Icons.bolt_outlined,
          'See every stage change the moment it happens.',
        ),
        point(
          Icons.devices_outlined,
          'Pick up where you left off on web, Android or iOS.',
        ),
      ],
    );
  }
}

/// Inline message box inside forms (errors, info, success).
class AuthNotice extends StatelessWidget {
  const AuthNotice({
    super.key,
    required this.message,
    this.icon = Icons.error_outline,
    this.tone = LuzChipTone.neutral,
  });

  final String message;
  final IconData icon;
  final LuzChipTone tone;

  @override
  Widget build(BuildContext context) {
    final c = context.luz.chips[tone]!;
    return Semantics(
      liveRegion: true,
      child: LuzSurface(
        depth: LuzDepth.insetSm,
        radius: LuzRadius.md,
        color: c.background,
        padding: const EdgeInsets.all(LuzSpace.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: c.foreground),
            const SizedBox(width: LuzSpace.sm),
            Expanded(
              child: Text(
                message,
                style: context.luzText.bodySm.copyWith(color: c.foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "or" divider between password and Google sign-in.
class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: LuzSpace.md),
      child: Row(
        children: [
          Expanded(child: Divider(color: p.hairline)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: LuzSpace.sm),
            child: Text(
              'or',
              style: context.luzText.caption.copyWith(color: p.muted),
            ),
          ),
          Expanded(child: Divider(color: p.hairline)),
        ],
      ),
    );
  }
}

/// Password field with a show/hide toggle.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    this.label = 'Password',
    this.error,
    this.helper,
    this.onSubmitted,
    this.newPassword = false,
  });

  final TextEditingController controller;
  final String label;
  final String? error;
  final String? helper;
  final ValueChanged<String>? onSubmitted;
  final bool newPassword;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    return LuzTextField(
      label: widget.label,
      controller: widget.controller,
      obscureText: !_visible,
      error: widget.error,
      helper: widget.helper,
      prefixIcon: Icons.lock_outline,
      textInputAction: TextInputAction.done,
      onSubmitted: widget.onSubmitted,
      autofillHints: [
        widget.newPassword ? AutofillHints.newPassword : AutofillHints.password,
      ],
      suffix: IconButton(
        tooltip: _visible ? 'Hide password' : 'Show password',
        icon: Icon(
          _visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          size: 20,
        ),
        onPressed: () => setState(() => _visible = !_visible),
      ),
    );
  }
}

// ------------------------------------------------------------------ validation

String? validateEmail(String v) {
  final s = v.trim();
  if (s.isEmpty) return 'Enter your email address.';
  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(s)) {
    return 'Enter a valid email address.';
  }
  return null;
}

String? validateNewPassword(String v) {
  if (v.length < 8) return 'Use at least 8 characters.';
  if (!RegExp(r'[A-Za-z]').hasMatch(v) || !RegExp(r'\d').hasMatch(v)) {
    return 'Use at least one letter and one number.';
  }
  return null;
}

String? validateName(String v) {
  final s = v.trim();
  if (s.isEmpty) return 'Enter your name.';
  if (s.length > 120) return 'That name is too long.';
  return null;
}

/// Runs an auth action, returning the error message to show (or null).
Future<String?> runAuthAction(Future<void> Function() action) async {
  try {
    await action();
    return null;
  } on AppFailure catch (e) {
    return e.code == 'auth/cancelled' ? null : e.message;
  } catch (e) {
    return mapDbError(e).message;
  }
}

/// Google's official "G" mark, unaltered, for "Continue with Google"
/// (per Google's sign-in branding guidelines: full colour, ~18 px).
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key, this.size = 18});
  final double size;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/brand/google_g.svg',
    width: size,
    height: size,
    excludeFromSemantics: true, // the button label already says "Google"
  );
}
