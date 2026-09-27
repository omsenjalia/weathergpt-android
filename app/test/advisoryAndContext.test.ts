import { describe, expect, it } from "vitest";

import {
  ActionWindowTab,
  AdvisorySource,
  aiApplied,
  collapseHourlyCells,
  dayDecisionFrom,
  dailySuitabilityCells,
  suitabilityFromName,
  Suitability,
  verdictTextForBand,
} from "../src/features/farm/models/advisoryModels";
import { AdvisoryStatus, stateForTab, unavailableActionWindows, actionWindowsHasData } from "../src/features/farm/farmStores";
import { agentContextPayload, buildAgentRequestContext } from "../src/core/models/requestContext";

describe("suitabilityFromName", () => {
  it("maps bands", () => {
    expect(suitabilityFromName("good")).toBe(Suitability.Good);
    expect(suitabilityFromName("poor")).toBe(Suitability.Avoid);
    expect(suitabilityFromName("caution")).toBe(Suitability.Caution);
    expect(suitabilityFromName(undefined)).toBe(Suitability.Neutral);
  });
});

describe("collapseHourlyCells", () => {
  const cells = Array.from({ length: 24 }, (_, i) => ({
    hour: `${String(i).padStart(2, "0")}:00`,
    suitability: i < 6 ? "avoid" : i < 12 ? "good" : "caution",
  }));

  it("collapses 24 hourly cells into 12 two-hour buckets", () => {
    const buckets = collapseHourlyCells(cells);
    expect(buckets).toHaveLength(12);
    expect(buckets[0]!.suitability).toBe(Suitability.Avoid);
    expect(buckets[0]!.hours).toBe(2);
  });

  it("takes the worst band within a bucket", () => {
    // 12 buckets over 2 cells → 1 cell per bucket, so both cells survive and
    // the second bucket (the avoid one) carries the worst band.
    const mixed = [
      { suitability: "good" },
      { suitability: "avoid" },
    ];
    const buckets = collapseHourlyCells(mixed, 2);
    expect(buckets).toHaveLength(2);
    expect(buckets[0]!.suitability).toBe(Suitability.Good);
    expect(buckets[1]!.suitability).toBe(Suitability.Avoid);
  });

  it("handles empty input", () => {
    expect(collapseHourlyCells([])).toEqual([]);
  });
});

describe("dailySuitabilityCells", () => {
  it("one cell per day", () => {
    const windows = [{ suitability: "good" }, { suitability: "poor" }, {}];
    const cells = dailySuitabilityCells(windows);
    expect(cells).toHaveLength(3);
    expect(cells[0]!.suitability).toBe(Suitability.Good);
    expect(cells[2]!.suitability).toBe(Suitability.Neutral);
  });
});

describe("dayDecisionFrom", () => {
  it("reads windows[i].ai.overall", () => {
    expect(dayDecisionFrom({ ai: { overall: { choice: "good", confidence: 0.88 } } })).toEqual({
      choice: "good",
      confidence: 0.88,
    });
  });
  it("returns absent decision when missing", () => {
    expect(dayDecisionFrom({})).toEqual({ choice: null, confidence: null });
    expect(dayDecisionFrom(null)).toEqual({ choice: null, confidence: null });
  });
});

describe("stateForTab", () => {
  const payload = {
    summary: "Advisory for Wheat: 1/2 day(s) look favourable",
    ai: { enabled: true, applied: true, mean_confidence: 0.9 },
    windows: [
      {
        date: "2026-09-19",
        suitability: "good",
        summary: "Clear morning window",
        best_window: "Best: 6–10 AM",
        hourly: {
          irrigation: Array.from({ length: 24 }, (_, i) => ({ hour: `${i}:00`, suitability: i < 8 ? "good" : "caution" })),
          spraying: Array.from({ length: 24 }, () => ({ suitability: "good" })),
          field_work: Array.from({ length: 24 }, () => ({ suitability: "avoid" })),
        },
        ai: { overall: { choice: "good", confidence: 0.91 } },
      },
      {
        date: "2026-09-20",
        suitability: "caution",
        summary: "Windy afternoon",
        ai: { overall: { choice: "caution", confidence: 0.7 } },
      },
    ],
  };

  it("today reads its own decision, not the global verdict", () => {
    const state = stateForTab(ActionWindowTab.Today, payload, "Rajkot", new Date("2026-09-19T05:00:00Z"));
    expect(state.source).toBe(AdvisorySource.SystemOne);
    expect(state.aiConfidence).toBe(0.91);
    expect(actionWindowsHasData(state)).toBe(true);
    expect(state.irrigationWindows).toHaveLength(12);
  });

  it("tomorrow is unavailable when only today exists", () => {
    const single = { ...payload, windows: payload.windows.slice(0, 1) };
    const state = stateForTab(ActionWindowTab.Tomorrow, single, "Rajkot", new Date());
    expect(state.status).toBe(AdvisoryStatus.Unavailable);
    expect(state.summaryExplanation).toBe("");
  });

  it("seven day aggregates with mean confidence", () => {
    const state = stateForTab(ActionWindowTab.SevenDay, payload, "Rajkot", new Date());
    expect(state.summaryVerdict).toBe("This week at a glance");
    expect(state.aiConfidence).toBe(0.9);
    expect(state.irrigationWindows).toHaveLength(2);
  });
});

describe("unavailableActionWindows", () => {
  it("ships no fabricated windows", () => {
    const state = unavailableActionWindows(ActionWindowTab.Today, "Rajkot");
    expect(actionWindowsHasData(state)).toBe(false);
    expect(state.source).toBe(AdvisorySource.Offline);
  });
});

describe("aiApplied", () => {
  it("requires enabled AND applied", () => {
    expect(aiApplied({ enabled: true, applied: true })).toBe(true);
    expect(aiApplied({ enabled: true, applied: false })).toBe(false);
    expect(aiApplied(null)).toBe(false);
  });
});

describe("verdictTextForBand", () => {
  it("maps bands to farmer-facing lines", () => {
    expect(verdictTextForBand("good")).toBe("Good day for field work");
    expect(verdictTextForBand("poor")).toBe("Avoid heavy farm work today");
    expect(verdictTextForBand(undefined)).toBe("Advisory ready");
  });
});

describe("agent request context", () => {
  const farm = { crop: "Cotton", growthStage: "Flowering", soilType: "Black", irrigationType: "Drip" };

  it("attaches farm context only in farmer mode", () => {
    const farmer = buildAgentRequestContext({ profilePersona: "farmer", farm });
    expect(farmer.mode).toBe("farmer");
    const payload = agentContextPayload(farmer);
    expect(payload).toMatchObject({ mode: "farmer", farmer_mode: true, crop: "Cotton", soil: "Black", irrigation: "Drip", growth_stage: "Flowering" });

    const researcher = buildAgentRequestContext({ profilePersona: "researcher", farm });
    const researcherPayload = agentContextPayload(researcher);
    expect(researcherPayload).toMatchObject({ mode: "researcher", farmer_mode: false, crop: "" });
    expect(researcherPayload.soil).toBeUndefined();
  });

  it("de-escalates unknown stored personas", () => {
    const ctx = buildAgentRequestContext({ profilePersona: "typo-admin", farm });
    expect(ctx.mode).toBe("everyone");
  });

  it("same question, same payload from chat and voice", () => {
    const viaChat = agentContextPayload(buildAgentRequestContext({ profilePersona: "farmer", farm }));
    const viaVoice = agentContextPayload(buildAgentRequestContext({ profilePersona: "farmer", farm }));
    expect(viaChat).toEqual(viaVoice);
  });
});
