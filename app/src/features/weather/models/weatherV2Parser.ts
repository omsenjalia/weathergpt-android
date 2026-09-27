/// Parser for v2 `/v2/weather` — WeatherNext capable. Port of
/// `lib/models/weather_v2_parser.dart`. Handles both v2 and legacy v1 so
/// migration is safe.

import {
  jsonBool,
  jsonDate,
  jsonDouble,
  jsonInt,
  jsonList,
  jsonMap,
  jsonNum,
  jsonString,
} from "../../../core/models/jsonValues";
import { weatherProvenanceFromJson } from "../../../core/models/dataProvenance";
import { fieldSourcesFromJson, precipitationIntervalFromJson, temperatureSpreadFromJson } from "../../../core/models/fieldSources";
import { DayForecast, HourlyPoint, WeatherSnapshot } from "./weather";

/// Parses the backend's location timezone into a UTC offset in seconds.
///
/// Accepts `utc_offset_seconds`, `utc_offset_hours_approx`, or the
/// WeatherNext label `UTC+5 (solar approximation)`. Returns `null` when
/// nothing usable was reported — callers then fall back to device time
/// rather than guessing.
export function parseUtcOffsetSeconds(location: Record<string, unknown> | null): number | null {
  if (location === null) return null;
  const seconds = jsonInt(location["utc_offset_seconds"]);
  if (seconds !== null) return seconds;
  const hours = jsonNum(location["utc_offset_hours_approx"]);
  if (hours !== null) return Math.round(hours * 3600);
  const tz = jsonString(location["timezone"]);
  if (tz !== null) {
    const m = /^UTC([+-])(\d{1,2})(?::?(\d{2}))?/.exec(tz);
    if (m !== null) {
      const sign = m[1] === "-" ? -1 : 1;
      const h = parseInt(m[2]!, 10);
      const min = m[3] !== undefined ? parseInt(m[3], 10) : 0;
      return sign * (h * 3600 + min * 60);
    }
  }
  return null;
}

/// 12-hour clock label for an hourly bucket in the *location's* local time.
export function hourLabelFor(utc: Date | null, offsetSeconds: number | null): string {
  if (utc === null) return "";
  const shifted = offsetSeconds === null ? utc : new Date(utc.getTime() + offsetSeconds * 1000);
  const h = offsetSeconds === null ? shifted.getHours() : shifted.getUTCHours();
  if (h === 0) return "12AM";
  if (h === 12) return "12PM";
  return h > 12 ? `${h - 12}PM` : `${h}AM`;
}

function hourLabel(iso: string | null, offsetSeconds: number | null): string {
  const utc = jsonDate(iso);
  if (utc !== null) return hourLabelFor(utc, offsetSeconds);
  if (iso === null) return "";
  const h = iso.length >= 13 ? parseInt(iso.slice(11, 13), 10) : NaN;
  const hour = Number.isNaN(h) ? 0 : h;
  if (hour === 0) return "12AM";
  if (hour === 12) return "12PM";
  return hour > 12 ? `${hour - 12}PM` : `${hour}AM`;
}

function fieldSourceMap(raw: unknown): Record<string, string> {
  const m = jsonMap(raw);
  if (m === null) return {};
  const out: Record<string, string> = {};
  for (const [key, value] of Object.entries(m)) {
    const s = jsonString(value);
    if (s !== null) out[key] = s;
  }
  return out;
}

