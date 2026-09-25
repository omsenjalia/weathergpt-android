import 'package:flutter_test/flutter_test.dart';
import 'package:weathergpt_mobile/models/weather.dart';
import 'package:weathergpt_mobile/models/weather_parser.dart';
import 'package:weathergpt_mobile/models/weather_v2_parser.dart';

void main() {
  group('parseWeatherSnapshot — legacy contract', () {
    test('parses the documented /weather response', () {
      final snapshot = parseWeatherSnapshot({
        'temperature_c': 31.4,
        'feels_like_c': 35.1,
        'condition': 'Partly cloudy',
        'weather_code': 2,
        'high_c': 34,
        'low_c': 26,
        'humidity': 62,
        'wind_kmh': 14,
        'wind_direction': 210,
        'pressure_hpa': 1008,
        'rain_probability': 30,
        'uv_index': 7.5,
        'sunrise': '06:12',
        'sunset': '18:44',
        'aqi': 88,
        'pm2_5': 34.2,
        'hourly': [
          {'time': '2026-09-19T09:00', 'temperature_c': 29.0},
          {'time': '2026-09-19T10:00', 'temperature_c': 30.5},
        ],
        'forecast': [
          {
            'date': '2026-09-19',
            'high_c': 34,
            'low_c': 26,
            'condition': 'Partly cloudy',
            'rain_probability': 30,
          },
        ],
      }, cityName: 'Anand');

      expect(snapshot.temperatureC, 31.4);
      expect(snapshot.feelsLikeC, 35.1);
      expect(snapshot.condition, 'Partly cloudy');
      expect(snapshot.weatherCode, 2);
      expect(snapshot.humidity, 62);
      expect(snapshot.pm25, 34.2);
      expect(snapshot.hourly, hasLength(2));
      expect(snapshot.hourly.first.tempC, 29.0);
      expect(snapshot.forecast.single.date, '2026-09-19');
      expect(snapshot.forecast.single.rainProbability, 30);
      expect(snapshot.cityName, 'Anand');
    });

    test('keeps the complete hourly series — no fixed truncation', () {
      final snapshot = parseWeatherSnapshot({
        'hourly': [
          for (var h = 0; h < 40; h++)
            {'time': '2026-09-19T${h.toString().padLeft(2, '0')}:00', 'temperature_c': 20 + h}
        ],
      }, cityName: 'X');
      // The old parser silently dropped everything after 12 buckets, which
      // shortened the horizon for every mode that needed more.
      expect(snapshot.hourlyPoints, 40);
      expect(snapshot.hourly.last.tempC, 59);
    });

    test('hour buckets keep their UTC instant and additive fields', () {
      final snapshot = parseWeatherSnapshot({
        'hourly': [
          {
            'time': '2026-09-19T14:00:00+05:30',
            'temperature_c': 33,
            'rain_probability': 45,
            'precipitation': 1.5,
            'wind_kmh': 22,
          },
        ],
      }, cityName: 'X');
      final point = snapshot.hourly.single;
      expect(point.timeUtc, DateTime.utc(2026, 9, 19, 8, 30));
      expect(point.rainProbability, 45);
      expect(point.precipMm, 1.5);
      expect(point.windKmh, 22);
    });
  });

  group('parseWeatherSnapshot — missing and malformed data', () {
    test('a missing weather code stays null and is not read as clear sky', () {
      final snapshot =
          parseWeatherSnapshot({'condition': '—'}, cityName: 'X');
      expect(snapshot.weatherCode, isNull);
      expect(snapshot.hasCondition, isFalse);
      // Regression: code 0 means "clear sky", so a default of 0 turned an
      // unknown sky into a sunny one downstream.
      expect(snapshot.weatherCode, isNot(0));
    });

    test('absent measurements stay null instead of becoming zero', () {
      final snapshot = parseWeatherSnapshot(const {}, cityName: 'X');
      expect(snapshot.temperatureC, isNull);
      expect(snapshot.rainProbability, isNull);
      expect(snapshot.humidity, isNull);
      expect(snapshot.windKmh, isNull);
      expect(snapshot.pressureHpa, isNull);
      expect(snapshot.uvIndex, isNull);
      expect(snapshot.metrics.every((m) => m.value == '—'), isTrue);
    });

    test('malformed rows are skipped rather than plotted as zero', () {
      final snapshot = parseWeatherSnapshot({
        'hourly': [
          'not-a-map',
          {'time': '2026-09-19T09:00'}, // no temperature
          {'time': '2026-09-19T10:00', 'temperature_c': 'warm'},
          {'time': '2026-09-19T11:00', 'temperature_c': 31},
        ],
        'forecast': [
          'not-a-map',
          {'date': '2026-09-19'},
        ],
      }, cityName: 'X');
      expect(snapshot.hourly, hasLength(1));
      expect(snapshot.hourly.single.tempC, 31);
      // A day with no measurements is kept but flagged, never zero-filled.
      expect(snapshot.forecast.single.hasAnyMeasurement, isFalse);
      expect(snapshot.forecast.single.highC, isNull);
    });

    test('a partial day keeps its interval caveat', () {
      final snapshot = parseWeatherSnapshot({
        'forecast': [
          {
            'date': '2026-09-19',
            'precipitation_mm': 6,
            'precipitation_interval': '12–18 IST',
            'covers_full_day': false,
          }
        ],
      }, cityName: 'X');
      final day = snapshot.forecast.single;
      expect(day.precipMm, 6);
      expect(day.precipIntervalLabel, '12–18 IST');
      expect(day.coversFullDay, isFalse);
    });
  });

  group('parseWeatherSnapshot — Everyone enrichments', () {
    test('accepts a p10–p90 temperature spread with its coverage', () {
      final snapshot = parseWeatherSnapshot({
        'temperature_spread': {
          'p10_c': 27.2,
          'p90_c': 33.8,
          'source': 'weathernext',
          'run_id': '2026091906',
          'valid_from': '2026-09-19T00:00:00Z',
          'valid_to': '2026-09-20T00:00:00Z',
          'members': 50,
        },
      }, cityName: 'X');
      final spread = snapshot.temperatureSpread!;
      expect(spread.p10C, 27.2);
      expect(spread.p90C, 33.8);
      expect(spread.spanC, closeTo(6.6, 1e-9));
      expect(spread.source, 'weathernext');
      expect(spread.runId, '2026091906');
      expect(spread.coverage, const Duration(hours: 24));
      expect(spread.memberCount, 50);
    });

    test('rejects a one-sided or inverted spread instead of showing a fake range',
        () {
      expect(
          parseWeatherSnapshot({
            'temperature_spread': {'p10_c': 27.2}
          }, cityName: 'X').temperatureSpread,
          isNull);
      expect(
          parseWeatherSnapshot({
            'temperature_spread': {'p10_c': 33.8, 'p90_c': 27.2}
          }, cityName: 'X').temperatureSpread,
          isNull);
      expect(
          parseWeatherSnapshot(const {}, cityName: 'X').temperatureSpread,
          isNull);
    });

    test('parses next-24h precipitation and flags incomplete coverage', () {
      final complete = parseWeatherSnapshot({
        'precip_next_24h': {
          'total_mm': 12.4,
          'start': '2026-09-19T06:00:00Z',
          'end': '2026-09-20T06:00:00Z',
          'complete': true,
          'source': 'imd',
        },
      }, cityName: 'X').precipNext24h!;
      expect(complete.totalMm, 12.4);
      expect(complete.isComplete, isTrue);
      expect(complete.length, const Duration(hours: 24));
      expect(complete.source, 'imd');

      final partial = parseWeatherSnapshot({
        'precip_next_24h': {
          'total_mm': 4.0,
          'start': '2026-09-19T06:00:00Z',
          'end': '2026-09-19T14:00:00Z',
          'complete': false,
        },
      }, cityName: 'X').precipNext24h!;
      expect(partial.isComplete, isFalse);
      expect(partial.length, const Duration(hours: 8));

      // Negative totals are not a measurement.
      expect(
          parseWeatherSnapshot({
            'precip_next_24h': {'total_mm': -2}
          }, cityName: 'X').precipNext24h,
          isNull);
    });
  });

  group('parseWeatherSnapshot — provenance', () {
    test('records source, run and freshness when the backend reports them', () {
      final snapshot = parseWeatherSnapshot({
        'source': 'weathernext',
        'run_id': '2026091906',
        'issued_at': '2026-09-19T06:00:00Z',
        'retrieved_at': '2026-09-19T09:15:00Z',
        'timezone': 'Asia/Kolkata',
        'fallback': false,
      }, cityName: 'X');
      expect(snapshot.provenance.provider, WeatherProvider.weathernext);
      expect(snapshot.provenance.runId, '2026091906');
      expect(snapshot.provenance.issuedAtUtc, DateTime.utc(2026, 9, 19, 6));
      expect(snapshot.provenance.timezoneId, 'Asia/Kolkata');
      expect(snapshot.provenance.fallback, isFalse);
    });

    test('a legacy response with no metadata claims no source at all', () {
      final snapshot = parseWeatherSnapshot(const {'temperature_c': 30},
          cityName: 'X');
      expect(snapshot.provenance.hasSource, isFalse);
      expect(snapshot.provenance.ageUnknown, isTrue);
      // Unknown age must not be reported as stale.
      expect(snapshot.provenance.isStaleAt(DateTime.utc(2030)), isFalse);
    });

    test('detects a stale payload against an injected clock', () {
      final snapshot = parseWeatherSnapshot(
          const {'issued_at': '2026-09-19T06:00:00Z'},
          cityName: 'X');
      expect(
          snapshot.provenance
              .isStaleAt(DateTime.utc(2026, 9, 19, 8)),
          isFalse);
      expect(
          snapshot.provenance
              .isStaleAt(DateTime.utc(2026, 9, 20, 6)),
          isTrue);
    });

    test('surfaces explicitly unavailable fields', () {
      final snapshot = parseWeatherSnapshot(const {
        'source': 'imd',
        'missing_fields': ['uv_index', 'aqi'],
      }, cityName: 'X');
      expect(snapshot.provenance.isMissing('uv_index'), isTrue);
      expect(snapshot.provenance.isMissing('wind_kmh'), isFalse);
      expect(snapshot.provenance.missingFields, ['aqi', 'uv_index']);
    });
  });

  group('parseWeatherSnapshotV2 — WeatherNext + supplement contract', () {
    Map<String, dynamic> payload() => {
          'schema_version': '2.0.0',
          'location': {'lat': 22.3, 'lon': 70.8, 'timezone': 'Asia/Kolkata', 'utc_offset_seconds': 19800},
          'provenance': {
            'requested_source': 'auto',
            'selected_source': 'weathernext',
            'model': 'weathernext_3_0_0',
            'run_id': 'weathernext_3_0_0_2026091906',
            'init_time_utc': '2026-09-19T06:00:00Z',
            'served_at_utc': '2026-09-19T09:10:00Z',
            'freshness_status': 'fresh',
            'is_stale': false,
            'horizon_hours': 96,
            'expected_member_count': 64,
            'fallback_reasons': [
              {'provider': 'imd', 'reason': 'missing_credentials'},
            ],
            'tried_providers': ['imd', 'weathernext'],
            'query_diagnostics': {'served_from_cache': true},
          },
          'degraded': false,
          'hourly_available': 96,
          'current': {
            'time_utc': '2026-09-19T09:00:00Z',
            'temperature_c': 30.2,
            'weather_code': 3,
            'condition': 'Overcast',
            'humidity_percent': 71,
            'uv_index': null,
            'is_ensemble_mean': true,
          },
          'hourly': [
            {'time_utc': '2026-09-19T09:00:00Z', 'temperature_c': 30.2, 'precipitation_probability': 20},
            {'time_utc': '2026-09-19T10:00:00Z', 'temperature_c': 31.0, 'precipitation_probability': 25},
          ],
          'daily': [
            {
              'date': '2026-09-19',
              'high_c': 33.0,
              'low_c': 26.0,
              'covers_full_day': false,
              'hours_covered': 15,
              'sunrise': '06:31',
              'sunset': '18:49',
              'uv_index_max': 8.1,
              'field_sources': {'sunrise': 'open_meteo', 'sunset': 'open_meteo', 'uv_index_max': 'open_meteo'},
            },
            {'date': '2026-09-20', 'high_c': 32.0, 'low_c': 25.5, 'covers_full_day': true, 'hours_covered': 24},
          ],
          'field_sources': {
            'temperature_c': 'weathernext',
            'humidity_percent': 'open_meteo',
            'uv_index': null,
            'sunrise': 'open_meteo',
            '_supplement': {
              'provider': 'open_meteo',
              'enabled': true,
              'attempted': true,
              'filled': ['humidity_percent', 'sunrise'],
              'errors': [
                {'call': 'air_quality', 'reason': 'timeout'},
              ],
              'cache_hit': false,
            },
          },
        };

    test('attributes each field to the provider that supplied it', () {
      final w = parseWeatherSnapshotV2(payload(), cityName: 'Rajkot');
      expect(w.provenance.selectedSource, 'weathernext');
      expect(w.sourceOf('temperature_c'), 'weathernext');
      expect(w.sourceOf('humidity_percent'), 'open_meteo');
      expect(w.isSupplemented('humidity_percent'), isTrue);
      expect(w.isSupplemented('temperature_c'), isFalse);
      // Explicit null = nobody could supply it; must stay null, not "weathernext".
      expect(w.sourceOf('uv_index'), isNull);
      expect(w.uvIndex, isNull);
      expect(w.fieldSources.contributors, {'weathernext', 'open_meteo'});
      expect(w.fieldSources.supplementFilled, ['humidity_percent', 'sunrise']);
      expect(w.fieldSources.supplementErrors, ['air_quality: timeout']);
    });

    test('not-configured providers do not mark the snapshot as a fallback', () {
      final w = parseWeatherSnapshotV2(payload(), cityName: 'Rajkot');
      expect(w.provenance.fallbackReasons, hasLength(1));
      expect(w.provenance.fallbackReasons.single.isNotConfigured, isTrue);
      expect(w.provenance.realFailures, isEmpty);
      expect(w.provenance.fallback, isFalse);
      expect(w.provenance.weatherNextFailed, isFalse);
      expect(w.degraded, isFalse);
      expect(w.provenance.triedProviders, ['imd', 'weathernext']);
      expect(w.provenance.servedFromCache, isTrue);
      expect(w.provenance.expectedMemberCount, 64);
    });

    test('a real WeatherNext failure is reported as degraded', () {
      final p = payload();
      final prov = p['provenance'] as Map<String, dynamic>;
      prov['selected_source'] = 'open_meteo';
      prov['fallback_reasons'] = [
        {'provider': 'imd', 'reason': 'missing_credentials'},
        {'provider': 'weathernext', 'reason': 'query_timeout'},
      ];
      p.remove('degraded');
      final w = parseWeatherSnapshotV2(p, cityName: 'Rajkot');
      expect(w.provenance.fallback, isTrue);
      expect(w.provenance.weatherNextFailed, isTrue);
      expect(w.provenance.realFailures.single.humanReason, 'query timed out');
    });

    test('daily rows keep partial-day flags, sun times and per-day sources', () {
      final w = parseWeatherSnapshotV2(payload(), cityName: 'Rajkot');
      expect(w.forecast, hasLength(2));
      final today = w.forecast.first;
      expect(today.coversFullDay, isFalse);
      expect(today.hoursCovered, 15);
      expect(today.sunrise, '06:31');
      expect(today.uvIndexMax, 8.1);
      expect(today.fieldSources['sunrise'], 'open_meteo');
      expect(w.sunrise, '06:31');
      expect(w.sunset, '18:49');
      expect(w.forecast[1].coversFullDay, isTrue);
      expect(w.forecast[1].sunrise, isNull);
    });

    test('hourly points carry UTC instants and the location offset', () {
      final w = parseWeatherSnapshotV2(payload(), cityName: 'Rajkot');
      expect(w.hourly, hasLength(2));
      expect(w.hourly.first.timeUtc, DateTime.utc(2026, 9, 19, 9));
      expect(w.utcOffset, const Duration(hours: 5, minutes: 30));
      expect(w.timezoneId, 'Asia/Kolkata');
      expect(w.toLocationLocal(w.hourly.first.timeUtc!).hour, 14);
      expect(w.hourlyAvailable, 96);
      expect(w.currentIsEnsembleMean, isTrue);
      expect(w.humidity, 71);
    });

    test('missing field_sources falls back to the selected source, never invents', () {
      final p = payload()..remove('field_sources');
      final w = parseWeatherSnapshotV2(p, cityName: 'Rajkot');
      expect(w.fieldSources.isEmpty, isTrue);
      expect(w.sourceOf('temperature_c'), 'weathernext');
      expect(w.isSupplemented('humidity_percent'), isFalse);
    });
  });
}
