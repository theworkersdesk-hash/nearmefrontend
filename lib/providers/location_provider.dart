import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

enum LocationStatus { idle, updating, granted, denied }

/// Captures + syncs the device location to the backend. Called after signup
/// and on app foreground so discovery has fresh coordinates.
class LocationNotifier extends StateNotifier<LocationStatus> {
  LocationNotifier(this._ref) : super(LocationStatus.idle);
  final Ref _ref;

  Future<bool> sync() async {
    state = LocationStatus.updating;
    final ok = await _ref.read(locationServiceProvider).syncCurrentLocation();
    state = ok ? LocationStatus.granted : LocationStatus.denied;
    return ok;
  }
}

final locationProvider =
    StateNotifierProvider<LocationNotifier, LocationStatus>(
        (ref) => LocationNotifier(ref));
