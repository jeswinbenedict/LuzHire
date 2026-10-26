// Keyboard access (WCAG 2.1.1, 2.1.2, 2.4.7): every control a mouse can
// click is reachable with Tab, Tab never gets stuck, and the focused control
// shows where focus is. Prepares the manual screen-reader pass
// (docs/RELEASE.md §6).
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luzhire/core/data/enums.dart';
import 'package:luzhire/core/theme/app_theme.dart';

import 'support/admin_fakes.dart';
import 'support/candidate_fakes.dart';
import 'support/employer_fakes.dart';
import 'support/fakes.dart';
import 'support/job_fakes.dart';

Future<void> _pump(
  WidgetTester tester, {
  required String location,
  AppRole? role,
  double width = 1280,
}) => pumpLuzHire(
  tester,
  location: location,
  size: Size(width, 900),
  gateway: FakeAuthGateway(signedIn: role == null ? null : signedInAs(role)),
  overrides: [
    ...jobBoardOverrides(),
    ...CandidateFakes().overrides,
    ...employerOverrides(FakeEmployerRepository()),
    ...adminOverrides(
      FakeAdminRepository(),
      FakeGovernanceRepository(FakeAdminRepository()),
    ),
  ],
);

/// (route, signed-in role): every area of the app.
const _screens = <(String, AppRole?)>[
  ('/', null),
  ('/jobs', null),
  ('/jobs/job-1', null),
  ('/jobs/map', null),
  ('/companies', null),
  ('/companies/nimbus-labs', null),
  ('/events', null),
  ('/news', null),
  ('/sign-in', null),
  ('/sign-up', null),
  ('/me', AppRole.candidate),
  ('/me/applications', AppRole.candidate),
  ('/me/saved', AppRole.candidate),
  ('/me/interviews', AppRole.candidate),
  ('/me/profile', AppRole.candidate),
  ('/account', AppRole.candidate),
  ('/account/notifications', AppRole.candidate),
  ('/employer', AppRole.employer),
  ('/employer/jobs', AppRole.employer),
  ('/employer/jobs/new', AppRole.employer),
  ('/employer/pipeline', AppRole.employer),
  ('/employer/interviews', AppRole.employer),
  ('/employer/analytics', AppRole.employer),
  ('/employer/company', AppRole.employer),
  ('/employer/events', AppRole.employer),
  ('/admin', AppRole.admin),
  ('/admin/verification', AppRole.admin),
  ('/admin/moderation', AppRole.admin),
  ('/admin/users', AppRole.admin),
  ('/admin/announcements', AppRole.admin),
  ('/admin/audit', AppRole.admin),
  ('/admin/news', AppRole.admin),
];

/// Labels of on-screen nodes that act on a tap but can't take focus.
List<String> _clickableButNotFocusable(WidgetTester tester) {
  final out = <String>[];
  void visit(SemanticsNode node) {
    final data = node.getSemanticsData();
    final hidden =
        data.flagsCollection.isHidden ||
        node.isInvisible ||
        node.isMergedIntoParent;
    final tappable = data.hasAction(SemanticsAction.tap);
    // Text fields take focus through their own editable text.
    final textField = data.flagsCollection.isTextField;
    if (!hidden &&
        tappable &&
        !textField &&
        data.flagsCollection.isFocused == Tristate.none) {
      final label = [
        data.label,
        data.value,
        data.tooltip,
      ].where((s) => s.isNotEmpty).join(' / ');
      out.add(label.isEmpty ? '(unlabelled at ${node.rect})' : label);
    }
    node.visitChildren((c) {
      visit(c);
      return true;
    });
  }

  visit(
    tester.binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!,
  );
  return out;
}

/// Presses Tab until focus comes back to the first stop (or [max] presses).
/// Fails if focus is lost or loops without reaching the first stop again (a
/// keyboard trap). Returns the stops in order.
Future<List<FocusNode>> _tabThrough(
  WidgetTester tester, {
  int max = 120,
  void Function(FocusNode stop)? onStop,
}) async {
  final stops = <FocusNode>[];
  for (var i = 0; i < max; i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    // Let focus rings fade in and scrolling to the control finish (the
    // first frame starts those animations, the second ends them).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final f = FocusManager.instance.primaryFocus;
    expect(f, isNotNull, reason: 'focus lost after ${stops.length} stops');
    // Back at the start: the first stop still on the page (long lists
    // rebuild rows that scrolled away, with new focus nodes).
    final first = stops.where((s) => s.context?.mounted ?? false).firstOrNull;
    if (first != null && f == first) break;
    if (stops.contains(f)) {
      fail(
        'Tab loops back to stop ${stops.indexOf(f!) + 1} (${_describe(f)}) '
        'without reaching the rest of the page (keyboard trap). Stops: '
        '${[for (final s in stops) _describe(s)].join(' | ')}',
      );
    }
    stops.add(f!);
    onStop?.call(f);
  }
  return stops;
}

