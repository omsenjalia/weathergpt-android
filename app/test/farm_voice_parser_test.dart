import 'package:flutter_test/flutter_test.dart';
import 'package:weathergpt_mobile/features/farmer/models/farm_voice_parser.dart';

void main() {
  group('normalizeVoiceInput', () {
    test('lowercases, strips punctuation and collapses whitespace', () {
      expect(normalizeVoiceInput('  Wheat!  '), 'wheat');
      expect(normalizeVoiceInput('My crop: Cotton.'), 'my crop cotton');
    });

    test('leaves Indic scripts untouched', () {
      expect(normalizeVoiceInput('गेहूं,'), 'गेहूं');
      expect(normalizeVoiceInput('ડાંગર.'), 'ડાંગર');
    });
  });

  group('indicDigitsToAscii', () {
    test('converts Devanagari and Gujarati digits', () {
      expect(indicDigitsToAscii('४'), '4');
      expect(indicDigitsToAscii('૧૦'), '10');
      expect(indicDigitsToAscii('4 एकड़'), '4 एकड़');
    });
  });

  group('parseVoiceCrop', () {
    test('exact match, case-insensitive', () {
      expect(parseVoiceCrop('wheat'), 'Wheat');
      expect(parseVoiceCrop('COTTON'), 'Cotton');
    });

    test('finds the crop inside a sentence', () {
      expect(parseVoiceCrop('my crop is wheat'), 'Wheat');
      expect(parseVoiceCrop('I grow cotton'), 'Cotton');
    });

    test('Hindi and Gujarati names', () {
      expect(parseVoiceCrop('गेहूं'), 'Wheat');
      expect(parseVoiceCrop('कपास'), 'Cotton');
      expect(parseVoiceCrop('डांगर'), isNull); // misspelt on purpose
      expect(parseVoiceCrop('ડાંગર'), 'Rice');
      expect(parseVoiceCrop('મારો પાક કપાસ છે'), 'Cotton');
    });

    test('romanized Indic forms from English-locale STT', () {
      expect(parseVoiceCrop('narma'), 'Cotton');
      expect(parseVoiceCrop('tamatar'), 'Tomato');
      expect(parseVoiceCrop('dal'), 'Pulses');
    });

    test('returns null rather than guessing', () {
      expect(parseVoiceCrop(''), isNull);
      expect(parseVoiceCrop('hello there'), isNull);
      expect(parseVoiceCrop('bajra'), isNull); // not in the catalog
    });
  });

  group('parseVoiceGrowthStage', () {
    test('options and English variants', () {
      expect(parseVoiceGrowthStage('Flowering'), 'Flowering');
      expect(parseVoiceGrowthStage('ready to harvest'), 'Harvest');
      expect(parseVoiceGrowthStage('it is blooming'), 'Flowering');
    });

    test('Hindi and Gujarati stages', () {
      expect(parseVoiceGrowthStage('फूल'), 'Flowering');
      expect(parseVoiceGrowthStage('कटाई'), 'Harvest');
      expect(parseVoiceGrowthStage('લણણી'), 'Harvest');
    });

    test('returns null rather than guessing', () {
      expect(parseVoiceGrowthStage(''), isNull);
      expect(parseVoiceGrowthStage('good morning'), isNull);
    });
  });

  group('parseVoiceIrrigation', () {
    test('options and variants', () {
      expect(parseVoiceIrrigation('drip'), 'Drip');
      expect(parseVoiceIrrigation('tubewell'), 'Borewell');
      expect(parseVoiceIrrigation('only rain'), 'Rainfed');
    });

    test('Hindi and Gujarati methods', () {
      expect(parseVoiceIrrigation('टपक'), 'Drip');
      expect(parseVoiceIrrigation('नहर'), 'Canal');
      expect(parseVoiceIrrigation('વરસાદ'), 'Rainfed');
    });

    test('short words match whole tokens only', () {
      // "rain" must not fire inside "drain"/"grain".
      expect(parseVoiceIrrigation('drain the field'), isNull);
      expect(parseVoiceIrrigation('grain market'), isNull);
      expect(parseVoiceIrrigation('depends on rain'), 'Rainfed');
    });
  });

  group('parseVoiceSoil', () {
    test('longest phrase wins', () {
      expect(parseVoiceSoil('black cotton soil'), 'Black');
      expect(parseVoiceSoil('sandy'), 'Sandy');
    });

    test('Hindi and Gujarati soils', () {
      expect(parseVoiceSoil('काली'), 'Black');
      expect(parseVoiceSoil('દોમટ'), isNull); // not a listed alias
      expect(parseVoiceSoil('ગોરાડુ'), 'Loamy');
    });

    test('returns null rather than guessing', () {
      expect(parseVoiceSoil(''), isNull);
      expect(parseVoiceSoil('nice weather'), isNull);
    });
  });

  group('parseVoiceFarmSize', () {
    test('ASCII digits', () {
      expect(parseVoiceFarmSize('4'), 4.0);
      expect(parseVoiceFarmSize('4.5 acres'), 4.5);
      expect(parseVoiceFarmSize('4,5'), 4.5);
      expect(parseVoiceFarmSize('1,000'), 1000.0);
    });

    test('Indic digits', () {
      expect(parseVoiceFarmSize('४'), 4.0);
      expect(parseVoiceFarmSize('૧૦'), 10.0);
    });

    test('number words in three languages', () {
      expect(parseVoiceFarmSize('two acres'), 2.0);
      expect(parseVoiceFarmSize('चार'), 4.0);
      expect(parseVoiceFarmSize('પાંચ એકર'), 5.0);
    });

    test('bare acre word means one acre', () {
      expect(parseVoiceFarmSize('an acre'), 1.0);
    });

    test('number words match whole tokens only', () {
      // "one" must not fire inside "someone".
      expect(parseVoiceFarmSize('someone'), isNull);
    });

    test('rejects non-positive and unparseable input', () {
      expect(parseVoiceFarmSize(''), isNull);
      expect(parseVoiceFarmSize('zero'), isNull);
      expect(parseVoiceFarmSize('0'), isNull);
      expect(parseVoiceFarmSize('big farm'), isNull);
    });
  });

  group('formatVoiceFarmSize', () {
    test('strips the trailing .0', () {
      expect(formatVoiceFarmSize(4), '4');
      expect(formatVoiceFarmSize(4.5), '4.5');
    });
  });
}
