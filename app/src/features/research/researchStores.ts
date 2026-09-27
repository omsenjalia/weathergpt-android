/// Researcher data — ports of
/// `lib/features/researcher/providers/` (historical data, comparison,
/// anomaly statistics, chart points).

import { ApiEndpoints } from "../../core/config/apiEndpoints";
import { jsonDouble, jsonList, jsonMap, jsonString } from "../../core/models/jsonValues";
import { ApiClient } from "../../core/services/apiClient";
import { AppLocation, SavedLocation } from "../../models/location";

export interface ChartPoint {
  x: number;
  value: number;
  label?: string | null;
}

// ---------------------------------------------------------------------------
// Historical data

export enum HistoricalMetric {
  Rainfall = "rainfall",
  Temperature = "temperature",
  Humidity = "humidity",
}

/// Metric name as the archive API expects it.
export function metricParam(metric: HistoricalMetric): string {
  return metric;
}

export function metricLabel(metric: HistoricalMetric): string {
  switch (metric) {
    case HistoricalMetric.Rainfall:
      return "Rainfall";
    case HistoricalMetric.Temperature:
      return "Temperature";
    case HistoricalMetric.Humidity:
      return "Humidity";
  }
}

export function metricUnit(metric: HistoricalMetric): string {
  switch (metric) {
    case HistoricalMetric.Rainfall:
      return "mm";
    case HistoricalMetric.Temperature:
      return "°C";
    case HistoricalMetric.Humidity:
      return "%";
  }
}

export interface HistoricalDataSelection {
  metric: HistoricalMetric;
  /// When true, month-of-year climatology is requested; when false, a yearly
  /// archive series.
  monthly: boolean;
}

/// Why a series could not be shown. Distinct reasons matter: "the archive has
/// nothing for this place" and "this API does not serve that view" are
/// different facts and must not be rendered identically.
export enum ArchiveStatus {
  Available = "available",
  Empty = "empty",
  Unsupported = "unsupported",
}

export interface HistoricalSeries {
  metric: HistoricalMetric;
  points: ChartPoint[];
  status: ArchiveStatus;
  detail: string | null;
  source: string | null;
}

export function historicalIsAvailable(series: HistoricalSeries): boolean {
  return series.status === ArchiveStatus.Available && series.points.length > 0;
}

export function historicalFirstYear(series: HistoricalSeries): number | null {
  return series.points.length === 0 ? null : Math.trunc(series.points[0]!.x);
}

export function historicalLastYear(series: HistoricalSeries): number | null {
  return series.points.length === 0 ? null : Math.trunc(series.points[series.points.length - 1]!.x);
}

/// Actual coverage of the returned data, e.g. "2001 – 2024". The UI shows
/// this instead of a hardcoded range so the label cannot overstate coverage.
export function historicalRangeLabel(series: HistoricalSeries): string | null {
  const first = historicalFirstYear(series);
  const last = historicalLastYear(series);
  return first === null ? null : `${first} – ${last}`;
}

export function historicalSeriesFromJson(metric: HistoricalMetric, data: Record<string, unknown>): HistoricalSeries {
  const points: ChartPoint[] = [];
  for (const item of jsonList(data["points"])) {
    const row = jsonMap(item);
    if (row === null) continue;
    const x = jsonDouble(row["year"] ?? row["x"]);
    const value = jsonDouble(row["value"] ?? row["y"]);
    if (x === null || value === null) continue;
    points.push({ x, value, label: jsonString(row["label"]) });
  }
  return {
    metric,
    points,
    status: points.length === 0 ? ArchiveStatus.Empty : ArchiveStatus.Available,
    detail: null,
    source: jsonString(data["source"] ?? data["provider"]),
  };
}

/// Fetches the archive series for a selection from `/historical`.
///
/// The previous version of this screen charted bundled constant series, which
/// presented invented numbers as an observed climate record. Data now comes
/// from the archive API, and a view the API does not serve says so.
export async function fetchHistoricalSeries(
  selection: HistoricalDataSelection,
  location: AppLocation,
): Promise<HistoricalSeries> {
  if (selection.monthly) {
    // `/historical` serves yearly points only. Month-of-year climatology is a
    // different product; inventing it from a bundled table is not an option.
    return {
      metric: selection.metric,
      points: [],
      status: ArchiveStatus.Unsupported,
      detail: "Month-of-year climatology is not served by the archive API.",
      source: null,
    };
  }
  const data = await ApiClient.get(ApiEndpoints.historical, {
    lat: location.lat,
    lon: location.lon,
    metric: metricParam(selection.metric),
  });
  return historicalSeriesFromJson(selection.metric, data);
}

export function longTermAverage(points: ChartPoint[]): number {
  if (points.length === 0) return 0;
  return points.reduce((sum, p) => sum + p.value, 0) / points.length;
}

