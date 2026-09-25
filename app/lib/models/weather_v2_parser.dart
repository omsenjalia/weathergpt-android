/// Parser for v2 `/v2/weather` — WeatherNext capable.
/// Handles both v2 and legacy v1 so migration is safe.
library;

import '../core/models/json_values.dart';
import 'weather.dart';

/// Parses the backend's location timezone into a UTC offset.
///
/// Accepts `utc_offset_seconds`, `utc_offset_hours_approx`, or the
/// WeatherNext label `UTC+5 (solar approximation)`. Returns `null` when
/// nothing usable was reported — callers then fall back to device time
/// rather than guessing.
Duration? parseUtcOffset(Map<String, dynamic>? location) {
  if (location == null) return null;
  final seconds = jsonInt(location['utc_offset_seconds']);
  if (seconds != null) return Duration(seconds: seconds);
  final hours = jsonNum(location['utc_offset_hours_approx']);
  if (hours != null) return Duration(minutes: (hours * 60).round());
  final tz = jsonString(location['timezone']);
  if (tz != null) {
    final m = RegExp(r'^UTC([+-])(\d{1,2})(?::?(\d{2}))?').firstMatch(tz);
    if (m != null) {
      final sign = m.group(1) == '-' ? -1 : 1;
      final h = int.parse(m.group(2)!);
      final min = int.tryParse(m.group(3) ?? '') ?? 0;
      return Duration(minutes: sign * (h * 60 + min));
    }
  }
  return null;
}

/// 12-hour clock label for an hourly bucket in the *location's* local time.
String hourLabelFor(DateTime? utc, Duration? offset) {
  if (utc == null) return '';
  final local = offset == null ? utc.toLocal() : utc.toUtc().add(offset);
  final h = local.hour;
  if (h == 0) return '12AM';
  if (h == 12) return '12PM';
  return h > 12 ? '${h - 12}PM' : '${h}AM';
}

String _hourLabel(String? iso, Duration? offset) {
  final utc = jsonUtc(iso);
  if (utc != null) return hourLabelFor(utc, offset);
  if (iso == null) return '';
  final h = int.tryParse(iso.length >= 13 ? iso.substring(11, 13) : '') ?? 0;
  if (h == 0) return '12AM';
  if (h == 12) return '12PM';
  return h > 12 ? '${h - 12}PM' : '${h}AM';
}

Map<String, String> _fieldSourceMap(Object? raw) {
  final m = jsonMap(raw);
  if (m == null) return const {};
  return {
    for (final e in m.entries)
      if (jsonString(e.value) != null) e.key: jsonString(e.value)!,
  };
}

