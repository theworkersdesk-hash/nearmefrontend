import 'package:geolocator/geolocator.dart';

import 'api_service.dart';

/// Result of trying to acquire the device location, so callers can show an
/// actionable message (ask again, turn on GPS, or open settings).
enum LocationOutcome { ok, serviceDisabled, denied, deniedForever }

/// Captures the device GPS location and pushes it to the backend so discovery
/// can place the user. Privacy: only coordinates are sent; other users see
/// distance, never exact position.
class LocationService {
  LocationService(this._api);
  final ApiService _api;

  // Dedupe concurrent callers (e.g. home shell + discover on cold start) so the
  // OS permission dialog is never requested twice at once.
  Future<LocationOutcome>? _inFlight;

  /// Ensures permission (prompting if needed), captures the position, and pushes
  /// it to the backend. Returns the outcome so the UI can react.
  Future<LocationOutcome> ensureAndSync() {
    return _inFlight ??= _run().whenComplete(() => _inFlight = null);
  }

  Future<LocationOutcome> _run() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationOutcome.serviceDisabled;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission(); // shows the OS dialog
    }
    if (permission == LocationPermission.deniedForever) {
      return LocationOutcome.deniedForever;
    }
    if (permission == LocationPermission.denied) {
      return LocationOutcome.denied;
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(_fixTimeout);
      await pushLocation(pos.latitude, pos.longitude);
      return LocationOutcome.ok;
    } catch (_) {
      // Couldn't get a fix within the timeout (weak GPS, or a web permission
      // prompt left unanswered). Treat as service-disabled so the UI can hint.
      return LocationOutcome.serviceDisabled;
    }
  }

  /// Max time to wait for a single GPS fix before giving up. Without this a
  /// slow/blocked provider (notably a pending web permission prompt) hangs the
  /// caller forever — which previously froze the events/discover feeds.
  static const _fixTimeout = Duration(seconds: 10);

  /// Returns the current position or null if unavailable/denied/timed out (no
  /// push). Never throws and never hangs — callers fall back gracefully.
  Future<Position?> getCurrent() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(_fixTimeout);
    } catch (_) {
      return null;
    }
  }

  Future<void> pushLocation(double latitude, double longitude) async {
    await _api.put('/users/me/location',
        data: {'latitude': latitude, 'longitude': longitude});
  }

  /// Capture + push in one call. Returns true if location updated.
  Future<bool> syncCurrentLocation() async {
    return (await ensureAndSync()) == LocationOutcome.ok;
  }

  /// Opens the OS app-settings page (used when permission is permanently denied).
  Future<bool> openSettings() => Geolocator.openAppSettings();
}
