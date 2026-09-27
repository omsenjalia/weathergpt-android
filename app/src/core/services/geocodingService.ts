/// Geocodes free-text place names via Open-Meteo (no API key) — port of
/// `lib/core/services/geocoding_service.dart`.

import { AppLocation } from "../../models/location";

async function getJson(url: string, query: Record<string, string | number>, timeoutMs: number): Promise<unknown> {
  const full = new URL(url);
  for (const [key, value] of Object.entries(query)) full.searchParams.set(key, String(value));
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const response = await fetch(full.toString(), { signal: controller.signal });
    if (!response.ok) return null;
    return await response.json();
  } catch {
    return null;
  } finally {
    clearTimeout(timeout);
  }
}

export const GeocodingService = {
  /// Returns the best-matching place for `query`, or null when the query is
  /// too short, has no match, or the request fails.
  async search(query: string): Promise<AppLocation | null> {
    const matches = await this.searchMany(query, 1);
    return matches.length === 0 ? null : matches[0];
  },

  /// Returns up to `count` matching places for `query` (empty when the query
  /// is too short, has no match, or the request fails). Backs the location
  /// search suggestions.
  async searchMany(query: string, count = 5): Promise<AppLocation[]> {
    const q = query.trim();
    if (q.length < 2) return [];
    const data = await getJson(
      "https://geocoding-api.open-meteo.com/v1/search",
      { name: q, count: Math.min(Math.max(count, 1), 10), language: "en" },
      10_000,
    );
    const results = data !== null && typeof data === "object" ? (data as Record<string, unknown>)["results"] : null;
    return parseGeocodeResults(results, q);
  },

  /// Best-effort human name for coordinates via BigDataCloud's keyless client
  /// endpoint. Falls back to `fallback` (never throws) so GPS flows always
  /// succeed even when the reverse-geocode service is unreachable.
  async reverseName(lat: number, lon: number, fallback = "Current location"): Promise<string> {
    const data = await getJson(
      "https://api.bigdatacloud.net/data/reverse-geocode-client",
      { latitude: lat, longitude: lon, localityLanguage: "en" },
      8_000,
    );
    if (data === null || typeof data !== "object") return fallback;
    const record = data as Record<string, unknown>;
    const city = (record["city"] ?? record["locality"]) as string | undefined;
    const region = record["principalSubdivision"] as string | undefined;
    const label = [city, region && region !== city ? region : null].filter((part): part is string => !!part && part.trim() !== "").join(", ");
    return label === "" ? fallback : label;
  },
};

/// Pure parser for the geocoding `results` array, shared by `searchMany` and
/// unit tests. Malformed entries are skipped, never throw.
export function parseGeocodeResults(results: unknown, query: string): AppLocation[] {
  if (!Array.isArray(results)) return [];
  const places: AppLocation[] = [];
  for (const entry of results) {
    if (entry === null || typeof entry !== "object") continue;
    const row = entry as Record<string, unknown>;
    const lat = row["latitude"];
    const lon = row["longitude"];
    if (typeof lat !== "number" || typeof lon !== "number") continue;
    const name = typeof row["name"] === "string" ? row["name"] : query;
    const admin = typeof row["admin1"] === "string" ? row["admin1"] : undefined;
    const country = typeof row["country"] === "string" ? row["country"] : undefined;
    const label = [name, admin && admin !== "" ? admin : null, country && country !== "" && country !== admin ? country : null]
      .filter((part): part is string => !!part)
      .join(", ");
    places.push(new AppLocation(label, lat, lon));
  }
  return places;
}
