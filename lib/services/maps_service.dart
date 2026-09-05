import 'dart:typed_data';

import 'api_service.dart';

/// A resolved geographic point (from geocoding / place details).
class GeoPoint {
  const GeoPoint({required this.lat, required this.lng, this.formattedAddress});
  final double lat;
  final double lng;
  final String? formattedAddress;

  factory GeoPoint.fromJson(Map<String, dynamic> j) => GeoPoint(
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        formattedAddress: j['formattedAddress'] as String?,
      );
}

/// A place autocomplete suggestion for a location search box.
class PlaceSuggestion {
  const PlaceSuggestion({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
  });
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;

  factory PlaceSuggestion.fromJson(Map<String, dynamic> j) => PlaceSuggestion(
        placeId: j['placeId'] as String,
        description: j['description'] as String? ?? '',
        mainText: j['mainText'] as String? ?? '',
        secondaryText: j['secondaryText'] as String? ?? '',
      );
}

/// Client for the backend Google Maps proxy (`/api/maps/*`). The Maps API key
/// lives only on the server — this talks to our own endpoints, never Google
/// directly. A [MapsException]/[ApiException] with statusCode 503 means maps are
/// not configured on the server; callers should degrade gracefully.
class MapsService {
  MapsService(this._api);
  final ApiService _api;

  Future<GeoPoint?> geocode(String address) async {
    final d = await _api
        .get<Map<String, dynamic>>('/maps/geocode', query: {'address': address});
    final p = d['point'];
    return p == null ? null : GeoPoint.fromJson(p as Map<String, dynamic>);
  }

  Future<GeoPoint?> reverseGeocode(double lat, double lng) async {
    final d = await _api.get<Map<String, dynamic>>('/maps/reverse-geocode',
        query: {'lat': lat, 'lng': lng});
    final p = d['point'];
    return p == null ? null : GeoPoint.fromJson(p as Map<String, dynamic>);
  }

  Future<List<PlaceSuggestion>> autocomplete(String input) async {
    final d = await _api.get<Map<String, dynamic>>('/maps/places/autocomplete',
        query: {'input': input});
    final list = (d['suggestions'] as List? ?? const []);
    return list
        .map((e) => PlaceSuggestion.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<GeoPoint?> placeDetails(String placeId) async {
    final d = await _api.get<Map<String, dynamic>>('/maps/places/details',
        query: {'placeId': placeId});
    final p = d['point'];
    return p == null ? null : GeoPoint.fromJson(p as Map<String, dynamic>);
  }

  /// Proxied Google Static Map image bytes (authed). Renders with Image.memory.
  Future<Uint8List> staticMap({
    required double lat,
    required double lng,
    int zoom = 15,
    int width = 600,
    int height = 300,
  }) {
    return _api.getBytes('/maps/static', query: {
      'lat': lat,
      'lng': lng,
      'zoom': zoom,
      'width': width,
      'height': height,
    });
  }
}
