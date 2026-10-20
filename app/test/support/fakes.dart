import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:luzhire/app.dart';
import 'package:luzhire/core/config/app_config.dart';
import 'package:luzhire/core/data/enums.dart';
import 'package:luzhire/core/data/failures.dart';
import 'package:luzhire/features/auth/application/auth_controller.dart';
import 'package:luzhire/features/auth/data/account_api.dart';
import 'package:luzhire/features/auth/data/auth_gateway.dart';
import 'package:luzhire/features/auth/domain/auth_state.dart';

class FakeAccount {
  FakeAccount({
    required this.uid,
    required this.email,
    required this.password,
    required this.name,
    this.role,
    this.verified = true,
    this.usesPassword = true,
  });
  final String uid;
  final String email;
  final String password;
  final String name;
  AppRole? role;
  bool verified;
  bool usesPassword;

  AuthUser toUser() => AuthUser(
    uid: uid,
    email: email,
    displayName: name,
    emailVerified: verified,
    usesPassword: usesPassword,
    appRole: role,
  );
}

/// In-memory identity provider with the same behaviour the app relies on.
class FakeAuthGateway implements AuthGateway {
  FakeAuthGateway({
    List<FakeAccount> accounts = const [],
    FakeAccount? signedIn,
  }) : _accounts = {for (final a in accounts) a.email: a},
       _current = signedIn {
    if (signedIn != null) _accounts[signedIn.email] = signedIn;
  }

  final Map<String, FakeAccount> _accounts;
  final _changes = StreamController<AuthUser?>.broadcast();
  FakeAccount? _current;

  /// The Google account used by [signInWithGoogle].
  FakeAccount google = FakeAccount(
    uid: 'g-1',
    email: 'g@example.com',
    password: '',
    name: 'Google User',
    usesPassword: false,
  );

  int verificationEmails = 0;
  final resetEmails = <String>[];

  FakeAccount? account(String email) => _accounts[email];

  void _emit() => _changes.add(_current?.toUser());

  @override
  bool get isConfigured => true;
  @override
  AuthUser? get currentUser => _current?.toUser();

  @override
  Stream<AuthUser?> userChanges() async* {
    yield currentUser;
    yield* _changes.stream;
  }

  @override
  Future<void> signInWithEmail(String email, String password) async {
    final a = _accounts[email.trim()];
    if (a == null || a.password != password) {
      throw mapAuthError('invalid-credential');
    }
    _current = a;
    _emit();
  }

  @override
  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    if (_accounts.containsKey(email.trim())) {
      throw mapAuthError('email-already-in-use');
    }
    final a = FakeAccount(
      uid: 'u-${_accounts.length + 1}',
      email: email.trim(),
      password: password,
      name: displayName.trim(),
      verified: false,
    );
    _accounts[a.email] = a;
    _current = a;
    _emit();
  }

  @override
  Future<void> signInWithGoogle() async {
    _accounts[google.email] = google;
    _current = google;
    _emit();
  }

  @override
  Future<void> sendEmailVerification() async => verificationEmails++;

  @override
  Future<void> sendPasswordReset(String email) async => resetEmails.add(email);

  @override
  Future<AuthUser?> refresh() async => currentUser;

  @override
  Future<String?> idToken({bool forceRefresh = false}) async =>
      _current == null ? null : 'token-${_current!.uid}';

  @override
  Future<void> signOut() async {
    _current = null;
    _emit();
  }
}

/// Stands in for POST /api/auth/bootstrap: grants the role on the fake.
class FakeAccountApi extends AccountApi {
  FakeAccountApi(this.gateway)
    : super(
        AppConfig.fromEnvironment(),
        MockClient((_) async => http.Response('not used in tests', 500)),
      );
  final FakeAuthGateway gateway;
  final calls = <(String token, AppRole role, String? name)>[];
  AppFailure? failWith;

  @override
  Future<bool> bootstrap({
    required String idToken,
    required AppRole role,
    String? displayName,
  }) async {
    calls.add((idToken, role, displayName));
    if (failWith != null) throw failWith!;
    final current = gateway._current!;
    current.role ??= role;
    return true;
  }

  /// Admin calls: (uid, new role or status).
  final adminCalls = <(String uid, String change)>[];

  /// Emails the fake "ADMIN_EMAILS" allows.
  Set<String> adminEmails = const {};

  @override
  Future<void> claimAdmin({required String idToken}) async {
    final current = gateway._current!;
    if (!adminEmails.contains(current.email)) {
      throw const AppFailure(
        'This account is not on the admin list.',
        code: 'api/403',
      );
    }
    current.role = AppRole.admin;
  }

  @override
  Future<void> changeRole({
    required String idToken,
    required String uid,
    required AppRole role,
  }) async => adminCalls.add((uid, role.dbValue));

  @override
  Future<void> setStatus({
    required String idToken,
    required String uid,
    required AccountStatus status,
  }) async => adminCalls.add((uid, status.dbValue));
}

/// Pumps the whole app with fake auth. Returns the router for assertions.
Future<GoRouter> pumpLuzHire(
  WidgetTester tester, {
  FakeAuthGateway? gateway,
  FakeAccountApi? api,
  String location = '/',
  Size size = const Size(1280, 900),
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final g = gateway ?? FakeAuthGateway();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authGatewayProvider.overrideWithValue(g),
        accountApiProvider.overrideWithValue(api ?? FakeAccountApi(g)),
        ...overrides,
      ],
      child: const LuzHireApp(),
    ),
  );
  await tester.pumpAndSettle();
  final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
  if (location != '/') {
    router.go(location);
    await tester.pumpAndSettle();
  }
  return router;
}

FakeAccount signedInAs(AppRole role) => FakeAccount(
  uid: '${role.dbValue}-1',
  email: '${role.dbValue}@example.com',
  password: 'secret123',
  name: 'Test ${role.dbValue}',
  role: role,
);
