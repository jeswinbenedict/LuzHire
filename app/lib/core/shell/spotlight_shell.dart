import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/domain/auth_state.dart';
import '../data/enums.dart';

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
/// Top-level pages that live in the menu sheet on phones.
const _menuOnlyOnPhones = {'/news'};

/// Bottom/top destinations; the last item points at the signed-in role's home.
List<LuzDestination> spotlightDestinationsFor(AuthState auth) {
  final role = auth is SignedIn ? auth.role : null;
  final last = switch (role) {
    AppRole.employer => const LuzDestination(
      label: 'Workspace',
      path: '/employer',
      icon: Icons.business_center_outlined,
      selectedIcon: Icons.business_center,
    ),
    AppRole.admin => const LuzDestination(
      label: 'Admin',
      path: '/admin',
      icon: Icons.admin_panel_settings_outlined,
      selectedIcon: Icons.admin_panel_settings,
    ),
    _ => spotlightDestinations.last,
  };
  return [
    ...spotlightDestinations.take(spotlightDestinations.length - 1),
    last,
  ];
}

/// "For employers": sign up as an employer, or open the workspace.
LuzDestination? employerLinkFor(AuthState auth) => switch (auth) {
  SignedIn(role: AppRole.candidate) => null,
  SignedIn() => const LuzDestination(
    label: 'Employer workspace',
    path: '/employer',
    icon: Icons.business_center_outlined,
  ),
  _ => const LuzDestination(
    label: 'For employers',
    path: '/sign-up?role=employer',
    icon: Icons.business_center_outlined,
  ),
};

class SpotlightShell extends ConsumerWidget {
  const SpotlightShell({
    super.key,
    required this.location,
    required this.child,
  });

  final String location;
  final Widget child;

  static const wideNavWidth = 900.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = MediaQuery.sizeOf(context).width >= wideNavWidth;
    final auth = ref.watch(authControllerProvider);
    final dests = spotlightDestinationsFor(auth);
    final selected = selectedIndexFor(dests, location);
    // Phones keep five tabs; the others are in the menu sheet.
    final compact = [
      for (final d in dests)
        if (!_menuOnlyOnPhones.contains(d.path)) d,
    ];

    return LuzZone(
      kind: LuzZoneKind.spotlight,
      child: LuzAppShortcuts(
        onCommandMenu: () =>
            showCommandMenu(context, menuDestinations(context)),
        onFocusSearch: () => context.go('/jobs'),
        child: Scaffold(
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                wide
                    ? _TopNav(
                        destinations: dests,
                        selected: selected,
                        employerLink: employerLinkFor(auth),
                      )
                    : _CompactTopBar(employerLink: employerLinkFor(auth)),
                Expanded(child: child),
              ],
            ),
          ),
          bottomNavigationBar: wide
              ? null
              : _BottomNav(
                  destinations: compact,
                  selected: selectedIndexFor(compact, location),
                  onSelect: (i) => context.go(compact[i].path),
                ),
        ),
      ),
    );
  }
}

class _TopNav extends StatelessWidget {
  const _TopNav({
    required this.destinations,
    required this.selected,
    this.employerLink,
  });
  final List<LuzDestination> destinations;
  final int selected;
  final LuzDestination? employerLink;

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
                  // Clipped so links that do not fit never paint over the
                  // buttons; the padding keeps the pills' shadows inside.
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      for (var i = 1; i < destinations.length - 1; i++)
                        _NavLink(
                          destination: destinations[i],
                          selected: i == selected,
                        ),
                      if (wide && employerLink != null)
                        _NavLink(destination: employerLink!, selected: false),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: LuzSpace.sm),
              LuzPressable(
                onPressed: () =>
                    showCommandMenu(context, menuDestinations(context)),
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
              const AccountArea(),
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

class _CompactTopBar extends ConsumerWidget {
  const _CompactTopBar({this.employerLink});
  final LuzDestination? employerLink;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LuzSurface(
      depth: LuzDepth.raisedXs,
      radius: 0,
      child: SizedBox(
        height: 60,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: LuzSpace.md),
          child: Row(
            children: [
              // On very narrow phones the logo scales down instead of
              // pushing the controls off-screen.
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: LuzLogo(onTap: () => context.go('/')),
                ),
              ),
              const SizedBox(width: LuzSpace.sm),
              const ThemeSwitchButton(),
              const SizedBox(width: LuzSpace.sm),
              const AccountArea(compact: true),
              const SizedBox(width: LuzSpace.sm),
              LuzIconButton(
                icon: Icons.menu,
                tooltip: 'Menu',
                size: 40,
                onPressed: () =>
                    _openMenu(context, ref.read(authControllerProvider)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openMenu(BuildContext context, AuthState auth) {
    showLuzModal<void>(
      context: context,
      title: 'Menu',
      forceSheet: true,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (auth is SignedOut) ...[
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
          ],
          if (auth is SignedIn) ...[
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
          ],
          for (final d in spotlightDestinations)
            if (_menuOnlyOnPhones.contains(d.path)) ...[
              LuzButton(
                label: d.label,
                icon: d.icon,
                expand: true,
                onPressed: () {
                  Navigator.of(ctx).pop();
                  context.go(d.path);
                },
              ),
              const SizedBox(height: LuzSpace.md),
            ],
          if (employerLink != null)
            LuzButton(
              label: employerLink!.label,
              icon: Icons.business_center_outlined,
              expand: true,
              onPressed: () {
                Navigator.of(ctx).pop();
                context.go(employerLink!.path);
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
  const _BottomNav({
    required this.destinations,
    required this.selected,
    required this.onSelect,
  });
  final List<LuzDestination> destinations;
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
              for (var i = 0; i < destinations.length; i++)
                Expanded(
                  child: LuzPressable(
                    onPressed: () => onSelect(i),
                    radius: LuzRadius.md,
                    semanticLabel: destinations[i].label,
                    selected: i == selected,
                    builder: (context, pressed, _) {
                      final on = i == selected;
                      final d = destinations[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 4,
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
                            // Tab labels stop growing at 130 % (like system
                            // tab bars) so the bar keeps its height; each tab
                            // also has its icon and accessible name.
                            MediaQuery.withClampedTextScaling(
                              maxScaleFactor: 1.3,
                              child: Text(
                                d.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.luzText.caption.copyWith(
                                  color: on ? p.ink : p.muted,
                                  fontWeight: on ? FontWeight.w700 : null,
                                ),
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
