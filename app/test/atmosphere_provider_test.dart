import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:weathergpt_mobile/features/home/providers/atmosphere_provider.dart';
import 'package:weathergpt_mobile/features/home/theme/atmosphere_theme.dart';

/// Reads [atmospherePaletteProvider] for a frozen clock. The ticker is a
/// StreamProvider, so the container must be primed and given a microtask
/// for the fixed value to land before the palette is derived.
Future<AtmospherePalette> paletteAt(DateTime now) async {
  final container = ProviderContainer(overrides: [
    clockTickerProvider.overrideWith((ref) => Stream.value(now)),
  ]);
  container.listen(clockTickerProvider, (_, __) {});
  await Future<void>.delayed(Duration.zero);
  final palette = container.read(atmospherePaletteProvider);
  container.dispose();
  return palette;
}

void main() {
  test('midday with no weather snapshot yields the midday clear palette',
      () async {
    final palette = await paletteAt(DateTime(2026, 9, 22, 12, 30));
    final expected = paletteFor(SkyPeriod.midday, SkyCondition.clear);
    expect(palette.top, expected.top);
    expect(palette.text, expected.text);
  });

  test('late evening switches to the night palette (time-of-day drive)',
      () async {
    final palette = await paletteAt(DateTime(2026, 9, 22, 23, 5));
    final expected = paletteFor(SkyPeriod.night, SkyCondition.clear);
    expect(palette.top, expected.top);
  });

  test('different times of day produce different skies', () async {
    final noon = await paletteAt(DateTime(2026, 9, 22, 12, 30));
    final night = await paletteAt(DateTime(2026, 9, 22, 23, 5));
    expect(noon.top, isNot(night.top));
  });
}
