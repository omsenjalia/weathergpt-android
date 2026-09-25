import 'package:flutter_test/flutter_test.dart';
import 'package:weathergpt_mobile/features/settings/models/tts_voice_option.dart';

void main() {
  group('parseTtsVoices', () {
    test('parses name/locale maps', () {
      final voices = parseTtsVoices([
        {'name': 'en-gb-x-rjs#female_2-local', 'locale': 'en-GB'},
        {'name': 'Karen', 'locale': 'en-AU'},
      ]);
      expect(voices.map((v) => v.name),
          ['en-gb-x-rjs#female_2-local', 'Karen']);
      expect(voices.map((v) => v.locale), ['en-GB', 'en-AU']);
    });

    test('skips malformed entries without throwing', () {
      expect(parseTtsVoices(null), isEmpty);
      expect(parseTtsVoices('nope'), isEmpty);
      expect(
          parseTtsVoices([
            {'name': 'ok', 'locale': 'en-US'},
            {'name': 'missing-locale'},
            {'locale': 'en-US'},
            {'name': '', 'locale': 'en-US'},
            {'name': 42, 'locale': 'en-US'},
            'junk',
            null,
          ]).map((v) => v.name),
          ['ok']);
    });
  });

  group('friendlyName', () {
    test('prettifies Google-style engine ids', () {
      expect(
          const TtsVoiceOption(
                  name: 'en-gb-x-rjs#female_2-local', locale: 'en-GB')
              .friendlyName,
          'Female 2');
      expect(
          const TtsVoiceOption(
                  name: 'hi-in-x-hia-network', locale: 'hi-IN')
              .friendlyName,
          'X Hia');
    });

    test('keeps plain names readable', () {
      expect(const TtsVoiceOption(name: 'Karen', locale: 'en-AU').friendlyName,
          'Karen');
      expect(
          const TtsVoiceOption(name: 'en-US-SMTf00', locale: 'en-US')
              .friendlyName,
          'SMTf00');
    });
  });

  group('filterVoicesForLanguage', () {
    const voices = [
      TtsVoiceOption(name: 'us-1', locale: 'en-US'),
      TtsVoiceOption(name: 'in-1', locale: 'en_IN'),
      TtsVoiceOption(name: 'hindi-1', locale: 'hi-IN'),
      TtsVoiceOption(name: 'gb-1', locale: 'en-GB'),
    ];

    test('matches locale prefixes across -/_ separators and case', () {
      final en = filterVoicesForLanguage(voices, 'en');
      expect(en.map((v) => v.name), ['gb-1', 'in-1', 'us-1']);
      expect(filterVoicesForLanguage(voices, 'HI').map((v) => v.name),
          ['hindi-1']);
    });

    test('returns empty when nothing matches', () {
      expect(filterVoicesForLanguage(voices, 'ta'), isEmpty);
    });
  });

  group('resolveVoiceName', () {
    const voices = [TtsVoiceOption(name: 'keep', locale: 'en-US')];

    test('keeps saved voices that still exist', () {
      expect(resolveVoiceName(voices, 'keep'), 'keep');
    });

    test('drops missing or blank saved voices', () {
      expect(resolveVoiceName(voices, 'gone-after-update'), isNull);
      expect(resolveVoiceName(voices, null), isNull);
      expect(resolveVoiceName(voices, ''), isNull);
    });
  });

  group('TtsVoiceSelection', () {
    test('round-trips through a map', () {
      const sel = TtsVoiceSelection(name: 'Karen', locale: 'en-AU');
      final back = TtsVoiceSelection.fromMap(sel.toMap());
      expect(back.source, 'device');
      expect(back.name, 'Karen');
      expect(back.locale, 'en-AU');
      expect(back.isDevice, isTrue);
      expect(back.isValid, isTrue);
    });

    test('tolerates missing fields', () {
      final back = TtsVoiceSelection.fromMap(const {});
      expect(back.source, 'device');
      expect(back.isValid, isFalse);
    });
  });
}
