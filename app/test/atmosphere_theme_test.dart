import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:weathergpt_mobile/features/home/theme/atmosphere_theme.dart';

void main() {
  test('daytime palette keeps text readable on dark glass cards', () {
    final palette = paletteFor(SkyPeriod.midday, SkyCondition.clear);

    expect(palette.card.computeLuminance(), lessThan(0.45));
    // _ensureReadable guarantees a *visible* accent on dark cards: it swaps in
    // cyan only when the accent is dark, so warm daylight accents (amber) stay.
    expect(palette.accent.computeLuminance(), greaterThan(0.25));
    expect(palette.text, const Color(0xFFF8FAFC));
    expect(palette.textMuted, const Color(0xFFD6E2EE));
  });

  test('bright daytime weather variants use the same readable text treatment', () {
    for (final sky in [
      SkyCondition.fog,
      SkyCondition.overcast,
      SkyCondition.partlyCloudy,
    ]) {
      final palette = paletteFor(SkyPeriod.morning, sky);
      expect(palette.text, const Color(0xFFF8FAFC), reason: '$sky text');
      expect(palette.textMuted, const Color(0xFFD6E2EE), reason: '$sky muted text');
    }
  });
}
