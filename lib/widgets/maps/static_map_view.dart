import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/theme.dart';
import '../../providers/providers.dart';
import '../../services/api_exception.dart';

/// Renders a Google Static Map (proxied through the backend so the API key stays
/// server-side) for [lat]/[lng]. Shows a spinner while loading and a graceful
/// placeholder if maps are unconfigured (503) or the fetch fails. Tapping opens
/// the location in the Google Maps app / web.
class StaticMapView extends ConsumerStatefulWidget {
  const StaticMapView({
    super.key,
    required this.lat,
    required this.lng,
    this.height = 160,
    this.zoom = 15,
    this.label,
    this.openOnTap = true,
    this.borderRadius = 16,
  });

  final double lat;
  final double lng;
  final double height;
  final int zoom;

  /// Optional caption shown at the top-left over the map.
  final String? label;
  final bool openOnTap;
  final double borderRadius;

  @override
  ConsumerState<StaticMapView> createState() => _StaticMapViewState();
}

class _StaticMapViewState extends ConsumerState<StaticMapView> {
  late Future<Uint8List> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(StaticMapView old) {
    super.didUpdateWidget(old);
    if (old.lat != widget.lat || old.lng != widget.lng || old.zoom != widget.zoom) {
      _future = _load();
    }
  }

  Future<Uint8List> _load() => ref.read(mapsServiceProvider).staticMap(
        lat: widget.lat,
        lng: widget.lng,
        zoom: widget.zoom,
        height: widget.height.round(),
      );

  Future<void> _open() async {
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${widget.lat},${widget.lng}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: GestureDetector(
        onTap: widget.openOnTap ? _open : null,
        child: SizedBox(
          height: widget.height,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              FutureBuilder<Uint8List>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const ColoredBox(
                      color: AppColors.tertiary,
                      child: Center(
                        child: SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  }
                  if (snap.hasError || snap.data == null || snap.data!.isEmpty) {
                    return _MapUnavailable(reason: _reason(snap.error));
                  }
                  return Image.memory(snap.data!, fit: BoxFit.cover);
                },
              ),
              if (widget.label != null)
                Positioned(
                  left: 10,
                  top: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(widget.label!,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              if (widget.openOnTap)
                const Positioned(
                  right: 10,
                  bottom: 10,
                  child: _OpenChip(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _reason(Object? err) {
    if (err is ApiException && err.statusCode == 503) {
      return 'Map preview unavailable';
    }
    return "Couldn't load map";
  }
}

class _MapUnavailable extends StatelessWidget {
  const _MapUnavailable({required this.reason});
  final String reason;
  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.tertiary,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.map_outlined,
                color: AppColors.primaryDark, size: 30),
            const SizedBox(height: 6),
            Text(reason,
                style: const TextStyle(
                    color: AppColors.primaryDark, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _OpenChip extends StatelessWidget {
  const _OpenChip();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.open_in_new, size: 14, color: AppColors.primaryDark),
          SizedBox(width: 4),
          Text('Open in Maps',
              style: TextStyle(
                  color: AppColors.primaryDark,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
