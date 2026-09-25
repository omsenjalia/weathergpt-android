import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/services/api_client.dart';
import '../../../core/services/request_log.dart';
import '../../../models/weather.dart';
import '../../../models/weather_parser.dart';
import '../../../models/weather_v2_parser.dart';
import '../../settings/providers/developer_options_provider.dart';
import '../../settings/providers/settings_provider.dart';
import 'location_provider.dart';

/// Defaults used when developer mode is off (or the knobs are untouched).
const kDefaultHourlyHours = 48;
const kDefaultForecastDays = 7;

/// Exactly what the app sent for the current snapshot, so the Debug screen
/// can show the request next to the response.
class WeatherRequestInfo {
  const WeatherRequestInfo({
    required this.endpoint,
    required this.query,
    required this.usedLegacyFallback,
    this.v2Error,
  });
  final String endpoint;
  final Map<String, dynamic> query;
  final bool usedLegacyFallback;
  final String? v2Error;
}

final lastWeatherRequestProvider =
    StateProvider<WeatherRequestInfo?>((ref) => null);

/// The query the app will send, derived from mode + developer options.
Map<String, dynamic> buildWeatherQuery({
  required double lat,
  required double lon,
  required AppMode mode,
  required DeveloperOptions dev,
}) {
  final customise = dev.enabled;
  final pin = customise ? dev.sourcePin : DevSourcePin.auto;
  // Researcher mode pins WeatherNext by contract unless a developer override
  // explicitly asks for something else.
  final requested = pin != DevSourcePin.auto
      ? pin.wire
      : (mode == AppMode.researcher ? 'weathernext' : 'auto');
  return {
    'lat': lat,
    'lon': lon,
    'mode': mode.wire,
    'requested_source': requested,
    'forecast_days': customise ? dev.forecastDays : kDefaultForecastDays,
    'hourly_hours': customise ? dev.hourlyHours : kDefaultHourlyHours,
    if (customise && !dev.supplementSecondaryFields) 'supplement': false,
    if (customise && dev.wnModel != DevWnModel.wn3) 'model': dev.wnModel.wire,
  };
}

/// Current conditions — WeatherNext aware via /v2/weather.
/// v2 returns selected_source, fallback_reasons, per-field sources and richer
/// provenance. Falls back to legacy /weather if v2 is unavailable (unless the
/// developer option disables that so failures are visible).
final weatherProvider = FutureProvider<WeatherSnapshot>((ref) async {
  final location = ref.watch(locationProvider);
  final mode = ref.watch(settingsProvider.select((s) => s.mode));
  final dev = ref.watch(developerOptionsProvider);
  // Keep the ring buffer alive from app start so the Debug screen shows the
  // requests that happened before it was first opened.
  ref.watch(requestLogProvider.notifier);
  RequestLog.enabled = !dev.enabled || dev.logRequests;
  final cityName = location.name.split(',').first;

  final query = buildWeatherQuery(
    lat: location.lat,
    lon: location.lon,
    mode: mode,
    dev: dev,
  );

  Object? v2Error;
  try {
    final data = await ApiClient.instance.get(ApiEndpoints.v2Weather, query: query);
    if (data['status'] == 'unavailable') {
      // The backend answered honestly that nothing could serve this request
      // (typically a pinned source). Surface that instead of falling back.
      final reasons = (data['fallback_reasons'] as List?)
              ?.map((r) => r is Map ? '${r['provider']}: ${r['reason']}' : '$r')
              .join('; ') ??
          '';
      final err = data['error'] ?? 'No forecast provider available';
      throw ServerError(reasons.isEmpty ? '$err' : '$err ($reasons)');
    }
    ref.read(lastWeatherRequestProvider.notifier).state = WeatherRequestInfo(
      endpoint: ApiEndpoints.v2Weather,
      query: query,
      usedLegacyFallback: false,
    );
    return parseWeatherSnapshotV2(data, cityName: cityName);
  } catch (e) {
    v2Error = e;
    if (dev.enabled && dev.disableV2Fallback) rethrow;
    if (e is ServerError && (e.message.contains('unavailable') || e.message.contains('provider'))) {
      // A pinned source that is honestly unavailable must not be replaced by
      // a silent legacy call to a different provider.
      if (query['requested_source'] != 'auto') rethrow;
    }
  }

  final legacyQuery = {
    'lat': location.lat,
    'lon': location.lon,
    'mode': mode.wire,
    'requested_source': query['requested_source'],
  };
  final data = await ApiClient.instance.get(ApiEndpoints.weather, query: legacyQuery);
  ref.read(lastWeatherRequestProvider.notifier).state = WeatherRequestInfo(
    endpoint: ApiEndpoints.weather,
    query: legacyQuery,
    usedLegacyFallback: true,
    v2Error: v2Error.toString(),
  );
  return parseWeatherSnapshot(data, cityName: cityName);
});
