import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// Represents the state of the user's location.
class LocationState {
  final Position? position;
  final bool isLoading;
  final bool isDenied; // user denied permission
  final String? error;

  const LocationState({
    this.position,
    this.isLoading = false,
    this.isDenied = false,
    this.error,
  });

  bool get hasLocation => position != null;
}

class LocationNotifier extends StateNotifier<LocationState> {
  LocationNotifier() : super(const LocationState(isLoading: true)) {
    _init();
  }

  Future<void> _init() async {
    try {
      // 1. Check if location service is enabled on the device
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        state = const LocationState(
          isDenied: true,
          error: 'Location services are disabled on this device.',
        );
        return;
      }

      // 2. Check / request permission
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        state = LocationState(
          isDenied: true,
          error: permission == LocationPermission.deniedForever
              ? 'Location permission permanently denied. Enable it in Settings.'
              : 'Location permission denied.',
        );
        return;
      }

      // 3. Get current position with a reasonable timeout
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );

      state = LocationState(position: position);
    } catch (e) {
      // On timeout or other errors, fall back gracefully (isDenied = false,
      // but position = null so callers know to use fallback ordering).
      state = LocationState(error: e.toString());
    }
  }

  /// Retry — useful if user just enabled permissions in Settings.
  Future<void> retry() async {
    state = const LocationState(isLoading: true);
    await _init();
  }
}

final locationProvider = StateNotifierProvider<LocationNotifier, LocationState>(
  (ref) => LocationNotifier(),
);

/// Haversine distance in kilometres between two lat/lng points.
double distanceKm(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
) {
  return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000.0;
}
