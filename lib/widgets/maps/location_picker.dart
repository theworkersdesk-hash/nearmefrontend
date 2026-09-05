import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../providers/providers.dart';
import '../../services/api_exception.dart';
import '../../services/maps_service.dart';
import '../common/hloppl_button.dart';
import 'static_map_view.dart';

/// Lets a user set an event location either by searching (Google Places, via the
/// backend proxy) or using their current GPS position (reverse-geocoded). Shows
/// a live static-map preview of the chosen point. Emits a [GeoPoint] via
/// [onChanged]; the parent stores lat/lng/address for submission.
class LocationPicker extends ConsumerStatefulWidget {
  const LocationPicker({super.key, required this.onChanged, this.initial});

  final GeoPoint? initial;
  final ValueChanged<GeoPoint> onChanged;

  @override
  ConsumerState<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends ConsumerState<LocationPicker> {
  GeoPoint? _selected;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
  }

  void _set(GeoPoint p) {
    setState(() => _selected = p);
    widget.onChanged(p);
  }

  Future<void> _search() async {
    final result = await Navigator.of(context).push<GeoPoint>(
      MaterialPageRoute(builder: (_) => const _LocationSearchScreen()),
    );
    if (result != null) _set(result);
  }

  Future<void> _useCurrent() async {
    setState(() => _locating = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final pos = await ref.read(locationServiceProvider).getCurrent();
      if (pos == null) {
        messenger.showSnackBar(const SnackBar(
            content: Text('Location unavailable — enable location access')));
        return;
      }
      GeoPoint point;
      try {
        final geo =
            await ref.read(mapsServiceProvider).reverseGeocode(pos.latitude, pos.longitude);
        point = geo ??
            GeoPoint(lat: pos.latitude, lng: pos.longitude, formattedAddress: null);
      } on ApiException {
        // Maps unconfigured/unreachable — still usable with raw coordinates.
        point = GeoPoint(lat: pos.latitude, lng: pos.longitude, formattedAddress: null);
      }
      _set(point);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _selected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Location', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (p != null) ...[
          StaticMapView(lat: p.lat, lng: p.lng, height: 150),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.place, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  p.formattedAddress ??
                      '${p.lat.toStringAsFixed(5)}, ${p.lng.toStringAsFixed(5)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _search,
                icon: const Icon(Icons.search),
                label: Text(p == null ? 'Search location' : 'Change'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _locating ? null : _useCurrent,
                icon: _locating
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.my_location),
                label: const Text('Current'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Full-screen Places search: debounced autocomplete → tap → place details.
class _LocationSearchScreen extends ConsumerStatefulWidget {
  const _LocationSearchScreen();

  @override
  ConsumerState<_LocationSearchScreen> createState() =>
      _LocationSearchScreenState();
}

class _LocationSearchScreenState extends ConsumerState<_LocationSearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<PlaceSuggestion> _results = const [];
  bool _loading = false;
  bool _resolving = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() {
        _results = const [];
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _query(value.trim()));
  }

  Future<void> _query(String input) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ref.read(mapsServiceProvider).autocomplete(input);
      if (mounted) setState(() => _results = res);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _error = e.statusCode == 503
            ? 'Location search is unavailable right now.'
            : e.message);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pick(PlaceSuggestion s) async {
    setState(() => _resolving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final point = await ref.read(mapsServiceProvider).placeDetails(s.placeId);
      if (!mounted) return;
      if (point == null) {
        messenger.showSnackBar(
            const SnackBar(content: Text("Couldn't resolve that place")));
        return;
      }
      Navigator.of(context).pop(
        GeoPoint(
          lat: point.lat,
          lng: point.lng,
          formattedAddress: point.formattedAddress ?? s.description,
        ),
      );
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search location')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _controller,
                autofocus: true,
                onChanged: _onChanged,
                decoration: InputDecoration(
                  hintText: 'Search for a place or address',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _loading
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : null,
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(_error!,
                    style: const TextStyle(color: AppColors.error)),
              ),
            Expanded(
              child: ListView.separated(
                itemCount: _results.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final s = _results[i];
                  return ListTile(
                    leading: const Icon(Icons.place_outlined,
                        color: AppColors.primary),
                    title: Text(s.mainText.isEmpty ? s.description : s.mainText),
                    subtitle:
                        s.secondaryText.isEmpty ? null : Text(s.secondaryText),
                    onTap: _resolving ? null : () => _pick(s),
                  );
                },
              ),
            ),
            if (_resolving)
              const Padding(
                padding: EdgeInsets.all(12),
                child: HlopplButton(label: 'Resolving…', onPressed: null),
              ),
          ],
        ),
      ),
    );
  }
}
