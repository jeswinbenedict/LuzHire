import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/enums.dart';
import '../../../core/data/failures.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_state.dart';
import '../../auth/presentation/account_flow_pages.dart' show AuthLoadingPage;
import '../../candidate/presentation/candidate_widgets.dart'
    show AsyncBlock, runWithToast;
import '../application/notification_providers.dart';
import '../data/notifications_repository.dart';

/// /account/notifications: push on this device, and which groups arrive by
/// push and by email. In-app notifications are always kept.
class NotificationSettingsPage extends ConsumerWidget {
  const NotificationSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    if (auth is! SignedIn) return const AuthLoadingPage();
    final t = context.luzText;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(LuzSpace.lg),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: LuzTextLink(
                  label: '← Account',
                  onPressed: () => context.go('/account'),
                ),
              ),
              const SizedBox(height: LuzSpace.xs),
              Semantics(
                header: true,
                child: Text('Notifications', style: t.h3),
              ),
              const SizedBox(height: LuzSpace.lg),
              const _DeviceCard(),
              const SizedBox(height: LuzSpace.lg),
              _PreferencesCard(role: auth.role),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeviceCard extends ConsumerStatefulWidget {
  const _DeviceCard();

  @override
  ConsumerState<_DeviceCard> createState() => _DeviceCardState();
}

class _DeviceCardState extends ConsumerState<_DeviceCard> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) showLuzToast(context, success, icon: Icons.check);
    } catch (e) {
      if (mounted) {
        showLuzToast(context, mapDbError(e).message, icon: Icons.error_outline);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    final t = context.luzText;
    final status = ref.watch(pushDeviceProvider);
    final device = ref.read(pushDeviceProvider.notifier);
    return LuzCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Push on this device', style: t.wsSection),
          const SizedBox(height: LuzSpace.xs),
          status.when(
            skipLoadingOnReload: true,
            loading: () => const LuzSkeleton(width: 220, height: 16),
            error: (e, _) => Text(
              mapDbError(e).message,
              style: t.bodySm.copyWith(color: p.inkMuted),
            ),
            data: (s) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(switch (s) {
                  PushStatus.unsupported =>
                    'This browser can’t show notifications. On an iPhone, '
                        'add LuzHire to your Home Screen first.',
                  PushStatus.blocked =>
                    'Notifications are blocked for LuzHire. Allow them in '
                        'your browser or phone settings, then reload.',
                  PushStatus.off =>
                    'Get a notification on this device when something '
                        'changes, even when LuzHire is closed.',
                  PushStatus.on =>
                    'This device gets push notifications for the groups '
                        'you turn on below.',
                }, style: t.bodySm.copyWith(color: p.inkMuted)),
                const SizedBox(height: LuzSpace.sm),
                Wrap(
                  spacing: LuzSpace.sm,
                  runSpacing: LuzSpace.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (s == PushStatus.on)
                      const LuzStatusChip(
                        label: 'On for this device',
                        tone: LuzChipTone.green,
                        icon: Icons.notifications_active_outlined,
                      ),
                    if (s == PushStatus.off || s == PushStatus.blocked)
                      LuzButton.accent(
                        label: 'Turn on push notifications',
                        icon: Icons.notifications_active_outlined,
                        onPressed: _busy
                            ? null
                            : () => _run(
                                device.enable,
                                'Push notifications are on',
                              ),
                      ),
                    if (s == PushStatus.on)
                      LuzButton(
                        label: 'Turn off on this device',
                        icon: Icons.notifications_off_outlined,
                        onPressed: _busy
                            ? null
                            : () => _run(
                                device.disable,
                                'Push notifications are off for this device',
                              ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: LuzSpace.md),
          Divider(color: p.hairline, height: 1),
          const SizedBox(height: LuzSpace.md),
          Text(
            'Send yourself a test to check push and email. It also appears '
            'in your notification list.',
            style: t.bodySm.copyWith(color: p.inkMuted),
          ),
          const SizedBox(height: LuzSpace.sm),
          LuzButton(
            label: 'Send a test notification',
            icon: Icons.send_outlined,
            onPressed: _busy
                ? null
                : () => runWithToast(
                    context,
                    ref.read(notificationActionsProvider).sendTest,
                    success: 'Test sent. It should arrive in a few seconds.',
                  ),
          ),
        ],
      ),
    );
  }
}

class _PreferencesCard extends ConsumerWidget {
  const _PreferencesCard({required this.role});
  final AppRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.luz;
    final t = context.luzText;
    final value = ref.watch(notificationPreferencesProvider);
    final controller = ref.read(notificationPreferencesProvider.notifier);
    return LuzCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('What you receive', style: t.wsSection),
          const SizedBox(height: LuzSpace.xs),
          Text(
            'You always see every notification inside LuzHire. Choose which '
            'ones also arrive by push and by email.',
            style: t.bodySm.copyWith(color: p.inkMuted),
          ),
          const SizedBox(height: LuzSpace.md),
          AsyncBlock<Map<NotificationCategory, ChannelPrefs>>(
            value: value,
            onRetry: () => ref.invalidate(notificationPreferencesProvider),
            data: (prefs) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ExcludeSemantics(
                  child: Row(
                    children: [
                      const Spacer(),
                      for (final h in ['Push', 'Email'])
                        SizedBox(
                          width: _toggleColumn,
                          child: Text(
                            h,
                            textAlign: TextAlign.center,
                            style: t.caption.copyWith(color: p.muted),
                          ),
                        ),
                    ],
                  ),
                ),
                for (final c in NotificationCategory.forRole(role))
                  _PreferenceRow(
                    category: c,
                    prefs: prefs[c] ?? const ChannelPrefs(),
                    onChanged: (next) =>
                        runWithToast(context, () => controller.set(c, next)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const _toggleColumn = 68.0;

class _PreferenceRow extends StatelessWidget {
  const _PreferenceRow({
    required this.category,
    required this.prefs,
    required this.onChanged,
  });

  final NotificationCategory category;
  final ChannelPrefs prefs;
  final ValueChanged<ChannelPrefs> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    final t = context.luzText;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: LuzSpace.sm),
      child: Row(
        children: [
          Icon(category.icon, size: 20, color: p.inkMuted),
          const SizedBox(width: LuzSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(category.label, style: t.label),
                Text(
                  category.description,
                  style: t.caption.copyWith(color: p.muted),
                ),
              ],
            ),
          ),
          SizedBox(
            width: _toggleColumn,
            child: Center(
              child: LuzToggle(
                value: prefs.push,
                semanticLabel: '${category.label} by push',
                onChanged: (v) => onChanged(prefs.copyWith(push: v)),
              ),
            ),
          ),
          SizedBox(
            width: _toggleColumn,
            child: Center(
              child: LuzToggle(
                value: prefs.email,
                semanticLabel: '${category.label} by email',
                onChanged: (v) => onChanged(prefs.copyWith(email: v)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
