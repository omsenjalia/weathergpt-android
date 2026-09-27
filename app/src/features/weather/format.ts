/// Pure presentation helpers for weather values. Every function preserves
/// the null semantics of the models: a missing value renders as an em dash,
/// never as zero.

import { SkyCondition, conditionFromWeather } from "./theme/atmosphereTheme";

export const EM_DASH = "—";

type TempUnit = "celsius" | "fahrenheit";

function present(value: number | null | undefined): value is number {
  return value !== null && value !== undefined && Number.isFinite(value);
}

/// Degrees without the unit letter ("31°") — used where the unit is implied
/// (hero, hourly strip, daily list).
export function formatDegrees(celsius: number | null | undefined, unit: TempUnit): string {
  if (!present(celsius)) return EM_DASH;
  return `${Math.round(unit === "fahrenheit" ? (celsius * 9) / 5 + 32 : celsius)}°`;
}

export function formatPercent(value: number | null | undefined): string {
  return present(value) ? `${Math.round(value)}%` : EM_DASH;
}

export function formatNumber(value: number | null | undefined, suffix = "", digits = 0): string {
  if (!present(value)) return EM_DASH;
  const rounded = digits === 0 ? Math.round(value) : Number(value.toFixed(digits));
  return `${rounded}${suffix}`;
}

// ---------------------------------------------------------------------------
// Icons

type WeatherIcon =
  | "weather-sunny"
  | "weather-night"
  | "weather-partly-cloudy"
  | "weather-night-partly-cloudy"
  | "weather-cloudy"
  | "weather-fog"
  | "weather-partly-rainy"
  | "weather-rainy"
  | "weather-pouring"
  | "weather-lightning-rainy"
  | "weather-snowy"
  | "weather-windy"
  | "cloud-question-outline";

export function iconForSky(sky: SkyCondition, isNight = false): WeatherIcon {
  switch (sky) {
    case SkyCondition.Clear:
      return isNight ? "weather-night" : "weather-sunny";
    case SkyCondition.PartlyCloudy:
      return isNight ? "weather-night-partly-cloudy" : "weather-partly-cloudy";
    case SkyCondition.Cloudy:
    case SkyCondition.Overcast:
      return "weather-cloudy";
    case SkyCondition.Fog:
      return "weather-fog";
    case SkyCondition.Drizzle:
      return "weather-partly-rainy";
    case SkyCondition.Rain:
      return "weather-rainy";
    case SkyCondition.HeavyRain:
      return "weather-pouring";
    case SkyCondition.Thunder:
      return "weather-lightning-rainy";
    case SkyCondition.Snow:
      return "weather-snowy";
    case SkyCondition.Windy:
      return "weather-windy";
    case SkyCondition.Unknown:
      // Never draw an unknown sky as sunny; render it dimmed (see isUnknownWeather).
      return "cloud-question-outline";
  }
}

/// True when neither a WMO code nor a recognisable condition was reported.
export function isUnknownWeather(input: { weatherCode?: number | null; condition?: string | null; windKmh?: number | null }): boolean {
  return conditionFromWeather({ weatherCode: input.weatherCode ?? null, condition: input.condition ?? "", windKmh: input.windKmh ?? null }) === SkyCondition.Unknown;
}

export function iconForWeather(
  input: { weatherCode?: number | null; condition?: string | null; windKmh?: number | null },
  isNight = false,
): WeatherIcon {
  const sky = conditionFromWeather({
    weatherCode: input.weatherCode ?? null,
    condition: input.condition ?? "",
    windKmh: input.windKmh ?? null,
  });
  return iconForSky(sky, isNight);
}

// ---------------------------------------------------------------------------
// Bands (return i18n keys so labels stay translatable)

export function uvBandKey(uv: number | null | undefined): string | null {
  if (!present(uv)) return null;
  if (uv < 3) return "home.uv_low";
  if (uv < 6) return "home.uv_moderate";
  if (uv < 8) return "home.uv_high";
  if (uv < 11) return "home.uv_very_high";
  return "home.uv_extreme";
}

/// European AQI bands (Open-Meteo air-quality scale).
export function aqiBandKey(aqi: number | null | undefined): string | null {
  if (!present(aqi)) return null;
  if (aqi <= 20) return "home.aqi_good";
  if (aqi <= 40) return "home.aqi_fair";
  if (aqi <= 60) return "home.aqi_moderate";
  if (aqi <= 80) return "home.aqi_poor";
  if (aqi <= 100) return "home.aqi_very_poor";
  return "home.aqi_extremely_poor";
}

