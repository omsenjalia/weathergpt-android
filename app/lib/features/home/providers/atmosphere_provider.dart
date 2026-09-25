import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/atmosphere_theme.dart';
import 'weather_provider.dart';

/// Emits the current wall-clock time every minute so time-of-day palettes
/// stay fresh during long app sessions (dusk arriving while the user sits
/// on the chat screen still repaints the sky).
final clockTickerProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  await for (final _ in Stream.periodic(const Duration(minutes: 1))) {
    yield DateTime.now();
  }
});

/// The app-wide sky: current time-of-day period blended with the live
/// weather condition from the latest snapshot.
///
/// Every non-home screen (chat, voice, settings, persona hubs, onboarding)
/// watches this instead of computing a palette once in `build`, so the
/// atmosphere follows time and weather everywhere, not just on Home.
final atmospherePaletteProvider = Provider<AtmospherePalette>((ref) {
  final now = ref.watch(clockTickerProvider).value ?? DateTime.now();
  final weather = ref.watch(weatherProvider).value;
  final w = weather;
  final sunrise = w == null ? null : parseWeatherTime(w.sunrise);
  final sunset = w == null ? null : parseWeatherTime(w.sunset);
  final sky = w == null ? SkyCondition.clear : conditionFromWeather(w);
  return paletteFor(
    periodFromLocalTime(now.toLocal(), sunrise, sunset),
    sky,
  );
});
