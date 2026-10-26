import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// "/" — jump to the page's search field.
class FocusSearchIntent extends Intent {
  const FocusSearchIntent();
}

/// True while the user is typing in a text field, so single-key shortcuts
/// like "/" don't steal characters.
bool isTypingInTextField() {
  final ctx = FocusManager.instance.primaryFocus?.context;
  if (ctx == null) return false;
  return ctx.widget is EditableText ||
      ctx.findAncestorWidgetOfExactType<EditableText>() != null;
}

/// Tab / Shift+Tab as usual, but never stuck and never on an invisible
/// stop: a page with nothing to focus (an empty list, a chart) holds focus
/// on its route's scope, where the default traversal finds no next control
/// and stays put. Then focus moves on through the rest of the app (the
/// shell's navigation) instead, and a round of Tab skips that empty scope.
class _TraverseOrEscapeAction<T extends DirectionalFocusIntent>
    extends Action<T> {
  _TraverseOrEscapeAction(this.from, {required this.forward});

  /// A node above the whole shell; traversal from it reaches everything.
  final FocusNode from;
  final bool forward;

  @override
  Object? invoke(T intent) {
    _move();
    // Focus changes apply in a microtask. If this one landed on a page's
    // scope with nothing in it (it shows nothing), take one more step.
    scheduleMicrotask(() {
      final now = FocusManager.instance.primaryFocus;
      if (now is FocusScopeNode && now.traversalDescendants.isEmpty) _move();
    });
    return null;
  }

  void _move() {
    final node = FocusManager.instance.primaryFocus;
    final moved =
        node != null && (forward ? node.nextFocus() : node.previousFocus());
    if (!moved) forward ? from.nextFocus() : from.previousFocus();
  }
}

class _NextFocus extends DirectionalFocusIntent {
  const _NextFocus() : super(TraversalDirection.down);
}

class _PreviousFocus extends DirectionalFocusIntent {
  const _PreviousFocus() : super(TraversalDirection.up);
}

class _GuardedCallbackAction<T extends Intent> extends Action<T> {
  _GuardedCallbackAction(this.onInvoke, {this.skipWhileTyping = false});
  final VoidCallback? onInvoke;
  final bool skipWhileTyping;

  @override
  bool isEnabled(T intent) =>
      onInvoke != null && !(skipWhileTyping && isTypingInTextField());

  @override
  bool consumesKey(T intent) => isEnabled(intent);

  @override
  Object? invoke(T intent) {
    onInvoke?.call();
    return null;
  }
}

/// App-wide keyboard shortcuts for desktop web and hardware keyboards.
/// Shells supply the callbacks; a null callback disables that shortcut.
///
/// - Ctrl/⌘ K opens the command menu from anywhere, even while typing.
///   It is a global [HardwareKeyboard] handler because focused text fields
///   (notably on web) swallow modifier shortcuts before they bubble up.
/// - "/" goes to search, but never while the user is typing.
class LuzAppShortcuts extends StatefulWidget {
  const LuzAppShortcuts({
    super.key,
    required this.child,
    this.onCommandMenu,
    this.onFocusSearch,
  });

  final Widget child;
  final VoidCallback? onCommandMenu;
  final VoidCallback? onFocusSearch;

  @override
  State<LuzAppShortcuts> createState() => _LuzAppShortcutsState();
}

class _LuzAppShortcutsState extends State<LuzAppShortcuts> {
  final _root = FocusNode(debugLabel: 'LuzAppShortcuts', skipTraversal: true);

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _root.dispose();
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent || widget.onCommandMenu == null) return false;
    if (event.logicalKey != LogicalKeyboardKey.keyK) return false;
    final kb = HardwareKeyboard.instance;
    if (!(kb.isControlPressed || kb.isMetaPressed)) return false;
    // Only the shell whose page is on top reacts (not behind a dialog).
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return false;
    widget.onCommandMenu!();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const {
        CharacterActivator('/'): FocusSearchIntent(),
        SingleActivator(LogicalKeyboardKey.tab): _NextFocus(),
        SingleActivator(LogicalKeyboardKey.tab, shift: true): _PreviousFocus(),
      },
      child: Actions(
        actions: {
          FocusSearchIntent: _GuardedCallbackAction<FocusSearchIntent>(
            widget.onFocusSearch,
            skipWhileTyping: true,
          ),
          _NextFocus: _TraverseOrEscapeAction<_NextFocus>(_root, forward: true),
          _PreviousFocus: _TraverseOrEscapeAction<_PreviousFocus>(
            _root,
            forward: false,
          ),
        },
        // Without a focused node below the Shortcuts, key events go to the
        // root scope and never reach us (e.g. right after page load on web).
        // Not a Tab stop: it has nothing to show (WCAG 2.4.7).
        child: Focus(focusNode: _root, autofocus: true, child: widget.child),
      ),
    );
  }
}
