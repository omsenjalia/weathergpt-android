import { afterEach, describe, expect, it, vi } from "vitest";

import {
  aqiBandKey,
  compassLabel,
  formatDegrees,
  formatLocalClock,
  formatPercent,
  iconForSky,
  iconForWeather,
  isNightAt,
  localMinutesOfDay,
  minutesFromHourLabel,
  nowMinutesAtLocation,
  scaleRatio,
  uvBandKey,
  weekdayShort,
} from "../src/features/weather/format";
import { SkyCondition } from "../src/features/weather/theme/atmosphereTheme";
import { parseMarkdown } from "../src/ui/content/markdown";
import { ApiClient } from "../src/core/services/apiClient";
import { useWeatherStore } from "../src/features/weather/weatherStore";
import { DEFAULT_DEVELOPER_OPTIONS } from "../src/features/settings/developerOptionsStore";
import { AppLocation, DEFAULT_LOCATION } from "../src/models/location";

afterEach(() => {
  vi.restoreAllMocks();
  useWeatherStore.getState().clear();
});

describe("weather formatting keeps null semantics", () => {
  it("renders missing values as an em dash, never zero", () => {
    expect(formatDegrees(null, "celsius")).toBe("—");
    expect(formatDegrees(undefined, "fahrenheit")).toBe("—");
    expect(formatPercent(null)).toBe("—");
    expect(compassLabel(null)).toBe("—");
    expect(formatLocalClock(null, 19800)).toBe("—");
  });

  it("formats degrees in the chosen unit", () => {
    expect(formatDegrees(30.6, "celsius")).toBe("31°");
    expect(formatDegrees(0, "celsius")).toBe("0°");
    expect(formatDegrees(100, "fahrenheit")).toBe("212°");
  });

  it("never draws an unknown sky as sunny", () => {
    expect(iconForSky(SkyCondition.Unknown)).not.toBe("weather-sunny");
    expect(iconForWeather({ weatherCode: null, condition: "" })).toBe("cloud-question-outline");
    expect(iconForWeather({ weatherCode: 0, condition: "" })).toBe("weather-sunny");
    expect(iconForWeather({ weatherCode: 0, condition: "" }, true)).toBe("weather-night");
  });

  it("maps UV and AQI onto translatable bands", () => {
    expect(uvBandKey(null)).toBeNull();
    expect(uvBandKey(2)).toBe("home.uv_low");
    expect(uvBandKey(7)).toBe("home.uv_high");
    expect(uvBandKey(12)).toBe("home.uv_extreme");
    expect(aqiBandKey(15)).toBe("home.aqi_good");
    expect(aqiBandKey(55)).toBe("home.aqi_moderate");
    expect(aqiBandKey(140)).toBe("home.aqi_extremely_poor");
  });

  it("clamps scale ratios and keeps missing values null", () => {
    expect(scaleRatio(null, 0, 11)).toBeNull();
    expect(scaleRatio(-3, 0, 10)).toBe(0);
    expect(scaleRatio(15, 0, 10)).toBe(1);
    expect(scaleRatio(5, 0, 10)).toBe(0.5);
  });
});

describe("location-local time", () => {
  it("reads naive timestamps as location wall time", () => {
    expect(localMinutesOfDay("2026-09-19T06:12", 19800)).toBe(6 * 60 + 12);
    expect(formatLocalClock("2026-09-19T18:45", null)).toBe("6:45 PM");
  });

  it("shifts zoned timestamps by the location offset", () => {
    // 00:42Z + 5:30 = 06:12 IST
    expect(localMinutesOfDay("2026-09-19T00:42:00Z", 19800)).toBe(6 * 60 + 12);
    expect(formatLocalClock("2026-09-19T00:42:00Z", 19800)).toBe("6:12 AM");
  });

  it("computes now at the location from the offset", () => {
    expect(nowMinutesAtLocation(19800, new Date("2026-09-19T00:00:00Z"))).toBe(5 * 60 + 30);
  });

  it("parses hourly labels and classifies night", () => {
    expect(minutesFromHourLabel("12AM")).toBe(0);
    expect(minutesFromHourLabel("12PM")).toBe(12 * 60);
    expect(minutesFromHourLabel("3PM")).toBe(15 * 60);
    expect(minutesFromHourLabel("Now")).toBeNull();
    expect(isNightAt(22 * 60, 6 * 60, 18 * 60 + 30)).toBe(true);
    expect(isNightAt(12 * 60, 6 * 60, 18 * 60 + 30)).toBe(false);
  });

  it("names weekdays from ISO dates without timezone drift", () => {
    expect(weekdayShort("2026-09-19", "en-US")).toBe("Sat");
    expect(weekdayShort("not-a-date", "en-US")).toBe("not-a-date");
  });
});