WeatherSnapshot parseWeatherSnapshotV2(Map<String, dynamic> data, {required String cityName}) {
  final provenance = WeatherProvenance.fromJson(data);
  final location = jsonMap(data['location']);
  final utcOffset = parseUtcOffset(location);
  final timezoneId = jsonString(location?['timezone']) ?? provenance.timezoneId;

  final hourly = <HourlyPoint>[];
  for (final item in jsonList(data['hourly'])) {
    final row = jsonMap(item);
    if (row == null) continue;
    final temp = jsonDouble(row['temperature_c'] ?? row['temperature']);
    if (temp == null) continue;
    final rawTime = row['time'] ?? row['time_utc'];
    hourly.add(HourlyPoint(
      label: _hourLabel(jsonString(rawTime), utcOffset),
      tempC: temp,
      timeUtc: jsonUtc(rawTime),
      rainProbability: jsonNum(row['rain_probability'] ?? row['precipitation_probability']),
      precipMm: jsonNum(row['precipitation'] ?? row['precipitation_mm']),
      windKmh: jsonNum(row['wind_kmh'] ?? row['wind_speed_kmh']),
      windDirection: jsonNum(row['wind_direction_deg'] ?? row['wind_direction']),
      humidity: jsonNum(row['humidity_percent'] ?? row['humidity']),
      feelsLikeC: jsonDouble(row['feels_like_c']),
      pressureHpa: jsonNum(row['pressure_hpa']),
      cloudCover: jsonNum(row['cloud_cover_percent']),
      uvIndex: jsonNum(row['uv_index']),
      condition: jsonString(row['condition']),
      weatherCode: jsonInt(row['weather_code']),
      isEnsembleMean: jsonBool(row['is_ensemble_mean']),
      missingReason: jsonString(row['missing_reason']),
    ));
  }

  final dailyRaw = jsonList(data['daily']).isNotEmpty ? jsonList(data['daily']) : jsonList(data['forecast']);
  final forecast = <DayForecast>[];
  for (final item in dailyRaw) {
    final row = jsonMap(item);
    if (row == null) continue;
    forecast.add(DayForecast(
      date: jsonString(row['date']) ?? '',
      dateUtc: jsonUtc(row['date']),
      highC: jsonDouble(row['high_c']),
      lowC: jsonDouble(row['low_c']),
      condition: jsonString(row['condition']) ?? '—',
      rainProbability: jsonNum(row['rain_probability']),
      precipMm: jsonNum(row['precipitation_mm'] ?? row['rain_mm'] ?? row['rain_sum']),
      precipIntervalLabel: jsonString(row['precipitation_interval']),
      coversFullDay: jsonBool(row['covers_full_day']),
      windKmhMax: jsonNum(row['wind_kmh_max']),
      weatherCode: jsonInt(row['weather_code']),
      highP90C: jsonDouble(row['high_p90_c']),
      lowP10C: jsonDouble(row['low_p10_c']),
      sunrise: jsonString(row['sunrise']),
      sunset: jsonString(row['sunset']),
      uvIndexMax: jsonNum(row['uv_index_max']),
      hoursCovered: jsonInt(row['hours_covered']),
      source: jsonString(row['source']),
      statistic: jsonString(row['statistic']),
      fieldSources: _fieldSourceMap(row['field_sources']),
    ));
  }

  final current = jsonMap(data['current']);
  double? temperatureC;
  double? feelsLikeC;
  String condition = '—';
  int? weatherCode;
  double? highC;
  double? lowC;
  num? humidity;
  num? windKmh;
  num? windDirection;
  num? pressureHpa;
  num? rainProbability;
  num? uvIndex;
  String? sunrise;
  String? sunset;
  num? aqi;
  num? pm25;
  num? cloudCover;
  num? precipMm;
  DateTime? currentTimeUtc;
  bool? currentIsEnsembleMean;

  final first = dailyRaw.isNotEmpty ? jsonMap(dailyRaw.first) : null;
  final aq = jsonMap(data['air_quality']);

  if (current != null) {
    temperatureC = jsonDouble(current['temperature_c']);
    feelsLikeC = jsonDouble(current['feels_like_c']);
    condition = jsonString(current['condition']) ?? jsonString(first?['condition']) ?? '—';
    weatherCode = jsonInt(current['weather_code']) ?? (jsonString(current['condition']) == null ? jsonInt(first?['weather_code']) : null);
    humidity = jsonNum(current['humidity_percent'] ?? current['humidity']);
    windKmh = jsonNum(current['wind_speed_kmh'] ?? current['wind_kmh']);
    windDirection = jsonNum(current['wind_direction_deg'] ?? current['wind_direction']);
    pressureHpa = jsonNum(current['pressure_hpa']);
    rainProbability = jsonNum(current['precipitation_probability'] ?? current['rain_probability']) ??
        jsonNum(first?['rain_probability']);
    // UV: the current step first, else today's daily maximum (labelled as such
    // by the overview tile through `uvIsDailyMax`).
    uvIndex = jsonNum(current['uv_index']);
    cloudCover = jsonNum(current['cloud_cover_percent']);
    precipMm = jsonNum(current['precipitation_mm']);
    currentTimeUtc = jsonUtc(current['time_utc'] ?? current['time']);
    currentIsEnsembleMean = jsonBool(current['is_ensemble_mean']);
    if (forecast.isNotEmpty) {
      highC = forecast.first.highC;
      lowC = forecast.first.lowC;
    }
    sunrise = jsonString(first?['sunrise']);
    sunset = jsonString(first?['sunset']);
  } else {
    temperatureC = jsonDouble(data['temperature_c']);
    feelsLikeC = jsonDouble(data['feels_like_c']);
    condition = jsonString(data['condition']) ?? '—';
    weatherCode = jsonInt(data['weather_code']);
    highC = jsonDouble(data['high_c']);
    lowC = jsonDouble(data['low_c']);
    humidity = jsonNum(data['humidity']);
    windKmh = jsonNum(data['wind_kmh']);
    windDirection = jsonNum(data['wind_direction']);
    pressureHpa = jsonNum(data['pressure_hpa']);
    rainProbability = jsonNum(data['rain_probability']);
    uvIndex = jsonNum(data['uv_index']);
    sunrise = jsonString(data['sunrise']);
    sunset = jsonString(data['sunset']);
    aqi = jsonNum(data['aqi']);
    pm25 = jsonNum(data['pm2_5'] ?? data['pm25']);
    precipMm = jsonNum(data['precipitation_mm']);
  }
  if (aq != null) {
    aqi ??= jsonNum(aq['european_aqi'] ?? aq['aqi']);
    pm25 ??= jsonNum(aq['pm2_5'] ?? aq['pm25']);
  }

  return WeatherSnapshot(
    temperatureC: temperatureC,
    feelsLikeC: feelsLikeC,
    condition: condition,
    weatherCode: weatherCode,
    highC: highC,
    lowC: lowC,
    humidity: humidity,
    windKmh: windKmh,
    windDirection: windDirection,
    pressureHpa: pressureHpa,
    rainProbability: rainProbability,
    uvIndex: uvIndex,
    sunrise: sunrise,
    sunset: sunset,
    aqi: aqi,
    pm25: pm25,
    hourly: hourly,
    forecast: forecast,
    cityName: cityName,
    provenance: provenance,
    temperatureSpread: TemperatureSpread.fromJson(data['temperature_spread'] ?? data['temperature_range']),
    precipNext24h: PrecipitationInterval.fromJson(data['precip_next_24h'] ?? data['precipitation_next_24h']),
    fieldSources: FieldSources.fromJson(data['field_sources']),
    cloudCover: cloudCover,
    precipMm: precipMm,
    currentTimeUtc: currentTimeUtc,
    currentIsEnsembleMean: currentIsEnsembleMean,
    timezoneId: timezoneId,
    utcOffset: utcOffset,
    hourlyAvailable: jsonInt(data['hourly_available']),
    degraded: jsonBool(data['degraded']),
    endpoint: '/v2/weather',
    fetchedAtUtc: jsonUtc(data['fetched_at']),
    rawPayload: data,
  );
}
