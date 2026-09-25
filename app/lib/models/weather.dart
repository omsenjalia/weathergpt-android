import 'package:flutter/material.dart';

import '../core/models/data_provenance.dart';
import '../core/models/json_values.dart';

export '../core/models/data_provenance.dart';

/// Immutable models for weather data, extracted from
/// `weather_provider.dart` so UI/theme layers can import them without
/// provider machinery.
///
/// Nullable-by-design: a field the backend did not send stays `null` and the UI
/// renders an unavailable state. Missing measurements are never coerced to `0`,
/// and a missing weather code is never treated as "clear".

class HourlyPoint {
  const HourlyPoint({
    required this.label,
    required this.tempC,
    this.timeUtc,
    this.rainProbability,
    this.precipMm,
    this.windKmh,
    this.windDirection,
    this.humidity,
    this.feelsLikeC,
    this.pressureHpa,
    this.cloudCover,
    this.uvIndex,
    this.condition,
    this.weatherCode,
    this.isEnsembleMean,
    this.missingReason,
  });

  final String label;
  final double tempC;

  /// Instant this bucket refers to, in UTC. Kept as UTC so any timezone
  /// conversion happens at display time with the location's timezone id.
  final DateTime? timeUtc;
  final num? rainProbability;
  final num? precipMm;
  final num? windKmh;
  final num? windDirection;
  final num? humidity;
  final double? feelsLikeC;
  final num? pressureHpa;
  final num? cloudCover;
  final num? uvIndex;
  final String? condition;

  /// WMO code when reported. `null` means unknown, never "clear".
  final int? weatherCode;

  /// True when the value is an ensemble mean (WeatherNext), not a
  /// deterministic run.
  final bool? isEnsembleMean;

  /// Backend's stated reason when a field could not be derived.
  final String? missingReason;
}

/// One forecast day. Every measurement is nullable: a day the backend could not
/// fully resolve must not render as a confident zero.
class DayForecast {
  const DayForecast({
    required this.date,
    required this.highC,
    required this.lowC,
    required this.condition,
    required this.rainProbability,
    this.dateUtc,
    this.precipMm,
    this.precipIntervalLabel,
    this.coversFullDay,
    this.windKmhMax,
    this.weatherCode,
    this.highP90C,
    this.lowP10C,
    this.sunrise,
    this.sunset,
    this.uvIndexMax,
    this.hoursCovered,
    this.source,
    this.statistic,
    this.fieldSources = const {},
  });

  final String date;
  final double? highC;
  final double? lowC;
  final String condition;
  final num? rainProbability;

  /// WMO code when reported. `null` means unknown, never "clear".
  final int? weatherCode;

  /// Ensemble envelope for the day when the provider ships quantiles.
  final double? highP90C;
  final double? lowP10C;
  final String? sunrise;
  final String? sunset;
  final num? uvIndexMax;

  /// Number of hourly buckets that went into this day's aggregate.
  final int? hoursCovered;
  final String? source;
  final String? statistic;

  /// Per-field attribution when secondary providers filled a gap
  /// (e.g. `{'sunrise': 'open_meteo'}`).
  final Map<String, String> fieldSources;

  /// Calendar date as a UTC instant, preserved for per-day verdict lookups.
  final DateTime? dateUtc;

  /// Accumulated precipitation for this day, when reported.
  final num? precipMm;

  /// Human-readable coverage of [precipMm], e.g. "12–18 IST". A total whose
  /// interval is incomplete must never be shown as a whole-day total.
  final String? precipIntervalLabel;

  /// `false` when the backend says the interval does not cover the whole day.
  final bool? coversFullDay;
  final num? windKmhMax;

  bool get hasAnyMeasurement =>
      highC != null || lowC != null || rainProbability != null || precipMm != null;

  bool get hasEnvelope => highP90C != null && lowP10C != null;
}

