import { describe, expect, it } from "vitest";

import { parseWeatherSnapshot } from "../src/features/weather/models/weatherParser";
import { hourLabelFor, parseUtcOffsetSeconds, parseWeatherSnapshotV2 } from "../src/features/weather/models/weatherV2Parser";

const V2_PAYLOAD = {
  current: {
    temperature_c: 31.2,
    feels_like_c: 34,
    condition: "Partly cloudy",
    weather_code: 2,
    humidity_percent: 62,
    wind_speed_kmh: 11.5,
    precipitation_probability: 40,
    time_utc: "2026-09-19T09:00:00Z",
  },
  hourly: [
    { time: "2026-09-19T09:00:00Z", temperature_c: 31.2, rain_probability: 10 },
    { time: "2026-09-19T10:00:00Z", temperature_c: null },
    { time: "2026-09-19T11:00:00Z", temperature_c: 33 },
  ],
  daily: [
    {
      date: "2026-09-19",
      high_c: 34,
      low_c: 24,
      condition: "Partly cloudy",
      rain_probability: 40,
      weather_code: 2,
      sunrise: "2026-09-19T06:20",
      sunset: "2026-09-19T18:45",
    },
  ],
  provenance: { selected_source: "weathernext", run_id: "r-1", issued_at: "2026-09-19T06:00:00Z" },
  field_sources: { temperature_c: "weathernext", humidity: "open_meteo", uv_index: null },
  location: { timezone: "UTC+5 (solar approximation)" },
  temperature_spread: { p10_c: 29, p90_c: 36 },
  precip_next_24h: { total_mm: 4.5, complete: false },
  hourly_available: 168,
  degraded: false,
};

describe("parseWeatherSnapshotV2", () => {
  it("parses current conditions and provenance", () => {
    const w = parseWeatherSnapshotV2(V2_PAYLOAD, { cityName: "Rajkot" });
    expect(w.temperatureC).toBe(31.2);
    expect(w.condition).toBe("Partly cloudy");
    expect(w.weatherCode).toBe(2);
    expect(w.humidity).toBe(62);
    expect(w.provenance.selectedSource).toBe("weathernext");
    expect(w.provenance.runId).toBe("r-1");
    expect(w.provenance.fallback).toBe(false);
  });

  it("drops hourly buckets without a temperature", () => {
    const w = parseWeatherSnapshotV2(V2_PAYLOAD, { cityName: "Rajkot" });
    expect(w.hourly).toHaveLength(2);
    expect(w.hourly[0]!.tempC).toBe(31.2);
    expect(w.hourly[1]!.tempC).toBe(33);
  });

  it("keeps per-field attribution including explicit nulls", () => {
    const w = parseWeatherSnapshotV2(V2_PAYLOAD, { cityName: "Rajkot" });
    expect(w.fieldSources.sources["humidity"]).toBe("open_meteo");
    expect(w.fieldSources.sources["uv_index"]).toBeNull();
  });

  it("parses the UTC offset from a WeatherNext solar label", () => {
    const w = parseWeatherSnapshotV2(V2_PAYLOAD, { cityName: "Rajkot" });
    expect(w.utcOffsetSeconds).toBe(5 * 3600);
  });

  it("keeps the spread only when both percentiles are ordered", () => {
    const w = parseWeatherSnapshotV2(V2_PAYLOAD, { cityName: "Rajkot" });
    expect(w.temperatureSpread?.p10C).toBe(29);
    expect(w.temperatureSpread?.p90C).toBe(36);
  });

  it("marks partial precipitation intervals", () => {
    const w = parseWeatherSnapshotV2(V2_PAYLOAD, { cityName: "Rajkot" });
    expect(w.precipNext24h?.totalMm).toBe(4.5);
    expect(w.precipNext24h?.coversFullPeriod).toBe(false);
  });

  it("never treats a missing weather code as clear", () => {
    const w = parseWeatherSnapshotV2(
      { temperature_c: 20, condition: "—" },
      { cityName: "X" },
    );
    expect(w.weatherCode).toBeNull();
  });

  it("high/low come from the first forecast day in v2", () => {
    const w = parseWeatherSnapshotV2(V2_PAYLOAD, { cityName: "Rajkot" });
    expect(w.highC).toBe(34);
    expect(w.lowC).toBe(24);
  });
});

const LEGACY_PAYLOAD = {
  temperature_c: 28,
  feels_like_c: 30,
  condition: "Cloudy",
  high_c: 31,
  low_c: 22,
  rain_probability: 20,
  wind_kmh: 9,
  humidity: 70,
  sunrise: "2026-09-19T06:20",
  sunset: "2026-09-19T18:45",
  hourly: [{ time: "2026-09-19T09:00", temperature_c: 28.4, rain_probability: 15 }],
  forecast: [{ date: "2026-09-19", high_c: 31, low_c: 22, condition: "Cloudy", rain_probability: 20 }],
  source: "open_meteo",
  timezone: "Asia/Kolkata",
  utc_offset_seconds: 19800,
};

describe("parseWeatherSnapshot (legacy)", () => {
  it("parses legacy fields and naive local timestamps", () => {
    const w = parseWeatherSnapshot(LEGACY_PAYLOAD, { cityName: "Ahmedabad" });
    expect(w.temperatureC).toBe(28);
    expect(w.hourly[0]!.label).toBe("9AM");
    expect(w.provenance.source).toBe("open_meteo");
    expect(w.utcOffsetSeconds).toBe(19800);
  });

  it("malformed rows are skipped, never thrown", () => {
    const w = parseWeatherSnapshot(
      { hourly: [null, "nope", { temperature_c: 3 }], forecast: [[]] },
      { cityName: "X" },
    );
    expect(w.hourly).toHaveLength(1);
    expect(w.forecast).toHaveLength(0);
  });
});

describe("hourLabelFor", () => {
  it("labels in location-local time", () => {
    const utc = new Date("2026-09-19T18:30:00Z");
    expect(hourLabelFor(utc, 19800)).toBe("12AM");
    // No offset: falls back to the device clock, so derive the expectation
    // from the machine's own timezone instead of assuming UTC.
    const h = utc.getHours();
    expect(hourLabelFor(utc, null)).toBe(h === 0 ? "12AM" : h === 12 ? "12PM" : h > 12 ? `${h - 12}PM` : `${h}AM`);
  });
  it("handles midnight and noon", () => {
    expect(hourLabelFor(new Date("2026-09-19T00:30:00Z"), 0)).toBe("12AM");
    expect(hourLabelFor(new Date("2026-09-19T12:30:00Z"), 0)).toBe("12PM");
  });
});

describe("parseUtcOffsetSeconds", () => {
  it("accepts seconds, approx hours and UTC labels", () => {
    expect(parseUtcOffsetSeconds({ utc_offset_seconds: 19800 })).toBe(19800);
    expect(parseUtcOffsetSeconds({ utc_offset_hours_approx: 5.5 })).toBe(19800);
    expect(parseUtcOffsetSeconds({ timezone: "UTC-3" })).toBe(-3 * 3600);
    expect(parseUtcOffsetSeconds({})).toBeNull();
  });
});
