import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/enums.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../application/auth_controller.dart';
import 'auth_layout.dart';

class SignUpPage extends ConsumerStatefulWidget {
  const SignUpPage({super.key, this.initialRole, this.from});

  /// `?role=employer` pre-selects the employer option (from "For employers").
  final AppRole? initialRole;
  final String? from;

  @override
  ConsumerState<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends ConsumerState<SignUpPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  late AppRole _role = widget.initialRole == AppRole.employer
      ? AppRole.employer
      : AppRole.candidate;
  String? _nameError;
  String? _emailError;
  String? _passwordError;
  String? _formError;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _nameError = validateName(_name.text);
      _emailError = validateEmail(_email.text);
      _passwordError = validateNewPassword(_password.text);
      _formError = null;
    });
    if (_nameError != null || _emailError != null || _passwordError != null) {
      return;
    }
    await _go(
      () => ref
          .read(authControllerProvider.notifier)
          .signUp(
            email: _email.text,
            password: _password.text,
            displayName: _name.text,
            role: _role,
          ),
    );
  }

  Future<void> _go(Future<void> Function() action) async {
    setState(() => _busy = true);
    final error = await runAuthAction(action);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _formError = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final configured = ref.watch(authControllerProvider.notifier).isConfigured;
    final enabled = configured && !_busy;
    final p = context.luz;
    return AuthLayout(
      title: 'Create your account',
      subtitle: 'Free for job seekers and employers.',
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_formError != null) ...[
              AuthNotice(message: _formError!, tone: LuzChipTone.red),
              const SizedBox(height: LuzSpace.md),
            ],
            Text(
              'I want to',
              style: context.luzText.label.copyWith(color: p.inkMuted),
            ),
            const SizedBox(height: LuzSpace.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: LuzSegmented<AppRole>(
                segments: const [
                  (
                    value: AppRole.candidate,
                    label: 'Find a job',
                    icon: Icons.person_search_outlined,
                  ),
                  (
                    value: AppRole.employer,
                    label: 'Hire people',
                    icon: Icons.business_center_outlined,
                  ),
                ],
                selected: _role,
                onChanged: (r) => setState(() => _role = r),
              ),
            ),
            const SizedBox(height: LuzSpace.lg),
            LuzTextField(
              label: _role == AppRole.employer ? 'Your name' : 'Full name',
              controller: _name,
              prefixIcon: Icons.badge_outlined,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              error: _nameError,
              enabled: configured,
            ),
            const SizedBox(height: LuzSpace.md),
            LuzTextField(
              label: _role == AppRole.employer ? 'Work email' : 'Email',
              controller: _email,
              hint: 'you@example.com',
              prefixIcon: Icons.mail_outline,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              error: _emailError,
              enabled: configured,
            ),
            const SizedBox(height: LuzSpace.md),
            PasswordField(
              controller: _password,
              newPassword: true,
              error: _passwordError,
              helper: 'At least 8 characters, with a letter and a number.',
              onSubmitted: (_) => enabled ? _submit() : null,
            ),
            const SizedBox(height: LuzSpace.lg),
            LuzButton.accent(
              label: _busy ? 'Creating account…' : 'Create account',
              expand: true,
              onPressed: enabled ? _submit : null,
            ),
            const OrDivider(),
            LuzButton(
              label: 'Continue with Google',
              icon: Icons.account_circle_outlined,
              expand: true,
              onPressed: enabled
                  ? () => _go(
                      () => ref
                          .read(authControllerProvider.notifier)
                          .signInWithGoogle(),
                    )
                  : null,
            ),
            const SizedBox(height: LuzSpace.md),
            Text(
              "We'll email you a link to confirm your address. By creating an account you agree to the Terms and Privacy Policy.",
              style: context.luzText.caption.copyWith(color: p.muted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: LuzSpace.md),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: LuzSpace.xs,
              children: [
                Text(
                  'Already have an account?',
                  style: context.luzText.label.copyWith(color: p.muted),
                ),
                LuzTextLink(
                  label: 'Sign in',
                  onPressed: () => context.go(
                    widget.from == null
                        ? '/sign-in'
                        : Uri(
                            path: '/sign-in',
                            queryParameters: {'from': widget.from},
                          ).toString(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
