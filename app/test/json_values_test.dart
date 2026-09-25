import 'package:flutter_test/flutter_test.dart';
import 'package:weathergpt_mobile/core/models/json_values.dart';

void main() {
  group('jsonNum', () {
    test('passes through finite numbers, including zero and negatives', () {
      expect(jsonNum(0), 0);
      expect(jsonNum(-3.5), -3.5);
      expect(jsonNum(12), 12);
    });

    test('never turns a missing or unusable value into zero', () {
      expect(jsonNum(null), isNull);
      expect(jsonNum(''), isNull);
      expect(jsonNum('n/a'), isNull);
      expect(jsonNum([]), isNull);
      expect(jsonNum(double.nan), isNull);
      expect(jsonNum(double.infinity), isNull);
    });

    test('accepts numeric strings from loosely typed backends', () {
      expect(jsonNum(' 42 '), 42);
      expect(jsonNum('4.5'), 4.5);
    });
  });

  group('jsonInt', () {
    test('rejects genuinely fractional values instead of rounding silently',
        () {
      expect(jsonInt(3), 3);
      expect(jsonInt(3.0), 3);
      expect(jsonInt(3.4), isNull);
      expect(jsonInt(null), isNull);
    });
  });

  group('jsonString', () {
    test('treats serializer placeholders for absent values as null', () {
      expect(jsonString(null), isNull);
      expect(jsonString(''), isNull);
      expect(jsonString('   '), isNull);
      expect(jsonString('null'), isNull);
      expect(jsonString('None'), isNull);
      expect(jsonString('NaN'), isNull);
    });

    test('trims real values', () {
      expect(jsonString('  Partly cloudy '), 'Partly cloudy');
    });
  });

  group('jsonUtc', () {
    test('preserves the instant from an explicit offset', () {
      expect(jsonUtc('2026-09-19T14:30:00Z'),
          DateTime.utc(2026, 9, 19, 14, 30));
      // +05:30 must be converted, not read as a local wall clock.
      expect(jsonUtc('2026-09-19T20:00:00+05:30'),
          DateTime.utc(2026, 9, 19, 14, 30));
    });

    test('reads a naive timestamp as UTC and reports the assumption', () {
      expect(jsonUtc('2026-09-19T14:30:00'), DateTime.utc(2026, 9, 19, 14, 30));
      expect(naiveTimestampAssumedUtc('2026-09-19T14:30:00'), isTrue);
      expect(naiveTimestampAssumedUtc('2026-09-19T14:30:00Z'), isFalse);
      expect(naiveTimestampAssumedUtc('2026-09-19T20:00:00+05:30'), isFalse);
      expect(naiveTimestampAssumedUtc(null), isFalse);
    });

    test('malformed timestamps become null rather than throwing', () {
      expect(jsonUtc('not-a-date'), isNull);
      expect(jsonUtc(null), isNull);
    });
  });

  group('decodeJsonObject', () {
    test('tolerates empty and malformed bodies', () {
      expect(decodeJsonObject(null), isEmpty);
      expect(decodeJsonObject(''), isEmpty);
      expect(decodeJsonObject('{truncated'), isEmpty);
      expect(decodeJsonObject('[1,2]'), isEmpty);
      expect(decodeJsonObject('{"a":1}'), {'a': 1});
    });
  });
}
