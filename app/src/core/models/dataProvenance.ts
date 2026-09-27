/// Where a rendered weather value came from, and how fresh it is — port of
/// `lib/core/models/data_provenance.dart`. The app never *chooses* a provider
/// (the backend owns IMD → WeatherNext → AccuWeather → Open-Meteo selection);
/// this model only records what the backend reported so the UI can attribute a
/// source and say "source not reported" instead of guessing.

import { jsonBool, jsonInt, jsonList, jsonMap, jsonNum, jsonString, jsonDate } from "./jsonValues";

/// Known provider identifiers. Anything else is kept verbatim.
export type WeatherProvider = "imd" | "weathernext" | "accuweather" | "openMeteo" | "unknown";

export function providerFromName(value: string | null | undefined): WeatherProvider {
  switch (value?.trim().toLowerCase()) {
    case "imd":
      return "imd";
    case "weathernext":
    case "google":
    case "google_weathernext":
      return "weathernext";
    case "accuweather":
      return "accuweather";
    case "open-meteo":
    case "openmeteo":
    case "open_meteo":
      return "openMeteo";
    default:
      return "unknown";
  }
}

/// Reasons that mean "this provider was never set up", not "it failed".
export const NOT_CONFIGURED_REASONS = new Set([
  "missing_credentials",
  "credentials_missing_credentials",
  "credentials_invalid_config",
  "weathernext_disabled",
  "not_configured",
  "unknown_provider",
  "disabled",
]);

export interface FallbackReason {
  provider: string;
  reason: string;
  table?: string | null;
  surface?: string | null;
  message?: string | null;
  product?: string | null;
  raw: Record<string, unknown>;
}

export function fallbackReasonFromJson(json: Record<string, unknown>): FallbackReason {
  return {
    provider: jsonString(json["provider"]) ?? "unknown",
    reason: jsonString(json["reason"]) ?? "unknown",
    table: jsonString(json["table"]),
    surface: jsonString(json["surface"]),
    message: jsonString(json["message"]),
    product: jsonString(json["product"]),
    raw: json,
  };
}

export function isWeatherNextReason(reason: FallbackReason): boolean {
  return reason.provider.toLowerCase().includes("weathernext");
}

/// True when the provider was simply not configured (no key / disabled).
export function isNotConfiguredReason(reason: FallbackReason): boolean {
  return NOT_CONFIGURED_REASONS.has(reason.reason) || reason.reason.startsWith("credentials_");
}

/// True when a configured provider actually failed or returned stale data.
export function isRealFailureReason(reason: FallbackReason): boolean {
  return !isNotConfiguredReason(reason);
}

/// Short, user-readable form.
export function humanReason(reason: string): string {
  switch (reason) {
    case "missing_credentials":
    case "credentials_missing_credentials":
      return "not configured";
    case "circuit_breaker_open":
      return "temporarily disabled after repeated failures";
    case "stale_data":
      return "latest run is stale";
    case "permission_denied":
      return "access denied";
    case "query_timeout":
      return "query timed out";
    case "no_recent_run":
      return "no recent run available";
    case "surface_fallback":
      return "served from a secondary surface";
    default:
      return reason.replaceAll("_", " ");
  }
}

export interface WeatherProvenance {
  source?: string | null;
  selectedSource?: string | null;
  requestedSource?: string | null;
  product?: string | null;
  runId?: string | null;
  model?: string | null;
  issuedAtUtc?: Date | null;
  retrievedAtUtc?: Date | null;
  timezoneId?: string | null;
  schemaVersion?: string | null;
  fallback: boolean;
  missingFields: string[];
  horizonHours?: number | null;
  fallbackReasons: FallbackReason[];
  triedProviders: string[];
  selectionPolicyVersion?: string | null;
  modelVersion?: string | null;
  freshnessStatus?: string | null;
  isStale?: boolean | null;
  latencyMs?: number | null;
  resolutionDeg?: number | null;
  sampledLat?: number | null;
  sampledLon?: number | null;
  distanceKm?: number | null;
  spatialMethod?: string | null;
  surface?: string | null;
  table?: string | null;
  isEnsemble?: boolean | null;
  expectedMemberCount?: number | null;
  coverageCompleteness?: number | null;
  validityStartUtc?: Date | null;
  validityEndUtc?: Date | null;
  queryDiagnostics: Record<string, unknown>;
  methods: Record<string, unknown>;
  sources: string[];
}

