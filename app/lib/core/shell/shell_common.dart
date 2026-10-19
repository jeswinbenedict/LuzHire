import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/domain/auth_state.dart';
import '../layout/input_mode.dart';
import '../router/auth_redirect.dart';
import '../theme/app_theme.dart';
import '../theme/theme_mode_provider.dart';
import '../theme/tokens.dart';
import '../widgets/widgets.dart';
import 'destinations.dart';

export '../brand/luz_logo.dart' show LuzLogo, LuzLogoMark;

/// A navigation target shown in shells and the command menu.
class LuzDestination {
  const LuzDestination({
    required this.label,
    required this.path,
    required this.icon,
    IconData? selectedIcon,
    this.group = 'Navigate',
  }) : selectedIcon = selectedIcon ?? icon;

  final String label;
  final String path;
  final IconData icon;
  final IconData selectedIcon;
  final String group;

  /// Whether [location] is inside this destination ("/" matches exactly).
  bool matches(String location) => path == '/'
      ? location == '/'
      : location == path || location.startsWith('$path/');
}

/// Index of the destination that best matches the current location.
int selectedIndexFor(List<LuzDestination> items, String location) {
  var best = -1;
  var bestLen = -1;
  for (var i = 0; i < items.length; i++) {
    if (items[i].matches(location) && items[i].path.length > bestLen) {
      best = i;
      bestLen = items[i].path.length;
    }
  }
  return best;
}

/// Sun/moon physical switch between light and dark.
class ThemeSwitchButton extends ConsumerWidget {
  const ThemeSwitchButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return LuzIconButton(
      icon: isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
      tooltip: isDark ? 'Switch to light theme' : 'Switch to dark theme',
      size: 40,
      onPressed: () => ref
          .read(themeModeProvider.notifier)
          .set(isDark ? ThemeMode.light : ThemeMode.dark),
    );
  }
}

/// System / Light / Dark preference control (drawers, settings).
class ThemeModeSelector extends ConsumerWidget {
  const ThemeModeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LuzSegmented<ThemeMode>(
      segments: const [
        (
          value: ThemeMode.system,
          label: 'System',
          icon: Icons.brightness_auto_outlined,
        ),
        (
          value: ThemeMode.light,
          label: 'Light',
          icon: Icons.light_mode_outlined,
        ),
        (value: ThemeMode.dark, label: 'Dark', icon: Icons.dark_mode_outlined),
      ],
      selected: ref.watch(themeModeProvider),
      onChanged: (m) => ref.read(themeModeProvider.notifier).set(m),
    );
  }
}

/// Stand-in for screens built in later phases.
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({
    super.key,
    required this.title,
    required this.phase,
    required this.icon,
    this.description,
  });

  final String title;
  final String phase;
  final IconData icon;
  final String? description;

  @override
  Widget build(BuildContext context) {
    return LuzEmptyState(
      icon: icon,
      title: title,
      message: description ?? 'This screen is built in $phase.',
    );
  }
}

/// Small keyboard-hint chip, e.g. "Ctrl K". Only shown with a pointer.
class KeyHint extends StatelessWidget {
  const KeyHint(this.keys, {super.key});
  final String keys;

  @override
  Widget build(BuildContext context) {
    if (!context.isPointer) return const SizedBox.shrink();
    final p = context.luz;
    return ExcludeSemantics(
      child: LuzSurface(
        depth: LuzDepth.insetSm,
        radius: 6,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          keys,
          style: context.luzText.mono.copyWith(fontSize: 11, color: p.muted),
        ),
      ),
    );
  }
}

String commandKeyLabel(BuildContext context) =>
    context.usesCommandKey ? '⌘K' : 'Ctrl K';

/// Command menu (Ctrl/⌘ K): type to filter destinations, arrows + Enter to go.
/// Command-menu entries for whoever is signed in.
List<LuzDestination> menuDestinations(BuildContext context) {
  final auth = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(authControllerProvider);
  return destinationsFor(auth is SignedIn ? auth.user.appRole : null);
}

Future<void> showCommandMenu(
  BuildContext context,
  List<LuzDestination> destinations,
) {
  return showLuzModal<void>(
    context: context,
    title: 'Go to…',
    builder: (ctx) => _CommandMenu(destinations: destinations),
  );
}

class _CommandMenu extends StatefulWidget {
  const _CommandMenu({required this.destinations});
  final List<LuzDestination> destinations;

  @override
  State<_CommandMenu> createState() => _CommandMenuState();
}

class _CommandMenuState extends State<_CommandMenu> {
  final _query = TextEditingController();
  int _active = 0;

