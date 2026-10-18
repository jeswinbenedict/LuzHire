import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:luzhire/app.dart';
import 'package:luzhire/core/layout/breakpoints.dart';
import 'package:luzhire/core/layout/content.dart';
import 'package:luzhire/core/layout/input_mode.dart';
import 'package:luzhire/core/theme/app_theme.dart';
import 'package:luzhire/core/widgets/widgets.dart';

void setWindow(WidgetTester tester, double width, [double height = 900]) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> pumpApp(WidgetTester tester, {String location = '/'}) async {
  await tester.pumpWidget(const ProviderScope(child: LuzHireApp()));
  await tester.pumpAndSettle();
  if (location != '/') {
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go(location);
    await tester.pumpAndSettle();
  }
}

Widget wrap(Widget child, {LuzInputMode? mode}) => MaterialApp(
  theme: AppTheme.light(),
  home: LuzInputModeScope(
    forcedMode: mode,
    child: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  group('LuzBreakpoint', () {
    test('maps widths to size classes at the DESIGN.md boundaries', () {
      expect(LuzBreakpoint.fromWidth(375), LuzBreakpoint.compact);
      expect(LuzBreakpoint.fromWidth(599), LuzBreakpoint.compact);
      expect(LuzBreakpoint.fromWidth(600), LuzBreakpoint.medium);
      expect(LuzBreakpoint.fromWidth(1023), LuzBreakpoint.medium);
      expect(LuzBreakpoint.fromWidth(1024), LuzBreakpoint.expanded);
      expect(LuzBreakpoint.fromWidth(1440), LuzBreakpoint.large);
    });

    test('pick falls back to the next smaller breakpoint', () {
      expect(LuzBreakpoint.large.pick(compact: 1, medium: 2), 2);
      expect(LuzBreakpoint.medium.pick(compact: 1, expanded: 3), 1);
      expect(LuzBreakpoint.expanded.gridColumns, 3);
    });
  });

  testWidgets('LuzGrid uses 1 / 2 / 3 columns by available width', (
    tester,
  ) async {
    for (final (width, cols) in [(400.0, 1), (800.0, 2), (1200.0, 3)]) {
      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: width,
            child: LuzGrid(
              spacing: 0,
              children: List.generate(
                3,
                (i) => SizedBox(key: ValueKey(i), height: 10),
              ),
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byKey(const ValueKey(0))).width, width / cols);
    }
  });

  group('Spotlight shell', () {
    testWidgets('wide: top navigation links, no bottom bar', (tester) async {
      setWindow(tester, 1280);
      await pumpApp(tester);
      expect(find.text('Companies'), findsOneWidget);
      expect(find.text('Get started'), findsOneWidget);
      expect(find.byTooltip('Menu'), findsNothing);
    });

    testWidgets('phone: bottom navigation + menu sheet', (tester) async {
      setWindow(tester, 375, 812);
      await pumpApp(tester);
      expect(find.text('My LuzHire'), findsOneWidget, reason: 'bottom bar');
      expect(find.text('Get started'), findsNothing);

      await tester.tap(find.byTooltip('Menu'));
      await tester.pumpAndSettle();
      expect(find.byType(LuzSheet), findsOneWidget);
      expect(find.text('Get started'), findsOneWidget);
    });

    testWidgets('bottom bar navigates and marks the selection', (tester) async {
      setWindow(tester, 375, 812);
      await pumpApp(tester);
      await tester.tap(find.text('Companies'));
      await tester.pumpAndSettle();
      expect(find.text('Companies'), findsWidgets);
      final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
      expect(router.state.uri.path, '/companies');
    });
  });

  group('Workspace shell', () {
    testWidgets('expanded: full sidebar with labels', (tester) async {
      setWindow(tester, 1280);
      await pumpApp(tester, location: '/employer/pipeline');
      expect(find.text('Company & team'), findsOneWidget);
      expect(find.byTooltip('Open navigation'), findsNothing);
    });

    testWidgets('medium: icon rail with tooltips', (tester) async {
      setWindow(tester, 800);
      await pumpApp(tester, location: '/employer');
      expect(find.text('Company & team'), findsNothing);
      expect(find.byTooltip('Company & team'), findsOneWidget);
    });

    testWidgets('compact: drawer opens from the menu button', (tester) async {
      setWindow(tester, 375, 812);
      await pumpApp(tester, location: '/admin');
      expect(find.text('Audit log'), findsNothing);
      await tester.tap(find.byTooltip('Open navigation'));
      await tester.pumpAndSettle();
      expect(find.text('Audit log'), findsOneWidget);

      await tester.tap(find.text('Audit log'));
      await tester.pumpAndSettle();
      final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
      expect(router.state.uri.path, '/admin/audit');
    });
  });

  group('Keyboard shortcuts', () {
    testWidgets('Ctrl+K opens the command menu; Enter navigates', (
      tester,
    ) async {
      setWindow(tester, 1280);
      await pumpApp(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(find.text('Go to…'), findsOneWidget);

      await tester.enterText(find.byType(TextField).last, 'audit');
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
      expect(router.state.uri.path, '/admin/audit');
    });

    testWidgets('Ctrl+K works even while typing in a text field', (
      tester,
    ) async {
      setWindow(tester, 1280);
      await pumpApp(tester);
      await tester.tap(find.byType(TextField).first);
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(find.text('Go to…'), findsOneWidget);
      // A second Ctrl+K while the menu is open doesn't stack another one.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(find.text('Go to…'), findsOneWidget);
    });

    testWidgets('"/" jumps to job search but not while typing', (tester) async {
      setWindow(tester, 1280);
      await pumpApp(tester);

      // Typing "/" inside the hero search must stay in the field.
      await tester.tap(find.byType(TextField).first);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.slash, character: '/');
      await tester.pumpAndSettle();
      final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
      expect(router.state.uri.path, '/');

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.slash, character: '/');
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/jobs');
    });
  });

  group('Adaptive modal', () {
    Future<void> open(WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) => LuzButton(
              label: 'Open',
              onPressed: () => showLuzModal<void>(
                context: context,
                title: 'Hello',
                builder: (_) => const Text('Body'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    }

    testWidgets('bottom sheet on phones', (tester) async {
      setWindow(tester, 375, 812);
      await open(tester);
      expect(find.byType(LuzSheet), findsOneWidget);
      expect(find.byType(LuzDialog), findsNothing);
    });

    testWidgets('dialog on wider screens', (tester) async {
      setWindow(tester, 1024);
      await open(tester);
      expect(find.byType(LuzDialog), findsOneWidget);
      expect(find.byType(LuzSheet), findsNothing);
    });
  });

  testWidgets('range slider thumbs move with arrow keys', (tester) async {
    var values = const RangeValues(10, 20);
    await tester.pumpWidget(
      wrap(
        StatefulBuilder(
          builder: (context, setState) => SizedBox(
            width: 300,
            child: LuzRangeSlider(
              min: 0,
              max: 40,
              values: values,
              semanticLabel: 'Salary',
              onChanged: (v) => setState(() => values = v),
            ),
          ),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(values.start, 11);
    // The start thumb can't pass the end thumb.
    for (var i = 0; i < 20; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    }
    await tester.pump();
    expect(values.start, 20);
    expect(values.end, 20);
  });

  testWidgets('data table sorts by header and stacks on narrow widths', (
    tester,
  ) async {
    Widget table(double width) => wrap(
      SizedBox(
        width: width,
        child: LuzDataTable<(String, int)>(
          columns: [
            LuzColumn(
              label: 'Name',
              sortKey: (r) => r.$1,
              cell: (c, r) => Text(r.$1),
            ),
            LuzColumn(
              label: 'Score',
              numeric: true,
              sortKey: (r) => r.$2,
              cell: (c, r) => Text('${r.$2}'),
            ),
          ],
          rows: const [('Zed', 1), ('Amy', 3)],
        ),
      ),
    );

    await tester.pumpWidget(table(700));
    double y(String s) => tester.getTopLeft(find.text(s)).dy;
    expect(y('Zed') < y('Amy'), isTrue);
    await tester.tap(find.bySemanticsLabel('Sort by Name'));
    await tester.pump();
    expect(y('Amy') < y('Zed'), isTrue);

    await tester.pumpWidget(table(360));
    expect(
      find.text('NAME'),
      findsNothing,
      reason: 'no header row when stacked',
    );
    expect(
      find.text('Name'),
      findsNWidgets(2),
      reason: 'label per stacked row',
    );
  });

  testWidgets('Workspace controls are dense only with a pointer', (
    tester,
  ) async {
    Future<double> height(LuzInputMode mode) async {
      await tester.pumpWidget(
        wrap(
          LuzZone(
            kind: LuzZoneKind.workspace,
            child: LuzButton(label: 'Export', onPressed: () {}),
          ),
          mode: mode,
        ),
      );
      return tester.getSize(find.byType(LuzSurface)).height;
    }

    expect(await height(LuzInputMode.pointer), 38);
    expect(await height(LuzInputMode.touch), 48);
  });

  testWidgets('dark theme toast keeps its action readable', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: Builder(
            builder: (context) => LuzButton(
              label: 'Go',
              onPressed: () =>
                  showLuzToast(context, 'Saved', actionLabel: 'Undo'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Go'));
    await tester.pump();
    final action = tester.widget<SnackBarAction>(find.byType(SnackBarAction));
    expect(action.textColor, isNot(equals(const Color(0xFFFFB224))));
  });
}
