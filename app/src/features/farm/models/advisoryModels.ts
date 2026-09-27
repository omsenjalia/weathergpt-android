/// Pure models and mapping for the backend `/advisory` payload — port of
/// `lib/features/farmer/models/advisory_models.dart`. The backend returns a
/// summary, per-day windows with hourly suitability tracks, and optional
/// System One (Jev) AI decisions.

/// Which slice of the forecast the action-window screen is showing.
export enum ActionWindowTab {
  Today = "today",
  Tomorrow = "tomorrow",
  SevenDay = "sevenDay",
}

/// Visual band for one activity in one time bucket.
export enum Suitability {
  Good = "good",
  Caution = "caution",
  Avoid = "avoid",
  Neutral = "neutral",
}

/// Where the currently displayed advisory came from.
export enum AdvisorySource {
  SystemOne = "systemOne",
  Thresholds = "thresholds",
  Offline = "offline",
}

export interface HourlySuitability {
  suitability: Suitability;
  hours: number;
}

/// Maps a backend band name onto the visual enum. Unknown/missing -> neutral.
export function suitabilityFromName(name: string | null | undefined): Suitability {
  switch (name) {
    case "good":
      return Suitability.Good;
    case "caution":
      return Suitability.Caution;
    case "poor":
    case "avoid":
      return Suitability.Avoid;
    default:
      return Suitability.Neutral;
  }
}

function severity(value: Suitability): number {
  switch (value) {
    case Suitability.Avoid:
      return 3;
    case Suitability.Caution:
      return 2;
    case Suitability.Good:
      return 1;
    default:
      return 0;
  }
}

function worstOf(a: Suitability, b: Suitability): Suitability {
  return severity(a) >= severity(b) ? a : b;
}

function cellSuitability(cell: unknown): string | null {
  if (cell === null || typeof cell !== "object") return null;
  const value = (cell as Record<string, unknown>)["suitability"];
  return typeof value === "string" ? value : null;
}

/// Collapses the backend's 24 hourly cells into `bucketCount` visual cells
/// (default 12 two-hour buckets for the action-window bars), taking the worst
/// band within each bucket so caution is never hidden by averaging.
export function collapseHourlyCells(cells: unknown[], bucketCount = 12): HourlySuitability[] {
  if (cells.length === 0) return [];
  if (bucketCount < 1) bucketCount = 1;
  const size = Math.min(Math.max(Math.ceil(cells.length / bucketCount), 1), cells.length);
  const result: HourlySuitability[] = [];
  for (let start = 0; start < cells.length; start += size) {
    let worst = Suitability.Neutral;
    let count = 0;
    for (let i = start; i < start + size && i < cells.length; i++) {
      worst = worstOf(worst, suitabilityFromName(cellSuitability(cells[i])));
      count++;
    }
    result.push({ suitability: worst, hours: count });
  }
  return result;
}

/// One visual cell per forecast day (for the 7-day tab).
export function dailySuitabilityCells(windows: unknown[], maxDays = 7): HourlySuitability[] {
  const cells: HourlySuitability[] = [];
  for (const window of windows.slice(0, maxDays)) {
    cells.push({ suitability: suitabilityFromName(cellSuitability(window)), hours: 1 });
  }
  return cells;
}

function aiMap(ai: Record<string, unknown> | null): Record<string, unknown> | null {
  return ai;
}

/// True when the backend actually applied System One answers (not just enabled).
export function aiApplied(ai: Record<string, unknown> | null): boolean {
  const map = aiMap(ai);
  return map !== null && map["enabled"] === true && map["applied"] === true;
}

/// Top-level verdict choice reported by System One, if any.
///
/// This is a *whole-request* verdict (the backend's highest-confidence overall
/// answer). It must not be rendered as one specific day's decision — use
/// `dayDecisionFrom` for that.
export function aiOverallVerdict(ai: Record<string, unknown> | null): string | null {
  const value = ai?.["overall_verdict"];
  return typeof value === "string" ? value : null;
}

export interface DayDecision {
  choice: string | null;
  confidence: number | null;
}

export function noDayDecision(): DayDecision {
  return { choice: null, confidence: null };
}

export function dayDecisionIsPresent(decision: DayDecision): boolean {
  return decision.choice !== null && decision.choice !== "";
}

/// Extracts the per-day decision from one `/advisory` window entry.
///
/// `/advisory` returns `windows[i].ai.overall = {choice, confidence}`. Reading
/// the day's own decision is what stops a global, highest-confidence verdict
/// from being shown as "today's" answer when it was actually computed for
/// another day.
export function dayDecisionFrom(window: Record<string, unknown> | null): DayDecision {
  const ai = window?.["ai"];
  if (ai === null || typeof ai !== "object") return noDayDecision();
  const overall = (ai as Record<string, unknown>)["overall"];
  if (overall === null || typeof overall !== "object") return noDayDecision();
  const map = overall as Record<string, unknown>;
  return {
    choice: typeof map["choice"] === "string" ? map["choice"] : null,
    confidence: typeof map["confidence"] === "number" ? map["confidence"] : null,
  };
}

/// Farmer-facing verdict line derived from a daily band name.
export function verdictTextForBand(band: string | null | undefined): string {
  switch (band) {
    case "good":
      return "Good day for field work";
    case "caution":
      return "A workable day with caution";
    case "poor":
    case "avoid":
      return "Avoid heavy farm work today";
    default:
      return "Advisory ready";
  }
}

/// Mean confidence across the System One answers the backend acted on.
export function aiMeanConfidence(ai: Record<string, unknown> | null): number | null {
  const value = ai?.["mean_confidence"];
  return typeof value === "number" ? value : null;
}