/// Which backend provider supplied each user-visible field.
///
/// The backend fills gaps the selected provider cannot cover (WeatherNext has
/// no sunrise/UV/AQI) from a secondary source and reports it per field, so the
/// UI can say "via Open-Meteo" instead of pretending the value came from the
/// primary model. Unknown fields resolve to `null`, never to a guess.
class FieldSources {
  const FieldSources({
    this.sources = const {},
    this.supplementProvider,
    this.supplementAttempted = false,
    this.supplementEnabled = true,
    this.supplementFilled = const [],
    this.supplementErrors = const [],
    this.supplementCacheHit = false,
  });

  static const FieldSources none = FieldSources();

  /// field name → provider id (`weathernext`, `open_meteo`, …) or `null`
  /// when the backend explicitly reported nobody could supply it.
  final Map<String, String?> sources;
  final String? supplementProvider;
  final bool supplementAttempted;
  final bool supplementEnabled;
  final List<String> supplementFilled;
  final List<String> supplementErrors;
  final bool supplementCacheHit;

  bool get isEmpty => sources.isEmpty;

  /// Provider that supplied [field], or `null` when unknown/unreported.
  String? providerFor(String field) => sources[field];

  WeatherProvider providerEnumFor(String field) =>
      providerFromName(sources[field]);

  /// True when [field] came from a provider other than the payload's
  /// selected source.
  bool isSupplemented(String field, String? primary) {
    final p = sources[field];
    if (p == null || primary == null) return false;
    return providerFromName(p) != providerFromName(primary);
  }

  /// Every distinct provider that contributed at least one field.
  Set<String> get contributors =>
      {for (final v in sources.values) if (v != null) v};

  static FieldSources fromJson(Object? raw) {
    final data = jsonMap(raw);
    if (data == null || data.isEmpty) return none;
    final sources = <String, String?>{};
    Map<String, dynamic>? meta;
    for (final entry in data.entries) {
      if (entry.key == '_supplement') {
        meta = jsonMap(entry.value);
        continue;
      }
      sources[entry.key] = jsonString(entry.value);
    }
    final errors = <String>[];
    for (final e in jsonList(meta?['errors'])) {
      final m = jsonMap(e);
      if (m == null) continue;
      final call = jsonString(m['call']);
      final reason = jsonString(m['reason']) ?? 'unknown';
      errors.add(call == null ? reason : '$call: $reason');
    }
    return FieldSources(
      sources: sources,
      supplementProvider: jsonString(meta?['provider']),
      supplementAttempted: jsonBool(meta?['attempted']) ?? false,
      supplementEnabled: jsonBool(meta?['enabled']) ?? true,
      supplementFilled: [
        for (final f in jsonList(meta?['filled']))
          if (jsonString(f) != null) jsonString(f)!,
      ],
      supplementErrors: errors,
      supplementCacheHit: jsonBool(meta?['cache_hit']) ?? false,
    );
  }
}

/// Model-spread of forecast temperature (p10–p90).
///
/// This is a *spread*, not a probability: no exact rain/temperature probability
/// may be inferred from percentiles (feature/app/implementation_plan.md §3).
class TemperatureSpread {
  const TemperatureSpread({
    required this.p10C,
    required this.p90C,
    this.source,
    this.runId,
    this.validFromUtc,
    this.validToUtc,
    this.memberCount,
  });

  final double p10C;
  final double p90C;
  final String? source;
  final String? runId;
  final DateTime? validFromUtc;
  final DateTime? validToUtc;
  final int? memberCount;

  double get spanC => p90C - p10C;

  /// Coverage window this spread applies to; `null` when unreported.
  Duration? get coverage => validFromUtc == null || validToUtc == null
      ? null
      : validToUtc!.difference(validFromUtc!);

  bool get hasCoverage => coverage != null;

