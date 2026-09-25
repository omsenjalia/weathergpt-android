/// Every backend path the app calls. Legacy paths stay version-less for
/// backward compatibility; `/v2/...` WeatherNext contracts are live in backend v2.1.0.
abstract final class ApiEndpoints {
  static const chat = '/chat';
  static const weather = '/weather';
  static const health = '/health';
  static const diagnostics = '/dev';
  static const sandbox = '/dev/sandbox';
  static const advisory = '/advisory';
  static const historical = '/historical';
  static const comparison = '/comparison';

  // WeatherNext v2 (backend v2.1.0+)
  static const v2Weather = '/v2/weather';
  static const v2WeatherHealth = '/v2/weather/health';
  static const v2WeatherCatalog = '/v2/weather/catalog';
  static const v2WeatherSeries = '/v2/weather/series';
}
