// Offline demo: local sign-in gateway and one-role-per-port modules.
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:luzhire/core/config/app_config.dart';
import 'package:luzhire/core/config/app_module.dart';
import 'package:luzhire/core/data/enums.dart';
import 'package:luzhire/core/data/failures.dart';
import 'package:luzhire/core/platform/local_store.dart';
import 'package:luzhire/features/auth/application/auth_controller.dart';
import 'package:luzhire/features/auth/data/local_auth_gateway.dart';
import 'package:luzhire/features/auth/domain/auth_state.dart';

import 'support/fakes.dart';

String _token(Map<String, Object?> claims) {
  String part(Object o) =>
      base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${part({'alg': 'HS256'})}.${part(claims)}.sig';
}

int _inAnHour() => DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;

const _config = AppConfig(
  env: 'demo',
  supabaseUrl: 'http://127.0.0.1:54321',
  supabasePublishableKey: 'sb_publishable_test',
  apiBaseUrl: 'http://localhost:8081',
  firebaseApiKey: '',
  firebaseProjectId: '',
  firebaseMessagingSenderId: '',
  firebaseAuthDomain: '',
  firebaseStorageBucket: '',
  firebaseWebAppId: '',
  firebaseAndroidAppId: '',
  firebaseIosAppId: '',
  firebaseIosBundleId: '',
  authProvider: 'local',
);

void main() {
  group('AppConfig', () {
    test('local auth counts as configured without Firebase', () {
      expect(_config.usesLocalAuth, isTrue);
      expect(_config.isFirebaseConfigured, isFalse);
      expect(_config.isAuthConfigured, isTrue);
    });
  });

  group('ModuleConfig', () {
    test('reads the module and links from the page meta', () {
      final m = ModuleConfig.parse(
        '{"module":"recruiter","links":{"candidate":"http://localhost:8081"}}',
      );
      expect(m.module, AppModule.recruiter);
      expect(m.links[AppModule.candidate], 'http://localhost:8081');
      expect(m.allows(AppRole.employer), isTrue);
      expect(m.allows(AppRole.candidate), isFalse);
    });

    test('no or broken meta means every role (production)', () {
      for (final raw in [null, '', 'not json']) {
        final m = ModuleConfig.parse(raw);
        expect(m.module, AppModule.all);
        expect(AppRole.values.every(m.allows), isTrue);
      }
    });
  });

  group('LocalAuthGateway', () {
    late List<http.Request> requests;
    late MemoryLocalStore store;

    LocalAuthGateway gateway(Map<String, Object?> claims, {int status = 200}) {
      final client = MockClient((req) async {
        requests.add(req);
        if (status != 200) {
          return http.Response(
            jsonEncode({
              'error': {'code': 'auth/invalid-credential'},
            }),
            status,
          );
        }
        return http.Response(jsonEncode({'token': _token(claims)}), 200);
      });
      return LocalAuthGateway(_config, client: client, store: store);
    }

    setUp(() {
      requests = [];
      store = MemoryLocalStore();
    });

    test('signs in, keeps the session and maps claims to the user', () async {
      final g = gateway({
        'sub': 'demo-lisa',
        'email': 'lisa@luzhire.local',
        'name': 'Lisa Immanuel',
        'email_verified': true,
        'role': 'authenticated',
        'app_role': 'employer',
        'exp': _inAnHour(),
      });
      await g.signInWithEmail(' lisa@luzhire.local ', 'pw');
      expect(
        requests.single.url.toString(),
        'http://localhost:8081/local-auth/sign-in',
      );
      expect(jsonDecode(requests.single.body), {
        'email': 'lisa@luzhire.local',
        'password': 'pw',
      });
      final user = g.currentUser!;
      expect(user.uid, 'demo-lisa');
      expect(user.appRole, AppRole.employer);
      expect(user.needsVerification, isFalse);
      expect(authStateFor(user), isA<SignedIn>());
      expect(await g.accessToken(), isNotNull);

      // A reload of the page restores the same session.
      final restored = LocalAuthGateway(_config, store: store);
      expect(restored.currentUser?.uid, 'demo-lisa');

      await g.signOut();
      expect(g.currentUser, isNull);
      expect(LocalAuthGateway(_config, store: store).currentUser, isNull);
    });

    test('gives Supabase no token before the role is set', () async {
      final g = gateway({'sub': 'new', 'email': 'n@x.co', 'exp': _inAnHour()});
      await g.signUpWithEmail(
        email: 'n@x.co',
        password: 'password1',
        displayName: 'N',
      );
      expect(g.currentUser?.appRole, isNull);
      expect(await g.accessToken(), isNull);
    });

    test(
      'wrong password shows the usual message; Google needs the internet',
      () async {
        final g = gateway(const {}, status: 401);
        await expectLater(
          g.signInWithEmail('x@y.co', 'bad'),
          throwsA(
            isA<AppFailure>().having((f) => f.code, 'code', 'auth/credentials'),
          ),
        );
        await expectLater(
          g.signInWithGoogle(),
          throwsA(
            isA<AppFailure>().having((f) => f.code, 'code', 'auth/offline'),
          ),
        );
      },
    );
  });

  group('Single-role modules', () {
    ProviderContainer container(AppModule module, FakeAuthGateway g) {
      final c = ProviderContainer(
        overrides: [
          authGatewayProvider.overrideWithValue(g),
          accountApiProvider.overrideWithValue(FakeAccountApi(g)),
          moduleConfigProvider.overrideWithValue(
            ModuleConfig(
              module: module,
              links: const {AppModule.candidate: 'http://localhost:8081'},
            ),
          ),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test(
      'a candidate is sent to the candidate module from the recruiter port',
      () async {
        final tom = signedInAs(AppRole.candidate);
        final c = container(
          AppModule.recruiter,
          FakeAuthGateway(accounts: [tom]),
        );
        c.read(authControllerProvider);
        await expectLater(
          c
              .read(authControllerProvider.notifier)
              .signIn(tom.email, tom.password),
          throwsA(
            isA<AppFailure>()
                .having((f) => f.code, 'code', 'auth/wrong-module')
                .having(
                  (f) => f.message,
                  'message',
                  contains('http://localhost:8081'),
                ),
          ),
        );
        expect(c.read(authControllerProvider), isA<SignedOut>());
      },
    );

    test('the matching role signs in normally', () async {
      final lisa = signedInAs(AppRole.employer);
      final c = container(
        AppModule.recruiter,
        FakeAuthGateway(accounts: [lisa]),
      );
      c.read(authControllerProvider);
      await c
          .read(authControllerProvider.notifier)
          .signIn(lisa.email, lisa.password);
      expect(c.read(authControllerProvider), isA<SignedIn>());
    });

    test(
      'sign-up for another role is refused before an account is made',
      () async {
        final g = FakeAuthGateway();
        final c = container(AppModule.recruiter, g);
        c.read(authControllerProvider);
        await expectLater(
          c
              .read(authControllerProvider.notifier)
              .signUp(
                email: 'n@x.co',
                password: 'password1',
                displayName: 'N',
                role: AppRole.candidate,
              ),
          throwsA(
            isA<AppFailure>().having(
              (f) => f.code,
              'code',
              'auth/wrong-module',
            ),
          ),
        );
        expect(g.account('n@x.co'), isNull);
      },
    );
  });
}
