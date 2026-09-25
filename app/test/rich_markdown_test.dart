import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:weathergpt_mobile/core/widgets/rich_markdown.dart';

void main() {
  group('RichMarkdown.sanitize', () {
    test('strips native widget fences', () {
      const input = 'Answer text\n```widget:weather\n{"temp": 31}\n```\nDone';
      expect(RichMarkdown.sanitize(input), 'Answer text\n\nDone');
    });

    test('strips json fences', () {
      const input = 'Before\n```json\n{"a": 1}\n```\nAfter';
      expect(RichMarkdown.sanitize(input), 'Before\n\nAfter');
    });

    test('closes a dangling fence so it cannot swallow the answer', () {
      const input = 'Table incoming\n| a | b |\n|---|---|\n| 1 | 2 |\n```';
      final out = RichMarkdown.sanitize(input);
      expect(out.isNotEmpty, isTrue);
      expect('```'.allMatches(out).length.isEven, isTrue);
    });

    test('leaves plain markdown untouched', () {
      const input = '**Bold** and | pipes | in prose';
      expect(RichMarkdown.sanitize(input), input);
    });
  });

  group('RichMarkdown rendering', () {
    testWidgets('renders a GFM table structurally, not as raw pipes',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RichMarkdown(
              '| Day | Rain |\n|-----|------|\n| Mon | 10%  |\n| Tue | 40%  |',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Header and data cells exist as standalone text — proof the table was
      // parsed into a structure rather than printed verbatim.
      expect(find.text('Day'), findsOneWidget);
      expect(find.text('Rain'), findsOneWidget);
      expect(find.text('Mon'), findsOneWidget);
      expect(find.text('Tue'), findsOneWidget);
      // And no source syntax leaks into the rendered answer.
      expect(find.textContaining('|'), findsNothing);
    });

    testWidgets('renders headings, emphasis, lists and blockquotes',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RichMarkdown(
                '## Forecast\n\n**Heavy rain** expected.\n\n- Carry an umbrella\n\n> IMD warning in effect',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Forecast'), findsOneWidget);
      expect(find.textContaining('Heavy rain', findRichText: true),
          findsOneWidget);
      expect(find.text('Carry an umbrella'), findsOneWidget);
    });

    testWidgets('strips widget fences before rendering', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RichMarkdown('Visible answer\n```widget:forecast\n{}\n```'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('widget:'), findsNothing);
      expect(find.text('Visible answer'), findsOneWidget);
    });
  });
}
