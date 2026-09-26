/// Every backend path the app calls. Legacy paths stay version-less for
/// backward compatibility; v2 shares the local provider-aware service.
abstract final class ApiEndpoints {
  static const chat = '/chat';
  static const weather = '/weather';
  static const health = '/health';
  static const diagnostics = '/dev';
  static const sandbox = '/dev/sandbox';
  static const advisory = '/advisory';
  static const historical = '/historical';
  static const comparison = '/comparison';

  // Versioned weather facade and configuration health
  static const v2Weather = '/v2/weather';
  static const v2WeatherHealth = '/v2/weather/health';
}