  /// Tolerant parser. Returns `null` unless *both* percentiles are present and
  /// ordered — a one-sided spread is not a spread.
  static TemperatureSpread? fromJson(Object? raw) {
    final data = jsonMap(raw);
    if (data == null) return null;
    final low = jsonDouble(data['p10_c'] ??
        data['p10'] ??
        data['temp_p10_c'] ??
        data['temperature_p10_c']);
    final high = jsonDouble(data['p90_c'] ??
        data['p90'] ??
        data['temp_p90_c'] ??
        data['temperature_p90_c']);
    if (low == null || high == null || high < low) return null;
    return TemperatureSpread(
      p10C: low,
      p90C: high,
      source: jsonString(data['source'] ?? data['provider']),
      runId: jsonString(data['run_id'] ?? data['run']),
      validFromUtc: jsonUtc(data['valid_from'] ?? data['start']),
      validToUtc: jsonUtc(data['valid_to'] ?? data['end']),
      memberCount: jsonInt(data['members'] ?? data['member_count']),
    );
  }
}

/// Expected precipitation for a bounded interval (the Everyone card uses the
/// next 24 hours). Carries its own coverage so a partial interval is never
/// presented as a full-period total.
class PrecipitationInterval {
  const PrecipitationInterval({
    required this.totalMm,
    this.startUtc,
    this.endUtc,
    this.coversFullPeriod,
    this.source,
    this.runId,
    this.label,
  });

  final double totalMm;
  final DateTime? startUtc;
  final DateTime? endUtc;

  /// `false` when the backend says the interval is incomplete.
  final bool? coversFullPeriod;
  final String? source;
  final String? runId;
  final String? label;

  Duration? get length => startUtc == null || endUtc == null
      ? null
      : endUtc!.difference(startUtc!);

  bool get isComplete => coversFullPeriod != false;

  static PrecipitationInterval? fromJson(Object? raw) {
    final data = jsonMap(raw);
    if (data == null) return null;
    final total = jsonDouble(data['total_mm'] ??
        data['precipitation_mm'] ??
        data['precip_mm'] ??
        data['rain_mm']);
    if (total == null || total < 0) return null;
    return PrecipitationInterval(
      totalMm: total,
      startUtc: jsonUtc(data['start'] ?? data['valid_from']),
      endUtc: jsonUtc(data['end'] ?? data['valid_to']),
      coversFullPeriod: jsonBool(data['complete'] ?? data['covers_full_period']),
      source: jsonString(data['source'] ?? data['provider']),
      runId: jsonString(data['run_id'] ?? data['run']),
      label: jsonString(data['label'] ?? data['interval']),
    );
  }
}

class WeatherSnapshot {
  const WeatherSnapshot({
    required this.temperatureC,
    required this.feelsLikeC,
    required this.condition,
    required this.highC,
    required this.lowC,
    required this.humidity,
    required this.windKmh,
    required this.windDirection,
    required this.pressureHpa,
    required this.rainProbability,
    required this.uvIndex,
    required this.sunrise,
    required this.sunset,
    required this.aqi,
    required this.pm25,
    required this.hourly,
    required this.forecast,
    required this.cityName,
    this.weatherCode,
    this.provenance = WeatherProvenance.none,
    this.temperatureSpread,
    this.precipNext24h,
    this.fieldSources = FieldSources.none,
    this.cloudCover,
    this.precipMm,
    this.currentTimeUtc,
    this.currentIsEnsembleMean,
    this.timezoneId,
    this.utcOffset,
    this.hourlyAvailable,
    this.degraded,
    this.endpoint,
    this.fetchedAtUtc,
    this.rawPayload,
  });

  final double? temperatureC;
  final double? feelsLikeC;
  final String condition;

  /// WMO code when the backend sent one. `null` means unknown — it must never
  /// be read as code `0` ("clear sky").
  final int? weatherCode;
  final double? highC;
  final double? lowC;
  final num? humidity;
  final num? windKmh;
  final num? windDirection;

  /// Sea-level pressure. Kept separate from any station pressure the backend
  /// may add later rather than overloading one field.
  final num? pressureHpa;
  final num? rainProbability;
  final num? uvIndex;
  final String? sunrise;
  final String? sunset;
  final num? aqi;
  final num? pm25;

