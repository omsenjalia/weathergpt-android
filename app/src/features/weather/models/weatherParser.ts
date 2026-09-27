/// Parser for the backend `/weather` payload — port of
/// `lib/models/weather_parser.dart`. Unknown additive fields are ignored, and
/// absent values stay `null` rather than becoming a confident zero.

import { jsonDate, jsonBool, jsonDouble, jsonInt, jsonList, jsonMap, jsonNum, jsonString, naiveTimestampAssumedUtc } from "../../../core/models/jsonValues";
import { weatherProvenanceFromJson } from "../../../core/models/dataProvenance";
import { fieldSourcesFromJson, precipitationIntervalFromJson, temperatureSpreadFromJson } from "../../../core/models/fieldSources";
import { DayForecast, HourlyPoint, WeatherSnapshot } from "./weather";
import { hourLabelFor, parseUtcOffsetSeconds } from "./weatherV2Parser";

function hourLabel(iso: string | null, offsetSeconds: number | null): string {
  if (iso === null || iso.length < 13) return "";
  // Legacy payloads carry naive local timestamps ("2026-09-19T09:00"): the
  // hour digits are already local. Offset-bearing stamps are converted.
  const utc = jsonDate(iso);
  if (utc !== null && !naiveTimestampAssumedUtc(iso)) {
    return hourLabelFor(utc, offsetSeconds);
  }
  const h = parseInt(iso.slice(11, 13), 10) || 0;
  if (h === 0) return "12AM";
  if (h === 12) return "12PM";
  return h > 12 ? `${h - 12}PM` : `${h}AM`;
}

/// Parses the backend `/weather` payload into a WeatherSnapshot. Split out of
/// the store body so it can be exercised directly by parser fixture tests
/// without a network.
export function parseWeatherSnapshot(
  data: Record<string, unknown>,
  opts: { cityName: string },
): WeatherSnapshot {
  const provenance = weatherProvenanceFromJson(data);
  const locationRaw = jsonMap(data["location"]) ?? {
    timezone: data["timezone"],
    utc_offset_seconds: data["utc_offset_seconds"],
  };
  const utcOffset = parseUtcOffsetSeconds(locationRaw);

  const hourly: HourlyPoint[] = [];
  for (const item of jsonList(data["hourly"])) {
    const row = jsonMap(item);
    if (row === null) continue;
    const temp = jsonDouble(row["temperature_c"] ?? row["temperature"]);
    // A bucket with no temperature cannot be plotted; dropping it is honest,
    // but it must not be drawn as 0 °C.
    if (temp === null) continue;
    const rawTime = row["time"];
    hourly.push({
      label: hourLabel(jsonString(rawTime), utcOffset),
      tempC: temp,
      timeUtc: jsonDate(rawTime),
      rainProbability: jsonNum(row["rain_probability"]),
      precipMm: jsonNum(row["precipitation"] ?? row["precipitation_mm"]),
      windKmh: jsonNum(row["wind_kmh"]),
      humidity: jsonNum(row["humidity"]),
      condition: jsonString(row["condition"]),
      weatherCode: jsonInt(row["weather_code"]),
    });
  }

  const forecast: DayForecast[] = [];
  for (const item of jsonList(data["forecast"])) {
    const row = jsonMap(item);
    if (row === null) continue;
    forecast.push({
      date: jsonString(row["date"]) ?? "",
      dateUtc: jsonDate(row["date"]),
      highC: jsonDouble(row["high_c"]),
      lowC: jsonDouble(row["low_c"]),
      condition: jsonString(row["condition"]) ?? "—",
      rainProbability: jsonNum(row["rain_probability"]),
      precipMm: jsonNum(row["precipitation_mm"] ?? row["rain_mm"]),
      precipIntervalLabel: jsonString(row["precipitation_interval"]),
      coversFullDay: jsonBool(row["covers_full_day"]),
      windKmhMax: jsonNum(row["wind_kmh_max"]),
      weatherCode: jsonInt(row["weather_code"]),
      sunrise: jsonString(row["sunrise"]),
      sunset: jsonString(row["sunset"]),
      uvIndexMax: jsonNum(row["uv_index_max"]),
      fieldSources: {},
    });
  }

  return {
    temperatureC: jsonDouble(data["temperature_c"]),
    feelsLikeC: jsonDouble(data["feels_like_c"]),
    condition: jsonString(data["condition"]) ?? "—",
    // A missing code stays null. Code 0 means "clear sky", so defaulting here
    // would turn an unknown sky into a sunny one.
    weatherCode: jsonInt(data["weather_code"]),
    highC: jsonDouble(data["high_c"]),
    lowC: jsonDouble(data["low_c"]),
    humidity: jsonNum(data["humidity"]),
    windKmh: jsonNum(data["wind_kmh"]),
    windDirection: jsonNum(data["wind_direction"]),
    pressureHpa: jsonNum(data["pressure_hpa"]),
    rainProbability: jsonNum(data["rain_probability"]),
    uvIndex: jsonNum(data["uv_index"]),
    sunrise: jsonString(data["sunrise"]),
    sunset: jsonString(data["sunset"]),
    aqi: jsonNum(data["aqi"]),
    pm25: jsonNum(data["pm2_5"] ?? data["pm25"]),
    hourly,
    forecast,
    cityName: opts.cityName,
    provenance,
    temperatureSpread: temperatureSpreadFromJson(data["temperature_spread"] ?? data["temperature_range"]),
    precipNext24h: precipitationIntervalFromJson(data["precip_next_24h"] ?? data["precipitation_next_24h"]),
    fieldSources: fieldSourcesFromJson(data["field_sources"]),
    precipMm: jsonNum(data["precipitation_mm"]),
    timezoneId: jsonString(data["timezone"]) ?? provenance.timezoneId ?? null,
    utcOffsetSeconds: utcOffset,
    endpoint: "/weather",
    fetchedAtUtc: jsonDate(data["fetched_at"]),
    rawPayload: data,
  };
}