export function noProvenance(): WeatherProvenance {
  return {
    fallback: false,
    missingFields: [],
    fallbackReasons: [],
    triedProviders: [],
    queryDiagnostics: {},
    methods: {},
    sources: [],
  };
}

export function realFailures(prov: WeatherProvenance): FallbackReason[] {
  return prov.fallbackReasons.filter(isRealFailureReason);
}

export function skippedUnconfigured(prov: WeatherProvenance): FallbackReason[] {
  return prov.fallbackReasons.filter(isNotConfiguredReason);
}

export function servedFromCache(prov: WeatherProvenance): boolean {
  return prov.queryDiagnostics["served_from_cache"] === true;
}

export function provenanceProvider(prov: WeatherProvenance): WeatherProvider {
  return providerFromName(prov.selectedSource ?? prov.source);
}

export function provenanceHasSource(prov: WeatherProvenance): boolean {
  return !!(prov.selectedSource ?? prov.source);
}

export function isWeatherNext(prov: WeatherProvenance): boolean {
  return provenanceProvider(prov) === "weathernext";
}

/// True when WeatherNext was configured, tried, and actually failed.
export function weatherNextFailed(prov: WeatherProvenance): boolean {
  return (
    !isWeatherNext(prov) && prov.fallbackReasons.some((r) => isWeatherNextReason(r) && isRealFailureReason(r))
  );
}

export function provenanceIsMissing(prov: WeatherProvenance, field: string): boolean {
  return prov.missingFields.includes(field);
}

export function effectiveAtUtc(prov: WeatherProvenance): Date | null {
  return prov.issuedAtUtc ?? prov.retrievedAtUtc ?? null;
}

const STALE_MAX_AGE_MS = 6 * 60 * 60 * 1000;

/// Whether the payload is older than 6 hours as of `nowUtc`. Returns `false`
/// when no timestamp was reported: an unknown age is not the same as a
/// known-stale payload, and the UI labels those differently.
export function isStaleAt(prov: WeatherProvenance, nowUtc: Date): boolean {
  const stamp = effectiveAtUtc(prov);
  if (stamp === null) return false;
  return nowUtc.getTime() - stamp.getTime() > STALE_MAX_AGE_MS;
}

export function provenanceAgeUnknown(prov: WeatherProvenance): boolean {
  return effectiveAtUtc(prov) === null;
}

function firstString(
  prov: Record<string, unknown>,
  data: Record<string, unknown>,
  meta: Record<string, unknown>,
  keys: string[],
): string | null {
  for (const key of keys) {
    const fromProv = jsonString(prov[key]);
    if (fromProv !== null) return fromProv;
    const direct = jsonString(data[key]);
    if (direct !== null) return direct;
    const nested = jsonString(meta[key]);
    if (nested !== null) return nested;
  }
  return null;
}

function firstBool(
  prov: Record<string, unknown>,
  data: Record<string, unknown>,
  meta: Record<string, unknown>,
  keys: string[],
): boolean | null {
  for (const key of keys) {
    const fromProv = jsonBool(prov[key]);
    if (fromProv !== null) return fromProv;
    const direct = jsonBool(data[key]);
    if (direct !== null) return direct;
    const nested = jsonBool(meta[key]);
    if (nested !== null) return nested;
  }
  return null;
}

function firstValue(
  prov: Record<string, unknown>,
  data: Record<string, unknown>,
  meta: Record<string, unknown>,
  keys: string[],
): unknown {
  for (const key of keys) {
    if (prov[key] !== null && prov[key] !== undefined) return prov[key];
    if (data[key] !== null && data[key] !== undefined) return data[key];
    if (meta[key] !== null && meta[key] !== undefined) return meta[key];
  }
  return null;
}

