import { describe, expect, it } from "vitest";

import {
  conditionFromWeather,
  formatClock,
  paletteFor,
  parseWeatherTime,
  periodFromLocalTime,
  SkyCondition,
  SkyPeriod,
  windDirLabel,
} from "../src/features/weather/theme/atmosphereTheme";

describe("periodFromLocalTime", () => {
  it("buckets the day into 11 periods", () => {
    const rise = new Date("2026-09-19T06:20:00");
    const set = new Date("2026-09-19T18:45:00");
    expect(periodFromLocalTime(new Date("2026-09-19T00:30:00"), rise, set)).toBe(SkyPeriod.Midnight);
    expect(periodFromLocalTime(new Date("2026-09-19T05:45:00"), rise, set)).toBe(SkyPeriod.Predawn);
    expect(periodFromLocalTime(new Date("2026-09-19T06:30:00"), rise, set)).toBe(SkyPeriod.Sunrise);
    expect(periodFromLocalTime(new Date("2026-09-19T08:00:00"), rise, set)).toBe(SkyPeriod.Morning);
    expect(periodFromLocalTime(new Date("2026-09-19T12:30:00"), rise, set)).toBe(SkyPeriod.Midday);
    expect(periodFromLocalTime(new Date("2026-09-19T16:00:00"), rise, set)).toBe(SkyPeriod.Afternoon);
    expect(periodFromLocalTime(new Date("2026-09-19T18:10:00"), rise, set)).toBe(SkyPeriod.GoldenHour);
    expect(periodFromLocalTime(new Date("2026-09-19T18:50:00"), rise, set)).toBe(SkyPeriod.Sunset);
    expect(periodFromLocalTime(new Date("2026-09-19T19:10:00"), rise, set)).toBe(SkyPeriod.Dusk);
    expect(periodFromLocalTime(new Date("2026-09-19T21:00:00"), rise, set)).toBe(SkyPeriod.Evening);
    expect(periodFromLocalTime(new Date("2026-09-19T23:30:00"), rise, set)).toBe(SkyPeriod.Night);
  });

  it("falls back to default rise/set when unknown", () => {
    expect(periodFromLocalTime(new Date("2026-09-19T02:00:00"), null, null)).toBe(SkyPeriod.Night);
    expect(periodFromLocalTime(new Date("2026-09-19T12:00:00"), null, null)).toBe(SkyPeriod.Midday);
  });
});

describe("conditionFromWeather", () => {
  it("maps WMO codes", () => {
    expect(conditionFromWeather({ weatherCode: 0, condition: "", windKmh: 0 })).toBe(SkyCondition.Clear);
    expect(conditionFromWeather({ weatherCode: 2, condition: "", windKmh: 0 })).toBe(SkyCondition.PartlyCloudy);
    expect(conditionFromWeather({ weatherCode: 3, condition: "", windKmh: 0 })).toBe(SkyCondition.Overcast);
    expect(conditionFromWeather({ weatherCode: 61, condition: "", windKmh: 0 })).toBe(SkyCondition.Rain);
    expect(conditionFromWeather({ weatherCode: 95, condition: "", windKmh: 0 })).toBe(SkyCondition.Thunder);
    expect(conditionFromWeather({ weatherCode: 73, condition: "", windKmh: 0 })).toBe(SkyCondition.Snow);
    expect(conditionFromWeather({ weatherCode: 45, condition: "", windKmh: 0 })).toBe(SkyCondition.Fog);
  });

  it("a missing code is unknown, never clear", () => {
    expect(conditionFromWeather({ weatherCode: null, condition: "—", windKmh: 0 })).toBe(SkyCondition.Unknown);
  });

  it("falls back to condition text and wind", () => {
    expect(conditionFromWeather({ weatherCode: null, condition: "Heavy rain", windKmh: 0 })).toBe(SkyCondition.HeavyRain);
    expect(conditionFromWeather({ weatherCode: null, condition: "Mist", windKmh: 0 })).toBe(SkyCondition.Fog);
    expect(conditionFromWeather({ weatherCode: null, condition: "—", windKmh: 40 })).toBe(SkyCondition.Windy);
  });
});

describe("paletteFor", () => {
  it("produces readable text for every period × condition combination", () => {
    for (const period of Object.values(SkyPeriod)) {
      for (const sky of Object.values(SkyCondition)) {
        const palette = paletteFor(period, sky);
        expect(palette.top).toMatch(/^rgba?\(/);
        expect(palette.text).toMatch(/^rgba?\(/);
      }
    }
  });

  it("rain darkens the sky and hides the sun", () => {
    const clear = paletteFor(SkyPeriod.Midday, SkyCondition.Clear);
    const rain = paletteFor(SkyPeriod.Midday, SkyCondition.Rain);
    expect(rain.showSun).toBe(false);
    expect(rain.mid).not.toBe(clear.mid);
  });
});

describe("time helpers", () => {
  it("parses lenient weather times", () => {
    expect(parseWeatherTime("2026-09-19T06:20")).not.toBeNull();
    expect(parseWeatherTime("2026-09-19T06:20:00")).not.toBeNull();
    expect(parseWeatherTime("junk")).toBeNull();
    expect(formatClock("2026-09-19T06:20")).toBe("6:20 AM");
    expect(formatClock("2026-09-19T18:45")).toBe("6:45 PM");
    expect(formatClock(null)).toBe("—");
  });

  it("labels wind direction in 8 sectors", () => {
    expect(windDirLabel(0)).toBe("N");
    expect(windDirLabel(45)).toBe("NE");
    expect(windDirLabel(360)).toBe("N");
    expect(windDirLabel(270)).toBe("W");
    expect(windDirLabel(null)).toBe("—");
  });
});
