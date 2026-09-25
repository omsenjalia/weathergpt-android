import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:weathergpt_mobile/features/home/theme/atmosphere_theme.dart';
import 'package:weathergpt_mobile/features/home/widgets/weather_segment_tabs.dart';

void main() {
  Future<AlignmentGeometry> pillAlignmentFor(
    WidgetTester tester,
    int index,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WeatherSegmentTabs(
            index: index,
            onChanged: (_) {},
            palette: paletteFor(SkyPeriod.midday, SkyCondition.clear),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return tester
        .widget<AnimatedAlign>(find.byType(AnimatedAlign))
        .alignment;
  }

  testWidgets('pill sits under the selected tab (regression: Hourly pill '
      'used to land on 7-Day)', (tester) async {
    // Overview / Hourly / 7-Day → left / centre / right.
    expect(await pillAlignmentFor(tester, 0), const Alignment(-1, 0));
    expect(await pillAlignmentFor(tester, 1), const Alignment(0, 0));
    expect(await pillAlignmentFor(tester, 2), const Alignment(1, 0));
  });

  testWidgets('tapping a label reports that label’s index', (tester) async {
    var selected = -1;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WeatherSegmentTabs(
            index: 0,
            onChanged: (i) => selected = i,
            palette: paletteFor(SkyPeriod.midday, SkyCondition.clear),
          ),
        ),
      ),
    );
    // Without the localization delegate the labels render as their keys.
    await tester.tap(find.text('home.tab_hourly'));
    expect(selected, 1);
    await tester.tap(find.text('home.tab_7day'));
    expect(selected, 2);
  });
}
