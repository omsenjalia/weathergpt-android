/// Validated user-facing product mode — port of `lib/core/models/app_mode.dart`.
/// Everyone / Farmer / Researcher share one data platform but must not render
/// the same dashboard in different colours, and a user-selected Researcher
/// mode never grants server permissions.

export type AppMode = "everyone" | "farmer" | "researcher";

export const APP_MODES: readonly AppMode[] = ["everyone", "farmer", "researcher"];

export function appModeWire(mode: AppMode): string {
  return mode;
}

/// Parses a mode value. Returns `null` for anything unrecognised so callers can
/// reject it instead of silently escalating to a more privileged mode.
export function appModeFromName(value: unknown): AppMode | null {
  if (typeof value !== "string") return null;
  switch (value.trim().toLowerCase()) {
    case "everyone":
      return "everyone";
    case "farmer":
      return "farmer";
    case "researcher":
      return "researcher";
    default:
      return null;
  }
}

/// Raised when a caller supplies an explicit but unrecognised mode value.
export class AppModeException extends Error {
  constructor(public readonly value: unknown) {
    super(`Unsupported mode value: ${value === null || value === undefined ? "null" : `"${String(value)}"`}`);
    this.name = "AppModeException";
  }
}

/// Resolves the mode to send on an outgoing forecast/chat/voice request.
///
/// Rules (feature/app/implementation_plan.md §3):
/// - An explicit `mode` is authoritative.
/// - An explicit but unknown value is **rejected**, never escalated. With
///   `strict` the caller gets an `AppModeException`; otherwise it de-escalates
///   to `everyone`, the least privileged mode.
/// - A blank/absent `mode` falls back to the legacy boolean:
///   `farmer_mode == true` → farmer, anything else → everyone.
export function resolveAppMode(opts: {
  mode?: unknown;
  legacyFarmerMode?: boolean | null;
  strict?: boolean;
}): AppMode {
  const { mode, legacyFarmerMode, strict = true } = opts;
  const explicit = appModeFromName(mode);
  if (explicit !== null) return explicit;

  if (mode !== null && mode !== undefined) {
    const blank = typeof mode === "string" && mode.trim() === "";
    if (!blank) {
      if (strict) throw new AppModeException(mode);
      return "everyone";
    }
  }
  return legacyFarmerMode === true ? "farmer" : "everyone";
}

/// Legacy compatibility flag derived *from* the resolved mode, so the two can
/// never disagree on the wire.
export function legacyFarmerModeFor(mode: AppMode): boolean {
  return mode === "farmer";
}
