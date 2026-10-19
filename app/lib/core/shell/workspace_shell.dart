import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../layout/app_shortcuts.dart';
import '../layout/breakpoints.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/widgets.dart';
import 'shell_common.dart';

/// Shell for employer + admin screens (Workspace zone).
///
/// - ≥ 1024 px: 240 px sidebar (collapsible to a 72 px rail).
/// - 600 – 1023 px: 72 px navigation rail with tooltips.
/// - < 600 px: top bar + navigation drawer.
class WorkspaceShell extends StatefulWidget {
  const WorkspaceShell({
    super.key,
    required this.title,
    required this.destinations,
    required this.location,
    required this.child,
  });

  /// "Employer" or "Admin".
  final String title;
  final List<LuzDestination> destinations;
  final String location;
  final Widget child;

  @override
  State<WorkspaceShell> createState() => _WorkspaceShellState();
}

class _WorkspaceShellState extends State<WorkspaceShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _collapsed = false;

  @override
  Widget build(BuildContext context) {
    final bp = context.breakpoint;
    final selected = selectedIndexFor(widget.destinations, widget.location);
    final current = selected >= 0 ? widget.destinations[selected] : null;

    final nav = switch (bp) {
      LuzBreakpoint.compact => null,
      LuzBreakpoint.medium => _Sidebar(
        title: widget.title,
        destinations: widget.destinations,
        selected: selected,
        collapsed: true,
      ),
      _ => _Sidebar(
        title: widget.title,
        destinations: widget.destinations,
        selected: selected,
        collapsed: _collapsed,
        onToggleCollapsed: () => setState(() => _collapsed = !_collapsed),
      ),
    };

    return LuzZone(
      kind: LuzZoneKind.workspace,
      child: LuzAppShortcuts(
        onCommandMenu: () =>
            showCommandMenu(context, menuDestinations(context)),
        child: Scaffold(
          key: _scaffoldKey,
          drawer: bp.isCompact
              ? Drawer(
                  backgroundColor: context.luz.base,
                  width: 280,
                  child: SafeArea(
                    child: _Sidebar(
                      title: widget.title,
                      destinations: widget.destinations,
                      selected: selected,
                      collapsed: false,
                      onNavigate: () => Navigator.of(context).pop(),
                    ),
                  ),
                )
              : null,
          body: SafeArea(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ?nav,
                Expanded(
                  child: Column(
                    children: [
                      _TopBar(
                        title: current?.label ?? widget.title,
                        showMenu: bp.isCompact,
                        onMenu: () => _scaffoldKey.currentState?.openDrawer(),
                      ),
                      Expanded(child: widget.child),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.title,
    required this.destinations,
    required this.selected,
    required this.collapsed,
    this.onToggleCollapsed,
    this.onNavigate,
  });

  final String title;
  final List<LuzDestination> destinations;
  final int selected;
  final bool collapsed;
  final VoidCallback? onToggleCollapsed;
  final VoidCallback? onNavigate;

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    final t = context.luzText;
    return AnimatedContainer(
      duration: LuzMotion.sheet,
      curve: LuzMotion.curve,
      width: collapsed ? 72 : 240,
      color: p.base,
      padding: const EdgeInsets.symmetric(vertical: LuzSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: collapsed ? 19 : LuzSpace.md,
            ),
            child: collapsed
                ? LuzLogo(
                    size: 34,
                    showWordmark: false,
                    onTap: () => context.go('/'),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LuzLogo(size: 30, onTap: () => context.go('/')),
                      const SizedBox(height: LuzSpace.xs),
                      // Which workspace you're in, set into the surface.
                      LuzSurface(
                        depth: LuzDepth.insetSm,
                        radius: LuzRadius.pill,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        child: Text(
                          '$title workspace',
                          overflow: TextOverflow.ellipsis,
                          style: t.caption.copyWith(
                            color: p.inkMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: LuzSpace.lg),
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(
                horizontal: collapsed ? 12 : LuzSpace.sm,
              ),
              children: [
                for (var i = 0; i < destinations.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _SidebarItem(
                      destination: destinations[i],
                      selected: i == selected,
                      collapsed: collapsed,
                      onTap: () {
                        onNavigate?.call();
                        context.go(destinations[i].path);
                      },
                    ),
                  ),
              ],
            ),
          ),
          if (onToggleCollapsed != null)
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: collapsed ? 12 : LuzSpace.sm,
              ),
              child: _SidebarItem(
                destination: LuzDestination(
                  label: collapsed ? 'Expand sidebar' : 'Collapse sidebar',
                  path: '',
                  icon: collapsed
                      ? Icons.keyboard_double_arrow_right
                      : Icons.keyboard_double_arrow_left,
                ),
                selected: false,
                collapsed: collapsed,
                onTap: onToggleCollapsed!,
              ),
            ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.destination,
    required this.selected,
    required this.collapsed,
    required this.onTap,
  });

  final LuzDestination destination;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    return LuzPressable(
      onPressed: onTap,
      radius: LuzRadius.sm,
      semanticLabel: destination.label,
      tooltip: collapsed ? destination.label : null,
      selected: selected,
      builder: (context, pressed, hovered) => LuzSurface(
        depth: selected || pressed ? LuzDepth.insetSm : LuzDepth.flat,
        radius: LuzRadius.sm,
        color: hovered && !selected ? p.sunken : null,
        child: SizedBox(
          height: 40,
          child: Row(
            children: [
              // Orange indicator bar: selection is never relief-only.
              AnimatedContainer(
                duration: LuzMotion.toggle,
                width: 3,
                height: selected ? 20 : 0,
                margin: const EdgeInsets.only(left: 3),
                decoration: BoxDecoration(
                  color: p.accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: collapsed
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.start,
                  children: [
                    if (!collapsed) const SizedBox(width: 10),
                    Icon(
                      selected ? destination.selectedIcon : destination.icon,
                      size: 18,
                      color: selected ? p.accent : p.inkMuted,
                    ),
                    if (!collapsed) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          destination.label,
                          overflow: TextOverflow.ellipsis,
                          style: context.luzText.label.copyWith(
                            color: selected ? p.ink : p.inkMuted,
                            fontWeight: selected ? FontWeight.w600 : null,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.showMenu,
    required this.onMenu,
  });
  final String title;
  final bool showMenu;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    final compact = context.breakpoint.isCompact;
    return SizedBox(
      height: 60,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? LuzSpace.md : LuzSpace.lg,
        ),
        child: Row(
          children: [
            if (showMenu) ...[
              LuzIconButton(
                icon: Icons.menu,
                tooltip: 'Open navigation',
                size: 40,
                onPressed: onMenu,
              ),
              const SizedBox(width: LuzSpace.md),
            ],
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  style: context.luzText.wsTitle,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            if (!compact) ...[
              LuzPressable(
                onPressed: () =>
                    showCommandMenu(context, menuDestinations(context)),
                radius: LuzRadius.sm,
                semanticLabel: 'Search pages',
                builder: (context, pressed, _) => LuzSurface(
                  depth: LuzDepth.insetSm,
                  radius: LuzRadius.sm,
                  outline: p.outline,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
                    height: 36,
                    width: 220,
                    child: Row(
                      children: [
                        Icon(Icons.search, size: 16, color: p.muted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Search…',
                            style: context.luzText.bodySm.copyWith(
                              color: p.muted,
                            ),
                          ),
                        ),
                        KeyHint(commandKeyLabel(context)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: LuzSpace.md),
            ] else ...[
              LuzIconButton(
                icon: Icons.search,
                tooltip: 'Search pages',
                size: 40,
                onPressed: () =>
                    showCommandMenu(context, menuDestinations(context)),
              ),
              const SizedBox(width: LuzSpace.sm),
            ],
            const ThemeSwitchButton(),
            const SizedBox(width: LuzSpace.sm),
            LuzIconButton(
              icon: Icons.notifications_none,
              tooltip: 'Notifications',
              size: 40,
              onPressed: () => showLuzToast(
                context,
                'Notifications arrive in Phase 9.',
                icon: Icons.notifications_none,
              ),
            ),
            const SizedBox(width: LuzSpace.sm),
            const AccountArea(compact: true),
          ],
        ),
      ),
    );
  }
}
