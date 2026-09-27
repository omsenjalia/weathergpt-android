import { describe, expect, it } from "vitest";

import { mapBackendAnswer, looksLikeGreetingOrIntro, typeForQuery, ResultType } from "../src/features/voice/mappers/voiceResponseMapper";
import { MarkdownUtils } from "../src/core/utils/markdownUtils";
import {
  formatVoiceFarmSize,
  indicDigitsToAscii,
  matchVoiceOption,
  normalizeVoiceInput,
  parseVoiceCrop,
  parseVoiceFarmSize,
  parseVoiceGrowthStage,
  parseVoiceIrrigation,
  parseVoiceSoil,
} from "../src/features/farm/models/farmVoiceParser";
import { FARM_CROPS } from "../src/features/farm/models/farmOptions";

describe("markdown forSpeech", () => {
  it("strips widget fences and tables", () => {
    const input = [
      "## 🌤️ WeatherGPT Live Status",
      "",
      "```widget:weather",
      '{"city": "Rajkot"}',
      "```",
      "",
      "| Field | Value |",
      "|---|---|",
      "| Temp | 31 |",
      "",
      "Wind <15 km/h, no rain.",
    ].join("\n");
    const speech = MarkdownUtils.forSpeech(input);
    expect(speech).not.toContain("widget");
    expect(speech).not.toContain("|");
    expect(speech).not.toContain("#");
    expect(speech).toContain("Wind <15 km/h");
  });

  it("removes latex delimiters and bold markers", () => {
    expect(MarkdownUtils.forSpeech("$$\\frac{a}{b}$$ and **bold**")).not.toContain("\\frac");
    expect(MarkdownUtils.forSpeech("**bold**")).toBe("bold");
  });

  it("spokenSummary keeps the body and trims long text", () => {
    const long = `${"Rain expected. ".repeat(60)}End.`;
    const summary = MarkdownUtils.spokenSummary("verdict", long);
    expect(summary.length).toBeLessThanOrEqual(321);
    expect(summary.endsWith("…") || summary.endsWith(".")).toBe(true);
  });
});

describe("voice response mapper", () => {
  it("greetings render as Assistant without fabricated stats", () => {
    const result = mapBackendAnswer("hi", "Hello! I'm WeatherGPT.");
    expect(result.label).toBe("Assistant");
    expect(result.stats).toHaveLength(0);
    expect(result.forecast).toHaveLength(0);
  });

  it("numbers come only from the structured card", () => {
    const result = mapBackendAnswer("Will it rain?", "Rain likely tomorrow.", {
      card: {
        label: "Rain Forecast",
        verdict: "Favorable",
        stats: [
          { label: "Rain Risk", value: "10%", tone: "good" },
          { label: "Wind", value: "8 km/h", tone: "caution" },
        ],
        forecast: [{ day: "Today", temperature: "32°C", rainfall: "0 mm", condition: "sunny" }],
        confidence: 0.88,
      },
    });
    expect(result.stats).toHaveLength(2);
    expect(result.forecast).toHaveLength(1);
    expect(result.forecast[0]!.rainfall).toBe("0 mm");
  });

  it("prose-only answers stay prose-only", () => {
    const result = mapBackendAnswer("Will it rain?", "Rain likely tomorrow.");
    expect(result.stats).toHaveLength(0);
    expect(result.explanation).toBe("Rain likely tomorrow.");
  });

  it("classifies the ask for chrome only", () => {
    expect(typeForQuery("should i irrigate today", false)).toBe(ResultType.Irrigation);
    expect(typeForQuery("will it rain", false)).toBe(ResultType.RainForecast);
    expect(typeForQuery("how is my crop", false)).toBe(ResultType.CropStatus);
    expect(typeForQuery("hello", true)).toBe(ResultType.General);
  });

  it("looksLikeGreetingOrIntro catches intros in Indic scripts", () => {
    expect(looksLikeGreetingOrIntro("नमस्ते", "नमस्ते!")).toBe(true);
    expect(looksLikeGreetingOrIntro("rain?", "rain expected")).toBe(false);
  });
});

describe("farm voice parser", () => {
  it("normalizes punctuation but keeps Indic scripts", () => {
    expect(normalizeVoiceInput("Hello, world!")).toBe("hello world");
    expect(normalizeVoiceInput("गेहूं")).toBe("गेहूं");
  });

  it("converts Indic digits", () => {
    expect(indicDigitsToAscii("४")).toBe("4");
    expect(indicDigitsToAscii("૫")).toBe("5");
  });

  it("matches crops across scripts and romanizations", () => {
    expect(parseVoiceCrop("wheat")).toBe("Wheat");
    expect(parseVoiceCrop("गेहूं")).toBe("Wheat");
    expect(parseVoiceCrop("ઘઉં")).toBe("Wheat");
    expect(parseVoiceCrop("gehu")).toBe("Wheat");
    expect(parseVoiceCrop("corn")).toBe("Maize");
    expect(parseVoiceCrop("something else")).toBeNull();
  });

  it("matches stages, irrigation and soil", () => {
    expect(parseVoiceGrowthStage("blooming")).toBe("Flowering");
    expect(parseVoiceGrowthStage("फूल")).toBe("Flowering");
    expect(parseVoiceIrrigation("drip irrigation")).toBe("Drip");
    expect(parseVoiceIrrigation("depends on rain")).toBe("Rainfed");
    expect(parseVoiceSoil("black cotton soil")).toBe("Black");
    expect(parseVoiceSoil("sand")).toBe("Sandy");
  });

  it("longest phrase wins over short keys", () => {
    // A sentence with no crop word matches nothing…
    expect(matchVoiceOption("i grow it near the river", FARM_CROPS, {})).toBeNull();
    // …while a soil sentence resolves through the longest soil alias.
    expect(parseVoiceSoil("i have black soil")).toBe("Black");
  });

  it("short keys only match whole words", () => {
    expect(parseVoiceIrrigation("down the drain")).not.toBe("Rainfed");
  });

  it("parses farm sizes: digits, Indic digits, words", () => {
    expect(parseVoiceFarmSize("4.5")).toBe(4.5);
    expect(parseVoiceFarmSize("४")).toBe(4);
    expect(parseVoiceFarmSize("चार")).toBe(4);
    expect(parseVoiceFarmSize("two")).toBe(2);
    expect(parseVoiceFarmSize("an acre")).toBe(1);
    expect(parseVoiceFarmSize("1,000")).toBe(1000);
    expect(parseVoiceFarmSize("none")).toBeNull();
  });

  it("formats sizes for round-trip display", () => {
    expect(formatVoiceFarmSize(4)).toBe("4");
    expect(formatVoiceFarmSize(4.5)).toBe("4.5");
  });
});
