import 'package:flutter/foundation.dart';

import '../../../core/data/enums.dart';

/// The signed-in Firebase user, plus the LuzHire role from custom claims.
@immutable
class AuthUser {
  const AuthUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.emailVerified,
    required this.usesPassword,
    this.appRole,
  });

  final String uid;
  final String email;
  final String displayName;
  final bool emailVerified;

  /// Email/password accounts must verify their email; Google accounts are
  /// verified by Google already.
  final bool usesPassword;

  /// Null until /api/auth/bootstrap has set the claim.
  final AppRole? appRole;

  bool get needsVerification => usesPassword && !emailVerified;

  @override
  bool operator ==(Object other) =>
      other is AuthUser &&
      other.uid == uid &&
      other.email == email &&
      other.displayName == displayName &&
      other.emailVerified == emailVerified &&
      other.usesPassword == usesPassword &&
      other.appRole == appRole;

  @override
  int get hashCode => Object.hash(
    uid,
    email,
    displayName,
    emailVerified,
    usesPassword,
    appRole,
  );
}

/// Where the user is in the sign-in journey. Drives router redirects.
sealed class AuthState {
  const AuthState();
}

/// Firebase is restoring a previous session (app start only).
class AuthLoading extends AuthState {
  const AuthLoading();
}

class SignedOut extends AuthState {
  const SignedOut();
}

/// Signed in (e.g. first Google sign-in) but no role chosen yet.
class NeedsRole extends AuthState {
  const NeedsRole(this.user);
  final AuthUser user;
}

/// Email/password account that hasn't clicked the verification link.
class NeedsEmailVerification extends AuthState {
  const NeedsEmailVerification(this.user);
  final AuthUser user;
}

class SignedIn extends AuthState {
  const SignedIn(this.user);
  final AuthUser user;
  AppRole get role => user.appRole!;
}

/// Decides the state for a Firebase user.
AuthState authStateFor(AuthUser? user) {
  if (user == null) return const SignedOut();
  if (user.appRole == null) return NeedsRole(user);
  if (user.needsVerification) return NeedsEmailVerification(user);
  return SignedIn(user);
}
