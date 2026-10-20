import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:luzhire/core/config/app_config.dart';
import 'package:luzhire/core/data/enums.dart';
import 'package:luzhire/core/data/models.dart';
import 'package:luzhire/core/telemetry/error_reporter.dart';

import 'support/admin_fakes.dart';
import 'support/candidate_fakes.dart';
import 'support/fakes.dart';
import 'support/job_fakes.dart';

const _config = AppConfig(
  env: 'test',
  supabaseUrl: '',
  supabasePublishableKey: '',
  apiBaseUrl: 'https://luzhire.example',
  firebaseApiKey: '',
  firebaseProjectId: '',
  firebaseMessagingSenderId: '',
  firebaseAuthDomain: '',
  firebaseStorageBucket: '',
  firebaseWebAppId: '',
  firebaseAndroidAppId: '',
  firebaseIosAppId: '',
  firebaseIosBundleId: '',
);

void main() {
  group('ErrorReporter', () {
    test('sends each distinct error once, without query strings', () async {
      final sent = <Map<String, dynamic>>[];
      final reporter = ErrorReporter(
        _config,
        enabled: true,
        currentRoute: () => '/jobs',
        client: MockClient((req) async {
          expect(
            req.url.toString(),
            'https://luzhire.example/api/telemetry/error',
          );
          sent.add(jsonDecode(req.body) as Map<String, dynamic>);
          return http.Response('{"ok":true}', 202);
        }),
      );
      await reporter.report(
        StateError('Bad state: no job'),
        StackTrace.current,
      );
      await reporter.report(StateError('Bad state: no job'), null);
      await reporter.report(ArgumentError('other'), null);
      expect(sent, hasLength(2));
      expect(
        sent.first,
        containsPair('message', 'Bad state: Bad state: no job'),
      );
      expect(sent.first, containsPair('route', '/jobs'));
      expect(sent.first['source'], isIn(['web', 'android', 'ios']));
      expect(sent.first['detail'], isA<String>());
    });

    test('stops after the per-session cap and never throws', () async {
      var calls = 0;
      final reporter = ErrorReporter(
        _config,
        enabled: true,
        client: MockClient((_) async {
          calls++;
          throw http.ClientException('offline');
        }),
      );
      for (var i = 0; i < 25; i++) {
        await reporter.report(Exception('error $i'), null);
      }
      expect(calls, ErrorReporter.maxPerSession);
    });

    test('does nothing when disabled (debug builds)', () async {
      var calls = 0;
      final reporter = ErrorReporter(
        _config,
        enabled: false,
        client: MockClient((_) async {
          calls++;
          return http.Response('', 202);
        }),
      );
      await reporter.report(Exception('x'), null);
      expect(calls, 0);
    });
  });

  testWidgets('admins see recent app errors on the overview', (tester) async {
    final admin = FakeAdminRepository()
      ..errors.add(
        AppErrorEntry(
          source: 'web',
          message: 'TypeError: null is not a subtype of String',
          route: '/jobs',
          release: 'd8a3e80',
          createdAt: DateTime.now(),
        ),
      );
    await pumpLuzHire(
      tester,
      location: '/admin',
      size: const Size(1440, 1000),
      gateway: FakeAuthGateway(signedIn: signedInAs(AppRole.admin)),
      overrides: [
        ...jobBoardOverrides(),
        ...CandidateFakes().overrides,
        ...adminOverrides(admin, FakeGovernanceRepository(admin)),
      ],
    );
    final card = find.text('App errors');
    await tester.scrollUntilVisible(
      card,
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(
      find.text('TypeError: null is not a subtype of String'),
      findsOneWidget,
    );
    expect(find.text('web · /jobs · build d8a3e80'), findsOneWidget);
  });
}
