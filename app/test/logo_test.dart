import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luzhire/core/brand/luz_logo.dart';
import 'package:luzhire/core/theme/app_theme.dart';
import 'package:luzhire/core/theme/tokens.dart';

Widget _wrap(Widget child, {ThemeData? theme, double width = 400}) =>
    MaterialApp(
      theme: theme ?? AppTheme.light(),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: Align(alignment: Alignment.centerLeft, child: child),
          ),
        ),
      ),
    );

void main() {
  test('letter path stays inside the tile and matches the official bounds', () {
    final b = LuzLogoSpec.letterPath(1).getBounds();
    expect(b.left, closeTo(55.5, 0.01));
    expect(b.top, closeTo(48.5, 0.01)); // stem cap: 68.5 - radius 20
    expect(b.right, closeTo(161.38, 0.01));
    expect(b.bottom, closeTo(211.5, 0.01));
  });

  test('brand accent is the logo orange', () {
    expect(LuzBrand.primary, LuzLogoSpec.dot);
  });

  testWidgets('logo shows mark + wordmark with one accessible label', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(_wrap(LuzLogo(onTap: () => taps++)));
    expect(find.byType(LuzLogoMark), findsOneWidget);
    expect(find.text('LuzHire'), findsOneWidget);
    expect(find.bySemanticsLabel('LuzHire home'), findsOneWidget);
    await tester.tap(find.byType(LuzLogo));
    expect(taps, 1);
  });

  testWidgets('wordmark uses ink in light and reversed ink in dark', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const LuzLogo()));
    expect(
      tester.widget<Text>(find.text('LuzHire')).style!.color,
      LuzPalette.light.ink,
    );
    await tester.pumpWidget(_wrap(const LuzLogo(), theme: AppTheme.dark()));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.text('LuzHire')).style!.color,
      LuzPalette.dark.ink,
    );
  });

  testWidgets(
    'logo ignores OS text scaling and scales down instead of overflowing',
    (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: _wrap(const LuzLogo(size: 40), width: 120),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(LuzLogo)).width,
        lessThanOrEqualTo(120),
      );
    },
  );
}
