import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/data/enums.dart';
import '../../../core/data/failures.dart';
import '../../notifications/application/notification_providers.dart'
    show forgetPushDevice;
import '../data/account_api.dart';
import '../data/auth_gateway.dart';
import '../domain/auth_state.dart';

/// Overridden in main() with the config the services were started with.
final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);

final authGatewayProvider = Provider<AuthGateway>((ref) {
  final config = ref.watch(appConfigProvider);
  return config.isAuthConfigured
      ? FirebaseAuthGateway()
      : const DisabledAuthGateway();
});

final accountApiProvider = Provider<AccountApi>(
  (ref) => AccountApi(ref.watch(appConfigProvider)),
);

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

/// Orchestrates sign-in journeys. Screens call these methods and show the
/// [AppFailure] message if one is thrown; the router reacts to [state].
class AuthController extends Notifier<AuthState> {
  late AuthGateway _gateway;
  bool _busy = false;

  @override
  AuthState build() {
    _gateway = ref.watch(authGatewayProvider);
    if (!_gateway.isConfigured) return const SignedOut();
    final sub = _gateway.userChanges().listen((user) {
      // While a multi-step journey runs, it sets the final state itself.
      if (!_busy) state = authStateFor(user);
    });
    ref.onDispose(sub.cancel);
    return const AuthLoading();
  }

  bool get isConfigured => _gateway.isConfigured;

  Future<void> signIn(String email, String password) => _run(() async {
    await _gateway.signInWithEmail(email, password);
    await _sync();
  });

  /// Creates the Firebase account, sets the role + profile through the API,
  /// and sends the verification email.
  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
    required AppRole role,
  }) => _run(() async {
    await _gateway.signUpWithEmail(
      email: email,
      password: password,
      displayName: displayName,
    );
    await _bootstrap(role, displayName);
    try {
      await _gateway.sendEmailVerification();
    } on AppFailure {
      // The verify screen offers "Resend"; don't fail the whole sign-up.
    }
    await _sync();
  });

  Future<void> signInWithGoogle() => _run(() async {
    await _gateway.signInWithGoogle();
    await _sync();
  });

  /// For accounts without a role yet (first Google sign-in, or a sign-up
  /// whose setup step failed).
  Future<void> chooseRole(AppRole role) => _run(() async {
    if (role == AppRole.admin) {
      throw const AppFailure('That role is not available.');
    }
    await _bootstrap(role, null);
    await _sync();
  });

  /// "I've verified my email" — returns true once the account is verified.
  Future<bool> checkEmailVerified() async {
    await _run(_sync);
    return state is SignedIn;
  }

  Future<void> resendVerification() => _gateway.sendEmailVerification();

  Future<void> sendPasswordReset(String email) =>
      _gateway.sendPasswordReset(email);

  /// Claims admin access (owner's allow-list), then refreshes the token so
  /// the new role applies at once.
  Future<void> claimAdmin() => _run(() async {
    final token = await _gateway.idToken();
    if (token == null) {
      throw const AppFailure(
        'Your session ended. Sign in again.',
        code: 'auth/no-session',
      );
    }
    await ref.read(accountApiProvider).claimAdmin(idToken: token);
    await _sync();
  });

  Future<void> signOut() async {
    await forgetPushDevice(ref);
    await _gateway.signOut();
    state = const SignedOut();
  }

  Future<void> _bootstrap(AppRole role, String? displayName) async {
    final token = await _gateway.idToken();
    if (token == null) {
      throw const AppFailure(
        'Your session ended. Sign in again.',
        code: 'auth/no-session',
      );
    }
    await ref
        .read(accountApiProvider)
        .bootstrap(idToken: token, role: role, displayName: displayName);
  }

  Future<void> _sync() async {
    state = authStateFor(await _gateway.refresh());
  }

  Future<void> _run(Future<void> Function() journey) async {
    if (_busy) return;
    _busy = true;
    try {
      await journey();
    } catch (_) {
      // Leave the state consistent with whatever did succeed.
      state = authStateFor(_gateway.currentUser);
      rethrow;
    } finally {
      _busy = false;
    }
  }
}
