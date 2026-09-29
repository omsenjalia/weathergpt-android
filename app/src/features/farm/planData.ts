/// Farmer "Plan" tab data: a 15-day daily rain outlook built from the hourly
/// series (`/v2/weather/series`) and a general crop calendar keyed by the farm
/// profile's wire values.

import { ApiEndpoints } from "../../core/config/apiEndpoints";
import { ApiClient } from "../../core/services/apiClient";
import { AppLocation } from "../../models/location";
import { forecastSeriesFromJson, ForecastSeries, SeriesVariable } from "../research/modelData";
import { GROWTH_STAGES } from "./models/farmOptions";

// ---------------------------------------------------------------------------
// Rain outlook

/// IMD counts a day with 2.5 mm or more as a rainy day.
export const RAINY_DAY_MM = 2.5;
export const OUTLOOK_DAYS = 15;

export interface RainDay {
  /// Local calendar date, `YYYY-MM-DD`.
  date: string;
  expectedMm: number;
}

export interface RainOutlook {
  series: ForecastSeries;
  days: RainDay[];
}

function localDateKey(ms: number): string {
  const d = new Date(ms);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}

/// Buckets hourly millimetres into local days, in order.
export function dailyRain(series: ForecastSeries): RainDay[] {
  const byDay = new Map<string, RainDay>();
  for (const p of series.mean) {
    const key = localDateKey(series.startMs + p.x * 3_600_000);
    const day = byDay.get(key) ?? { date: key, expectedMm: 0 };
    day.expectedMm += Math.max(p.value, 0);
    byDay.set(key, day);
  }
  return [...byDay.values()].sort((a, b) => a.date.localeCompare(b.date)).slice(0, OUTLOOK_DAYS);
}

/// Index of the first rainy day, or null when none is forecast.
export function nextRainyDay(days: RainDay[]): number | null {
  const i = days.findIndex((d) => d.expectedMm >= RAINY_DAY_MM);
  return i === -1 ? null : i;
}

export function totalRain(days: RainDay[]): number {
  return days.reduce((sum, d) => sum + d.expectedMm, 0);
}

export async function fetchRainOutlook(location: AppLocation): Promise<RainOutlook> {
  const data = await ApiClient.get(ApiEndpoints.v2WeatherSeries, {
    lat: location.lat,
    lon: location.lon,
    variable: SeriesVariable.Rainfall,
    forecast_days: OUTLOOK_DAYS,
  });
  const series = forecastSeriesFromJson(data);
  return { series, days: series.status === "ok" ? dailyRain(series) : [] };
}

// ---------------------------------------------------------------------------
// Crop calendar (general guidance, not a local agronomy source)

/// Typical days from sowing to harvest across common Indian varieties.
export const CROP_DURATION_DAYS: Readonly<Record<string, readonly [number, number]>> = {
  Wheat: [110, 130],
  Rice: [110, 150],
  Cotton: [150, 180],
  Maize: [90, 120],
  Sugarcane: [300, 365],
  Soybean: [90, 110],
  Groundnut: [100, 130],
  Mustard: [110, 140],
  Potato: [90, 120],
  Onion: [120, 150],
  Tomato: [120, 150],
  Pulses: [90, 120],
};

/// i18n key for a stage's general tasks, e.g. `plan.stage_sowing`.
export function stageTaskKey(stage: string): string {
  return `plan.stage_${stage.toLowerCase()}`;
}

/// i18n key for the crop's watch-out, or null for a crop outside the catalog.
export function cropNoteKey(crop: string): string | null {
  return crop in CROP_DURATION_DAYS ? `plan.crop_${crop.toLowerCase()}` : null;
}

export function stageIndex(stage: string): number {
  return GROWTH_STAGES.indexOf(stage);
}
