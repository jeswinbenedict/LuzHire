import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luzhire/app.dart';
import 'package:luzhire/core/theme/app_theme.dart';
import 'package:luzhire/core/theme/tokens.dart';
import 'package:luzhire/core/widgets/widgets.dart';

Widget _wrap(Widget child, {ThemeData? theme, bool highContrast = false}) =>
    MaterialApp(
      theme: theme ?? AppTheme.light(),
      home: MediaQuery(
        data: MediaQueryData(highContrast: highContrast),
        child: Scaffold(body: Center(child: child)),
      ),
    );

void main() {
  testWidgets('app boots into the design gallery and toggles theme', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: LuzHireApp()));
    await tester.pumpAndSettle();
    expect(find.text('LuzHire design system'), findsOneWidget);

    await tester.tap(find.byTooltip('Switch to dark theme'));
    await tester.pumpAndSettle();
    final ctx = tester.element(find.text('LuzHire design system'));
    expect(Theme.of(ctx).brightness, Brightness.dark);
    expect(ctx.luz.base, LuzPalette.dark.base);
  });

  testWidgets('LuzButton fires on tap and sinks while pressed', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _wrap(LuzButton(label: 'Apply', onPressed: () => taps++)),
    );

    LuzSurface surface() => tester.widget(find.byType(LuzSurface));
    expect(surface().depth, greaterThan(0));

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Apply')),
    );
    await tester.pump();
    expect(surface().depth, lessThan(0), reason: 'pressed buttons are inset');

    await gesture.up();
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(surface().depth, greaterThan(0));
  });

  testWidgets('disabled LuzButton is flat and ignores taps', (tester) async {
    await tester.pumpWidget(
      _wrap(const LuzButton(label: 'Apply', onPressed: null)),
    );
    expect(
      tester.widget<LuzSurface>(find.byType(LuzSurface)).depth,
      LuzDepth.flat,
    );
    await tester.tap(find.text('Apply'), warnIfMissed: false);
  });

  testWidgets('LuzButton activates with the keyboard', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _wrap(LuzButton(label: 'Go', onPressed: () => taps++)),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('selected filter chip shows an indicator, not just relief', (
    tester,
  ) async {
    var selected = false;
    await tester.pumpWidget(
      _wrap(
        StatefulBuilder(
          builder: (context, setState) => LuzFilterChip(
            label: 'Remote',
            selected: selected,
            onSelected: (v) => setState(() => selected = v),
          ),
        ),
      ),
    );
    expect(find.byType(Container), findsNothing);
    await tester.tap(find.text('Remote'));
    await tester.pumpAndSettle();
    expect(selected, isTrue);
    expect(
      find.byType(Container),
      findsOneWidget,
      reason: 'amber dot indicator',
    );
  });

  testWidgets('high-contrast mode replaces relief with an outline', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const LuzSurface(
          depth: LuzDepth.raisedMd,
          child: SizedBox(width: 40, height: 40),
        ),
        highContrast: true,
      ),
    );
    await tester.pumpAndSettle();
    final painter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((c) => c.painter)
        .whereType<LuzReliefPainter>()
        .single;
    expect(painter.depth, 0);
    expect(painter.outline, LuzPalette.light.outline);
  });

  testWidgets('every application stage chip renders its label', (tester) async {
    await tester.pumpWidget(
      _wrap(
        Wrap(
          children: [
            for (final s in ApplicationStage.values) LuzStatusChip.stage(s),
          ],
        ),
      ),
    );
    for (final s in ApplicationStage.values) {
      expect(find.text(s.label), findsOneWidget);
    }
  });
}
