import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/data/enums.dart';
import '../../../core/data/failures.dart';
import '../../../core/data/models.dart';
import '../../../core/layout/content.dart';
import '../../../core/router/links.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_state.dart';
import '../../candidate/presentation/candidate_widgets.dart' show runWithToast;
import '../../jobs/application/job_board_providers.dart'
    show companyByIdProvider;
import '../../jobs/presentation/job_search_page.dart' show JobBoardError;
import '../../jobs/presentation/job_widgets.dart'
    show LoadMoreFooter, SimpleMarkdown, BulletLine;
import '../application/events_providers.dart';
import '../data/events_repository.dart';

/// The /events tabs: hiring drives, hackathons, competitions, webinars.
typedef EventTab = ({String slug, String label, Set<EventKind> kinds});

const eventTabs = <EventTab>[
  (
    slug: 'hiring',
    label: 'Hiring drives',
    kinds: {EventKind.walkIn, EventKind.campusDrive, EventKind.hiringChallenge},
  ),
  (slug: 'hackathons', label: 'Hackathons', kinds: {EventKind.hackathon}),
  (slug: 'competitions', label: 'Competitions', kinds: {EventKind.competition}),
  (slug: 'webinars', label: 'Webinars', kinds: {EventKind.webinar}),
];

/// "Sat 24 Oct, 10:00 am" (and the end time or day when there is one).
String formatEventWhen(Opportunity e) {
  final start = e.startsAt.toLocal();
  final day = DateFormat('EEE d MMM');
  final time = DateFormat('h:mm a');
  final end = e.endsAt?.toLocal();
  if (end == null) return '${day.format(start)}, ${time.format(start)}';
  if (DateUtils.isSameDay(start, end)) {
    return '${day.format(start)}, ${time.format(start)}–${time.format(end)}';
  }
  return '${day.format(start)} – ${day.format(end)}';
}

/// "Closes in 3 days", "Closes today", "Registration closed", "Full".
({String label, bool urgent, bool open}) registrationState(
  Opportunity e,
  DateTime now,
) {
  if (e.status != EventStatus.published) {
    return (label: e.status.label, urgent: false, open: false);
  }
  // Registration on the organiser's site with no deadline given (imported
  // hackathons): say when it runs instead of guessing a closing date.
  if (!e.registersInApp && e.registrationDeadline == null) {
    final end = e.endsAt ?? e.startsAt;
    if (now.isAfter(end)) return (label: 'Ended', urgent: false, open: false);
    if (!now.isBefore(e.startsAt)) {
      return (label: 'Happening now', urgent: false, open: true);
    }
    final days = e.startsAt.difference(now).inHours ~/ 24;
    return (
      label: switch (days) {
        0 => 'Starts today',
        1 => 'Starts tomorrow',
        _ => 'Starts in $days days',
      },
      urgent: days <= 3,
      open: true,
    );
  }
  if (!e.closesAt.isAfter(now)) {
    return (label: 'Registration closed', urgent: false, open: false);
  }
  if (e.isFull) return (label: 'Full', urgent: false, open: false);
  final days = e.closesAt.difference(now).inHours ~/ 24;
  return (
    label: switch (days) {
      0 => 'Closes today',
      1 => 'Closes tomorrow',
      _ => 'Closes in $days days',
    },
    urgent: days <= 3,
    open: true,
  );
}

LuzChipTone _toneFor(EventKind k) =>
    k.isHiring ? LuzChipTone.orange : LuzChipTone.blue;

String _where(Opportunity e) => e.mode == EventMode.online
    ? 'Online'
    : [
        e.location,
        if (e.mode == EventMode.hybrid) 'and online',
      ].whereType<String>().join(' ');

// ---------------------------------------------------------------- /events

/// /events: hiring drives, hackathons, competitions and webinars.
class OpportunitiesPage extends ConsumerWidget {
  const OpportunitiesPage({super.key, this.tab, this.mode});

  /// A slug from [eventTabs], or null for everything.
  final String? tab;
  final EventMode? mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.luz;
    final t = context.luzText;
    final selected = eventTabs.where((x) => x.slug == tab).firstOrNull;
    final query = EventQuery(kinds: selected?.kinds ?? const {}, mode: mode);
    final list = ref.watch(eventListProvider(query));
    final notifier = ref.read(eventListProvider(query).notifier);

