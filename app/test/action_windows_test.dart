import 'package:flutter_test/flutter_test.dart';
import 'package:weathergpt_mobile/features/farmer/providers/action_windows_provider.dart';

final _verifiedAt = DateTime.utc(2026, 9, 19, 9);

List<Map<String, dynamic>> _hourly(String band) => [
      for (var h = 0; h < 24; h++) {'hour': '$h', 'suitability': band}
    ];

Map<String, dynamic> _window({
  required String date,
  required String suitability,
  required String summary,
  String? choice,
  double? confidence,
  String hourlyBand = 'good',
}) =>
    {
      'date': date,
      'suitability': suitability,
      'summary': summary,
      'best_window': 'Best: 6–10 AM',
      'hourly': {
        'irrigation': _hourly(hourlyBand),
        'spraying': _hourly(hourlyBand),
        'field_work': _hourly(hourlyBand),
      },
      if (choice != null)
        'ai': {
          'overall': {'choice': choice, 'confidence': confidence},
        },
    };

void main() {
  group('ActionWindowsState.unavailable', () {
    test('carries no windows — there is no bundled favourable baseline', () {
      // Regression: the provider used to ship a canned "Good day for field
      // work" pattern for every tab and show it as live advice when the
      // backend was unreachable.
      for (final tab in ActionWindowTab.values) {
        final state = ActionWindowsState.unavailable(tab);
        expect(state.selectedTab, tab);
        expect(state.status, AdvisoryStatus.unavailable);
        expect(state.irrigationWindows, isEmpty);
        expect(state.sprayingWindows, isEmpty);
        expect(state.fieldWorkWindows, isEmpty);
        expect(state.hasWindows, isFalse);
        expect(state.summaryVerdict, isEmpty);
        expect(state.summaryExplanation, isEmpty);
        expect(state.aiAssisted, isFalse);
        expect(state.asOfUtc, isNull);
      }
    });
  });

  group('dayDecisionFrom', () {
    test('reads the decision attached to that specific day', () {
      final decision = dayDecisionFrom({
        'ai': {
          'overall': {'choice': 'caution', 'confidence': 0.71}
        }
      });
      expect(decision.isPresent, isTrue);
      expect(decision.choice, 'caution');
      expect(decision.confidence, 0.71);
    });

    test('is absent when the day carries no decision', () {
      expect(dayDecisionFrom(null).isPresent, isFalse);
      expect(dayDecisionFrom(const {}).isPresent, isFalse);
      expect(dayDecisionFrom({'ai': {}}).isPresent, isFalse);
      expect(dayDecisionFrom({'ai': {'overall': {}}}).isPresent, isFalse);
    });
  });

  group('ActionWindowsNotifier.stateForTab', () {
    test('each day renders its own final decision', () {
      // The global verdict disagrees with both days on purpose: if the code
      // read the global answer, today would render "good".
      final payload = <String, dynamic>{
        'summary': 'Weekly summary',
        'ai': {
          'enabled': true,
          'applied': true,
          'mean_confidence': 0.9,
          'overall_verdict': 'good',
        },
        'windows': [
          _window(
              date: '2026-09-19',
              suitability: 'caution',
              summary: 'Today: spray drift risk after 4 PM',
              choice: 'caution',
              confidence: 0.64),
          _window(
              date: '2026-09-20',
              suitability: 'poor',
              summary: 'Tomorrow: rain all day',
              choice: 'avoid',
              confidence: 0.81),
        ],
      };

      final today = ActionWindowsNotifier.stateForTab(
          ActionWindowTab.today, payload, 'Anand', _verifiedAt);
      expect(today.summaryVerdict, 'A workable day with caution');
      expect(today.summaryExplanation, 'Today: spray drift risk after 4 PM');
      expect(today.aiConfidence, 0.64);
      expect(today.aiAssisted, isTrue);
      expect(today.asOfUtc, _verifiedAt);
      expect(today.locationLabel, 'Anand');

      final tomorrow = ActionWindowsNotifier.stateForTab(
          ActionWindowTab.tomorrow, payload, 'Anand', _verifiedAt);
      // Regression: tomorrow must not inherit today's verdict, and today must
      // not inherit the highest-confidence global answer.
      expect(tomorrow.summaryVerdict, 'Avoid heavy farm work today');
      expect(tomorrow.summaryExplanation, 'Tomorrow: rain all day');
      expect(tomorrow.aiConfidence, 0.81);
      expect(tomorrow.summaryVerdict, isNot(today.summaryVerdict));
    });

    test('no System One badge when the displayed day has no decision', () {
      final payload = <String, dynamic>{
        'ai': {
          'enabled': true,
          'applied': true,
          'mean_confidence': 0.9,
          'overall_verdict': 'good',
        },
        'windows': [
          _window(date: '2026-09-19', suitability: 'good', summary: 'Fine day'),
        ],
      };
      final today = ActionWindowsNotifier.stateForTab(
          ActionWindowTab.today, payload, 'Anand', _verifiedAt);
      expect(today.aiAssisted, isFalse,
          reason: 'a global verdict did not shape this day');
      expect(today.aiConfidence, isNull);
      expect(today.summaryVerdict, 'Good day for field work');
    });

    test('falls back to the day band when no decision is attached', () {
      final payload = <String, dynamic>{
        'windows': [
          _window(date: '2026-09-19', suitability: 'poor', summary: 'Wet'),
        ],
      };
      final today = ActionWindowsNotifier.stateForTab(
          ActionWindowTab.today, payload, 'Anand', _verifiedAt);
      expect(today.summaryVerdict, 'Avoid heavy farm work today');
      expect(today.source, AdvisorySource.thresholds);
    });

    test('the week tab is an aggregate and says so', () {
      final payload = <String, dynamic>{
        'summary': 'Two of seven days look workable',
        'ai': {
          'enabled': true,
          'applied': true,
          'mean_confidence': 0.77,
        },
        'windows': [
          for (var d = 19; d < 26; d++)
            _window(
                date: '2026-09-$d',
                suitability: d.isEven ? 'good' : 'caution',
                summary: 'day'),
        ],
      };
      final week = ActionWindowsNotifier.stateForTab(
          ActionWindowTab.sevenDay, payload, 'Anand', _verifiedAt);
      expect(week.irrigationWindows, hasLength(7));
      expect(week.summaryExplanation, 'Two of seven days look workable');
      expect(week.aiConfidence, 0.77);
      expect(week.aiAssisted, isTrue);
    });

    test('an empty or malformed payload produces no windows, not fake ones',
        () {
      for (final payload in <Map<String, dynamic>>[
        const {},
        {'windows': 'not-a-list'},
        {
          'windows': ['not-a-map', {'date': '2026-09-19'}]
        },
      ]) {
        final today = ActionWindowsNotifier.stateForTab(
            ActionWindowTab.today, payload, 'Anand', _verifiedAt);
        expect(today.irrigationWindows, isEmpty, reason: '$payload');
        expect(today.hasWindows, isFalse, reason: '$payload');
        expect(today.aiAssisted, isFalse, reason: '$payload');
      }
    });

    test('hourly cells collapse into buckets taking the worst band', () {
      final cells = _hourly('good');
      cells[6]['suitability'] = 'avoid';
      final payload = <String, dynamic>{
        'windows': [
          {
            'date': '2026-09-19',
            'suitability': 'good',
            'hourly': {
              'irrigation': cells,
              'spraying': _hourly('caution'),
              'field_work': _hourly('neutral'),
            },
          }
        ],
      };
      final today = ActionWindowsNotifier.stateForTab(
          ActionWindowTab.today, payload, 'Anand', _verifiedAt);
      expect(today.irrigationWindows, hasLength(12));
      expect(today.irrigationWindows[3].suitability, Suitability.avoid,
          reason: 'risk must not be averaged away');
      expect(today.sprayingWindows.every((c) => c.suitability == Suitability.caution),
          isTrue);
      expect(today.fieldWorkWindows.every((c) => c.suitability == Suitability.neutral),
          isTrue);
    });
  });
}
