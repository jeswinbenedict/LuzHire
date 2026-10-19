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
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
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
      shortcuts: const {CharacterActivator('/'): FocusSearchIntent()},
      child: Actions(
        actions: {
          FocusSearchIntent: _GuardedCallbackAction<FocusSearchIntent>(
            widget.onFocusSearch,
            skipWhileTyping: true,
          ),
        },
        // Without a focused node below the Shortcuts, key events go to the
        // root scope and never reach us (e.g. right after page load on web).
        child: Focus(autofocus: true, child: widget.child),
      ),
    );
  }
}
