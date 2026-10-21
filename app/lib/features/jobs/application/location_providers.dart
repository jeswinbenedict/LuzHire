import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/data/failures.dart';
import '../../../core/data/models.dart';
import '../data/jobs_repository.dart';
import 'job_board_providers.dart';

typedef GeoPoint = ({double latitude, double longitude});

/// The device's approximate position (city level is enough).
abstract interface class LocationService {
  /// Throws [AppFailure] with a readable message when location is off or
  /// not allowed.
  Future<GeoPoint> current();
}

class DeviceLocationService implements LocationService {
  @override
  Future<GeoPoint> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const AppFailure(
        'Location is turned off on this device. Turn it on, or pick a city.',
        code: 'location_off',
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const AppFailure(
        'LuzHire may not use your location. Allow it in your browser or '
        'phone settings, or pick a city instead.',
        code: 'location_denied',
      );
    }
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return (latitude: p.latitude, longitude: p.longitude);
    } catch (_) {
      throw const AppFailure(
        "Couldn't find your location. Try again, or pick a city.",
        code: 'location_unavailable',
      );
    }
  }
}

final locationServiceProvider = Provider<LocationService>(
  (ref) => DeviceLocationService(),
);

/// OpenStreetMap's standard tiles (free with attribution, CORS enabled);
/// the map darkens them in the dark theme. CARTO's basemaps now need an API
/// key. Tests override this with null to draw no tiles.
final mapTileUrlProvider = Provider<String? Function(bool dark)>(
  (ref) =>
      (dark) => 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
);

/// Cities with open roles, most first.
final hiringLocationsProvider =
    FutureProvider.autoDispose<List<HiringLocation>>(
      (ref) => ref.watch(jobsRepositoryProvider).hiringLocations(),
    );

/// Jobs picked for the signed-in user (newest jobs for visitors). Refreshes
/// on sign-in and sign-out.
final recommendedJobsProvider = FutureProvider.autoDispose<List<Job>>((
  ref,
) async {
  ref.watch(currentUidProvider);
  final jobs = await ref.watch(jobsRepositoryProvider).recommended();
  ref.read(jobPreviewsProvider).addAll(jobs);
  return jobs;
});

typedef NearbyQuery = ({double latitude, double longitude, double radiusKm});

final nearbyJobsProvider = FutureProvider.autoDispose
    .family<List<Job>, NearbyQuery>((ref, q) async {
      final jobs = await ref
          .watch(jobsRepositoryProvider)
          .near(
            latitude: q.latitude,
            longitude: q.longitude,
            radiusKm: q.radiusKm,
          );
      ref.read(jobPreviewsProvider).addAll(jobs);
      return jobs;
    });
