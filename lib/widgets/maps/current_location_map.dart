import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../providers/event_provider.dart' show userPositionProvider;
import '../../providers/providers.dart';
import '../../services/maps_service.dart';
import 'static_map_view.dart';

/// Reverse-geocodes a rounded lat/lng to a human address (Google, via backend).
/// Keyed on a "lat,lng" string so nearby refreshes reuse the cached result.
final _reverseGeocodeProvider =
    FutureProvider.family<GeoPoint?, String>((ref, latlng) async {
  final parts = latlng.split(',');
  final lat = double.parse(parts[0]);
  final lng = double.parse(parts[1]);
  return ref.read(mapsServiceProvider).reverseGeocode(lat, lng);
});

/// Shows the current user's own location on a Google map + its address — the
/// "person location" the 5km people-find is centred on. Degrades to a hint when
/// location is off and to plain coordinates when maps are unconfigured.
class CurrentLocationMap extends ConsumerWidget {
  const CurrentLocationMap({super.key, this.height = 150});
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posAsync = ref.watch(userPositionProvider);

    return posAsync.when(
      loading: () => SizedBox(
        height: height,
        child: const Center(
          child: SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ),
      error: (_, __) => const _LocationHint('Enable location to see your area.'),
      data: (pos) {
        if (pos == null) {
          return const _LocationHint('Enable location to see people nearby.');
        }
        final key = '${pos.latitude},${pos.longitude}';
        final addr = ref.watch(_reverseGeocodeProvider(key));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StaticMapView(
              lat: pos.latitude,
              lng: pos.longitude,
              height: height,
              label: 'Your location',
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.my_location, size: 15, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    addr.maybeWhen(
                      data: (p) => p?.formattedAddress ?? 'Your current location',
                      orElse: () => 'Your current location',
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _LocationHint extends StatelessWidget {
  const _LocationHint(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.tertiary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_off, color: AppColors.primaryDark, size: 18),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: const TextStyle(color: AppColors.primaryDark))),
        ],
      ),
    );
  }
}
