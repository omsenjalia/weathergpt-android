import 'package:flutter_test/flutter_test.dart';
import 'package:weathergpt_mobile/core/services/geocoding_service.dart';

void main() {
  group('GeocodingService.parseResults', () {
    test('labels places as name, admin, country', () {
      final places = GeocodingService.parseResults([
        {
          'name': 'Anand',
          'admin1': 'Gujarat',
          'country': 'India',
          'latitude': 22.5645,
          'longitude': 72.9289,
        },
        {
          'name': 'Singapore',
          'country': 'Singapore',
          'latitude': 1.35,
          'longitude': 103.82,
        },
      ], 'anand');
      expect(places.map((p) => p.name),
          ['Anand, Gujarat, India', 'Singapore, Singapore']);
      expect(places.first.lat, 22.5645);
      expect(places.first.lon, 72.9289);
    });

    test('dedups country when it repeats admin, tolerates missing fields',
        () {
      final places = GeocodingService.parseResults([
        {
          'name': 'Paris',
          'admin1': 'Île-de-France',
          'country': 'France',
          'latitude': 48.85,
          'longitude': 2.35,
        },
        {
          'admin1': 'Gujarat',
          'country': 'India',
          'latitude': 23.0,
          'longitude': 72.5,
        },
      ], 'fallback-query');
      expect(places.map((p) => p.name),
          ['Paris, Île-de-France, France', 'fallback-query, Gujarat, India']);
    });

    test('skips malformed entries without throwing', () {
      expect(GeocodingService.parseResults(null, 'q'), isEmpty);
      expect(GeocodingService.parseResults('nope', 'q'), isEmpty);
      expect(GeocodingService.parseResults([], 'q'), isEmpty);
      final places = GeocodingService.parseResults([
        {
          'name': 'ok',
          'latitude': 1.0,
          'longitude': 2.0,
        },
        {'name': 'missing-coords'},
        {'name': 'bad-coords', 'latitude': 'x', 'longitude': 2.0},
        'junk',
        null,
      ], 'q');
      expect(places.map((p) => p.name), ['ok']);
    });
  });
}
