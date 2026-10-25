import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/data/failures.dart';
import '../../../core/data/models.dart';
import '../../../core/layout/content.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../../events/application/events_providers.dart';
import '../../events/data/events_repository.dart';
import '../../events/presentation/events_pages.dart' show EventCard;
import '../application/location_providers.dart';
import 'job_search_page.dart' show JobBoardError;
import 'job_widgets.dart';

/// /jobs/map: where hiring is happening, and jobs near the user.
///
/// The map is a visual summary; the city list beside it carries the same
/// information for keyboard and screen-reader users.
class HiringMapPage extends ConsumerStatefulWidget {
  const HiringMapPage({super.key});

  static const radii = [25.0, 50.0, 100.0, 250.0];

  @override
  ConsumerState<HiringMapPage> createState() => _HiringMapPageState();
}

class _HiringMapPageState extends ConsumerState<HiringMapPage> {
  final _map = MapController();
  bool _mapReady = false;
  HiringLocation? _city;
  GeoPoint? _me;
  double _radius = 50;
  bool _locating = false;

  void _move(LatLng to, double zoom) {
    if (_mapReady) _map.move(to, zoom);
  }

  void _selectCity(HiringLocation c) {
    setState(() {
      _city = c;
      _me = null;
    });
    _move(LatLng(c.latitude, c.longitude), 9);
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    try {
      final me = await ref.read(locationServiceProvider).current();
      if (!mounted) return;
      setState(() {
        _me = me;
        _city = null;
      });
      _move(LatLng(me.latitude, me.longitude), _zoomFor(_radius));
    } catch (e) {
      if (mounted) {
        showLuzToast(context, mapDbError(e).message, icon: Icons.location_off);
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  static double _zoomFor(double radiusKm) =>
      (11 - math.log(radiusKm / 10) / math.ln2).clamp(4, 11).toDouble();

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    final t = context.luzText;
    final locations = ref.watch(hiringLocationsProvider);
    final cities = locations.value ?? const <HiringLocation>[];
    final total = cities.fold<int>(0, (n, c) => n + c.openJobs);

    final controls = Wrap(
      spacing: LuzSpace.xs,
      runSpacing: LuzSpace.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        LuzButton.accent(
          label: _locating ? 'Finding you…' : 'Jobs near me',
          icon: Icons.my_location,
          onPressed: _locating ? null : _locate,
        ),
        if (_me != null)
          for (final r in HiringMapPage.radii)
            LuzFilterChip(
              label: '${r.round()} km',
              selected: _radius == r,
              onSelected: (_) {
                setState(() => _radius = r);
                _move(LatLng(_me!.latitude, _me!.longitude), _zoomFor(r));
              },
            ),
        if (_me != null || _city != null)
          LuzTextLink(
            label: 'Show all cities',
            onPressed: () => setState(() {
              _me = null;
              _city = null;
            }),
          ),
      ],
    );

    final map = _HiringMap(
      controller: _map,
      cities: cities,
      selected: _city,
      me: _me,
      radiusKm: _radius,
      onReady: () => _mapReady = true,
      onSelect: _selectCity,
    );

    final panel = _Panel(
      cities: cities,
      loading: locations.isLoading && cities.isEmpty,
      error: locations.hasError && cities.isEmpty
          ? mapDbError(locations.error!)
          : null,
      onRetry: () => ref.invalidate(hiringLocationsProvider),
      city: _city,
      me: _me,
      radiusKm: _radius,
      onSelect: _selectCity,
    );

    return SingleChildScrollView(
      child: LuzContent(
        vertical: LuzSpace.xl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('HIRING MAP', style: t.eyebrow.copyWith(color: p.accent)),
            const SizedBox(height: LuzSpace.xs),
            Semantics(
              header: true,
              child: Text('Where hiring is happening', style: t.h2),
            ),
            const SizedBox(height: LuzSpace.xs),
            Text(
              cities.isEmpty
                  ? 'Open roles by city, and jobs near you.'
                  : '$total open roles in ${cities.length} '
                        '${cities.length == 1 ? 'city' : 'cities'}. Remote '
                        'jobs are on the job board.',
              style: t.body.copyWith(color: p.inkMuted),
            ),
            const SizedBox(height: LuzSpace.md),
            controls,
            const SizedBox(height: LuzSpace.lg),
            LayoutBuilder(
              builder: (context, c) => c.maxWidth >= 1024
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: SizedBox(height: 560, child: map)),
                        const SizedBox(width: LuzSpace.lg),
                        SizedBox(width: 400, child: panel),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: 340, child: map),
                        const SizedBox(height: LuzSpace.lg),
                        panel,
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HiringMap extends ConsumerWidget {
  const _HiringMap({
    required this.controller,
    required this.cities,
    required this.selected,
    required this.me,
    required this.radiusKm,
    required this.onReady,
    required this.onSelect,
  });

  final MapController controller;
  final List<HiringLocation> cities;
  final HiringLocation? selected;
  final GeoPoint? me;
  final double radiusKm;
  final VoidCallback onReady;
  final ValueChanged<HiringLocation> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.luz;
    final t = context.luzText;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tiles = ref.watch(mapTileUrlProvider)(dark);
    final most = cities.fold<int>(1, (m, c) => math.max(m, c.openJobs));
    final points = [for (final c in cities) LatLng(c.latitude, c.longitude)];

    return LuzSurface(
      depth: LuzDepth.insetMd,
      radius: LuzRadius.lg,
      padding: const EdgeInsets.all(LuzSpace.xs),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(LuzRadius.md),
        child: FlutterMap(
          mapController: controller,
          options: MapOptions(
            // One city: centred on it; none: India; more: fitted below.
            initialCenter: points.length == 1
                ? points.single
                : const LatLng(21.5, 79),
            initialZoom: points.length == 1 ? 6 : 4,
            minZoom: 2,
            maxZoom: 14,
            initialCameraFit: points.length > 1
                ? CameraFit.coordinates(
                    coordinates: points,
                    padding: const EdgeInsets.all(48),
                    maxZoom: 8,
                  )
                : null,
            backgroundColor: p.sunken,
            onMapReady: onReady,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            if (tiles != null)
              TileLayer(
                urlTemplate: tiles,
                userAgentPackageName: 'app.luzhire',
                tileBuilder: dark ? darkModeTileBuilder : null,
              ),
            if (me != null)
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: LatLng(me!.latitude, me!.longitude),
                    radius: radiusKm * 1000,
                    useRadiusInMeter: true,
                    color: p.accent.withValues(alpha: 0.12),
                    borderColor: p.accent,
                    borderStrokeWidth: 2,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                for (final c in cities)
                  Marker(
                    point: LatLng(c.latitude, c.longitude),
                    width: _size(c.openJobs, most),
                    height: _size(c.openJobs, most),
                    child: _Bubble(
                      city: c,
                      selected: c.cityId == selected?.cityId,
                      onTap: () => onSelect(c),
                    ),
                  ),
                if (me != null)
                  Marker(
                    point: LatLng(me!.latitude, me!.longitude),
                    width: 22,
                    height: 22,
                    child: Semantics(
                      label: 'Your location',
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: p.info,
                          shape: BoxShape.circle,
                          border: Border.all(color: p.base, width: 3),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: Container(
                margin: const EdgeInsets.all(LuzSpace.xxs),
                padding: const EdgeInsets.symmetric(
                  horizontal: LuzSpace.xs,
                  vertical: 2,
                ),
                color: p.base.withValues(alpha: 0.85),
                child: Text(
                  '© OpenStreetMap contributors',
                  style: t.caption.copyWith(color: p.inkMuted),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Bubble diameter grows with the square root of open roles.
  static double _size(int jobs, int most) =>
      28 + 30 * math.sqrt(jobs / most).clamp(0, 1);
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.city,
    required this.selected,
    required this.onTap,
  });
  final HiringLocation city;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    final t = context.luzText;
    return Semantics(
      button: true,
      selected: selected,
      excludeSemantics: true,
      label:
          '${city.name}: ${city.openJobs} open roles'
          '${city.events > 0 ? ', ${city.events} upcoming events' : ''}',
      child: GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: selected ? p.accent : p.base,
              shape: BoxShape.circle,
              border: Border.all(color: p.accent, width: 2),
              boxShadow: [
                BoxShadow(
                  color: p.shade.withValues(alpha: 0.35),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: FittedBox(
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Text(
                    '${city.openJobs + city.events}',
                    style: t.label.copyWith(
                      color: selected ? p.base : p.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Beside (or under) the map: jobs near the user, jobs in the chosen city,
/// or the cities ranked by open roles.
class _Panel extends ConsumerWidget {
  const _Panel({
    required this.cities,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.city,
    required this.me,
    required this.radiusKm,
    required this.onSelect,
  });

  final List<HiringLocation> cities;
  final bool loading;
  final AppFailure? error;
  final VoidCallback onRetry;
  final HiringLocation? city;
  final GeoPoint? me;
  final double radiusKm;
  final ValueChanged<HiringLocation> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.luz;
    final t = context.luzText;

    if (me != null || city != null) {
      final q = me != null
          ? (
              latitude: me!.latitude,
              longitude: me!.longitude,
              radiusKm: radiusKm,
            )
          : (
              latitude: city!.latitude,
              longitude: city!.longitude,
              radiusKm: 25.0,
            );
      final jobs = ref.watch(nearbyJobsProvider(q));
      final title = me != null
          ? 'Within ${radiusKm.round()} km of you'
          : 'Jobs in ${city!.name}';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (city != null && city!.events > 0) ...[
            Semantics(
              header: true,
              child: Text('Events in ${city!.name}', style: t.h4),
            ),
            const SizedBox(height: LuzSpace.sm),
            for (final e
                in ref
                    .watch(eventListProvider(EventQuery(cityId: city!.cityId)))
                    .items) ...[
              EventCard(event: e),
              const SizedBox(height: LuzSpace.sm),
            ],
            const SizedBox(height: LuzSpace.md),
          ],
          Semantics(header: true, child: Text(title, style: t.h4)),
          const SizedBox(height: LuzSpace.sm),
          jobs.when(
            loading: () => const JobCardSkeleton(),
            error: (e, _) => JobBoardError(
              error: mapDbError(e),
              onRetry: () => ref.invalidate(nearbyJobsProvider(q)),
            ),
            data: (list) => list.isEmpty
                ? Text(
                    me != null
                        ? 'No on-site or hybrid jobs this close yet. Try a '
                              'larger radius or a city on the map.'
                        : 'No open roles here right now.',
                    style: t.body.copyWith(color: p.inkMuted),
                  )
                // Compact cards, as in job search: same rows on every card.
                : LuzDense(
                    child: Column(
                      children: [
                        for (final j in list) ...[
                          JobCard(job: j),
                          const SizedBox(height: LuzSpace.sm),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      );
    }

    if (loading) return const JobCardSkeleton();
    if (error != null) return JobBoardError(error: error!, onRetry: onRetry);
    if (cities.isEmpty) {
      return LuzEmptyState(
        icon: Icons.public,
        title: 'No city-based jobs yet',
        message:
            'Most openings right now are remote. They are all on the job '
            'board.',
        actionLabel: 'Browse remote jobs',
        onAction: () => context.go('/jobs?remote=1'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(header: true, child: Text('Top hiring cities', style: t.h4)),
        const SizedBox(height: LuzSpace.sm),
        for (final c in cities.take(12)) ...[
          LuzPressable(
            radius: LuzRadius.md,
            semanticLabel: '${c.label}: ${c.openJobs} open roles',
            onPressed: () => onSelect(c),
            builder: (context, pressed, hovered) => LuzSurface(
              depth: pressed
                  ? LuzDepth.insetSm
                  : hovered
                  ? LuzDepth.raisedMd
                  : LuzDepth.raisedSm,
              radius: LuzRadius.md,
              padding: const EdgeInsets.symmetric(
                horizontal: LuzSpace.md,
                vertical: LuzSpace.sm,
              ),
              child: Row(
                children: [
                  Icon(Icons.place_outlined, color: p.accent, size: 20),
                  const SizedBox(width: LuzSpace.sm),
                  Expanded(child: Text(c.label, style: t.label)),
                  Text(
                    [
                      if (c.openJobs > 0)
                        '${c.openJobs} ${c.openJobs == 1 ? 'role' : 'roles'}',
                      if (c.events > 0)
                        '${c.events} ${c.events == 1 ? 'event' : 'events'}',
                    ].join(' · '),
                    style: t.bodySm.copyWith(color: p.inkMuted),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: LuzSpace.xs),
        ],
      ],
    );
  }
}