  List<LuzDestination> get _results {
    final q = _query.text.trim().toLowerCase();
    // One entry per path (e.g. "My LuzHire" and "Dashboard" are both /me).
    final seen = <String>{};
    final unique = widget.destinations.where((d) => seen.add(d.path)).toList();
    if (q.isEmpty) return unique;
    return unique
        .where(
          (d) =>
              d.label.toLowerCase().contains(q) ||
              d.group.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _go(LuzDestination d) {
    Navigator.of(context).pop();
    GoRouter.of(context).go(d.path);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    final t = context.luzText;
    final results = _results;
    if (_active >= results.length) {
      _active = results.isEmpty ? 0 : results.length - 1;
    }

    return Focus(
      onKeyEvent: (node, e) {
        if ((e is! KeyDownEvent && e is! KeyRepeatEvent) || results.isEmpty) {
          return KeyEventResult.ignored;
        }
        if (e.logicalKey == LogicalKeyboardKey.arrowDown) {
          setState(() => _active = (_active + 1).clamp(0, results.length - 1));
          return KeyEventResult.handled;
        }
        if (e.logicalKey == LogicalKeyboardKey.arrowUp) {
          setState(() => _active = (_active - 1).clamp(0, results.length - 1));
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LuzSurface(
            depth: LuzDepth.insetSm,
            radius: LuzRadius.lg,
            outline: p.outline,
            padding: const EdgeInsets.symmetric(horizontal: LuzSpace.md),
            child: SizedBox(
              height: 48,
              child: Row(
                children: [
                  Icon(Icons.search, size: 20, color: p.muted),
                  const SizedBox(width: LuzSpace.sm),
                  Expanded(
                    child: TextField(
                      controller: _query,
                      autofocus: true,
                      onChanged: (_) => setState(() => _active = 0),
                      onSubmitted: (_) {
                        if (results.isNotEmpty) _go(results[_active]);
                      },
                      style: t.body.copyWith(color: p.ink),
                      decoration: InputDecoration.collapsed(
                        hintText: 'Search pages',
                        hintStyle: t.body.copyWith(color: p.muted),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: LuzSpace.md),
          if (results.isEmpty)
            Padding(
              padding: const EdgeInsets.all(LuzSpace.lg),
              child: Text(
                'No matches',
                textAlign: TextAlign.center,
                style: t.bodySm.copyWith(color: p.muted),
              ),
            ),
          for (var i = 0; i < results.length; i++)
            LuzPressable(
              onPressed: () => _go(results[i]),
              radius: LuzRadius.sm,
              semanticLabel: '${results[i].label}, ${results[i].group}',
              builder: (context, pressed, hovered) {
                final active = i == _active || hovered;
                return LuzSurface(
                  depth: active ? LuzDepth.insetSm : LuzDepth.flat,
                  radius: LuzRadius.sm,
                  padding: const EdgeInsets.symmetric(
                    horizontal: LuzSpace.md,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        results[i].icon,
                        size: 18,
                        color: active ? p.accent : p.inkMuted,
                      ),
                      const SizedBox(width: LuzSpace.md),
                      Expanded(
                        child: Text(
                          results[i].label,
                          style: t.label.copyWith(color: p.ink),
                        ),
                      ),
                      Text(
                        results[i].group,
                        style: t.caption.copyWith(color: p.muted),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// Right side of the top bars: sign-in buttons, "finish setup", or the
/// signed-in avatar menu.
class AccountArea extends ConsumerWidget {
  const AccountArea({super.key, this.compact = false});

  /// Phones: avatar only (sign-in lives in the menu sheet).
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    switch (auth) {
      case SignedIn(:final user):
        return LuzPressable(
          onPressed: () => showAccountMenu(context, ref),
          radius: LuzRadius.pill,
          tooltip: 'Account: ${user.displayName}',
          semanticLabel: 'Account menu for ${user.displayName}',
          builder: (context, pressed, _) => LuzSurface(
            depth: pressed ? LuzDepth.insetSm : LuzDepth.raisedXs,
            radius: LuzRadius.pill,
            padding: EdgeInsets.fromLTRB(4, 4, compact ? 4 : 12, 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                LuzAvatar(name: user.displayName, size: 32),
                if (!compact) ...[
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 140),
                    child: Text(
                      user.displayName,
                      overflow: TextOverflow.ellipsis,
                      style: context.luzText.label,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.expand_more, size: 18, color: context.luz.muted),
                ],
              ],
            ),
          ),
        );
      case NeedsRole() || NeedsEmailVerification():
        return LuzButton(
          label: 'Finish setup',
          icon: Icons.arrow_forward,
          onPressed: () =>
              context.go(auth is NeedsRole ? chooseRolePath : verifyPath),
        );
      case AuthLoading():
        return const SizedBox(width: 32, height: 32);
      case SignedOut():
        if (compact) return const SizedBox.shrink();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            LuzButton(
              label: 'Sign in',
              onPressed: () => context.go('/sign-in'),
            ),
            const SizedBox(width: LuzSpace.md),
            LuzButton.accent(
              label: 'Get started',
              onPressed: () => context.go('/sign-up'),
            ),
          ],
        );
    }
  }
}

/// Account menu (sheet on phones, dialog elsewhere).
Future<void> showAccountMenu(BuildContext context, WidgetRef ref) {
  final auth = ref.read(authControllerProvider);
  if (auth is! SignedIn) return Future.value();
  return showLuzModal<void>(
    context: context,
    title: auth.user.displayName,
    builder: (ctx) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          auth.user.email,
          style: ctx.luzText.bodySm.copyWith(color: ctx.luz.muted),
        ),
        const SizedBox(height: LuzSpace.lg),
        LuzButton(
          label: 'My dashboard',
          icon: Icons.space_dashboard_outlined,
          expand: true,
          onPressed: () {
            Navigator.of(ctx).pop();
            context.go(homeFor(auth.role));
          },
        ),
        const SizedBox(height: LuzSpace.md),
        LuzButton(
          label: 'Account & appearance',
          icon: Icons.manage_accounts_outlined,
          expand: true,
          onPressed: () {
            Navigator.of(ctx).pop();
            context.go('/account');
          },
        ),
        const SizedBox(height: LuzSpace.md),
        LuzButton(
          label: 'Sign out',
          icon: Icons.logout,
          expand: true,
          onPressed: () {
            Navigator.of(ctx).pop();
            ref.read(authControllerProvider.notifier).signOut();
          },
        ),
      ],
    ),
  );
}
