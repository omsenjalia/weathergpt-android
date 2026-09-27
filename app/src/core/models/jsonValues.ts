/// Defensive coercion helpers for decoded JSON — port of
/// `lib/core/models/json_values.dart`. Every accessor returns `null` for
/// absent, wrong-typed, blank, `NaN` or infinite values. Nothing ever defaults
/// a missing measurement to `0`, because a `0` temperature, `0 mm` of rain or a
/// `0` rain probability is a *claim* the backend did not make.

export function jsonNum(value: unknown): number | null {
  if (typeof value === "number") return Number.isFinite(value) ? value : null;
  if (typeof value === "string") {
    const trimmed = value.trim();
    if (trimmed === "") return null;
    const parsed = Number(trimmed);
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

export function jsonDouble(value: unknown): number | null {
  const parsed = jsonNum(value);
  return parsed === null ? null : parsed;
}

export function jsonInt(value: unknown): number | null {
  const parsed = jsonNum(value);
  if (parsed === null) return null;
  const rounded = Math.round(parsed);
  return Math.abs(parsed - rounded) < 1e-9 ? rounded : null;
}

export function jsonString(value: unknown): string | null {
  if (value === null || value === undefined) return null;
  const text = typeof value === "string" ? value : String(value);
  const trimmed = text.trim();
  if (trimmed === "") return null;
  const lowered = trimmed.toLowerCase();
  if (lowered === "null" || lowered === "none" || lowered === "nan") return null;
  return trimmed;
}

export function jsonBool(value: unknown): boolean | null {
  if (typeof value === "boolean") return value;
  if (typeof value === "string") {
    switch (value.trim().toLowerCase()) {
      case "true":
        return true;
      case "false":
        return false;
    }
  }
  return null;
}

export function jsonMap(value: unknown): Record<string, unknown> | null {
  if (value !== null && typeof value === "object" && !Array.isArray(value)) {
    return value as Record<string, unknown>;
  }
  return null;
}

export function jsonList(value: unknown): unknown[] {
  return Array.isArray(value) ? value : [];
}

export function jsonDate(value: unknown): Date | null {
  const raw = jsonString(value);
  if (raw === null) return null;
  const hasExplicitOffset = /[zZ]$/.test(raw) || /[+-]\d{2}:?\d{2}$/.test(raw);
  const parsed = new Date(hasExplicitOffset ? raw : `${raw}Z`);
  if (Number.isNaN(parsed.getTime())) return null;
  return parsed;
}

export function naiveTimestampAssumedUtc(raw: unknown): boolean {
  const text = jsonString(raw);
  if (text === null) return false;
  const hasExplicitOffset = /[zZ]$/.test(text) || /[+-]\d{2}:?\d{2}$/.test(text);
  return !hasExplicitOffset;
}

export function decodeJsonObject(body: string | null | undefined): Record<string, unknown> {
  if (!body || body.trim() === "") return {};
  try {
    const decoded: unknown = JSON.parse(body);
    return jsonMap(decoded) ?? {};
  } catch {
    return {};
  }
}

export type Duration = { seconds: number };

export function durationSeconds(seconds: number): Duration {
  return { seconds };
}
