import 'package:flutter_test/flutter_test.dart';

import 'package:weathergpt_mobile/features/farmer/models/advisory_models.dart';

void main() {
  group('suitabilityFromName', () {
    test('maps backend band names', () {
      expect(suitabilityFromName('good'), Suitability.good);
      expect(suitabilityFromName('caution'), Suitability.caution);
      expect(suitabilityFromName('poor'), Suitability.avoid);
      expect(suitabilityFromName('avoid'), Suitability.avoid);
    });

    test('unknown or missing names fall back to neutral', () {
      expect(suitabilityFromName('excellent'), Suitability.neutral);
      expect(suitabilityFromName(null), Suitability.neutral);
    });
  });

  group('collapseHourlyCells', () {
    List<Map<String, String>> cells(List<String> bands) =>
        [for (var i = 0; i < bands.length; i++) {'hour': '$i', 'suitability': bands[i]}];

    test('collapses 24 hourly cells into 12 two-hour buckets', () {
      final bands = List<String>.filled(24, 'good');
      final result = collapseHourlyCells(cells(bands));
      expect(result, hasLength(12));
      expect(result.every((c) => c.hours == 2), isTrue);
      expect(result.every((c) => c.suitability == Suitability.good), isTrue);
    });

    test('worst band in a bucket wins (never averages away risk)', () {
      final bands = List<String>.filled(24, 'good');
      bands[5] = 'avoid'; // bucket index 2 (hours 4-5)
      final result = collapseHourlyCells(cells(bands));
      expect(result[2].suitability, Suitability.avoid);
      expect(result[2].hours, 2);
      expect(result[3].suitability, Suitability.good);
    });

    test('poor bands map onto avoid', () {
      final bands = List<String>.filled(24, 'poor');
      final result = collapseHourlyCells(cells(bands));
      expect(result.every((c) => c.suitability == Suitability.avoid), isTrue);
    });

    test('empty input yields an empty list', () {
      expect(collapseHourlyCells(const []), isEmpty);
    });

    test('handles non-12 divisibility gracefully', () {
      final bands = List<String>.filled(7, 'caution');
      final result = collapseHourlyCells(cells(bands), bucketCount: 7);
      expect(result, hasLength(7));
      expect(result.every((c) => c.hours == 1), isTrue);
    });

    test('ignores malformed cells (maps them to neutral)', () {
      final result = collapseHourlyCells([
        'not-a-map',
        {'suitability': 'good'},
      ]);
      // Two cells never merge into one bucket (bucket size floors at 1);
      // malformed entries read as neutral instead of crashing.
      expect(result, hasLength(2));
      expect(result[0].suitability, Suitability.neutral);
      expect(result[1].suitability, Suitability.good);
    });
  });

  group('dailySuitabilityCells', () {
    test('one cell per window, capped at maxDays', () {
      final windows = [
        {'suitability': 'good'},
        {'suitability': 'caution'},
        {'suitability': 'poor'},
      ];
      final result = dailySuitabilityCells(windows);
      expect(result, hasLength(3));
      expect(result[0].suitability, Suitability.good);
      expect(result[1].suitability, Suitability.caution);
      expect(result[2].suitability, Suitability.avoid);
      expect(result.every((c) => c.hours == 1), isTrue);
    });

    test('caps the rendered days at maxDays', () {
      final windows = List<Map<String, String>>.generate(
          9, (_) => {'suitability': 'good'});
      expect(dailySuitabilityCells(windows), hasLength(7));
    });
  });

  group('ai metadata helpers', () {
    final ai = {
      'enabled': true,
      'applied': true,
      'model': 'jev-latest',
      'evaluated_days': 2,
      'mean_confidence': 0.885,
      'overall_verdict': 'good',
      'overall_confidence': 0.91,
    };

    test('aiApplied requires enabled AND applied', () {
      expect(aiApplied(ai), isTrue);
      expect(aiApplied({...ai, 'applied': false}), isFalse);
      expect(aiApplied({...ai, 'enabled': false}), isFalse);
      expect(aiApplied(null), isFalse);
    });

    test('aiOverallVerdict and aiMeanConfidence parse numbers', () {
      expect(aiOverallVerdict(ai), 'good');
      expect(aiMeanConfidence(ai), closeTo(0.885, 1e-9));
      expect(aiOverallVerdict(null), isNull);
      expect(aiMeanConfidence(null), isNull);
      expect(aiMeanConfidence({'mean_confidence': 'n/a'}), isNull);
    });
  });

  group('verdictTextForBand', () {
    test('maps bands to farmer-facing verdicts', () {
      expect(verdictTextForBand('good'), 'Good day for field work');
      expect(verdictTextForBand('caution'), 'A workable day with caution');
      expect(verdictTextForBand('poor'), 'Avoid heavy farm work today');
      expect(verdictTextForBand('avoid'), 'Avoid heavy farm work today');
      expect(verdictTextForBand(null), 'Advisory ready');
    });
  });
}
