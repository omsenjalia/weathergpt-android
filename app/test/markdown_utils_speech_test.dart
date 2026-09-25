import 'package:flutter_test/flutter_test.dart';

import 'package:weathergpt_mobile/core/utils/markdown_utils.dart';

void main() {
  group('MarkdownUtils.forSpeech — tables', () {
    test('drops separator rows entirely', () {
      const input = '| Field | Value |\n|---|---|\n| Temp | 31 C |';
      final out = MarkdownUtils.forSpeech(input);
      expect(out.contains('---'), isFalse);
      expect(out.contains('|'), isFalse);
      expect(out.contains('Temp'), isTrue);
      expect(out.contains('31 C'), isTrue);
    });

    test('keeps prose around a table intact', () {
      const input =
          'Here is the outlook.\n\n| Day | Rain |\n|---|---|\n| Mon | 40% |\n\nStay alert.';
      final out = MarkdownUtils.forSpeech(input);
      expect(out.contains('Here is the outlook.'), isTrue);
      expect(out.contains('Stay alert.'), isTrue);
      expect(out.contains('|'), isFalse);
    });
  });

  group('MarkdownUtils.forSpeech — LaTeX', () {
    test('removes LaTeX delimiters and layout commands', () {
      const input = r'Rainfall is \( \frac{a}{b} \) mm per hour.';
      final out = MarkdownUtils.forSpeech(input);
      expect(out.contains('\\'), isFalse);
      expect(out.contains('frac'), isFalse);
      expect(out.contains('Rainfall is'), isTrue);
    });

    test('existing behaviour: strips code fences and emphasis markers', () {
      const input = '## Status\nIt will **rain** tomorrow. `10 mm` expected.';
      final out = MarkdownUtils.forSpeech(input);
      expect(out.contains('#'), isFalse);
      expect(out.contains('**'), isFalse);
      expect(out.contains('`'), isFalse);
      expect(out.contains('It will rain tomorrow'), isTrue);
    });
  });
}
