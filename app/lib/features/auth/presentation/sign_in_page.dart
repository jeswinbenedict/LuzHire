import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../application/auth_controller.dart';
import 'auth_layout.dart';

class SignInPage extends ConsumerStatefulWidget {
  const SignInPage({super.key, this.from});

  /// Where to return after signing in (validated by the router).
  final String? from;

  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<SignInPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _emailError;
  String? _passwordError;
  String? _formError;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _emailError = validateEmail(_email.text);
      _passwordError = _password.text.isEmpty ? 'Enter your password.' : null;
      _formError = null;
    });
    if (_emailError != null || _passwordError != null) return;
    await _go(
      () => ref
          .read(authControllerProvider.notifier)
          .signIn(_email.text, _password.text),
    );
  }

  Future<void> _google() =>
      _go(() => ref.read(authControllerProvider.notifier).signInWithGoogle());

  Future<void> _go(Future<void> Function() action) async {
    setState(() => _busy = true);
    final error = await runAuthAction(action);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _formError = error;
    });
  }

  String _withFrom(String path) => widget.from == null
      ? path
      : Uri(path: path, queryParameters: {'from': widget.from}).toString();

  @override
  Widget build(BuildContext context) {
    final configured = ref.watch(authControllerProvider.notifier).isConfigured;
    final enabled = configured && !_busy;
    return AuthLayout(
      title: 'Welcome back',
      subtitle: 'Sign in to track applications and manage your hiring.',
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_formError != null) ...[
              AuthNotice(message: _formError!, tone: LuzChipTone.red),
              const SizedBox(height: LuzSpace.md),
            ],
            LuzTextField(
              label: 'Email',
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
              error: _passwordError,
              onSubmitted: (_) => enabled ? _submit() : null,
            ),
            const SizedBox(height: LuzSpace.xs),
            Align(
              alignment: Alignment.centerRight,
              child: LuzTextLink(
                label: 'Forgot password?',
                onPressed: () => context.go('/forgot-password'),
              ),
            ),
            const SizedBox(height: LuzSpace.lg),
            LuzButton.accent(
              label: _busy ? 'Signing in…' : 'Sign in',
              expand: true,
              onPressed: enabled ? _submit : null,
            ),
            const OrDivider(),
            LuzButton(
              label: 'Continue with Google',
              leading: const GoogleLogo(),
              expand: true,
              onPressed: enabled ? _google : null,
            ),
            const SizedBox(height: LuzSpace.lg),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: LuzSpace.xs,
              children: [
                Text(
                  'New to LuzHire?',
                  style: context.luzText.label.copyWith(
                    color: context.luz.muted,
                  ),
                ),
                LuzTextLink(
                  label: 'Create an account',
                  onPressed: () => context.go(_withFrom('/sign-up')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
