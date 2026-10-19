import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luzhire/app.dart';
import 'package:luzhire/core/data/enums.dart';
import 'package:luzhire/core/data/failures.dart';
import 'package:luzhire/core/widgets/widgets.dart';
import 'package:luzhire/features/auth/presentation/auth_layout.dart';

import 'support/fakes.dart';

Finder field(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(LuzTextField));

Future<void> type(WidgetTester tester, String label, String text) async {
  await tester.enterText(
    find.descendant(of: field(label), matching: find.byType(TextField)),
    text,
  );
}

Future<void> tapButton(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label).last);
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Google buttons show the official Google mark', (tester) async {
    for (final page in ['/sign-in', '/sign-up']) {
      await pumpLuzHire(tester, location: page);
      final button = find.widgetWithText(LuzButton, 'Continue with Google');
      expect(button, findsOneWidget, reason: page);
      expect(
        find.descendant(of: button, matching: find.byType(GoogleLogo)),
        findsOneWidget,
        reason: page,
      );
      expect(
        find.descendant(of: button, matching: find.byType(SvgPicture)),
        findsOneWidget,
      );
    }
  });

  testWidgets('sign up as a job seeker → verify email → dashboard', (
    tester,
  ) async {
    final gateway = FakeAuthGateway();
    final api = FakeAccountApi(gateway);
    final router = await pumpLuzHire(
      tester,
      gateway: gateway,
      api: api,
      location: '/sign-up',
    );

    await type(tester, 'Full name', 'Asha Verma');
    await type(tester, 'Email', 'asha@example.com');
    await type(tester, 'Password', 'flutter123');
    await tapButton(tester, 'Create account');

    expect(
      api.calls.single.$2,
      AppRole.candidate,
      reason: 'role sent to bootstrap API',
    );
    expect(api.calls.single.$3, 'Asha Verma');
    expect(gateway.verificationEmails, 1);
    expect(router.state.uri.path, '/verify-email');
    expect(find.textContaining('asha@example.com'), findsOneWidget);

    // Not verified yet → stays, with an explanation.
    await tapButton(tester, "I've confirmed my email");
    expect(router.state.uri.path, '/verify-email');
    expect(
      find.textContaining("couldn't see the confirmation"),
      findsOneWidget,
    );

    gateway.account('asha@example.com')!.verified = true;
    await tapButton(tester, "I've confirmed my email");
    expect(router.state.uri.path, '/me');
  });

  testWidgets('"For employers" pre-selects the employer role', (tester) async {
    final gateway = FakeAuthGateway();
    final api = FakeAccountApi(gateway);
    await pumpLuzHire(
      tester,
      gateway: gateway,
      api: api,
      location: '/sign-up?role=employer',
    );
    expect(find.text('Work email'), findsOneWidget);
    await type(tester, 'Your name', 'Meera');
    await type(tester, 'Work email', 'meera@example.com');
    await type(tester, 'Password', 'hiring2026');
    await tapButton(tester, 'Create account');
    expect(api.calls.single.$2, AppRole.employer);
  });

  testWidgets('sign-up validates before calling anything', (tester) async {
    final gateway = FakeAuthGateway();
    final api = FakeAccountApi(gateway);
    await pumpLuzHire(tester, gateway: gateway, api: api, location: '/sign-up');
    await type(tester, 'Email', 'not-an-email');
    await type(tester, 'Password', 'short');
    await tapButton(tester, 'Create account');
    expect(find.text('Enter your name.'), findsOneWidget);
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(find.text('Use at least 8 characters.'), findsOneWidget);
    expect(api.calls, isEmpty);
  });

  testWidgets('sign in returns you to the page you wanted', (tester) async {
    final cand = signedInAs(AppRole.candidate)..verified = true;
    final gateway = FakeAuthGateway(accounts: [cand]);
    final router = await pumpLuzHire(
      tester,
      gateway: gateway,
      location: '/me/saved',
    );
    expect(
      router.state.uri.path,
      '/sign-in',
      reason: 'protected page asks to sign in',
    );

    await type(tester, 'Email', cand.email);
    await type(tester, 'Password', cand.password);
    await tapButton(tester, 'Sign in');
    expect(router.state.uri.path, '/me/saved');
  });

  testWidgets('wrong password shows a message that leaks nothing', (
    tester,
  ) async {
    final gateway = FakeAuthGateway(accounts: [signedInAs(AppRole.employer)]);
    final router = await pumpLuzHire(
      tester,
      gateway: gateway,
      location: '/sign-in',
    );
    await type(tester, 'Email', 'employer@example.com');
    await type(tester, 'Password', 'nope');
    await tapButton(tester, 'Sign in');
    expect(find.text('Email or password is incorrect.'), findsOneWidget);
    expect(router.state.uri.path, '/sign-in');
  });

  testWidgets('first Google sign-in asks for a role, then opens that area', (
    tester,
  ) async {
    final gateway = FakeAuthGateway();
    final router = await pumpLuzHire(
      tester,
      gateway: gateway,
      location: '/sign-in',
    );
    await tapButton(tester, 'Continue with Google');
    expect(router.state.uri.path, '/choose-role');

    await tapButton(tester, 'Continue');
    expect(find.text('Choose how you will use LuzHire.'), findsOneWidget);

    await tapButton(tester, 'I want to hire');
    await tapButton(tester, 'Continue');
    expect(router.state.uri.path, '/employer');
  });

  testWidgets('a role-setup failure is shown and can be retried', (
    tester,
  ) async {
    final gateway = FakeAuthGateway();
    final api = FakeAccountApi(gateway)
      ..failWith = const AppFailure('Server is busy.');
    final router = await pumpLuzHire(
      tester,
      gateway: gateway,
      api: api,
      location: '/sign-in',
    );
    await tapButton(tester, 'Continue with Google');
    await tapButton(tester, 'I want to find a job');
    await tapButton(tester, 'Continue');
    expect(find.text('Server is busy.'), findsOneWidget);
    expect(router.state.uri.path, '/choose-role');

    api.failWith = null;
    await tapButton(tester, 'Continue');
    expect(router.state.uri.path, '/me');
  });

  testWidgets('roles cannot open other areas', (tester) async {
    final gateway = FakeAuthGateway(signedIn: signedInAs(AppRole.candidate));
    final router = await pumpLuzHire(
      tester,
      gateway: gateway,
      location: '/admin/audit',
    );
    expect(router.state.uri.path, '/no-access');
    await tapButton(tester, 'Go to my dashboard');
    expect(router.state.uri.path, '/me');
  });

  testWidgets('signed-in users get an account menu that signs out', (
    tester,
  ) async {
    final gateway = FakeAuthGateway(signedIn: signedInAs(AppRole.employer));
    final router = await pumpLuzHire(tester, gateway: gateway);
    expect(find.text('Get started'), findsNothing);
    expect(
      find.text('Employer workspace'),
      findsOneWidget,
      reason: 'employer link goes to the workspace',
    );

    await tester.tap(find.byTooltip('Account: Test employer'));
    await tester.pumpAndSettle();
    await tapButton(tester, 'Sign out');
    expect(find.text('Get started'), findsOneWidget);
    expect(router.state.uri.path, '/');
  });

  testWidgets('forgot password never reveals whether the email exists', (
    tester,
  ) async {
    final gateway = FakeAuthGateway();
    await pumpLuzHire(tester, gateway: gateway, location: '/forgot-password');
    await type(tester, 'Email', 'someone@example.com');
    await tapButton(tester, 'Send reset link');
    expect(gateway.resetEmails, ['someone@example.com']);
    expect(find.textContaining('If an account exists'), findsOneWidget);
  });

  testWidgets('without Firebase config the form explains and is disabled', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // No overrides: tests have no dart-defines, so DisabledAuthGateway is used.
    await tester.pumpWidget(const ProviderScope(child: LuzHireApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('not available in this build'), findsOneWidget);
    final signIn = tester.widget<LuzButton>(
      find.widgetWithText(LuzButton, 'Sign in').last,
    );
    expect(signIn.onPressed, isNull);
  });
}
