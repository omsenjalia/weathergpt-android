/// Every backend path the app calls — port of
/// `lib/core/constants/api_endpoints.dart`. Legacy paths stay version-less for
/// backward compatibility; v2 shares the local provider-aware service.

export const ApiEndpoints = {
  chat: "/chat",
  weather: "/weather",
  health: "/health",
  diagnostics: "/dev",
  sandbox: "/dev/sandbox",
  advisory: "/advisory",
  historical: "/historical",
  comparison: "/comparison",

  // Versioned weather facade and configuration health
  v2Weather: "/v2/weather",
  v2WeatherHealth: "/v2/weather/health",
} as const;
