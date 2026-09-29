import { describe, expect, it } from "vitest";

import { cropNoteKey, dailyRain, nextRainyDay, stageTaskKey, totalRain } from "../src/features/farm/planData";
import { forecastSeriesFromJson } from "../src/features/research/modelData";
import { FARM_CROPS, GROWTH_STAGES } from "../src/features/farm/models/farmOptions";
import en from "../src/i18n/locales/en.json";

/// Hourly rows starting at local midnight, so day boundaries are exact in any TZ.
function hourly(days: number, mmPerHour: (day: number) => number) {
  const start = new Date();
  start.setHours(0, 0, 0, 0);
  const values = Array.from({ length: days * 24 }, (_, h) => {
    const mean = mmPerHour(Math.floor(h / 24));
    return { time_utc: new Date(start.getTime() + h * 3_600_000).toISOString(), value: mean };
  });
  return forecastSeriesFromJson({ status: "ok", units: "mm", source: "open_meteo", values });
}

describe("rain outlook", () => {
  it("sums hourly millimetres into local days", () => {
    const days = dailyRain(hourly(3, (d) => [0, 0.5, 0][d]!));
    expect(days).toHaveLength(3);
    expect(days.map((d) => d.expectedMm)).toEqual([0, 12, 0]);
    expect(totalRain(days)).toBe(12);
  });

  it("finds the first day at or above the IMD rainy-day threshold", () => {
    const days = dailyRain(hourly(4, (d) => [0.05, 0.1, 0.2, 0][d]!));
    // 1.2 mm, 2.4 mm, 4.8 mm, 0 mm → day 2 is the first rainy day.
    expect(nextRainyDay(days)).toBe(2);
    expect(nextRainyDay(dailyRain(hourly(2, () => 0)))).toBeNull();
  });
});

describe("crop calendar copy", () => {
  it("has English text for every stage and crop in the catalog", () => {
    const keys = new Set(Object.keys(en));
    for (const stage of GROWTH_STAGES) expect(keys.has(stageTaskKey(stage))).toBe(true);
    for (const crop of FARM_CROPS) expect(keys.has(cropNoteKey(crop)!)).toBe(true);
    expect(cropNoteKey("Millet")).toBeNull();
  });
});
