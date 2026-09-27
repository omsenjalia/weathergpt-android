import { describe, expect, it } from "vitest";

import { parseGeocodeResults } from "../src/core/services/geocodingService";
import {
  isStaleAt,
  realFailures,
  skippedUnconfigured,
  weatherNextFailed,
  weatherProvenanceFromJson,
} from "../src/core/models/dataProvenance";
import { fieldSourcesFromJson } from "../src/core/models/fieldSources";
import { withCurrentOption } from "../src/features/farm/models/farmOptions";

describe("geocoding parser", () => {
  it("builds labels from name, admin and country", () => {
    const places = parseGeocodeResults(
      [
        { name: "Rajkot", admin1: "Gujarat", country: "India", latitude: 22.3, longitude: 70.8 },
        { name: "X", latitude: 1, longitude: 2 },
      ],
      "query",
    );
    expect(places).toHaveLength(2);
    expect(places[0]!.name).toBe("Rajkot, Gujarat, India");
    expect(places[1]!.name).toBe("X");
  });

  it("skips malformed rows", () => {
    expect(parseGeocodeResults([null, { name: "no coords" }, 42], "q")).toHaveLength(0);
    expect(parseGeocodeResults("not a list", "q")).toHaveLength(0);
  });
});

describe("weather provenance", () => {
  it("reports nothing when the backend reports nothing", () => {
    const prov = weatherProvenanceFromJson({});
    expect(prov.selectedSource).toBeNull();
    expect(prov.fallback).toBe(false);
  });

  it("unconfigured providers are not degradation", () => {
    const prov = weatherProvenanceFromJson({
      provenance: {
        selected_source: "weathernext",
        fallback_reasons: [{ provider: "imd", reason: "missing_credentials" }],
      },
    });
    expect(prov.fallback).toBe(false);
    expect(skippedUnconfigured(prov)).toHaveLength(1);
    expect(realFailures(prov)).toHaveLength(0);
  });

  it("real failures degrade the payload", () => {
    const prov = weatherProvenanceFromJson({
      provenance: {
        selected_source: "open_meteo",
        fallback_reasons: [{ provider: "weathernext", reason: "stale_data" }],
      },
    });
    expect(prov.fallback).toBe(true);
    expect(weatherNextFailed(prov)).toBe(true);
  });

  it("explicit degraded verdict wins", () => {
    const prov = weatherProvenanceFromJson({ degraded: true });
    expect(prov.fallback).toBe(true);
  });

  it("null_reasons entries become missing fields", () => {
    const prov = weatherProvenanceFromJson({ null_reasons: { uv_index: "not provided" } });
    expect(prov.missingFields).toContain("uv_index");
  });

  it("unknown age is not stale", () => {
    const prov = weatherProvenanceFromJson({});
    expect(isStaleAt(prov, new Date())).toBe(false);
  });

  it("old payloads are stale at six hours", () => {
    const prov = weatherProvenanceFromJson({ issued_at: "2026-09-19T00:00:00Z" });
    expect(isStaleAt(prov, new Date("2026-09-19T07:00:00Z"))).toBe(true);
    expect(isStaleAt(prov, new Date("2026-09-19T05:00:00Z"))).toBe(false);
  });
});

describe("field sources", () => {
  it("parses supplement metadata", () => {
    const fs = fieldSourcesFromJson({
      temperature_c: "weathernext",
      uv_index: "open_meteo",
      _supplement: {
        provider: "open_meteo",
        attempted: true,
        filled: ["uv_index"],
        errors: [{ call: "aqi", reason: "timeout" }],
      },
    });
    expect(fs.supplementProvider).toBe("open_meteo");
    expect(fs.supplementFilled).toEqual(["uv_index"]);
    expect(fs.supplementErrors).toEqual(["aqi: timeout"]);
  });
});

describe("farm options", () => {
  it("withCurrentOption guarantees dropdown safety", () => {
    expect(withCurrentOption(["A", "B"], "A")).toEqual(["A", "B"]);
    expect(withCurrentOption(["A", "B"], "Z")).toEqual(["Z", "A", "B"]);
  });
});