/// Whether the focused [node] shows it: the 2 px accent ring of Luz
/// controls (or an accent border), a text cursor, or Material's focus
/// highlight.
bool _showsFocus(FocusNode node) {
  final context = node.context;
  if (context == null) return false;
  final accent = context.luz.accent;
  var shown = false;
  context.visitAncestorElements((e) {
    shown = e.widget is InkResponse || e.widget is EditableText;
    return !shown;
  });
  if (shown) return true;
  var found = false;
  void visit(Element e) {
    if (found) return;
    final w = e.widget;
    if (w is EditableText) {
      found = true;
      return;
    }
    if (w is DecoratedBox) {
      final d = w.decoration;
      if (d is BoxDecoration && d.border is Border) {
        final top = (d.border! as Border).top;
        if (top.color == accent && top.width >= 2) {
          found = true;
          return;
        }
      }
    }
    e.visitChildren(visit);
  }

  (context as Element).visitChildren(visit);
  return found;
}

String _describe(FocusNode node) {
  final context = node.context;
  if (context == null || !context.mounted) return node.toStringShort();
  final texts = <String>[];
  void visit(Element e) {
    if (texts.length > 2) return;
    final w = e.widget;
    if (w is Text && (w.data ?? '').isNotEmpty) texts.add(w.data!);
    if (w is Icon && w.icon != null) texts.add('icon ${w.icon!.codePoint}');
    e.visitChildren(visit);
  }

  (context as Element).visitChildren(visit);
  return '${context.widget.runtimeType}: ${texts.join(' / ')}';
}

void main() {
  group('every clickable control can be reached with Tab', () {
    for (final (path, role) in _screens) {
      testWidgets(path, (tester) async {
        final semantics = tester.ensureSemantics();
        await _pump(tester, location: path, role: role);
        expect(_clickableButNotFocusable(tester), isEmpty);
        semantics.dispose();
      });
    }
  });

  group('Tab moves through every page and focus is always visible', () {
    for (final (path, role) in _screens) {
      testWidgets(path, (tester) async {
        await _pump(tester, location: path, role: role);
        // Checked while each stop has focus (the ring follows focus).
        final hidden = <String>[];
        final stops = await _tabThrough(
          tester,
          onStop: (s) {
            if (!_showsFocus(s)) hidden.add(_describe(s));
          },
        );
        if (stops.length <= 3) {
          fail(
            'Only ${stops.length} Tab stops: '
            '${[for (final s in stops) _describe(s)].join(' | ')}',
          );
        }
        expect(hidden, isEmpty, reason: 'focus not visible on these');
      });
    }
  });

  testWidgets('Tab leaves a page with nothing to focus', (tester) async {
    // No interviews: the page has no controls of its own.
    await _pump(
      tester,
      location: '/employer/interviews',
      role: AppRole.employer,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.pump();
    final focused = FocusManager.instance.primaryFocus;
    expect(focused, isNot(isA<FocusScopeNode>()));
    expect(focused?.context?.mounted, isTrue);
  });

  testWidgets('Find jobs tabs through all filters before the results', (
    tester,
  ) async {
    await _pump(tester, location: '/jobs', width: 1440);
    final order = <String>[];
    await _tabThrough(tester, onStop: (s) => order.add(_describe(s)));
    final filters = [
      for (var i = 0; i < order.length; i++)
        if (order[i].contains('Full-time') ||
            order[i].contains('Internship') ||
            order[i].contains('Past week') ||
            order[i].contains('Senior'))
          i,
    ];
    final firstJob = order.indexWhere((s) => s.contains('Flutter Developer'));
    expect(filters, hasLength(4));
    expect(firstJob, greaterThan(filters.last));
  });

  testWidgets('a table row opens with Enter', (tester) async {
    await _pump(tester, location: '/admin/users', role: AppRole.admin);
    String focusedText() => _describe(FocusManager.instance.primaryFocus!);
    for (var i = 0; i < 40 && !focusedText().contains('Asha Verma'); i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }
    expect(focusedText(), contains('Asha Verma'));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    // The manage dialog is titled with the person's name.
    expect(find.text('Asha Verma'), findsAtLeastNWidgets(2));
  });
}
