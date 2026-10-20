import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/enums.dart';
import '../../../core/data/format.dart';
import '../../../core/data/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_state.dart';
import '../../candidate/presentation/candidate_widgets.dart'
    show AsyncBlock, runWithToast;
import '../application/notification_providers.dart';
import '../domain/notification_links.dart';

AppRole _role(WidgetRef ref) {
  final auth = ref.watch(authControllerProvider);
  return auth is SignedIn ? auth.role : AppRole.candidate;
}

/// One notification: unread dot (and "Unread" for screen readers), title,
/// message and time.
class NotificationTile extends StatelessWidget {
  const NotificationTile({
    super.key,
    required this.notification,
    required this.onTap,
  });

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    final t = context.luzText;
    final n = notification;
    return Semantics(
      label: n.isUnread ? 'Unread' : null,
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(LuzRadius.sm),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: LuzSpace.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: n.isUnread ? p.accent : Colors.transparent,
                  ),
                ),
              ),
              const SizedBox(width: LuzSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      n.title,
                      style: t.label.copyWith(
                        fontWeight: n.isUnread
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    if ((n.body ?? '').isNotEmpty)
                      Text(n.body!, style: t.bodySm),
                    Text(
                      formatRelative(n.createdAt),
                      style: t.caption.copyWith(color: p.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Live list of the signed-in user's notifications. Tapping one marks it
/// read and opens its screen ([beforeOpen] runs first, e.g. to close a
/// panel).
class NotificationList extends ConsumerWidget {
  const NotificationList({super.key, this.limit, this.beforeOpen, this.footer});

  final int? limit;
  final VoidCallback? beforeOpen;

  /// Shown under a truncated list (e.g. "See all").
  final Widget? footer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.luz;
    final t = context.luzText;
    final role = _role(ref);
    final actions = ref.read(notificationActionsProvider);
    return AsyncBlock<List<AppNotification>>(
      value: ref.watch(myNotificationsProvider),
      onRetry: () => ref.invalidate(myNotificationsProvider),
      data: (all) {
        final list = limit == null ? all : all.take(limit!).toList();
        if (list.isEmpty) {
          return Text(
            'You are all caught up.',
            style: t.body.copyWith(color: p.inkMuted),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final n in list)
              NotificationTile(
                notification: n,
                onTap: () {
                  if (n.isUnread) actions.markRead(n.id).ignore();
                  final router = GoRouter.of(context);
                  beforeOpen?.call();
                  router.go(notificationLink(n.type, n.data, role));
                },
              ),
            if (footer != null && limit != null && all.length > limit!) footer!,
          ],
        );
      },
    );
  }
}

/// "Mark all read", shown while something is unread.
class MarkAllReadLink extends ConsumerWidget {
  const MarkAllReadLink({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(unreadNotificationCountProvider) == 0) {
      return const SizedBox.shrink();
    }
    return LuzTextLink(
      label: 'Mark all read',
      onPressed: () => runWithToast(
        context,
        ref.read(notificationActionsProvider).markAllRead,
      ),
    );
  }
}

/// Workspace header bell: unread count badge and a panel with the list.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key, this.size = 40});
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.luz;
    final unread = ref.watch(unreadNotificationCountProvider);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        LuzIconButton(
          icon: unread > 0
              ? Icons.notifications_active_outlined
              : Icons.notifications_none,
          tooltip: unread == 0
              ? 'Notifications'
              : 'Notifications, $unread unread',
          size: size,
          onPressed: () => showNotificationsPanel(context),
        ),
        if (unread > 0)
          Positioned(
            top: -4,
            right: -4,
            child: ExcludeSemantics(
              child: IgnorePointer(
                child: Container(
                  constraints: const BoxConstraints(minWidth: 20),
                  height: 20,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: LuzBrand.primary,
                    borderRadius: BorderRadius.circular(LuzRadius.pill),
                    border: Border.all(color: p.base, width: 2),
                  ),
                  child: Text(
                    unread > 9 ? '9+' : '$unread',
                    style: context.luzText.caption.copyWith(
                      color: LuzBrand.onPrimary,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

Future<void> showNotificationsPanel(BuildContext context) => showLuzModal<void>(
  context: context,
  title: 'Notifications',
  builder: (ctx) => ConstrainedBox(
    constraints: const BoxConstraints(maxHeight: 440),
    child: SingleChildScrollView(
      child: NotificationList(beforeOpen: () => Navigator.of(ctx).pop()),
    ),
  ),
  actions: (ctx) => [
    const MarkAllReadLink(),
    LuzButton(
      label: 'Settings',
      icon: Icons.tune,
      onPressed: () {
        final router = GoRouter.of(ctx);
        Navigator.of(ctx).pop();
        router.go(notificationSettingsPath);
      },
    ),
  ],
);

const notificationSettingsPath = '/account/notifications';
