import 'package:flutter_test/flutter_test.dart';
import 'package:weathergpt_mobile/features/voice/mappers/voice_response_mapper.dart';
import 'package:weathergpt_mobile/features/voice/models/voice_card.dart';

void main() {
  group('VoiceCard.fromJson', () {
    test('returns null when the backend sent no card', () {
      expect(VoiceCard.fromJson(null), isNull);
      expect(VoiceCard.fromJson('not-a-map'), isNull);
      expect(VoiceCard.fromJson({'response': 'text only'}), isNotNull);
    });

    test('parses stats, forecast rows, source and confidence', () {
      final card = VoiceCard.fromJson({
        'label': 'Rain Forecast',
        'verdict': 'Rain likely tomorrow',
        'cta_label': 'View Detailed Forecast',
        'source': 'imd',
        'confidence': 0.82,
        'stats': [
          {'label': 'Chance of rain', 'value': '70%', 'tone': 'caution'},
          {'label': 'Expected rain', 'value': '9 mm'},
          'not-a-map',
          {'label': 'Missing value'},
        ],
        'forecast': [
          {'day': 'Sat', 'temperature': '31°', 'rainfall': '9 mm', 'condition': 'rain'},
          {'day': 'Sun', 'temperature': '30°'},
          {'temperature': '29°'}, // no day label -> skipped
        ],
      })!;
      expect(card.label, 'Rain Forecast');
      expect(card.verdict, 'Rain likely tomorrow');
      expect(card.source, 'imd');
      expect(card.confidence, 0.82);
      expect(card.stats, hasLength(2));
      expect(card.stats.first.tone, CardTone.caution);
      expect(card.stats.last.tone, CardTone.neutral);
      expect(card.forecast, hasLength(2));
      expect(card.forecast.first.condition, 'rain');
      expect(card.forecast.last.rainfall, isNull,
          reason: 'a missing value stays missing, it is not 0 mm');
    });

    test('maps backend tone names onto the enum', () {
      expect(cardToneFromName('safe'), CardTone.good);
      expect(cardToneFromName('favourable'), CardTone.good);
      expect(cardToneFromName('watch'), CardTone.caution);
      expect(cardToneFromName('risk'), CardTone.avoid);
      expect(cardToneFromName('poor'), CardTone.avoid);
      expect(cardToneFromName(null), CardTone.neutral);
      expect(cardToneFromName('sparkly'), CardTone.neutral);
    });
  });

  group('mapBackendAnswer — no fabricated data', () {
    test('a prose-only answer yields no stats and no forecast rows', () {
      final response = mapBackendAnswer(
        'Will it rain tomorrow?',
        'A moderate spell is likely from late morning in Anand.',
        raw: const {'response': 'A moderate spell is likely from late morning in Anand.'},
      );
      // Regression: the mapper used to attach a canned 78% / 12 mm card and a
      // fixed Tue/Wed/Thu forecast regardless of what the backend said.
      expect(response.stats, isEmpty);
      expect(response.forecast, isEmpty);
      expect(response.verdict,
          'A moderate spell is likely from late morning in Anand');
      expect(response.label, 'Rain Forecast');
    });

    test('a long answer is truncated for the headline but kept in full', () {
      final long = '${'Rain is expected. ' * 12}Details follow here.';
      final response = mapBackendAnswer('rain tomorrow?', long);
      expect(response.verdict.length, lessThanOrEqualTo(91));
      expect(response.explanation, long.trim());
    });

    test('an empty answer does not invent a verdict', () {
      final response = mapBackendAnswer('Will it rain tomorrow?', '');
      expect(response.verdict, isEmpty);
      expect(response.stats, isEmpty);
      expect(response.forecast, isEmpty);
    });

    test('greetings render no data card at all', () {
      for (final query in ['hi', 'hello', 'namaste', 'help', 'thanks']) {
        final response = mapBackendAnswer(
            query, "I'm **WeatherGPT** — ask me about weather or farming.");
        expect(response.label, 'Assistant', reason: query);
        expect(response.stats, isEmpty, reason: query);
        expect(response.forecast, isEmpty, reason: query);
      }
    });

    test('a structured card from the backend is rendered as sent', () {
      final response = mapBackendAnswer(
        'Should I irrigate today?',
        'Hold off today.',
        raw: const {
          'response': 'Hold off today.',
          'card': {
            'label': 'Irrigation Recommendation',
            'verdict': 'Not recommended today',
            'source': 'system-one',
            'confidence': 0.74,
            'stats': [
              {'label': 'Rain (tomorrow)', 'value': '9 mm', 'tone': 'good'},
            ],
            'forecast': [
              {'day': 'Sat', 'temperature': '31°', 'rainfall': '9 mm', 'condition': 'rain'},
            ],
          },
        },
      );
      expect(response.label, 'Irrigation Recommendation');
      expect(response.verdict, 'Not recommended today');
      expect(response.stats, hasLength(1));
      expect(response.stats.single.label, 'Rain (tomorrow)');
      expect(response.stats.single.value, '9 mm');
      expect(response.forecast.single.day, 'Sat');
      expect(response.forecast.single.rainfall, '9 mm');
    });

    test('a card with no rainfall shows an em dash, never 0 mm', () {
      final response = mapBackendAnswer('forecast?', 'Some text.', raw: const {
        'card': {
          'forecast': [
            {'day': 'Sun', 'temperature': '30°', 'condition': 'cloudy'}
          ]
        },
      });
      expect(response.forecast.single.rainfall, '—');
    });

    test('classification picks chrome but never values', () {
      expect(typeForQuery('should i irrigate', false), ResultType.irrigation);
      expect(typeForQuery('will it rain', false), ResultType.rainForecast);
      expect(typeForQuery('how is my crop', false), ResultType.cropStatus);
      expect(typeForQuery('what is a monsoon', false), ResultType.general);
      expect(typeForQuery('anything', true), ResultType.general);
      // Chrome differs per type, which is presentation only.
      expect(chromeForType(ResultType.irrigation).label,
          'Irrigation Recommendation');
      expect(chromeForType(ResultType.cropStatus).ctaLabel,
          'View Farm Action Windows');
    });
  });
}
