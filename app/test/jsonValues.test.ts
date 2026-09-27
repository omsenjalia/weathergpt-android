import { describe, expect, it } from "vitest";

import { jsonBool, jsonDate, jsonDouble, jsonInt, jsonList, jsonMap, jsonNum, jsonString, naiveTimestampAssumedUtc, decodeJsonObject } from "../src/core/models/jsonValues";

describe("jsonNum", () => {
  it("passes finite numbers through", () => {
    expect(jsonNum(3.4)).toBe(3.4);
    expect(jsonNum(0)).toBe(0);
  });
  it("rejects NaN and Infinity", () => {
    expect(jsonNum(Number.NaN)).toBeNull();
    expect(jsonNum(Number.POSITIVE_INFINITY)).toBeNull();
  });
  it("parses numeric strings", () => {
    expect(jsonNum(" 12.5 ")).toBe(12.5);
    expect(jsonNum("abc")).toBeNull();
    expect(jsonNum("")).toBeNull();
  });
});

describe("jsonInt", () => {
  it("accepts integral values", () => {
    expect(jsonInt(4)).toBe(4);
    expect(jsonInt(4.0)).toBe(4);
    expect(jsonInt("7")).toBe(7);
  });
  it("rejects fractional values", () => {
    expect(jsonInt(4.5)).toBeNull();
  });
});

describe("jsonString", () => {
  it("trims and passes real strings", () => {
    expect(jsonString(" hi ")).toBe("hi");
  });
  it("nulls absent markers", () => {
    expect(jsonString("null")).toBeNull();
    expect(jsonString("None")).toBeNull();
    expect(jsonString("NaN")).toBeNull();
    expect(jsonString("")).toBeNull();
    expect(jsonString(undefined)).toBeNull();
  });
});

describe("jsonBool", () => {
  it("accepts booleans and true/false strings", () => {
    expect(jsonBool(true)).toBe(true);
    expect(jsonBool("false")).toBe(false);
    expect(jsonBool("yes")).toBeNull();
    expect(jsonBool(1)).toBeNull();
  });
});

describe("jsonMap / jsonList", () => {
  it("maps objects and nulls arrays", () => {
    expect(jsonMap({ a: 1 })).toEqual({ a: 1 });
    expect(jsonMap([1])).toBeNull();
    expect(jsonList([1, 2])).toEqual([1, 2]);
    expect(jsonList("nope")).toEqual([]);
  });
});

describe("jsonDate", () => {
  it("honours explicit offsets", () => {
    const d = jsonDate("2026-09-19T09:00:00+05:30");
    expect(d).not.toBeNull();
    expect(d!.getUTCHours()).toBe(3);
    expect(d!.getUTCMinutes()).toBe(30);
  });
  it("reads naive strings as UTC", () => {
    const d = jsonDate("2026-09-19T09:00");
    expect(d).not.toBeNull();
    expect(d!.getUTCHours()).toBe(9);
    expect(naiveTimestampAssumedUtc("2026-09-19T09:00")).toBe(true);
    expect(naiveTimestampAssumedUtc("2026-09-19T09:00Z")).toBe(false);
  });
  it("rejects garbage", () => {
    expect(jsonDate("not a date")).toBeNull();
    expect(jsonDate(null)).toBeNull();
  });
});

describe("decodeJsonObject", () => {
  it("parses objects", () => {
    expect(decodeJsonObject('{"a":1}')).toEqual({ a: 1 });
  });
  it("survives truncated bodies", () => {
    expect(decodeJsonObject('{"a":')).toEqual({});
    expect(decodeJsonObject(null)).toEqual({});
  });
});
