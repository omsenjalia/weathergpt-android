/// Per-field attribution, temperature spread and precipitation interval
/// models — port of the corresponding classes in `lib/models/weather.dart`.

import { jsonBool, jsonDate, jsonDouble, jsonInt, jsonList, jsonMap, jsonString } from "./jsonValues";

export interface FieldSources {
  /// field name → provider id (`weathernext`, `open_meteo`, …) or `null`
  /// when the backend explicitly reported nobody could supply it.
  sources: Record<string, string | null>;
  supplementProvider?: string | null;
  supplementAttempted: boolean;
  supplementEnabled: boolean;
  supplementFilled: string[];
  supplementErrors: string[];
  supplementCacheHit: boolean;
}

export function noFieldSources(): FieldSources {
  return {
    sources: {},
    supplementProvider: null,
    supplementAttempted: false,
    supplementEnabled: true,
    supplementFilled: [],
    supplementErrors: [],
    supplementCacheHit: false,
  };
}

export function fieldSourcesProviderFor(fs: FieldSources, field: string): string | null {
  return fs.sources[field] ?? null;
}

export function fieldSourcesIsSupplemented(fs: FieldSources, field: string, primary: string | null): boolean {
  const p = fs.sources[field];
  if (p === null || p === undefined || primary === null) return false;
  return normalize(p) !== normalize(primary);
}

function normalize(value: string): string {
  return value.trim().toLowerCase().replaceAll("-", "_");
}

export function fieldSourcesContributors(fs: FieldSources): string[] {
  return Array.from(new Set(Object.values(fs.sources).filter((v): v is string => v !== null)));
}

export function fieldSourcesFromJson(raw: unknown): FieldSources {
  const data = jsonMap(raw);
  if (data === null || Object.keys(data).length === 0) return noFieldSources();
  const sources: Record<string, string | null> = {};
  let meta: Record<string, unknown> | null = null;
  for (const [key, value] of Object.entries(data)) {
    if (key === "_supplement") {
      meta = jsonMap(value);
      continue;
    }
    sources[key] = jsonString(value);
  }
  const errors: string[] = [];
  for (const e of jsonList(meta?.["errors"])) {
    const m = jsonMap(e);
    if (m === null) continue;
    const call = jsonString(m["call"]);
    const reason = jsonString(m["reason"]) ?? "unknown";
    errors.push(call === null ? reason : `${call}: ${reason}`);
  }
  return {
    sources,
    supplementProvider: jsonString(meta?.["provider"]),
    supplementAttempted: jsonBool(meta?.["attempted"]) ?? false,
    supplementEnabled: jsonBool(meta?.["enabled"]) ?? true,
    supplementFilled: jsonList(meta?.["filled"])
      .map((f) => jsonString(f))
      .filter((s): s is string => s !== null),
    supplementErrors: errors,
    supplementCacheHit: jsonBool(meta?.["cache_hit"]) ?? false,
  };
}

export interface TemperatureSpread {
  p10C: number;
  p90C: number;
  source?: string | null;
  runId?: string | null;
  validFromUtc?: Date | null;
  validToUtc?: Date | null;
  memberCount?: number | null;
}

export function temperatureSpreadSpan(spread: TemperatureSpread): number {
  return spread.p90C - spread.p10C;
}

export function temperatureSpreadCoverageMs(spread: TemperatureSpread): number | null {
  if (spread.validFromUtc === null || spread.validFromUtc === undefined) return null;
  if (spread.validToUtc === null || spread.validToUtc === undefined) return null;
  return spread.validToUtc.getTime() - spread.validFromUtc.getTime();
}

export function temperatureSpreadHasCoverage(spread: TemperatureSpread): boolean {
  return temperatureSpreadCoverageMs(spread) !== null;
}

/// Tolerant parser. Returns `null` unless *both* percentiles are present and
/// ordered — a one-sided spread is not a spread.
export function temperatureSpreadFromJson(raw: unknown): TemperatureSpread | null {
  const data = jsonMap(raw);
  if (data === null) return null;
  const low = jsonDouble(data["p10_c"] ?? data["p10"] ?? data["temp_p10_c"] ?? data["temperature_p10_c"]);
  const high = jsonDouble(data["p90_c"] ?? data["p90"] ?? data["temp_p90_c"] ?? data["temperature_p90_c"]);
  if (low === null || high === null || high < low) return null;
  return {
    p10C: low,
    p90C: high,
    source: jsonString(data["source"] ?? data["provider"]),
    runId: jsonString(data["run_id"] ?? data["run"]),
    validFromUtc: jsonDate(data["valid_from"] ?? data["start"]),
    validToUtc: jsonDate(data["valid_to"] ?? data["end"]),
    memberCount: jsonInt(data["members"] ?? data["member_count"]),
  };
}

export interface PrecipitationInterval {
  totalMm: number;
  startUtc?: Date | null;
  endUtc?: Date | null;
  coversFullPeriod?: boolean | null;
  source?: string | null;
  runId?: string | null;
  label?: string | null;
}

export function precipIntervalIsComplete(p: PrecipitationInterval): boolean {
  return p.coversFullPeriod !== false;
}

export function precipitationIntervalFromJson(raw: unknown): PrecipitationInterval | null {
  const data = jsonMap(raw);
  if (data === null) return null;
  const total = jsonDouble(data["total_mm"] ?? data["precipitation_mm"] ?? data["precip_mm"] ?? data["rain_mm"]);
  if (total === null || total < 0) return null;
  return {
    totalMm: total,
    startUtc: jsonDate(data["start"] ?? data["valid_from"]),
    endUtc: jsonDate(data["end"] ?? data["valid_to"]),
    coversFullPeriod: jsonBool(data["complete"] ?? data["covers_full_period"]),
    source: jsonString(data["source"] ?? data["provider"]),
    runId: jsonString(data["run_id"] ?? data["run"]),
    label: jsonString(data["label"] ?? data["interval"]),
  };
}
