/// Weather store — port of `lib/features/home/providers/weather_provider.dart`.
/// Fetches `/v2/weather` (provider provenance) with an honest legacy
/// `/weather` fallback, records exactly what was sent for the Debug screen,
/// and derives the app-wide atmosphere palette from the live snapshot.

import { create } from "zustand";

import { ApiEndpoints } from "../../core/config/apiEndpoints";
import { AppMode } from "../../core/models/appMode";
import { apiErrorMessage } from "../../core/errors/appErrors";
import { ApiClient } from "../../core/services/apiClient";
import { useRequestLogStore } from "../../core/services/requestLog";
import { WeatherSnapshot } from "./models/weather";
import { parseWeatherSnapshot } from "./models/weatherParser";
import { parseWeatherSnapshotV2 } from "./models/weatherV2Parser";
import {
  AtmospherePalette,
  conditionFromWeather,
  paletteFor,
  parseWeatherTime,
  periodFromLocalTime,
  SkyCondition,
  SkyPeriod,
} from "./theme/atmosphereTheme";
import { DEFAULT_DEVELOPER_OPTIONS, DevSourcePin, DEV_SOURCE_PIN_WIRE, DeveloperOptions } from "../settings/developerOptionsStore";
import { AppLocation, DEFAULT_LOCATION } from "../location/locationStore";

export const DEFAULT_HOURLY_HOURS = 48;
export const DEFAULT_FORECAST_DAYS = 7;

/// Exactly what the app sent for the current snapshot, so the Debug screen
/// can show the request next to the response.
export interface WeatherRequestInfo {
  endpoint: string;
  query: Record<string, unknown>;
  usedLegacyFallback: boolean;
  v2Error?: string | null;
}

export interface WeatherStatus {
  snapshot: WeatherSnapshot | null;
  loading: boolean;
  error: string | null;
  lastRequest: WeatherRequestInfo | null;
}

/// The query the app will send, derived from mode + developer options.
export function buildWeatherQuery(opts: {
  lat: number;
  lon: number;
  mode: AppMode;
  dev: DeveloperOptions;
}): Record<string, unknown> {
  const { lat, lon, mode, dev } = opts;
  const customise = dev.enabled;
  const pin = customise ? dev.sourcePin : DevSourcePin.Auto;
  // Every persona uses the backend policy unless a developer pins a source.
  const requested = DEV_SOURCE_PIN_WIRE[pin];
  return {
    lat,
    lon,
    mode,
    requested_source: requested,
    forecast_days: customise ? dev.forecastDays : DEFAULT_FORECAST_DAYS,
    hourly_hours: customise ? dev.hourlyHours : DEFAULT_HOURLY_HOURS,
    ...(customise && !dev.supplementSecondaryFields ? { supplement: false } : {}),
  };
}

/// Honest "nothing could serve this request" message, including each
/// provider's reason so a pinned-source failure is explainable.
function unavailableMessage(data: Record<string, unknown>): string {
  const base = String(data["error"] ?? "No forecast provider available");
  const reasons = Array.isArray(data["fallback_reasons"]) ? data["fallback_reasons"] : [];
  const detail = reasons
    .map((r) => {
      if (r === null || typeof r !== "object") return String(r);
      const o = r as Record<string, unknown>;
      return `${String(o["provider"] ?? "?")}: ${String(o["detail"] ?? o["reason"] ?? o["reason_code"] ?? "")}`;
    })
    .join("; ");
  return detail === "" ? base : `${base} (${detail})`;
}

interface WeatherStore extends WeatherStatus {
  generation: number;
  /// Request identity of the snapshot on screen. A refresh with the same key
  /// keeps the current snapshot visible; a new location/mode/pin clears it so
  /// one place's weather is never shown under another place's name.
  snapshotKey: string;
  /// When the app received the snapshot on screen (device clock).
  updatedAt: Date | null;
  locationRef: AppLocation;
  modeRef: AppMode;
  devRef: DeveloperOptions;
  setContext: (location: AppLocation, mode: AppMode, dev: DeveloperOptions) => void;
  fetchWeather: (location: AppLocation, mode: AppMode, dev: DeveloperOptions) => Promise<void>;
  clear: () => void;
}

