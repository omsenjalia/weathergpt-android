/// Researcher "Models" tab data: one forecast variable as an hourly series
/// (`/v2/weather/series`) and the provider catalog (`/v2/weather/catalog`).

import { ApiEndpoints } from "../../core/config/apiEndpoints";
import { jsonBool, jsonDouble, jsonList, jsonMap, jsonString } from "../../core/models/jsonValues";
import { ApiClient } from "../../core/services/apiClient";
import { AppLocation } from "../../models/location";
import { ChartPoint } from "./researchStores";

export enum SeriesVariable {
  Temperature = "temperature_2m",
  Rainfall = "total_precipitation_1hr",
  Wind = "wind_speed_10m",
}

export interface ForecastSeries {
  /// "ok" when values came back; anything else carries `detail`.
  status: string;
  detail: string | null;
  units: string;
  source: string | null;
  /// Epoch ms of the first value; chart x is hours after it.
  startMs: number;
  mean: ChartPoint[];
}

export interface CatalogProvider {
  id: string;
  name: string;
  coverage: string;
  products: string[];
  hourly: boolean;
}

export function forecastSeriesFromJson(data: Record<string, unknown>): ForecastSeries {
  const rows = jsonList(data["values"])
    .map((item) => jsonMap(item))
    .filter((row): row is Record<string, unknown> => row !== null)
    .map((row) => ({ ms: Date.parse(jsonString(row["time_utc"]) ?? ""), row }))
    .filter(({ ms }) => !Number.isNaN(ms));
  const startMs = rows[0]?.ms ?? Date.now();
  const pick = (key: string): ChartPoint[] =>
    rows.flatMap(({ ms, row }) => {
      const value = jsonDouble(row[key]);
      return value === null ? [] : [{ x: (ms - startMs) / 3_600_000, value }];
    });
  const mean = pick("mean");
  const status = jsonString(data["status"]) ?? "unavailable";
  return {
    status,
    detail: status === "ok" ? null : (jsonString(data["error"]) ?? status.replace(/_/g, " ")),
    units: jsonString(data["units"]) ?? "",
    source: jsonString(data["source"]),
    startMs,
    // Deterministic sources only send `value`.
    mean: mean.length > 0 ? mean : pick("value"),
  };
}

/// Providers this app uses; the backend's catalog may list more.
const SHOWN_PROVIDERS = new Set(["imd", "open_meteo"]);

export function catalogFromJson(data: Record<string, unknown>): CatalogProvider[] {
  return jsonList(data["providers"]).flatMap((item) => {
    const row = jsonMap(item);
    const id = jsonString(row?.["id"]);
    if (row === null || id === null || !SHOWN_PROVIDERS.has(id)) return [];
    return [
      {
        id,
        name: jsonString(row["name"]) ?? id,
        coverage: jsonString(row["coverage"]) ?? "",
        products: jsonList(row["products"]).flatMap((p) => jsonString(p) ?? []),
        hourly: jsonBool(row["hourly"]) ?? false,
      },
    ];
  });
}

/// The backend's own source policy picks the provider and says which one.
export async function fetchForecastSeries(variable: SeriesVariable, location: AppLocation): Promise<ForecastSeries> {
  const data = await ApiClient.get(ApiEndpoints.v2WeatherSeries, {
    lat: location.lat,
    lon: location.lon,
    variable,
  });
  return forecastSeriesFromJson(data);
}

export async function fetchCatalog(): Promise<CatalogProvider[]> {
  return catalogFromJson(await ApiClient.get(ApiEndpoints.v2WeatherCatalog));
}

/// "C" → "°" for chart ticks; other units print as sent.
export function tickUnit(units: string): string {
  return units === "C" ? "°" : "";
}

export function displayUnit(units: string): string {
  return units === "C" ? "°C" : units;
}

export function sourceLabel(series: ForecastSeries): string {
  if (series.source === "open_meteo") return "Open-Meteo";
  if (series.source === "imd") return "IMD";
  return series.source ?? "—";
}