    void go({String? tab, EventMode? mode}) => context.go(
      pathWithQuery('/events', {'type': ?tab, 'mode': ?mode?.dbValue}),
    );

    return SingleChildScrollView(
      child: LuzContent(
        vertical: LuzSpace.xl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('OPPORTUNITIES', style: t.eyebrow.copyWith(color: p.accent)),
            const SizedBox(height: LuzSpace.xs),
            Semantics(
              header: true,
              child: Text(
                'Hiring drives, hackathons and competitions',
                style: t.h3,
              ),
            ),
            const SizedBox(height: LuzSpace.xxs),
            Text(
              'Walk in, compete or learn: register in a tap and we keep '
              'your place.',
              style: t.body.copyWith(color: p.inkMuted),
            ),
            const SizedBox(height: LuzSpace.lg),
            // Types, then where: one row on wide screens, wrapping on phones.
            Wrap(
              spacing: LuzSpace.xs,
              runSpacing: LuzSpace.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                LuzFilterChip(
                  label: 'All',
                  selected: selected == null,
                  onSelected: (_) => go(mode: mode),
                ),
                for (final x in eventTabs)
                  LuzFilterChip(
                    label: x.label,
                    icon: x.kinds.first.icon,
                    selected: selected == x,
                    onSelected: (_) => go(tab: x.slug, mode: mode),
                  ),
                Container(
                  width: 1,
                  height: 28,
                  margin: const EdgeInsets.symmetric(horizontal: LuzSpace.xs),
                  color: p.hairline,
                ),
                for (final m in [null, EventMode.online, EventMode.inPerson])
                  LuzFilterChip(
                    label: m == null ? 'Anywhere' : m.label,
                    icon: m?.icon,
                    selected: mode == m,
                    onSelected: (_) => go(tab: selected?.slug, mode: m),
                  ),
              ],
            ),
            const SizedBox(height: LuzSpace.md),
            if (!list.isInitialLoad && list.items.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: LuzSpace.md),
                child: Text(
                  list.hasMore
                      ? 'Upcoming, soonest first'
                      : '${list.items.length} upcoming '
                            '${list.items.length == 1 ? 'event' : 'events'}, '
                            'soonest first',
                  style: t.bodySm.copyWith(color: p.inkMuted),
                ),
              ),
            const _MyRegistrations(),
            if (list.isInitialLoad)
              LuzGrid(
                children: [for (var i = 0; i < 6; i++) const _EventSkeleton()],
              )
            else if (list.items.isEmpty && list.error != null)
              JobBoardError(error: list.error!, onRetry: notifier.loadMore)
            else if (list.items.isEmpty)
              LuzEmptyState(
                icon: Icons.event_busy_outlined,
                title: 'No upcoming events here',
                message: 'New drives and contests are added every week.',
                actionLabel: selected == null && mode == null
                    ? null
                    : 'Show everything',
                onAction: selected == null && mode == null ? null : () => go(),
              )
            else ...[
              LuzGrid(
                equalHeights: true,
                children: [
                  for (final e in list.items)
                    EventCard(event: e, uniform: true),
                ],
              ),
              LoadMoreFooter(
                loading: list.loading,
                hasMore: list.hasMore,
                error: list.error,
                onLoadMore: notifier.loadMore,
                isEmpty: false,
                endLabel: '',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Signed-in candidates: their upcoming registrations.
class _MyRegistrations extends ConsumerWidget {
  const _MyRegistrations();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = ref.watch(myEventRegistrationsProvider).value ?? const {};
    if (mine.isEmpty) return const SizedBox.shrink();
    final t = context.luzText;
    final p = context.luz;
    return Padding(
      padding: const EdgeInsets.only(bottom: LuzSpace.lg),
      child: LuzCard(
        child: Row(
          children: [
            Icon(Icons.event_available, color: p.success),
            const SizedBox(width: LuzSpace.sm),
            Expanded(
              child: Text(
                mine.length == 1
                    ? "You're registered for 1 event. It's marked below."
                    : "You're registered for ${mine.length} events. They're "
                          'marked below.',
                style: t.body,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Event card: banner and logo, type and mode, title and organiser, when
/// and where, then the registration state. In a grid ([uniform]) the footer
/// sits at the bottom so neighbouring cards line up.
class EventCard extends ConsumerWidget {
  const EventCard({super.key, required this.event, this.uniform = false});
  final Opportunity event;
  final bool uniform;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.luz;
    final t = context.luzText;
    final e = event;
    final reg = registrationState(e, DateTime.now());
    final tone = p.chips[_toneFor(e.kind)]!;
    final mine = (ref.watch(myEventRegistrationsProvider).value ?? const {})
        .containsKey(e.id);
    return LuzPressable(
      radius: LuzRadius.lg,
      semanticLabel:
          '${e.kind.label}: ${e.title}, by ${e.organizerName}. '
          '${formatEventWhen(e)}. ${reg.label}',
      onPressed: () => context.go('/events/${e.slug}'),
      builder: (context, pressed, hovered) => LuzSurface(
        depth: pressed
            ? LuzDepth.insetSm
            : hovered
            ? LuzDepth.raisedLg
            : LuzDepth.raisedMd,
        radius: LuzRadius.lg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EventBanner(event: e, aspectRatio: 2.6),
            Expanded(
              flex: uniform ? 1 : 0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  LuzSpace.md,
                  LuzSpace.lg + LuzSpace.xs, // room for the overlapping logo
                  LuzSpace.md,
                  LuzSpace.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${e.kind.label} · ${e.mode.label}'.toUpperCase(),
                      style: t.eyebrow.copyWith(color: tone.foreground),
                    ),
                    const SizedBox(height: LuzSpace.xxs),
                    Text(
                      e.title,
                      style: t.wsSection,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      e.byline,
                      style: t.bodySm.copyWith(color: p.inkMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: LuzSpace.sm),
                    _Fact(icon: Icons.event_outlined, text: formatEventWhen(e)),
                    _Fact(
                      icon: e.mode == EventMode.online
                          ? Icons.wifi
                          : Icons.place_outlined,
                      text: _where(e),
                    ),
                    if ((e.prize ?? '').isNotEmpty)
                      _Fact(icon: Icons.emoji_events_outlined, text: e.prize!),
                    if (uniform) const Spacer(),
                    const SizedBox(height: LuzSpace.sm),
                    Divider(height: 1, color: p.hairline),
                    const SizedBox(height: LuzSpace.sm),
                    Row(
                      children: [
                        Icon(
                          reg.open ? Icons.schedule : Icons.event_busy_outlined,
                          size: 16,
                          color: reg.urgent ? p.accent : p.muted,
                        ),
                        const SizedBox(width: LuzSpace.xs),
                        Expanded(
                          child: Text(
                            reg.label,
                            style: t.label.copyWith(
                              color: !reg.open
                                  ? p.muted
                                  : reg.urgent
                                  ? p.accent
                                  : p.ink,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (mine)
                          const LuzStatusChip(
                            label: 'Registered',
                            tone: LuzChipTone.green,
                            icon: Icons.check_circle_outline,
                          )
                        else if (e.registersInApp && e.registrationCount > 0)
                          Text(
                            '${e.registrationCount} registered',
                            style: t.caption.copyWith(color: p.muted),
                          )
                        else
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'View',
                                style: t.label.copyWith(color: p.accent),
                              ),
                              const SizedBox(width: 2),
                              Icon(
                                Icons.arrow_forward,
                                size: 16,
                                color: p.accent,
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The event's banner image, or a designed one in its kind's colours, with
/// the organiser's logo overlapping its bottom edge. [aspectRatio] is width
/// over height.
class EventBanner extends StatelessWidget {
  const EventBanner({
    super.key,
    required this.event,
    this.aspectRatio = 2.6,
    this.logoSize = 52,
    this.radius = LuzRadius.lg,
  });
  final Opportunity event;
  final double aspectRatio;
  final double logoSize;

  /// Corner radius of the top of the banner (the card's or the page's).
  final double radius;

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    final e = event;
    final tone = p.chips[_toneFor(e.kind)]!;
    final designed = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tone.background,
            Color.lerp(tone.background, tone.foreground, 0.22)!,
          ],
        ),
      ),
      child: Align(
        alignment: const Alignment(0.85, 0),
        child: Icon(
          e.kind.icon,
          size: 72,
          color: tone.foreground.withValues(alpha: 0.22),
        ),
      ),
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
          child: AspectRatio(
            aspectRatio: aspectRatio,
            child: ExcludeSemantics(
              child: e.bannerUrl == null
                  ? designed
                  : Image.network(
                      networkImageUrl(e.bannerUrl!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => designed,
                      loadingBuilder: (_, child, progress) =>
                          progress == null ? child : designed,
                    ),
            ),
          ),
        ),
        Positioned(
          left: LuzSpace.md,
          bottom: -logoSize / 2,
          child: LuzLogoSocket(
            name: e.organizerName,
            logoUrl: e.logoUrl,
            size: logoSize,
          ),
        ),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    return Padding(
      padding: const EdgeInsets.only(top: LuzSpace.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: p.inkMuted),
          const SizedBox(width: LuzSpace.xs),
          Expanded(
            child: Text(
              text,
              style: context.luzText.bodySm.copyWith(color: p.inkMuted),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _EventSkeleton extends StatelessWidget {
  const _EventSkeleton();

  @override
  Widget build(BuildContext context) => const LuzSurface(
    depth: LuzDepth.raisedMd,
    radius: LuzRadius.lg,
    padding: EdgeInsets.all(LuzSpace.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LuzSkeleton(width: 120),
        SizedBox(height: LuzSpace.md),
        LuzSkeleton(height: 18),
        SizedBox(height: LuzSpace.xs),
        LuzSkeleton(width: 160),
        SizedBox(height: LuzSpace.md),
        LuzSkeleton(width: 200),
      ],
    ),
  );
}

// ---------------------------------------------------------------- detail

/// /events/:slug
class EventDetailPage extends ConsumerWidget {
  const EventDetailPage({super.key, required this.slug});
  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final event = ref.watch(eventBySlugProvider(slug));
    return event.when(
      loading: () => const Center(child: LuzSkeleton(width: 220, height: 16)),
      error: (e, _) => Center(
        child: JobBoardError(
          error: mapDbError(e),
          onRetry: () => ref.invalidate(eventBySlugProvider(slug)),
        ),
      ),
      data: (e) => e == null
          ? Center(
              child: LuzEmptyState(
                icon: Icons.event_busy_outlined,
                title: 'This event is not available',
                message: 'It may have been cancelled or taken down.',
                actionLabel: 'All opportunities',
                onAction: () => context.go('/events'),
              ),
            )
          : _EventBody(event: e),
    );
  }
}

class _EventBody extends ConsumerWidget {
  const _EventBody({required this.event});
  final Opportunity event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.luz;
    final t = context.luzText;
    final e = event;
    final company = e.companyId == null
        ? null
        : ref.watch(companyByIdProvider(e.companyId!)).value;

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EventBanner(
          event: e,
          aspectRatio: 3.6,
          logoSize: 72,
          radius: LuzRadius.lg,
        ),
        const SizedBox(height: 36 + LuzSpace.sm), // the logo's lower half
        Wrap(
          spacing: LuzSpace.xs,
          runSpacing: LuzSpace.xxs,
          children: [
            LuzStatusChip(
              label: e.kind.label,
              tone: _toneFor(e.kind),
              icon: e.kind.icon,
            ),
            LuzStatusChip(
              label: e.mode.label,
              tone: LuzChipTone.neutral,
              icon: e.mode.icon,
            ),
            if (e.status != EventStatus.published)
              LuzStatusChip(label: e.status.label, tone: LuzChipTone.neutral),
          ],
        ),
        const SizedBox(height: LuzSpace.sm),
        Semantics(header: true, child: Text(e.title, style: t.h2)),
        const SizedBox(height: LuzSpace.xs),
        if (company != null)
          LuzTextLink(
            label: e.byline,
            onPressed: () => context.go('/companies/${company.slug}'),
          )
        else
          Text(e.byline, style: t.bodyLg.copyWith(color: p.inkMuted)),
      ],
    );

    Widget section(String title, Widget child) => Padding(
      padding: const EdgeInsets.only(bottom: LuzSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(header: true, child: Text(title, style: t.h4)),
          const SizedBox(height: LuzSpace.sm),
          child,
        ],
      ),
    );

    final main = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if ((e.summary ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: LuzSpace.lg),
            child: Text(
              e.summary!,
              style: t.bodyLg.copyWith(color: p.inkMuted),
            ),
          ),
        if (e.descriptionMd.trim().isNotEmpty)
          section('About', SimpleMarkdown(e.descriptionMd)),
        if ((e.eligibility ?? '').isNotEmpty)
          section('Who can take part', BulletLine(e.eligibility!)),
        if ((e.prize ?? '').isNotEmpty) section('Prizes', BulletLine(e.prize!)),
      ],
    );

    final panel = _RegisterPanel(event: e);

    return SingleChildScrollView(
      child: LuzContent(
        vertical: LuzSpace.xl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LuzTextLink(
              label: '← All opportunities',
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go('/events'),
            ),
            const SizedBox(height: LuzSpace.md),
            LayoutBuilder(
              builder: (context, c) => c.maxWidth >= 960
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              header,
                              const SizedBox(height: LuzSpace.xl),
                              main,
                            ],
                          ),
                        ),
                        const SizedBox(width: LuzSpace.xl),
                        SizedBox(width: 360, child: panel),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        header,
                        const SizedBox(height: LuzSpace.lg),
                        panel,
                        const SizedBox(height: LuzSpace.lg),
                        main,
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// When, where, places and the register button.
class _RegisterPanel extends ConsumerWidget {
  const _RegisterPanel({required this.event});
  final Opportunity event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.luz;
    final t = context.luzText;
    final e = event;
    final reg = registrationState(e, DateTime.now());
    final auth = ref.watch(authControllerProvider);
    final role = auth is SignedIn ? auth.user.appRole : null;
    final mine = ref.watch(myEventRegistrationsProvider).value ?? const {};
    final registered = mine.containsKey(e.id);
    final actions = ref.read(eventActionsProvider);

    Widget fact(IconData icon, String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: LuzSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: p.inkMuted),
          const SizedBox(width: LuzSpace.sm),
          SizedBox(
            width: 92,
            child: Text(label, style: t.bodySm.copyWith(color: p.inkMuted)),
          ),
          Expanded(child: Text(value, style: t.label)),
        ],
      ),
    );

    final Widget button;
    if (registered) {
      button = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LuzButton(
            label: mine[e.id] == null
                ? "You're registered"
                : "Registered as team ${mine[e.id]}",
            icon: Icons.check_circle_outline,
            expand: true,
            onPressed: null,
          ),
          if (e.startsAt.isAfter(DateTime.now()))
            Padding(
              padding: const EdgeInsets.only(top: LuzSpace.xs),
              child: LuzTextLink(
                label: 'Cancel my registration',
                onPressed: () async {
                  final ok = await confirmLuz(
                    context,
                    title: 'Cancel your registration?',
                    message: 'Your place goes to someone else.',
                    confirmLabel: 'Cancel registration',
                    icon: Icons.event_busy_outlined,
                  );
                  if (ok && context.mounted) {
                    await runWithToast(
                      context,
                      () => actions.withdraw(e),
                      success: 'Registration cancelled',
                    );
                  }
                },
              ),
            ),
        ],
      );
    } else if (!e.registersInApp) {
      button = LuzButton.accent(
        label: "Register on the organiser's site",
        icon: Icons.open_in_new,
        expand: true,
        onPressed: reg.open
            ? () => launchUrl(
                Uri.parse(e.registrationUrl!),
                mode: LaunchMode.externalApplication,
              )
            : null,
      );
    } else if (auth is! SignedIn) {
      button = LuzButton.accent(
        label: 'Sign in to register',
        icon: Icons.login,
        expand: true,
        onPressed: reg.open
            ? () => context.go(
                Uri(
                  path: '/sign-in',
                  queryParameters: {'from': '/events/${e.slug}'},
                ).toString(),
              )
            : null,
      );
    } else if (role != AppRole.candidate) {
      button = const LuzButton(
        label: 'Candidates register here',
        expand: true,
        onPressed: null,
      );
    } else {
      button = LuzButton.accent(
        label: reg.open ? 'Register' : reg.label,
        icon: Icons.how_to_reg_outlined,
        expand: true,
        onPressed: reg.open ? () => _register(context, ref) : null,
      );
    }

    return LuzCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            reg.label.toUpperCase(),
            style: t.eyebrow.copyWith(color: reg.urgent ? p.accent : p.muted),
          ),
          const SizedBox(height: LuzSpace.md),
          fact(Icons.event_outlined, 'When', formatEventWhen(e)),
          fact(
            e.mode == EventMode.online ? Icons.wifi : Icons.place_outlined,
            'Where',
            [if ((e.venue ?? '').isNotEmpty) e.venue!, _where(e)].join(', '),
          ),
          fact(
            Icons.timer_outlined,
            'Register by',
            DateFormat('EEE d MMM, h:mm a').format(e.closesAt.toLocal()),
          ),
          if (e.isTeamEvent)
            fact(
              Icons.groups_outlined,
              'Team',
              e.teamMin == e.teamMax
                  ? '${e.teamMax} people'
                  : '${e.teamMin}–${e.teamMax} people',
            ),
          if (e.registersInApp)
            fact(
              Icons.how_to_reg_outlined,
              'Registered',
              e.capacity == null
                  ? '${e.registrationCount}'
                  : '${e.registrationCount} of ${e.capacity}',
            ),
          const SizedBox(height: LuzSpace.sm),
          button,
          const SizedBox(height: LuzSpace.sm),
          Row(
            children: [
              Expanded(
                child: LuzTextLink(
                  label: 'Add to Google Calendar',
                  onPressed: () => launchUrl(
                    _calendarLink(e),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              ),
              LuzIconButton(
                icon: Icons.link,
                tooltip: 'Copy link',
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: '${Uri.base.origin}/events/${e.slug}'),
                  );
                  if (context.mounted) {
                    showLuzToast(context, 'Link copied', icon: Icons.check);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _register(BuildContext context, WidgetRef ref) async {
    final e = event;
    if (!e.isTeamEvent) {
      await runWithToast(
        context,
        () => ref.read(eventActionsProvider).register(e),
        success: "You're registered",
      );
      return;
    }
    await showLuzModal<void>(
      context: context,
      title: 'Register your team',
      builder: (_) => _TeamForm(event: e),
    );
  }
}

class _TeamForm extends ConsumerStatefulWidget {
  const _TeamForm({required this.event});
  final Opportunity event;

  @override
  ConsumerState<_TeamForm> createState() => _TeamFormState();
}

class _TeamFormState extends ConsumerState<_TeamForm> {
  final _name = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give your team a name');
      return;
    }
    setState(() => _busy = true);
    final ok = await runWithToast(
      context,
      () =>
          ref.read(eventActionsProvider).register(widget.event, teamName: name),
      success: "Team $name is registered",
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.event;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Teams of ${e.teamMin}–${e.teamMax}. You register as the team '
          'lead; share the event link with your teammates.',
          style: context.luzText.body,
        ),
        const SizedBox(height: LuzSpace.md),
        LuzTextField(
          label: 'Team name',
          controller: _name,
          error: _error,
          maxLength: 80,
          autofocus: true,
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: LuzSpace.md),
        LuzButton.accent(
          label: _busy ? 'Registering…' : 'Register team',
          expand: true,
          onPressed: _busy ? null : _submit,
        ),
      ],
    );
  }
}

Uri _calendarLink(Opportunity e) {
  String stamp(DateTime d) =>
      '${DateFormat("yyyyMMdd'T'HHmmss").format(d.toUtc())}Z';
  final end = e.endsAt ?? e.startsAt.add(const Duration(hours: 2));
  return Uri.https('calendar.google.com', '/calendar/render', {
    'action': 'TEMPLATE',
    'text': e.title,
    'dates': '${stamp(e.startsAt)}/${stamp(end)}',
    'details':
        '${e.kind.label} by ${e.organizerName}. '
        'Details: ${Uri.base.origin}/events/${e.slug}',
    if (e.mode != EventMode.online)
      'location': [e.venue, e.location].whereType<String>().join(', '),
  });
}

// ---------------------------------------------------------------- home

/// Home: the next three opportunities.
class HomeEventsSection extends ConsumerWidget {
  const HomeEventsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref
        .watch(eventListProvider(const EventQuery()))
        .items
        .take(3)
        .toList();
    if (items.isEmpty) return const SizedBox.shrink();
    final p = context.luz;
    final t = context.luzText;
    return LuzContent(
      vertical: LuzSpace.xl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('OPPORTUNITIES', style: t.eyebrow.copyWith(color: p.accent)),
          const SizedBox(height: LuzSpace.xs),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: LuzSpace.md,
            children: [
              Text('Drives and contests coming up', style: t.h3),
              LuzTextLink(
                label: 'All opportunities →',
                onPressed: () => context.go('/events'),
              ),
            ],
          ),
          const SizedBox(height: LuzSpace.lg),
          LuzGrid(
            equalHeights: true,
            children: [
              for (final e in items) EventCard(event: e, uniform: true),
            ],
          ),
        ],
      ),
    );
  }
}