export const useWeatherStore = create<WeatherStore>((set, get) => ({
  snapshot: null,
  loading: false,
  error: null,
  lastRequest: null,
  generation: 0,
  snapshotKey: "",
  updatedAt: null,
  locationRef: DEFAULT_LOCATION,
  modeRef: "everyone",
  devRef: DEFAULT_DEVELOPER_OPTIONS,

  setContext: (location, mode, dev) => set({ locationRef: location, modeRef: mode, devRef: dev }),

  fetchWeather: async (location, mode, dev) => {
    const generation = get().generation + 1;
    const query = buildWeatherQuery({ lat: location.lat, lon: location.lon, mode, dev });
    const requestKey = JSON.stringify(query);
    const isRefresh = get().snapshot !== null && get().snapshotKey === requestKey;
    set({
      generation,
      loading: true,
      error: null,
      ...(isRefresh ? {} : { snapshot: null, snapshotKey: "", lastRequest: null }),
    });
    // Keep the ring buffer alive from app start so the Debug screen shows the
    // requests that happened before it was first opened.
    useRequestLogStore.getState().setEnabled(!dev.enabled || dev.logRequests);
    const cityName = location.name.split(",")[0]!.trim();

    let v2Error: string | null = null;
    try {
      const data = await ApiClient.get(ApiEndpoints.v2Weather, query);
      if (data["status"] === "unavailable") {
        if (get().generation === generation) set({
          loading: false,
          error: unavailableMessage(data),
          lastRequest: { endpoint: ApiEndpoints.v2Weather, query, usedLegacyFallback: false },
        });
        return;
      }
      if (get().generation !== generation) return;
      set({
        loading: false,
        snapshot: parseWeatherSnapshotV2(data, { cityName }),
        snapshotKey: requestKey,
        updatedAt: new Date(),
        lastRequest: { endpoint: ApiEndpoints.v2Weather, query, usedLegacyFallback: false },
      });
      return;
    } catch (error) {
      if (get().generation !== generation) return;
      v2Error = apiErrorMessage(error);
      if (dev.enabled && dev.disableV2Fallback) {
        if (get().generation === generation) {
          set({ loading: false, error: v2Error, lastRequest: { endpoint: ApiEndpoints.v2Weather, query, usedLegacyFallback: false, v2Error } });
        }
        return;
      }
      if (query["requested_source"] !== "auto") {
        // An explicit provider constraint must survive ALL failure shapes, not
        // just errors whose English message happens to mention a provider.
        set({ loading: false, error: v2Error, lastRequest: { endpoint: ApiEndpoints.v2Weather, query, usedLegacyFallback: false, v2Error } });
        return;
      }
    }

    const legacyQuery: Record<string, unknown> = {
      lat: location.lat,
      lon: location.lon,
      mode,
      requested_source: query["requested_source"],
      forecast_days: query["forecast_days"],
      hourly_hours: query["hourly_hours"],
      ...("supplement" in query ? { supplement: query["supplement"] } : {}),
    };
    try {
      const data = await ApiClient.get(ApiEndpoints.weather, legacyQuery);
      if (get().generation !== generation) return;
      set({
        loading: false,
        snapshot: parseWeatherSnapshot(data, { cityName }),
        snapshotKey: requestKey,
        updatedAt: new Date(),
        lastRequest: { endpoint: ApiEndpoints.weather, query: legacyQuery, usedLegacyFallback: true, v2Error },
      });
    } catch (error) {
      if (get().generation !== generation) return;
      set({
        loading: false,
        error: apiErrorMessage(error),
        lastRequest: { endpoint: ApiEndpoints.weather, query: legacyQuery, usedLegacyFallback: true, v2Error },
      });
    }
  },

  clear: () => set((s) => ({ generation: s.generation + 1, snapshot: null, snapshotKey: "", updatedAt: null, error: null, lastRequest: null, loading: false })),
}));

export interface SkyScene {
  period: SkyPeriod;
  sky: SkyCondition;
  palette: AtmospherePalette;
}

/// Resolves the live sky — solar period at the location, weather condition
/// and the derived palette — from wall-clock time and the snapshot. Port of
/// `atmosphere_provider.dart`. Developer overrides win when set.
export function skyScene(
  now: Date,
  snapshot: WeatherSnapshot | null,
  dev?: { forcePeriod: SkyPeriod | null; forceSky: SkyCondition | null },
): SkyScene {
  const offset = snapshot?.utcOffsetSeconds;
  const localClock = (instant: Date): Date => {
    if (offset == null) return instant;
    const shifted = new Date(instant.getTime() + offset * 1000);
    return new Date(2000, 0, 1, shifted.getUTCHours(), shifted.getUTCMinutes());
  };
  const solarClock = (raw: string | null | undefined): Date | null => {
    const parsed = parseWeatherTime(raw);
    if (!parsed) return null;
    // Naive solar timestamps already represent location-local wall time.
    return raw && /(?:Z|[+-]d{2}:?d{2})$/i.test(raw) ? localClock(parsed) : parsed;
  };
  const sky = dev?.forceSky ?? (snapshot === null ? SkyCondition.Clear : conditionFromWeather(snapshot));
  const period = dev?.forcePeriod ?? periodFromLocalTime(localClock(now), solarClock(snapshot?.sunrise), solarClock(snapshot?.sunset));
  return { period, sky, palette: paletteFor(period, sky) };
}

/// App-wide sky palette (see `skyScene`).
export function atmospherePalette(
  now: Date,
  snapshot: WeatherSnapshot | null,
  dev?: { forcePeriod: SkyPeriod | null; forceSky: SkyCondition | null },
): AtmospherePalette {
  return skyScene(now, snapshot, dev).palette;
}
