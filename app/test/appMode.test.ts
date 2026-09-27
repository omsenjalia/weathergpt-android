import { describe, expect, it } from "vitest";

import { appModeFromName, AppModeException, legacyFarmerModeFor, resolveAppMode } from "../src/core/models/appMode";

describe("appModeFromName", () => {
  it("recognises wire names", () => {
    expect(appModeFromName("everyone")).toBe("everyone");
    expect(appModeFromName("FARMER")).toBe("farmer");
    expect(appModeFromName(" researcher ")).toBe("researcher");
  });
  it("rejects unknown values", () => {
    expect(appModeFromName("admin")).toBeNull();
    expect(appModeFromName(42)).toBeNull();
  });
});

describe("resolveAppMode", () => {
  it("explicit mode wins", () => {
    expect(resolveAppMode({ mode: "researcher", legacyFarmerMode: true })).toBe("researcher");
  });
  it("unknown explicit value is rejected in strict mode", () => {
    expect(() => resolveAppMode({ mode: "root" })).toThrow(AppModeException);
  });
  it("unknown explicit value de-escalates when not strict", () => {
    expect(resolveAppMode({ mode: "root", strict: false })).toBe("everyone");
  });
  it("blank mode falls back to legacy boolean", () => {
    expect(resolveAppMode({ mode: "", legacyFarmerMode: true })).toBe("farmer");
    expect(resolveAppMode({ mode: undefined })).toBe("everyone");
  });
});

describe("legacyFarmerModeFor", () => {
  it("derives the boolean from the mode", () => {
    expect(legacyFarmerModeFor("farmer")).toBe(true);
    expect(legacyFarmerModeFor("everyone")).toBe(false);
    expect(legacyFarmerModeFor("researcher")).toBe(false);
  });
});
