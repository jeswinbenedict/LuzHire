import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../layout/app_shortcuts.dart';
import '../layout/breakpoints.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/widgets.dart';
import 'destinations.dart';
import 'shell_common.dart';

/// Shell for public + candidate screens (Spotlight zone).
///
/// - ≥ 900 px: raised top navigation with text links.
/// - < 900 px: compact top bar (logo, theme, menu) + bottom navigation
///   for thumb reach; secondary links live in the menu sheet.
class SpotlightShell extends StatelessWidget {
  const SpotlightShell({
    super.key,
    required this.location,
    required this.child,
  });

  final String location;
  final Widget child;

  static const wideNavWidth = 900.0;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= wideNavWidth;
    final selected = selectedIndexFor(spotlightDestinations, location);

    return LuzZone(
      kind: LuzZoneKind.spotlight,
      child: LuzAppShortcuts(
        onCommandMenu: () => showCommandMenu(context, allDestinations),
        onFocusSearch: () => context.go('/jobs'),
        child: Scaffold(
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                wide ? _TopNav(selected: selected) : const _CompactTopBar(),
                Expanded(child: child),
              ],
            ),
          ),
          bottomNavigationBar: wide
              ? null
              : _BottomNav(
                  selected: selected,
                  onSelect: (i) => context.go(spotlightDestinations[i].path),
                ),
        ),
      ),
    );
  }
}

class _TopNav extends StatelessWidget {
  const _TopNav({required this.selected});
  final int selected;

  @override
  Widget build(BuildContext context) {
    final gutter = context.breakpoint.gutter;
    final wide = MediaQuery.sizeOf(context).width >= 1200;
    return LuzSurface(
      depth: LuzDepth.raisedXs,
      radius: 0,
      child: SizedBox(
        height: 68,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: gutter),
          child: Row(
            children: [
              LuzLogo(onTap: () => context.go('/')),
              const SizedBox(width: LuzSpace.lg),
              // Links take the remaining space and scroll rather than overflow
              // (long translations, 200 % text scaling).
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  child: Row(
                    children: [
                      for (var i = 1; i < spotlightDestinations.length - 1; i++)
                        _NavLink(
                          destination: spotlightDestinations[i],
                          selected: i == selected,
                        ),
                      if (wide)
                        const _NavLink(
                          destination: LuzDestination(
                            label: 'For employers',
                            path: '/employer',
                            icon: Icons.business_center_outlined,
                          ),
                          selected: false,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: LuzSpace.sm),
              LuzPressable(
                onPressed: () => showCommandMenu(context, allDestinations),
                radius: LuzRadius.pill,
                tooltip: 'Search pages (${commandKeyLabel(context)})',
                semanticLabel: 'Search pages',
                builder: (context, pressed, _) => LuzSurface(
                  depth: pressed ? LuzDepth.insetSm : LuzDepth.raisedXs,
                  radius: LuzRadius.pill,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search, size: 18, color: context.luz.inkMuted),
                      const SizedBox(width: 8),
                      KeyHint(commandKeyLabel(context)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: LuzSpace.sm),
              const ThemeSwitchButton(),
              const SizedBox(width: LuzSpace.md),
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
          ),
        ),
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  const _NavLink({required this.destination, required this.selected});
  final LuzDestination destination;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    return LuzPressable(
      onPressed: () => context.go(destination.path),
      radius: LuzRadius.pill,
      semanticLabel: destination.label,
      selected: selected,
      builder: (context, pressed, hovered) => LuzSurface(
        depth: selected || pressed ? LuzDepth.insetSm : LuzDepth.flat,
        radius: LuzRadius.pill,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              destination.label,
              style: context.luzText.label.copyWith(
                color: selected || hovered ? p.ink : p.inkMuted,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            AnimatedContainer(
              duration: LuzMotion.toggle,
              width: selected ? 16 : 0,
              height: 2,
              color: p.accent,
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactTopBar extends StatelessWidget {
  const _CompactTopBar();

  @override
  Widget build(BuildContext context) {
    return LuzSurface(
      depth: LuzDepth.raisedXs,
      radius: 0,
      child: SizedBox(
        height: 60,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: LuzSpace.md),
          child: Row(
            children: [
              LuzLogo(onTap: () => context.go('/')),
              const Spacer(),
              const ThemeSwitchButton(),
              const SizedBox(width: LuzSpace.sm),
              LuzIconButton(
                icon: Icons.menu,
                tooltip: 'Menu',
                size: 40,
                onPressed: () => _openMenu(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openMenu(BuildContext context) {
    showLuzModal<void>(
      context: context,
      title: 'Menu',
      forceSheet: true,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          LuzButton.accent(
            label: 'Get started',
            expand: true,
            onPressed: () {
              Navigator.of(ctx).pop();
              context.go('/sign-up');
            },
          ),
          const SizedBox(height: LuzSpace.md),
          LuzButton(
            label: 'Sign in',
            expand: true,
            onPressed: () {
              Navigator.of(ctx).pop();
              context.go('/sign-in');
            },
          ),
          const SizedBox(height: LuzSpace.md),
          LuzButton(
            label: 'For employers',
            icon: Icons.business_center_outlined,
            expand: true,
            onPressed: () {
              Navigator.of(ctx).pop();
              context.go('/employer');
            },
          ),
          const SizedBox(height: LuzSpace.lg),
          Text(
            'Appearance',
            style: ctx.luzText.label.copyWith(color: ctx.luz.muted),
          ),
          const SizedBox(height: LuzSpace.sm),
          const Align(
            alignment: Alignment.centerLeft,
            child: ThemeModeSelector(),
          ),
        ],
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.selected, required this.onSelect});
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    return LuzSurface(
      depth: LuzDepth.raisedSm,
      radius: 0,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 66,
          child: Row(
            children: [
              for (var i = 0; i < spotlightDestinations.length; i++)
                Expanded(
                  child: LuzPressable(
                    onPressed: () => onSelect(i),
                    radius: LuzRadius.md,
                    semanticLabel: spotlightDestinations[i].label,
                    selected: i == selected,
                    builder: (context, pressed, _) {
                      final on = i == selected;
                      final d = spotlightDestinations[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 6,
                          horizontal: 4,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            LuzSurface(
                              depth: on || pressed
                                  ? LuzDepth.insetSm
                                  : LuzDepth.flat,
                              radius: LuzRadius.pill,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 4,
                              ),
                              child: Icon(
                                on ? d.selectedIcon : d.icon,
                                size: 22,
                                color: on ? p.accent : p.inkMuted,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              d.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.luzText.caption.copyWith(
                                color: on ? p.ink : p.muted,
                                fontWeight: on ? FontWeight.w700 : null,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
