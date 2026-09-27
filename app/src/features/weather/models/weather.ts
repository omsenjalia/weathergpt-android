/// Immutable models for weather data — port of `lib/models/weather.dart`.
///
/// Nullable-by-design: a field the backend did not send stays `null` and the
/// UI renders an unavailable state. Missing measurements are never coerced to
/// `0`, and a missing weather code is never treated as "clear".

import { WeatherProvenance, noProvenance } from "../../../core/models/dataProvenance";
import {
  FieldSources,
  PrecipitationInterval,
  TemperatureSpread,
  fieldSourcesFromJson,
  fieldSourcesIsSupplemented,
  fieldSourcesProviderFor,
  noFieldSources,
  precipitationIntervalFromJson,
  temperatureSpreadFromJson,
} from "../../../core/models/fieldSources";

export type { FieldSources, PrecipitationInterval, TemperatureSpread, WeatherProvenance };
export {
  fieldSourcesFromJson,
  fieldSourcesIsSupplemented,
  fieldSourcesProviderFor,
  noFieldSources,
  precipitationIntervalFromJson,
  temperatureSpreadFromJson,
};

export interface HourlyPoint {
  label: string;
  tempC: number;
  /// Instant this bucket refers to, in UTC.
  timeUtc?: Date | null;
  rainProbability?: number | null;
  precipMm?: number | null;
  windKmh?: number | null;
  windDirection?: number | null;
  humidity?: number | null;
  feelsLikeC?: number | null;
  pressureHpa?: number | null;
  cloudCover?: number | null;
  uvIndex?: number | null;
  condition?: string | null;
  /// WMO code when reported. `null` means unknown, never "clear".
  weatherCode?: number | null;
  /// True when the value is an ensemble mean (WeatherNext).
  isEnsembleMean?: boolean | null;
  /// Backend's stated reason when a field could not be derived.
  missingReason?: string | null;
}

export interface DayForecast {
  date: string;
  dateUtc?: Date | null;
  highC?: number | null;
  lowC?: number | null;
  condition: string;
  rainProbability?: number | null;
  weatherCode?: number | null;
  highP90C?: number | null;
  lowP10C?: number | null;
  sunrise?: string | null;
  sunset?: string | null;
  uvIndexMax?: number | null;
  hoursCovered?: number | null;
  source?: string | null;
  statistic?: string | null;
  fieldSources: Record<string, string>;
  precipMm?: number | null;
  precipIntervalLabel?: string | null;
  coversFullDay?: boolean | null;
  windKmhMax?: number | null;
}

export function dayHasAnyMeasurement(day: DayForecast): boolean {
  return day.highC !== null || day.lowC !== null || day.rainProbability !== null || day.precipMm !== null;
}

export function dayHasEnvelope(day: DayForecast): boolean {
  return day.highP90C !== null && day.highP90C !== undefined && day.lowP10C !== null && day.lowP10C !== undefined;
}

export interface WeatherSnapshot {
  temperatureC?: number | null;
  feelsLikeC?: number | null;
  condition: string;
  /// WMO code when the backend sent one. `null` means unknown — it must never
  /// be read as code `0` ("clear sky").
  weatherCode?: number | null;
  highC?: number | null;
  lowC?: number | null;
  humidity?: number | null;
  windKmh?: number | null;
  windDirection?: number | null;
  pressureHpa?: number | null;
  rainProbability?: number | null;
  uvIndex?: number | null;
  sunrise?: string | null;
  sunset?: string | null;
  aqi?: number | null;
  pm25?: number | null;
  hourly: HourlyPoint[];
  forecast: DayForecast[];
  cityName: string;
  provenance: WeatherProvenance;
  temperatureSpread?: TemperatureSpread | null;
  precipNext24h?: PrecipitationInterval | null;
  fieldSources: FieldSources;
  cloudCover?: number | null;
  precipMm?: number | null;
  currentTimeUtc?: Date | null;
  currentIsEnsembleMean?: boolean | null;
  timezoneId?: string | null;
  utcOffsetSeconds?: number | null;
  hourlyAvailable?: number | null;
  degraded?: boolean | null;
  endpoint?: string | null;
  fetchedAtUtc?: Date | null;
  rawPayload?: Record<string, unknown> | null;
}

export function snapshotHasCondition(w: WeatherSnapshot): boolean {
  return w.weatherCode !== null || w.condition !== "—";
}

/// Local time at the location right now, using the reported UTC offset. Falls
/// back to device local time when the backend gave no offset.
export function snapshotLocalNow(w: WeatherSnapshot): Date {
  if (w.utcOffsetSeconds === null || w.utcOffsetSeconds === undefined) return new Date();
  return new Date(Date.now() + w.utcOffsetSeconds * 1000);
}

export function snapshotToLocationLocal(w: WeatherSnapshot, utc: Date): Date {
  if (w.utcOffsetSeconds === null || w.utcOffsetSeconds === undefined) return utc;
  return new Date(utc.getTime() + w.utcOffsetSeconds * 1000 + utc.getTimezoneOffset() * 60_000 * 0);
}

/// Provider that supplied `field` (falls back to the selected source when the
/// backend sent no per-field attribution).
export function snapshotSourceOf(w: WeatherSnapshot, field: string): string | null {
  const perField = fieldSourcesProviderFor(w.fieldSources, field);
  if (perField !== null) return perField;
  if (Object.keys(w.fieldSources.sources).length === 0) return w.provenance.selectedSource ?? w.provenance.source ?? null;
  return null;
}

export function snapshotIsSupplemented(w: WeatherSnapshot, field: string): boolean {
  const primary = w.provenance.selectedSource ?? w.provenance.source ?? null;
  return fieldSourcesIsSupplemented(w.fieldSources, field, primary);
}

export function snapshotForecastDays(w: WeatherSnapshot): number {
  return w.forecast.length;
}

export function snapshotHourlyPoints(w: WeatherSnapshot): number {
  return w.hourly.length;
}

export interface WeatherMetric {
  icon: string;
  value: string;
  label: string;
  qualifier?: string | null;
}

export function snapshotTemperature(w: WeatherSnapshot): string {
  return w.temperatureC === null || w.temperatureC === undefined ? "—" : `${Math.round(w.temperatureC)}°`;
}

export function snapshotRange(w: WeatherSnapshot): string {
  const h = w.highC === null || w.highC === undefined ? "—" : `${Math.round(w.highC)}°`;
  const l = w.lowC === null || w.lowC === undefined ? "—" : `${Math.round(w.lowC)}°`;
  return `H: ${h}  L: ${l}`;
}

export function snapshotMetrics(w: WeatherSnapshot): WeatherMetric[] {
  return [
    {
      icon: "water-drop",
      value: w.rainProbability === null || w.rainProbability === undefined ? "—" : `${Math.round(w.rainProbability)}%`,
      label: "Rain",
    },
    {
      icon: "air",
      value: w.windKmh === null || w.windKmh === undefined ? "—" : `${Math.round(w.windKmh)} km/h`,
      label: "Wind",
    },
    {
      icon: "opacity",
      value: w.humidity === null || w.humidity === undefined ? "—" : `${Math.round(w.humidity)}%`,
      label: "Humidity",
    },
    {
      icon: "compress",
      value: w.pressureHpa === null || w.pressureHpa === undefined ? "—" : `${Math.round(w.pressureHpa)} hPa`,
      label: "Pressure",
    },
  ];
}

export { noProvenance };
