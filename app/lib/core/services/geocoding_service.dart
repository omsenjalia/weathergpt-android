import 'package:dio/dio.dart';

import '../../models/location.dart';

/// Geocodes free-text place names via Open-Meteo (no API key).
class GeocodingService {
  GeocodingService._();

  /// Returns the best-matching [AppLocation] for [query], or null when the
  /// query is too short, has no match, or the request fails.
  static Future<AppLocation?> search(String query) async {
    final matches = await searchMany(query, count: 1);
    return matches.isEmpty ? null : matches.first;
  }

  /// Returns up to [count] matching places for [query] (empty when the
  /// query is too short, has no match, or the request fails). Backs the
  /// location search suggestions.
  static Future<List<AppLocation>> searchMany(String query,
      {int count = 5}) async {
    final q = query.trim();
    if (q.length < 2) return const [];
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ));
      final res = await dio.get<Map<String, dynamic>>(
        'https://geocoding-api.open-meteo.com/v1/search',
        queryParameters: {'name': q, 'count': count.clamp(1, 10), 'language': 'en'},
      );
      return parseResults(res.data?['results'], q);
    } catch (_) {
      return const [];
    }
  }

  /// Pure parser for the geocoding `results` array, shared by [searchMany]
  /// and unit tests. Malformed entries are skipped, never throw.
  static List<AppLocation> parseResults(Object? results, String query) {
    if (results is! List) return const [];
    final places = <AppLocation>[];
    for (final entry in results) {
      if (entry is! Map) continue;
      final lat = entry['latitude'];
      final lon = entry['longitude'];
      if (lat is! num || lon is! num) continue;
      final name = entry['name'] as String? ?? query;
      final admin = entry['admin1'] as String?;
      final country = entry['country'] as String?;
      final label = [
        name,
        if (admin != null && admin.isNotEmpty) admin,
        if (country != null && country.isNotEmpty && country != admin) country,
      ].join(', ');
      places.add(AppLocation(
          name: label, lat: lat.toDouble(), lon: lon.toDouble()));
    }
    return places;
  }

  /// Best-effort human name for coordinates via BigDataCloud's keyless
  /// client endpoint. Falls back to [fallback] (never throws) so GPS flows
  /// always succeed even when the reverse-geocode service is unreachable.
  static Future<String> reverseName(
    double lat,
    double lon, {
    String fallback = 'Current location',
  }) async {
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
      ));
      final res = await dio.get<Map<String, dynamic>>(
        'https://api.bigdatacloud.net/data/reverse-geocode-client',
        queryParameters: {
          'latitude': lat,
          'longitude': lon,
          'localityLanguage': 'en',
        },
      );
      final data = res.data;
      if (data == null) return fallback;
      final city = (data['city'] ?? data['locality']) as String?;
      final region = data['principalSubdivision'] as String?;
      final label = [
        if (city != null && city.isNotEmpty) city,
        if (region != null && region.isNotEmpty && region != city) region,
      ].join(', ');
      return label.isEmpty ? fallback : label;
    } catch (_) {
      return fallback;
    }
  }
}