export function parseWeatherSnapshotV2(
  data: Record<string, unknown>,
  opts: { cityName: string },
): WeatherSnapshot {
  const provenance = weatherProvenanceFromJson(data);
  const location = jsonMap(data["location"]);
  const utcOffset = parseUtcOffsetSeconds(location);
  const timezoneId = jsonString(location?.["timezone"]) ?? provenance.timezoneId ?? null;

  const hourly: HourlyPoint[] = [];
  for (const item of jsonList(data["hourly"])) {
    const row = jsonMap(item);
    if (row === null) continue;
    const temp = jsonDouble(row["temperature_c"] ?? row["temperature"]);
    if (temp === null) continue;
    const rawTime = row["time"] ?? row["time_utc"];
    hourly.push({
      label: hourLabel(jsonString(rawTime), utcOffset),
      tempC: temp,
      timeUtc: jsonDate(rawTime),
      rainProbability: jsonNum(row["rain_probability"] ?? row["precipitation_probability"]),
      precipMm: jsonNum(row["precipitation"] ?? row["precipitation_mm"]),
      windKmh: jsonNum(row["wind_kmh"] ?? row["wind_speed_kmh"]),
      windDirection: jsonNum(row["wind_direction_deg"] ?? row["wind_direction"]),
      humidity: jsonNum(row["humidity_percent"] ?? row["humidity"]),
      feelsLikeC: jsonDouble(row["feels_like_c"]),
      pressureHpa: jsonNum(row["pressure_hpa"]),
      cloudCover: jsonNum(row["cloud_cover_percent"]),
      uvIndex: jsonNum(row["uv_index"]),
      condition: jsonString(row["condition"]),
      weatherCode: jsonInt(row["weather_code"]),
      isEnsembleMean: jsonBool(row["is_ensemble_mean"]),
      missingReason: jsonString(row["missing_reason"]),
    });
  }

  const dailyRaw = jsonList(data["daily"]).length > 0 ? jsonList(data["daily"]) : jsonList(data["forecast"]);
  const forecast: DayForecast[] = [];
  for (const item of dailyRaw) {
    const row = jsonMap(item);
    if (row === null) continue;
    forecast.push({
      date: jsonString(row["date"]) ?? "",
      dateUtc: jsonDate(row["date"]),
      highC: jsonDouble(row["high_c"]),
      lowC: jsonDouble(row["low_c"]),
      condition: jsonString(row["condition"]) ?? "—",
      rainProbability: jsonNum(row["rain_probability"]),
      precipMm: jsonNum(row["precipitation_mm"] ?? row["rain_mm"] ?? row["rain_sum"]),
      precipIntervalLabel: jsonString(row["precipitation_interval"]),
      coversFullDay: jsonBool(row["covers_full_day"]),
      windKmhMax: jsonNum(row["wind_kmh_max"]),
      weatherCode: jsonInt(row["weather_code"]),
      highP90C: jsonDouble(row["high_p90_c"]),
      lowP10C: jsonDouble(row["low_p10_c"]),
      sunrise: jsonString(row["sunrise"]),
      sunset: jsonString(row["sunset"]),
      uvIndexMax: jsonNum(row["uv_index_max"]),
      hoursCovered: jsonInt(row["hours_covered"]),
      source: jsonString(row["source"]),
      statistic: jsonString(row["statistic"]),
      fieldSources: fieldSourceMap(row["field_sources"]),
    });
  }

  const current = jsonMap(data["current"]);
  const first = dailyRaw.length > 0 ? jsonMap(dailyRaw[0]) : null;
  const aq = jsonMap(data["air_quality"]);

  let temperatureC: number | null = null;
  let feelsLikeC: number | null = null;
  let condition = "—";
  let weatherCode: number | null = null;
  let highC: number | null = null;
  let lowC: number | null = null;
  let humidity: number | null = null;
  let windKmh: number | null = null;
  let windDirection: number | null = null;
  let pressureHpa: number | null = null;
  let rainProbability: number | null = null;
  let uvIndex: number | null = null;
  let sunrise: string | null = null;
  let sunset: string | null = null;
  let aqi: number | null = null;
  let pm25: number | null = null;
  let cloudCover: number | null = null;
  let precipMm: number | null = null;
  let currentTimeUtc: Date | null = null;
  let currentIsEnsembleMean: boolean | null = null;

  if (current !== null) {
    temperatureC = jsonDouble(current["temperature_c"]);
    feelsLikeC = jsonDouble(current["feels_like_c"]);
    condition = jsonString(current["condition"]) ?? jsonString(first?.["condition"]) ?? "—";
    weatherCode =
      jsonInt(current["weather_code"]) ?? (jsonString(current["condition"]) === null ? jsonInt(first?.["weather_code"]) : null);
    humidity = jsonNum(current["humidity_percent"] ?? current["humidity"]);
    windKmh = jsonNum(current["wind_speed_kmh"] ?? current["wind_kmh"]);
    windDirection = jsonNum(current["wind_direction_deg"] ?? current["wind_direction"]);
    pressureHpa = jsonNum(current["pressure_hpa"]);
    rainProbability =
      jsonNum(current["precipitation_probability"] ?? current["rain_probability"]) ?? jsonNum(first?.["rain_probability"]);
    // UV: the current step first, else today's daily maximum.
    uvIndex = jsonNum(current["uv_index"]);
    cloudCover = jsonNum(current["cloud_cover_percent"]);
    precipMm = jsonNum(current["precipitation_mm"]);
    currentTimeUtc = jsonDate(current["time_utc"] ?? current["time"]);
    currentIsEnsembleMean = jsonBool(current["is_ensemble_mean"]);
    if (forecast.length > 0) {
      highC = forecast[0].highC ?? null;
      lowC = forecast[0].lowC ?? null;
    }
    sunrise = jsonString(first?.["sunrise"]);
    sunset = jsonString(first?.["sunset"]);
  } else {
    temperatureC = jsonDouble(data["temperature_c"]);
    feelsLikeC = jsonDouble(data["feels_like_c"]);
    condition = jsonString(data["condition"]) ?? "—";
    weatherCode = jsonInt(data["weather_code"]);
    highC = jsonDouble(data["high_c"]);
    lowC = jsonDouble(data["low_c"]);
    humidity = jsonNum(data["humidity"]);
    windKmh = jsonNum(data["wind_kmh"]);
    windDirection = jsonNum(data["wind_direction"]);
    pressureHpa = jsonNum(data["pressure_hpa"]);
    rainProbability = jsonNum(data["rain_probability"]);
    uvIndex = jsonNum(data["uv_index"]);
    sunrise = jsonString(data["sunrise"]);
    sunset = jsonString(data["sunset"]);
    aqi = jsonNum(data["aqi"]);
    pm25 = jsonNum(data["pm2_5"] ?? data["pm25"]);
    precipMm = jsonNum(data["precipitation_mm"]);
  }
  if (aq !== null) {
    aqi = aqi ?? jsonNum(aq["european_aqi"] ?? aq["aqi"]);
    pm25 = pm25 ?? jsonNum(aq["pm2_5"] ?? aq["pm25"]);
  }

  return {
    temperatureC,
    feelsLikeC,
    condition,
    weatherCode,
    highC,
    lowC,
    humidity,
    windKmh,
    windDirection,
    pressureHpa,
    rainProbability,
    uvIndex,
    sunrise,
    sunset,
    aqi,
    pm25,
    hourly,
    forecast,
    cityName: opts.cityName,
    provenance,
    temperatureSpread: temperatureSpreadFromJson(data["temperature_spread"] ?? data["temperature_range"]),
    precipNext24h: precipitationIntervalFromJson(data["precip_next_24h"] ?? data["precipitation_next_24h"]),
    fieldSources: fieldSourcesFromJson(data["field_sources"]),
    cloudCover,
    precipMm,
    currentTimeUtc,
    currentIsEnsembleMean,
    timezoneId,
    utcOffsetSeconds: utcOffset,
    hourlyAvailable: jsonInt(data["hourly_available"]),
    degraded: jsonBool(data["degraded"]),
    endpoint: "/v2/weather",
    fetchedAtUtc: jsonDate(data["fetched_at"]),
    rawPayload: data,
  };
}