/// Builds provenance from a decoded `/weather`-style payload, tolerating both
/// today's responses (which may report nothing) and the additive metadata
/// described in the backend contract. Supports legacy `/weather` and v2.
export function weatherProvenanceFromJson(data: Record<string, unknown>): WeatherProvenance {
  const meta = jsonMap(data["meta"]) ?? {};
  const prov = jsonMap(data["provenance"]) ?? {};

  const source = firstString(prov, data, meta, ["source", "provider", "data_source", "primary_source"]);
  const selected = firstString(prov, data, meta, ["selected_source"]);
  const requested = firstString(prov, data, meta, ["requested_source"]);
  const fallbackFlag = firstBool(prov, data, meta, ["fallback", "degraded", "is_fallback"]) ?? false;

  const missingRaw = jsonList(firstValue(prov, data, meta, ["missing_fields", "missing", "unavailable"]));
  const nullReasons = jsonMap(firstValue(prov, data, meta, ["null_reasons", "unavailable_reasons"]));

  const missing = Array.from(
    new Set([
      ...missingRaw.map((item) => jsonString(item)).filter((s): s is string => s !== null),
      ...(nullReasons !== null ? Object.keys(nullReasons) : []),
    ]),
  ).sort();

  const fallbackList = jsonList(firstValue(prov, data, meta, ["fallback_reasons"]));
  const fallbackReasons: FallbackReason[] = [];
  for (const item of fallbackList) {
    const map = jsonMap(item);
    if (map !== null) fallbackReasons.push(fallbackReasonFromJson(map));
  }
  if (fallbackReasons.length === 0) {
    for (const item of jsonList(data["fallback_reasons"])) {
      const map = jsonMap(item);
      if (map !== null) fallbackReasons.push(fallbackReasonFromJson(map));
    }
  }

  const stale = firstBool(prov, data, meta, ["is_stale"]);
  // Backend verdict wins; otherwise only *real* failures (not "no key
  // configured") or stale data count as a degradation.
  const degraded =
    firstBool(prov, data, meta, ["degraded"]) ??
    (fallbackFlag || stale === true || fallbackReasons.some(isRealFailureReason));

  const sampled = jsonMap(firstValue(prov, data, meta, ["sampled_coordinates"]));

  return {
    source,
    selectedSource: selected,
    requestedSource: requested,
    product: firstString(prov, data, meta, ["product", "dataset"]),
    runId: firstString(prov, data, meta, ["run_id", "run", "model_run"]),
    model: firstString(prov, data, meta, ["model", "model_version"]),
    issuedAtUtc: jsonDate(firstString(prov, data, meta, ["issued_at", "run_time", "analysis_time", "valid_time", "init_time_utc"])),
    retrievedAtUtc: jsonDate(firstString(prov, data, meta, ["retrieved_at", "fetched_at", "updated_at", "served_at_utc"])),
    timezoneId: firstString(prov, data, meta, ["timezone", "timezone_id"]),
    schemaVersion: firstString(prov, data, meta, ["schema_version", "contract_version"]),
    fallback: degraded,
    missingFields: missing,
    horizonHours: jsonInt(firstValue(prov, data, meta, ["horizon_hours", "horizon"])),
    fallbackReasons,
    triedProviders: jsonList(firstValue(prov, data, meta, ["tried_providers"]))
      .map((t) => jsonString(t))
      .filter((s): s is string => s !== null),
    selectionPolicyVersion: firstString(prov, data, meta, ["selection_policy_version"]),
    modelVersion: firstString(prov, data, meta, ["model_version"]),
    freshnessStatus: firstString(prov, data, meta, ["freshness_status"]),
    isStale: stale,
    latencyMs: jsonNum(firstValue(prov, data, meta, ["latency_ms"])),
    resolutionDeg: jsonNum(firstValue(prov, data, meta, ["resolution_deg"])),
    sampledLat: jsonNum(sampled?.["lat"]),
    sampledLon: jsonNum(sampled?.["lon"]),
    distanceKm: jsonNum(firstValue(prov, data, meta, ["distance_km"])),
    spatialMethod: firstString(prov, data, meta, ["spatial_method"]),
    surface: firstString(prov, data, meta, ["surface"]),
    table: firstString(prov, data, meta, ["table"]),
    isEnsemble: firstBool(prov, data, meta, ["is_ensemble"]),
    expectedMemberCount: jsonInt(firstValue(prov, data, meta, ["expected_member_count"])),
    coverageCompleteness: jsonNum(firstValue(prov, data, meta, ["coverage_completeness"])),
    validityStartUtc: jsonDate(firstString(prov, data, meta, ["validity_start_utc"])),
    validityEndUtc: jsonDate(firstString(prov, data, meta, ["validity_end_utc"])),
    queryDiagnostics: jsonMap(firstValue(prov, data, meta, ["query_diagnostics"])) ?? {},
    methods: jsonMap(firstValue(prov, data, meta, ["methods"])) ?? {},
    sources: jsonList(firstValue(prov, data, meta, ["sources", "providers_used"]))
      .map((t) => jsonString(t))
      .filter((s): s is string => s !== null),
  };
}
