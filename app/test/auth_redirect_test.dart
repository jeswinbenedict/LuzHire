import 'package:flutter_test/flutter_test.dart';
import 'package:luzhire/core/data/enums.dart';
import 'package:luzhire/core/router/auth_redirect.dart';
import 'package:luzhire/features/auth/domain/auth_state.dart';

AuthUser user({AppRole? role, bool verified = true, bool password = true}) =>
    AuthUser(
      uid: 'u1',
      email: 'u1@example.com',
      displayName: 'U One',
      emailVerified: verified,
      usesPassword: password,
      appRole: role,
    );

String? go(AuthState s, String location) =>
    authRedirect(s, Uri.parse(location));

void main() {
  group('signed out', () {
    const s = SignedOut();
    test('public pages are open', () {
      for (final p in [
        '/',
        '/jobs',
        '/companies',
        '/news',
        '/sign-in',
        '/dev/gallery',
      ]) {
        expect(go(s, p), isNull, reason: p);
      }
    });
    test('protected pages go to sign-in and remember where you were', () {
      expect(go(s, '/me/applications'), '/sign-in?from=%2Fme%2Fapplications');
      expect(
        go(s, '/employer/pipeline'),
        '/sign-in?from=%2Femployer%2Fpipeline',
      );
      expect(go(s, '/admin'), '/sign-in?from=%2Fadmin');
    });
  });

  group('signed in', () {
    test('each role reaches its own area', () {
      expect(go(SignedIn(user(role: AppRole.candidate)), '/me'), isNull);
      expect(
        go(SignedIn(user(role: AppRole.employer)), '/employer/jobs'),
        isNull,
      );
      expect(go(SignedIn(user(role: AppRole.admin)), '/admin/audit'), isNull);
      expect(
        go(SignedIn(user(role: AppRole.admin)), '/employer'),
        isNull,
        reason: 'admins can help employers',
      );
    });
    test('other areas show "no access"', () {
      expect(
        go(SignedIn(user(role: AppRole.candidate)), '/employer'),
        noAccessPath,
      );
      expect(
        go(SignedIn(user(role: AppRole.employer)), '/admin'),
        noAccessPath,
      );
      expect(go(SignedIn(user(role: AppRole.employer)), '/me'), noAccessPath);
    });
    test('sign-in page returns you to "from", else your home', () {
      final cand = SignedIn(user(role: AppRole.candidate));
      expect(go(cand, '/sign-in?from=%2Fme%2Fsaved'), '/me/saved');
      expect(go(cand, '/sign-in'), '/me');
      expect(
        go(SignedIn(user(role: AppRole.employer)), '/sign-up'),
        '/employer',
      );
    });
    test('"from" that the role cannot open falls back to home', () {
      expect(
        go(SignedIn(user(role: AppRole.candidate)), '/sign-in?from=%2Fadmin'),
        '/me',
      );
    });
    test('open redirects are ignored', () {
      final cand = SignedIn(user(role: AppRole.candidate));
      expect(go(cand, '/sign-in?from=https%3A%2F%2Fevil.example'), '/me');
      expect(go(cand, '/sign-in?from=%2F%2Fevil.example'), '/me');
    });
  });

  group('in-between states', () {
    test('unverified email is held at the verify screen', () {
      final s = NeedsEmailVerification(
        user(role: AppRole.candidate, verified: false),
      );
      expect(go(s, '/me'), verifyPath);
      expect(
        go(s, '/sign-in?from=%2Fme%2Fsaved'),
        '/verify-email?from=%2Fme%2Fsaved',
      );
      expect(go(s, '/jobs'), isNull, reason: 'public pages stay open');
      expect(go(s, verifyPath), isNull);
    });
    test('Google accounts are never asked to verify', () {
      expect(
        authStateFor(
          user(role: AppRole.candidate, verified: false, password: false),
        ),
        isA<SignedIn>(),
      );
    });
    test('no role yet: choose one before entering protected areas', () {
      final s = NeedsRole(user());
      expect(go(s, '/me'), '/choose-role?from=%2Fme');
      expect(go(s, chooseRolePath), isNull);
      expect(go(s, '/'), isNull);
    });
    test('while restoring a session, protected pages wait, then continue', () {
      expect(
        go(const AuthLoading(), '/me/saved'),
        '/auth/loading?from=%2Fme%2Fsaved',
      );
      expect(go(const AuthLoading(), '/jobs'), isNull);
      expect(
        go(
          SignedIn(user(role: AppRole.candidate)),
          '/auth/loading?from=%2Fme%2Fsaved',
        ),
        '/me/saved',
      );
      expect(
        go(const SignedOut(), '/auth/loading?from=%2Fme%2Fsaved'),
        '/sign-in?from=%2Fme%2Fsaved',
      );
    });
  });
}
