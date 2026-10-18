import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../core/data/enums.dart';
import '../../../core/data/failures.dart';
import '../domain/auth_state.dart';

/// Everything the app needs from the identity provider. Firebase in
/// production; fakes in tests; [DisabledAuthGateway] when a build has no
/// Firebase config.
abstract class AuthGateway {
  bool get isConfigured;
  AuthUser? get currentUser;

  /// Emits on sign-in, sign-out and token refresh (claims may change).
  Stream<AuthUser?> userChanges();

  Future<void> signInWithEmail(String email, String password);
  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  });
  Future<void> signInWithGoogle();
  Future<void> sendEmailVerification();
  Future<void> sendPasswordReset(String email);

  /// Reloads the user and forces a fresh ID token (new claims,
  /// email_verified), returning the up-to-date user.
  Future<AuthUser?> refresh();
  Future<String?> idToken({bool forceRefresh = false});
  Future<void> signOut();
}

class FirebaseAuthGateway implements AuthGateway {
  FirebaseAuthGateway([FirebaseAuth? auth])
    : _auth = auth ?? FirebaseAuth.instance;
  final FirebaseAuth _auth;
  AuthUser? _current;

  @override
  bool get isConfigured => true;

  @override
  AuthUser? get currentUser => _current;

  @override
  Stream<AuthUser?> userChanges() => _auth.idTokenChanges().asyncMap((u) async {
    _current = u == null ? null : await _toAuthUser(u);
    return _current;
  });

  Future<AuthUser> _toAuthUser(User u) async {
    final token = await u.getIdTokenResult();
    final role = token.claims?['app_role'] as String?;
    return AuthUser(
      uid: u.uid,
      email: u.email ?? '',
      displayName: (u.displayName?.trim().isNotEmpty ?? false)
          ? u.displayName!.trim()
          : (u.email ?? '').split('@').first,
      emailVerified: u.emailVerified,
      usesPassword: u.providerData.any((p) => p.providerId == 'password'),
      appRole: role == null ? null : AppRole.fromDb(role),
    );
  }

  @override
  Future<void> signInWithEmail(String email, String password) => _guard(
    () => _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    ),
  );

  @override
  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) => _guard(() async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await cred.user?.updateDisplayName(displayName.trim());
  });

  @override
  Future<void> signInWithGoogle() => _guard(() async {
    final provider = GoogleAuthProvider()
      ..setCustomParameters({'prompt': 'select_account'});
    if (kIsWeb) {
      await _auth.signInWithPopup(provider);
    } else {
      await _auth.signInWithProvider(provider);
    }
  });

  @override
  Future<void> sendEmailVerification() =>
      _guard(() async => _auth.currentUser?.sendEmailVerification());

  @override
  Future<void> sendPasswordReset(String email) =>
      _guard(() => _auth.sendPasswordResetEmail(email: email.trim()));

  @override
  Future<AuthUser?> refresh() => _guard(() async {
    final u = _auth.currentUser;
    if (u == null) return null;
    await u.reload();
    final fresh = _auth.currentUser!;
    await fresh.getIdToken(true);
    return _current = await _toAuthUser(fresh);
  });

  @override
  Future<String?> idToken({bool forceRefresh = false}) =>
      _guard(() async => _auth.currentUser?.getIdToken(forceRefresh));

  @override
  Future<void> signOut() => _auth.signOut();

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseAuthException catch (e) {
      throw mapAuthError(e.code);
    }
  }
}

/// Friendly messages for Firebase Auth error codes. Sign-in errors never
/// reveal whether an email is registered.
AppFailure mapAuthError(String code) => switch (code) {
  'invalid-credential' ||
  'wrong-password' ||
  'user-not-found' ||
  'invalid-login-credentials' => const AppFailure(
    'Email or password is incorrect.',
    code: 'auth/credentials',
  ),
  'email-already-in-use' => const AppFailure(
    'An account with this email already exists. Sign in instead.',
    code: 'auth/exists',
  ),
  'weak-password' => const AppFailure(
    'Choose a stronger password (at least 8 characters).',
    code: 'auth/weak',
  ),
  'invalid-email' => const AppFailure(
    'Enter a valid email address.',
    code: 'auth/email',
  ),
  'user-disabled' => const AppFailure(
    'This account has been suspended. Contact support.',
    code: 'auth/disabled',
  ),
  'too-many-requests' => const AppFailure(
    'Too many attempts. Wait a minute and try again.',
    code: 'auth/rate',
  ),
  'network-request-failed' => const AppFailure(
    'Check your internet connection and try again.',
    code: 'auth/network',
  ),
  'popup-closed-by-user' ||
  'cancelled-popup-request' ||
  'web-context-canceled' ||
  'canceled' => const AppFailure(
    'Sign-in was cancelled.',
    code: 'auth/cancelled',
  ),
  'popup-blocked' => const AppFailure(
    'Your browser blocked the sign-in window. Allow pop-ups and try again.',
    code: 'auth/popup',
  ),
  'account-exists-with-different-credential' => const AppFailure(
    'This email is already registered with a password. Sign in with your password.',
    code: 'auth/other-provider',
  ),
  _ => AppFailure('Sign-in failed. Please try again.', code: 'auth/$code'),
};

/// Used when the build has no Firebase/Supabase config (e.g. CI, demos).
class DisabledAuthGateway implements AuthGateway {
  const DisabledAuthGateway();
  static const _failure = AppFailure(
    'Sign-in is not available in this build yet.',
    code: 'auth/not-configured',
  );

  @override
  bool get isConfigured => false;
  @override
  AuthUser? get currentUser => null;
  @override
  Stream<AuthUser?> userChanges() => Stream.value(null);
  @override
  Future<void> signInWithEmail(String email, String password) async =>
      throw _failure;
  @override
  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async => throw _failure;
  @override
  Future<void> signInWithGoogle() async => throw _failure;
  @override
  Future<void> sendEmailVerification() async => throw _failure;
  @override
  Future<void> sendPasswordReset(String email) async => throw _failure;
  @override
  Future<AuthUser?> refresh() async => null;
  @override
  Future<String?> idToken({bool forceRefresh = false}) async => null;
  @override
  Future<void> signOut() async {}
}