/// Percent deviation of the latest point from the mean of the *returned*
/// points. This is a display statistic over whatever window the archive gave
/// back — it is not a climate-normal calculation, and the UI labels it as a
/// deviation rather than an anomaly against a 30-year baseline.
export function anomalyPercent(points: ChartPoint[]): number {
  const avg = longTermAverage(points);
  if (avg === 0 || points.length === 0) return 0;
  return ((points[points.length - 1]!.value - avg) / avg) * 100;
}

// ---------------------------------------------------------------------------
// Comparison

/// Series colours assigned by position so the palette stays stable across
/// fetches. Purely presentational.
export const COMPARISON_PALETTE: readonly string[] = [
  "#3B82F6",
  "#F59E0B",
  "#22C55E",
  "#A78BFA",
  "#F472B6",
];

export interface ComparedLocation {
  name: string;
  colorValue: string;
  points: ChartPoint[];
}

/// Value recorded for `year`, or `null` when this location has no record for
/// it. A gap is a gap — it is never drawn as zero.
export function comparedValueFor(location: ComparedLocation, year: number): number | null {
  const point = location.points.find((p) => p.x === year);
  return point === undefined ? null : point.value;
}

/// Sum of the records actually returned.
export function comparedTotal(location: ComparedLocation): number | null {
  return location.points.length === 0
    ? null
    : location.points.reduce((sum, p) => sum + p.value, 0);
}

export interface ComparisonResult {
  locations: ComparedLocation[];
  metric: string;
  /// Reason nothing is shown, e.g. fewer than two saved locations.
  detail: string | null;
}

export function comparisonIsEmpty(result: ComparisonResult): boolean {
  return result.locations.length === 0;
}

/// Sorted union of the years present in the response, so the axis and table
/// describe the data instead of a hardcoded 2021–2025 range.
export function comparisonYears(result: ComparisonResult): number[] {
  const values = new Set<number>();
  for (const location of result.locations) {
    for (const point of location.points) values.add(point.x);
  }
  return Array.from(values).sort((a, b) => a - b);
}

/// Last two years present, used by the summary table.
export function comparisonLastTwoYears(result: ComparisonResult): number[] {
  const all = comparisonYears(result);
  return all.length <= 2 ? all : all.slice(all.length - 2);
}

export function comparisonMaxValue(result: ComparisonResult): number {
  let max = 0;
  for (const location of result.locations) {
    for (const point of location.points) {
      if (point.value > max) max = point.value;
    }
  }
  return max;
}

export function comparisonResultFromJson(data: Record<string, unknown>): ComparisonResult {
  const locations: ComparedLocation[] = [];
  for (const item of jsonList(data["locations"])) {
    const row = jsonMap(item);
    if (row === null) continue;
    const name = jsonString(row["name"]);
    if (name === null) continue;
    const points: ChartPoint[] = [];
    for (const pointItem of jsonList(row["points"])) {
      const pointRow = jsonMap(pointItem);
      if (pointRow === null) continue;
      const x = jsonDouble(pointRow["year"] ?? pointRow["x"]);
      const value = jsonDouble(pointRow["value"] ?? pointRow["y"]);
      if (x === null || value === null) continue;
      points.push({ x, value });
    }
    if (points.length === 0) continue;
    locations.push({
      name,
      colorValue: COMPARISON_PALETTE[locations.length % COMPARISON_PALETTE.length]!,
      points,
    });
  }
  return {
    locations,
    metric: jsonString(data["metric"]) ?? "rainfall",
    detail:
      locations.length === 0
        ? "The comparison endpoint returned no series for these locations."
        : null,
  };
}

/// Comparison across the user's saved locations, fetched from `/comparison`.
///
/// The previous version charted a bundled table of five invented years for
/// three fixed cities. Locations now come from what the user actually saved,
/// and values come from the archive.
export async function fetchComparison(saved: SavedLocation[]): Promise<ComparisonResult> {
  if (saved.length < 2) {
    return { locations: [], metric: "rainfall", detail: "Save at least two locations to compare them." };
  }
  const bounded = saved.slice(0, COMPARISON_PALETTE.length);
  const locationsParam = bounded.map((l) => `${l.name},${l.lat},${l.lon}`).join(";");
  const data = await ApiClient.get(ApiEndpoints.comparison, {
    locations: locationsParam,
    metric: "rainfall",
  });
  return comparisonResultFromJson(data);
}

// ---------------------------------------------------------------------------
// Async result containers

export type AsyncSeries = { kind: "loading" } | { kind: "data"; series: HistoricalSeries } | { kind: "error"; message: string };

export type AsyncComparison =
  | { kind: "loading" }
  | { kind: "data"; result: ComparisonResult }
  | { kind: "error"; message: string };
