import 'package:flutter_test/flutter_test.dart';
import 'package:weathergpt_mobile/core/models/app_mode.dart';
import 'package:weathergpt_mobile/features/home/providers/weather_provider.dart';
import 'package:weathergpt_mobile/features/settings/providers/developer_options_provider.dart';

void main() {
  test('all personas use the installed backend policy by default', () {
    for (final mode in AppMode.values) {
      final query = buildWeatherQuery(
        lat: 23, lon: 72, mode: mode, dev: const DeveloperOptions(),
      );
      expect(query['requested_source'], 'auto');
      expect(query['forecast_days'], 7);
      expect(query['hourly_hours'], 48);
      expect(query.containsKey('model'), isFalse);
    }
  });

  test('developer pins and horizons are sent only when enabled', () {
    const dev = DeveloperOptions(
      enabled: true, sourcePin: DevSourcePin.accuweather,
      forecastDays: 3, hourlyHours: 24, supplementSecondaryFields: false,
    );
    final query = buildWeatherQuery(lat: 23, lon: 72, mode: AppMode.researcher, dev: dev);
    expect(query['requested_source'], 'accuweather');
    expect(query['forecast_days'], 3);
    expect(query['hourly_hours'], 24);
    expect(query['supplement'], isFalse);
    final defaults = buildWeatherQuery(
      lat: 23, lon: 72, mode: AppMode.researcher, dev: dev.copyWith(enabled: false),
    );
    expect(defaults['requested_source'], 'auto');
    expect(defaults.containsKey('supplement'), isFalse);
  });

  test('removed providers are not offered in settings', () {
    expect(DevSourcePin.values.map((pin) => pin.wire),
        ['auto', 'open_meteo', 'accuweather', 'imd']);
  });
}
