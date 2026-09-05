import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vibe/services/api_service.dart';
import 'package:vibe/services/maps_service.dart';
import 'package:vibe/services/storage_service.dart';

/// Fake API client returning canned envelopes — no network. Overrides only the
/// methods MapsService uses.
class _FakeApi extends ApiService {
  _FakeApi(this._json, {Uint8List? bytes})
      : _bytes = bytes ?? Uint8List(0),
        super(StorageService());

  final Map<String, dynamic> _json;
  final Uint8List _bytes;
  String? lastPath;
  Map<String, dynamic>? lastQuery;

  @override
  Future<T> get<T>(String path, {Map<String, dynamic>? query}) async {
    lastPath = path;
    lastQuery = query;
    return _json as T;
  }

  @override
  Future<Uint8List> getBytes(String path, {Map<String, dynamic>? query}) async {
    lastPath = path;
    lastQuery = query;
    return _bytes;
  }
}

void main() {
  group('model parsing', () {
    test('GeoPoint.fromJson reads lat/lng/address', () {
      final p = GeoPoint.fromJson({
        'lat': 28.6315,
        'lng': 77.2167,
        'formattedAddress': 'Connaught Place, New Delhi',
      });
      expect(p.lat, 28.6315);
      expect(p.lng, 77.2167);
      expect(p.formattedAddress, contains('Connaught'));
    });

    test('PlaceSuggestion.fromJson maps fields with fallbacks', () {
      final s = PlaceSuggestion.fromJson({
        'placeId': 'abc123',
        'description': 'India Gate, New Delhi',
        'mainText': 'India Gate',
        'secondaryText': 'New Delhi',
      });
      expect(s.placeId, 'abc123');
      expect(s.mainText, 'India Gate');
      expect(s.secondaryText, 'New Delhi');
    });
  });

  group('MapsService', () {
    test('geocode returns a GeoPoint from {point}', () async {
      final api = _FakeApi({
        'point': {'lat': 28.6, 'lng': 77.2, 'formattedAddress': 'Delhi'}
      });
      final svc = MapsService(api);
      final p = await svc.geocode('Connaught Place');
      expect(p, isNotNull);
      expect(p!.lat, 28.6);
      expect(api.lastPath, '/maps/geocode');
      expect(api.lastQuery, {'address': 'Connaught Place'});
    });

    test('geocode returns null when point is absent', () async {
      final svc = MapsService(_FakeApi({'point': null}));
      expect(await svc.geocode('nowhere'), isNull);
    });

    test('autocomplete parses the suggestions list', () async {
      final api = _FakeApi({
        'suggestions': [
          {
            'placeId': 'p1',
            'description': 'India Gate',
            'mainText': 'India Gate',
            'secondaryText': 'New Delhi'
          },
          {
            'placeId': 'p2',
            'description': 'India Habitat Centre',
            'mainText': 'India Habitat Centre',
            'secondaryText': 'New Delhi'
          },
        ]
      });
      final out = await MapsService(api).autocomplete('india');
      expect(out.length, 2);
      expect(out.first.placeId, 'p1');
      expect(api.lastPath, '/maps/places/autocomplete');
    });

    test('staticMap requests the proxy path with coordinates', () async {
      final api = _FakeApi(const {}, bytes: Uint8List.fromList([1, 2, 3]));
      final bytes = await MapsService(api).staticMap(lat: 28.6, lng: 77.2);
      expect(bytes.length, 3);
      expect(api.lastPath, '/maps/static');
      expect(api.lastQuery!['lat'], 28.6);
      expect(api.lastQuery!['lng'], 77.2);
    });
  });
}