export function humidityBandKey(humidity: number | null | undefined): string | null {
  if (!present(humidity)) return null;
  if (humidity >= 70) return "home.humid";
  if (humidity <= 30) return "home.dry";
  return "home.comfortable";
}

/// Position of `value` on a 0–1 track, clamped.
export function scaleRatio(value: number | null | undefined, min: number, max: number): number | null {
  if (!present(value) || max <= min) return null;
  return Math.min(1, Math.max(0, (value - min) / (max - min)));
}

// ---------------------------------------------------------------------------
// Time

const ZONED = /(?:Z|[+-]\d{2}:?\d{2})$/i;

/// Wall-clock minutes-of-day at the location for a backend timestamp.
///
/// Naive timestamps ("2026-09-19T06:12") already represent location-local
/// time and are read as written. Zoned timestamps are shifted by the
/// location's UTC offset when known.
export function localMinutesOfDay(raw: string | null | undefined, utcOffsetSeconds: number | null | undefined): number | null {
  if (raw === null || raw === undefined) return null;
  const trimmed = raw.trim();
  if (ZONED.test(trimmed) && present(utcOffsetSeconds)) {
    const ms = Date.parse(trimmed);
    if (Number.isNaN(ms)) return null;
    const shifted = new Date(ms + utcOffsetSeconds * 1000);
    return shifted.getUTCHours() * 60 + shifted.getUTCMinutes();
  }
  const m = /T(\d{2}):(\d{2})/.exec(trimmed);
  if (m === null) return null;
  return parseInt(m[1]!, 10) * 60 + parseInt(m[2]!, 10);
}

export function formatMinutesOfDay(minutes: number | null): string {
  if (minutes === null) return EM_DASH;
  const h = Math.floor(minutes / 60) % 24;
  const m = String(minutes % 60).padStart(2, "0");
  const period = h >= 12 ? "PM" : "AM";
  const h12 = h % 12 === 0 ? 12 : h % 12;
  return `${h12}:${m} ${period}`;
}

export function formatLocalClock(raw: string | null | undefined, utcOffsetSeconds: number | null | undefined): string {
  return formatMinutesOfDay(localMinutesOfDay(raw, utcOffsetSeconds));
}

/// Minutes-of-day right now at the location (device clock when no offset).
export function nowMinutesAtLocation(utcOffsetSeconds: number | null | undefined, now = new Date()): number {
  if (!present(utcOffsetSeconds)) return now.getHours() * 60 + now.getMinutes();
  const shifted = new Date(now.getTime() + utcOffsetSeconds * 1000);
  return shifted.getUTCHours() * 60 + shifted.getUTCMinutes();
}

/// Short weekday for an ISO date ("2026-09-19") in the app language.
export function weekdayShort(isoDate: string, locale: string): string {
  const parsed = new Date(`${isoDate.slice(0, 10)}T12:00:00Z`);
  if (Number.isNaN(parsed.getTime())) return isoDate;
  try {
    return parsed.toLocaleDateString(locale, { weekday: "short", timeZone: "UTC" });
  } catch {
    return ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][parsed.getUTCDay()]!;
  }
}

/// Whether a minutes-of-day value falls outside sunrise–sunset.
export function isNightAt(minutes: number, sunrise: number | null, sunset: number | null): boolean {
  if (sunrise === null || sunset === null) return minutes < 6 * 60 || minutes >= 19 * 60;
  return minutes < sunrise || minutes >= sunset;
}

/// Minutes-of-day an hourly label like "3PM" / "12AM" refers to.
export function minutesFromHourLabel(label: string): number | null {
  const m = /^(\d{1,2})\s*(AM|PM)$/i.exec(label.trim());
  if (m === null) return null;
  const h = parseInt(m[1]!, 10) % 12;
  return (m[2]!.toUpperCase() === "PM" ? h + 12 : h) * 60;
}

export function compassLabel(deg: number | null | undefined): string {
  if (!present(deg)) return EM_DASH;
  const dirs = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"];
  return dirs[Math.round((((deg % 360) + 360) % 360) / 45) % 8]!;
}
