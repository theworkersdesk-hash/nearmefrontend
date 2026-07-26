import 'package:geolocator/geolocator.dart';

import 'api_service.dart';

/// Captures the device GPS location and pushes it to the backend so discovery
/// can place the user. Privacy: only coordinates are sent; other users see
/// distance, never exact position.
class LocationService {
  LocationService(this._api);
  final ApiService _api;

  /// Ensures permission, returns the current position or null if denied.
  Future<Position?> getCurrent() async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    return Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
  }

  Future<void> pushLocation(double latitude, double longitude) async {
    await _api.put('/users/me/location',
        data: {'latitude': latitude, 'longitude': longitude});
  }

  /// Convenience: capture + push in one call. Returns true if location updated.
  Future<bool> syncCurrentLocation() async {
    final pos = await getCurrent();
    if (pos == null) return false;
    await pushLocation(pos.latitude, pos.longitude);
    return true;
  }
}