describe("markdown parser", () => {
  it("drops widget fences but keeps ordinary code blocks", () => {
    const blocks = parseMarkdown("Hello\n\n```widget:weather\n{}\n```\n\n```\nx = 1\n```");
    expect(blocks.map((b) => b.kind)).toEqual(["paragraph", "code"]);
  });

  it("drops JSON fences that carry a widget payload", () => {
    const md = 'Answer\n\n```json\n{\n  "widget_type": "weather_forecast",\n  "date": "2026-09-28"\n}\n```\n\n```json\n{"a": 1}\n```';
    expect(parseMarkdown(md).map((b) => b.kind)).toEqual(["paragraph", "code"]);
  });

  it("parses pipe tables, numbered lists and headings", () => {
    const blocks = parseMarkdown("## Forecast\n\n| Day | Rain |\n|---|---:|\n| Mon | 4 mm |\n| Tue | — |\n\n1. Irrigate\n2. Wait");
    expect(blocks[0]).toEqual({ kind: "heading", level: 2, text: "Forecast" });
    expect(blocks[1]).toEqual({ kind: "table", header: ["Day", "Rain"], rows: [["Mon", "4 mm"], ["Tue", "—"]] });
    expect(blocks[2]).toEqual({ kind: "numbers", items: ["Irrigate", "Wait"], start: 1 });
  });

  it("joins wrapped paragraph lines and ignores horizontal rules", () => {
    const blocks = parseMarkdown("line one\nline two\n\n---\n\n- a\n- b");
    expect(blocks).toEqual([
      { kind: "paragraph", lines: ["line one", "line two"] },
      { kind: "bullets", items: ["a", "b"] },
    ]);
  });
});

describe("weather refresh", () => {
  const payload = { current: { temperature_2m: 31, weather_code: 1 }, hourly: {}, daily: {} };

  it("keeps the snapshot visible while refreshing the same request", async () => {
    vi.spyOn(ApiClient, "get").mockResolvedValue(payload);
    await useWeatherStore.getState().fetchWeather(DEFAULT_LOCATION, "everyone", DEFAULT_DEVELOPER_OPTIONS);
    const first = useWeatherStore.getState().snapshot;
    expect(first).not.toBeNull();

    let resolve!: (v: Record<string, unknown>) => void;
    vi.spyOn(ApiClient, "get").mockReturnValue(new Promise((r) => { resolve = r; }));
    const pending = useWeatherStore.getState().fetchWeather(DEFAULT_LOCATION, "everyone", DEFAULT_DEVELOPER_OPTIONS);
    expect(useWeatherStore.getState().loading).toBe(true);
    expect(useWeatherStore.getState().snapshot).toBe(first);
    resolve(payload);
    await pending;
  });

  it("clears the snapshot when the location changes", async () => {
    vi.spyOn(ApiClient, "get").mockResolvedValue(payload);
    await useWeatherStore.getState().fetchWeather(DEFAULT_LOCATION, "everyone", DEFAULT_DEVELOPER_OPTIONS);
    vi.spyOn(ApiClient, "get").mockReturnValue(new Promise(() => undefined));
    void useWeatherStore.getState().fetchWeather(new AppLocation("Delhi, India", 28.61, 77.21), "everyone", DEFAULT_DEVELOPER_OPTIONS);
    expect(useWeatherStore.getState().snapshot).toBeNull();
  });

  it("keeps the old snapshot and reports the error when a refresh fails", async () => {
    vi.spyOn(ApiClient, "get").mockResolvedValue(payload);
    const dev = { ...DEFAULT_DEVELOPER_OPTIONS, enabled: true, disableV2Fallback: true };
    await useWeatherStore.getState().fetchWeather(DEFAULT_LOCATION, "everyone", dev);
    const first = useWeatherStore.getState().snapshot;
    vi.spyOn(ApiClient, "get").mockRejectedValue(new Error("offline"));
    await useWeatherStore.getState().fetchWeather(DEFAULT_LOCATION, "everyone", dev);
    expect(useWeatherStore.getState().snapshot).toBe(first);
    expect(useWeatherStore.getState().error).not.toBeNull();
    expect(useWeatherStore.getState().loading).toBe(false);
  });
});