  /// Complete supported hourly series. Display layers slice what they need;
  /// truncating here would silently shorten the horizon for other modes.
  final List<HourlyPoint> hourly;
  final List<DayForecast> forecast;
  final String cityName;

  /// Source/run/freshness reported by the backend, if any.
  final WeatherProvenance provenance;

  /// Everyone-mode enrichment 1: forecast temperature p10–p90 range.
  final TemperatureSpread? temperatureSpread;

  /// Everyone-mode enrichment 2: expected precipitation for the next 24 hours.
  final PrecipitationInterval? precipNext24h;

  /// Per-field provider attribution reported by the backend.
  final FieldSources fieldSources;
  final num? cloudCover;

  /// Precipitation amount for the current bucket, when reported.
  final num? precipMm;

  /// Instant the "current" block refers to (WeatherNext: nearest forecast
  /// step, not an observation).
  final DateTime? currentTimeUtc;
  final bool? currentIsEnsembleMean;

  /// IANA timezone (or the backend's solar approximation label) for the
  /// location. Sunrise/sunset strings are local to this zone.
  final String? timezoneId;

  /// UTC offset of the location when the backend reported one.
  final Duration? utcOffset;

  /// Total hourly buckets the backend had available (may exceed [hourly]).
  final int? hourlyAvailable;

  /// Backend's verdict: a configured higher-priority provider failed or the
  /// data is stale. `null` when the backend did not say.
  final bool? degraded;

  /// Endpoint the snapshot was parsed from (`/v2/weather` or `/weather`).
  final String? endpoint;
  final DateTime? fetchedAtUtc;

  /// Raw decoded payload, retained for the developer debug screen only.
  final Map<String, dynamic>? rawPayload;

  bool get hasCondition => weatherCode != null || condition != '—';

  /// Local time at the location right now, using the reported UTC offset.
  /// Falls back to device local time when the backend gave no offset.
  DateTime localNow() {
    final off = utcOffset;
    if (off == null) return DateTime.now();
    return DateTime.now().toUtc().add(off);
  }

  /// Converts a UTC instant to the location's local clock, when possible.
  DateTime toLocationLocal(DateTime utc) {
    final off = utcOffset;
    if (off == null) return utc.toLocal();
    return utc.toUtc().add(off);
  }

  /// Provider that supplied [field] (falls back to the selected source when
  /// the backend sent no per-field attribution).
  String? sourceOf(String field) =>
      fieldSources.providerFor(field) ??
      (fieldSources.isEmpty ? (provenance.selectedSource ?? provenance.source) : null);

  /// True when [field] was filled by a provider other than the selected one.
  bool isSupplemented(String field) =>
      fieldSources.isSupplemented(field, provenance.selectedSource ?? provenance.source);

  /// Number of days the backend actually returned, for horizon labels.
  int get forecastDays => forecast.length;

  /// Number of hourly buckets returned, for horizon labels.
  int get hourlyPoints => hourly.length;

  // Back-compat for older home scaffolds
  String get temperature =>
      temperatureC == null ? '—' : '${temperatureC!.round()}°';
  String get range =>
      'H: ${highC?.round() ?? '—'}°  L: ${lowC?.round() ?? '—'}°';
  List<WeatherMetric> get metrics => [
        WeatherMetric(Icons.water_drop_outlined,
            rainProbability == null ? '—' : '${rainProbability!.round()}%', 'Rain'),
        WeatherMetric(Icons.air,
            windKmh == null ? '—' : '${windKmh!.toStringAsFixed(0)} km/h', 'Wind'),
        WeatherMetric(Icons.opacity_outlined,
            humidity == null ? '—' : '${humidity!.round()}%', 'Humidity'),
        WeatherMetric(Icons.compress_outlined,
            pressureHpa == null ? '—' : '${pressureHpa!.round()} hPa', 'Pressure'),
      ];
}

class WeatherMetric {
  const WeatherMetric(this.icon, this.value, this.label, {this.qualifier});
  final IconData icon;
  final String value;
  final String label;
  final String? qualifier;
}
