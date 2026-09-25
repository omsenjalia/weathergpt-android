/// Parser for the backend `/weather` payload.
///
/// Kept in its own library (free of Riverpod/Dio) so parser fixtures can be
/// exercised directly: legacy responses, nulls, malformed and partial data.
/// Unknown additive fields are ignored, and absent values stay `null` rather
/// than becoming a confident zero.
library;

import '../core/models/json_values.dart';
import 'weather.dart';
import 'weather_v2_parser.dart' show hourLabelFor, parseUtcOffset;

String _hourLabel(String? iso, Duration? offset) {
  if (iso == null || iso.length < 13) return '';
  // Legacy payloads carry naive local timestamps ("2026-09-19T09:00"): the
  // hour digits are already local. Offset-bearing stamps are converted.
  final utc = jsonUtc(iso);
  if (utc != null && !naiveTimestampAssumedUtc(iso)) {
    return hourLabelFor(utc, offset);
  }
  final h = int.tryParse(iso.substring(11, 13)) ?? 0;
  if (h == 0) return '12AM';
  if (h == 12) return '12PM';
  return h > 12 ? '${h - 12}PM' : '${h}AM';
}

/// Parses the backend `/weather` payload into a [WeatherSnapshot].
///
/// Split out of the provider body so it can be exercised directly by parser
/// fixture tests (legacy responses, nulls, malformed and partial data) without
/// a network. Unknown additive fields are ignored, and absent values stay
/// `null` rather than becoming a confident zero.
WeatherSnapshot parseWeatherSnapshot(
  Map<String, dynamic> data, {
  required String cityName,
}) {
  final provenance = WeatherProvenance.fromJson(data);
  final utcOffset = parseUtcOffset(jsonMap(data['location']) ??
      {'timezone': data['timezone'], 'utc_offset_seconds': data['utc_offset_seconds']});

  final hourly = <HourlyPoint>[];
  for (final item in jsonList(data['hourly'])) {
    final row = jsonMap(item);
    if (row == null) continue;
    final temp = jsonDouble(row['temperature_c'] ?? row['temperature']);
    // A bucket with no temperature cannot be plotted; dropping it is honest,
    // but it must not be drawn as 0 °C.
    if (temp == null) continue;
    final rawTime = row['time'];
    hourly.add(HourlyPoint(
      label: _hourLabel(jsonString(rawTime), utcOffset),
      tempC: temp,
      timeUtc: jsonUtc(rawTime),
      rainProbability: jsonNum(row['rain_probability']),
      precipMm: jsonNum(row['precipitation'] ?? row['precipitation_mm']),
      windKmh: jsonNum(row['wind_kmh']),
      humidity: jsonNum(row['humidity']),
      condition: jsonString(row['condition']),
      weatherCode: jsonInt(row['weather_code']),
    ));
  }

  final forecast = <DayForecast>[];
  for (final item in jsonList(data['forecast'])) {
    final row = jsonMap(item);
    if (row == null) continue;
    final date = jsonString(row['date']) ?? '';
    forecast.add(DayForecast(
      date: date,
      dateUtc: jsonUtc(row['date']),
      highC: jsonDouble(row['high_c']),
      lowC: jsonDouble(row['low_c']),
      condition: jsonString(row['condition']) ?? '—',
      rainProbability: jsonNum(row['rain_probability']),
      precipMm: jsonNum(row['precipitation_mm'] ?? row['rain_mm']),
      precipIntervalLabel: jsonString(row['precipitation_interval']),
      coversFullDay: jsonBool(row['covers_full_day']),
      windKmhMax: jsonNum(row['wind_kmh_max']),
      weatherCode: jsonInt(row['weather_code']),
      sunrise: jsonString(row['sunrise']),
      sunset: jsonString(row['sunset']),
      uvIndexMax: jsonNum(row['uv_index_max']),
    ));
  }

  return WeatherSnapshot(
    temperatureC: jsonDouble(data['temperature_c']),
    feelsLikeC: jsonDouble(data['feels_like_c']),
    condition: jsonString(data['condition']) ?? '—',
    // A missing code stays null. Code 0 means "clear sky", so defaulting here
    // would turn an unknown sky into a sunny one.
    weatherCode: jsonInt(data['weather_code']),
    highC: jsonDouble(data['high_c']),
    lowC: jsonDouble(data['low_c']),
    humidity: jsonNum(data['humidity']),
    windKmh: jsonNum(data['wind_kmh']),
    windDirection: jsonNum(data['wind_direction']),
    pressureHpa: jsonNum(data['pressure_hpa']),
    rainProbability: jsonNum(data['rain_probability']),
    uvIndex: jsonNum(data['uv_index']),
    sunrise: jsonString(data['sunrise']),
    sunset: jsonString(data['sunset']),
    aqi: jsonNum(data['aqi']),
    pm25: jsonNum(data['pm2_5'] ?? data['pm25']),
    hourly: hourly,
    forecast: forecast,
    cityName: cityName,
    provenance: provenance,
    temperatureSpread: TemperatureSpread.fromJson(
        data['temperature_spread'] ?? data['temperature_range']),
    precipNext24h: PrecipitationInterval.fromJson(
        data['precip_next_24h'] ?? data['precipitation_next_24h']),
    fieldSources: FieldSources.fromJson(data['field_sources']),
    precipMm: jsonNum(data['precipitation_mm']),
    timezoneId: jsonString(data['timezone']) ?? provenance.timezoneId,
    utcOffset: utcOffset,
    endpoint: '/weather',
    fetchedAtUtc: jsonUtc(data['fetched_at']),
    rawPayload: data,
  );
}
