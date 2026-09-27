/// Farm stores — ports of `lib/features/farmer/providers/`
/// (`farm_profile_provider.dart` + `action_windows_provider.dart`).

import { create } from "zustand";

import { ApiEndpoints } from "../../core/config/apiEndpoints";
import { apiErrorMessage } from "../../core/errors/appErrors";
import { jsonList, jsonMap, jsonString } from "../../core/models/jsonValues";
import { GeocodingService } from "../../core/services/geocodingService";
import { ApiClient } from "../../core/services/apiClient";
import { loadJson, saveJson, StorageKeys } from "../../lib/persistence";
import { AppLocation, DEFAULT_LOCATION, useLocationStore } from "../location/locationStore";
import {
  ActionWindowTab,
  AdvisorySource,
  aiApplied,
  aiMeanConfidence,
  collapseHourlyCells,
  dailySuitabilityCells,
  DayDecision,
  dayDecisionFrom,
  dayDecisionIsPresent,
  HourlySuitability,
  Suitability,
  verdictTextForBand,
} from "./models/advisoryModels";
import { DEFAULT_FARM_PROFILE, FarmProfile, farmProfileFromMap, farmProfileToMap } from "./models/farmProfile";

// ---------------------------------------------------------------------------
// Farm profile

interface FarmProfileStore {
  profile: FarmProfile;
  completed: boolean;
  hydrated: boolean;
  hydrate: () => Promise<void>;
  save: (profile: FarmProfile) => Promise<void>;
}

export const useFarmProfileStore = create<FarmProfileStore>((set, get) => ({
  profile: DEFAULT_FARM_PROFILE,
  completed: false,
  hydrated: false,

  hydrate: async () => {
    if (get().hydrated) return;
    const [stored, completed] = await Promise.all([
      loadJson<Record<string, unknown> | null>(StorageKeys.farmProfile),
      loadJson<boolean | null>(StorageKeys.farmProfileCompleted),
    ]);
    set({
      profile: farmProfileFromMap(stored ?? undefined),
      // Profiles saved before this flag existed (a profile with no flag) count
      // as completed so existing farmers are never nagged to re-enter details.
      completed: completed !== null ? completed === true : stored !== null,
      hydrated: true,
    });
  },

  save: async (profile) => {
    if (!profile.location.trim() || !Number.isFinite(profile.farmSizeAcres) || profile.farmSizeAcres <= 0) {
      throw new Error("Enter a location and a positive farm size.");
    }
    const current = useLocationStore.getState().location;
    const location = profile.location === current.name ? current : await GeocodingService.search(profile.location);
    if (!location) throw new Error("Could not find this farm location. Check your connection or choose a nearby city.");
    await useLocationStore.getState().select(location);
    profile = { ...profile, location: location.name };
    set({ profile, completed: true });
    await Promise.all([
      saveJson(StorageKeys.farmProfile, farmProfileToMap(profile)),
      saveJson(StorageKeys.farmProfileCompleted, true),
    ]);
  },
}));

// ---------------------------------------------------------------------------
// Action windows (advisory)

export enum AdvisoryStatus {
  Loading = "loading",
  Ready = "ready",
  Unavailable = "unavailable",
}

export interface ActionWindowsState {
  selectedTab: ActionWindowTab;
  irrigationWindows: HourlySuitability[];
  sprayingWindows: HourlySuitability[];
  fieldWorkWindows: HourlySuitability[];
  fieldWorkStatus: string;
  summaryVerdict: string;
  summaryExplanation: string;
  status: AdvisoryStatus;
  source: AdvisorySource;
  /// Confidence of the decision actually shown, when the backend reported one.
  aiConfidence: number | null;
  locationLabel: string;
  /// When this advisory was verified against the backend. A timestamped
  /// last-known result is honest; a silent cached one is not.
  asOfUtc: Date | null;
}

/// Explicit "no verified windows" state.
///
/// There is deliberately **no** bundled favourable baseline. Shipping a demo
/// irrigation/spraying pattern as if it were live advice is the exact failure
/// the implementation plan calls out; when the backend cannot be reached the
/// farmer sees an unavailable state instead.
export function unavailableActionWindows(tab: ActionWindowTab, locationLabel = ""): ActionWindowsState {
  return {
    selectedTab: tab,
    irrigationWindows: [],
    sprayingWindows: [],
    fieldWorkWindows: [],
    fieldWorkStatus: "",
    summaryVerdict: "",
    summaryExplanation: "",
    status: AdvisoryStatus.Unavailable,
    source: AdvisorySource.Offline,
    aiConfidence: null,
    locationLabel,
    asOfUtc: null,
  };
}

export function actionWindowsAiAssisted(state: ActionWindowsState): boolean {
  return state.source === AdvisorySource.SystemOne;
}

export function actionWindowsHasData(state: ActionWindowsState): boolean {
  return (
    state.irrigationWindows.length > 0 ||
    state.sprayingWindows.length > 0 ||
    state.fieldWorkWindows.length > 0
  );
}

function dayDecisionOrNone(window: Record<string, unknown> | null): DayDecision {
  return dayDecisionFrom(window);
}

interface AdvisoryContext {
  location: AppLocation;
  profile: FarmProfile;
  mode: string;
}

interface ActionWindowsStore {
  state: ActionWindowsState;
  context: AdvisoryContext;
  generation: number;
  attempted: boolean;
  cache: Map<ActionWindowTab, ActionWindowsState>;
  cachedContextKey: string;
  setContext: (context: AdvisoryContext) => void;
  selectTab: (tab: ActionWindowTab) => void;
  refresh: () => Promise<void>;
  invalidate: () => void;
}

function contextKeyOf(context: AdvisoryContext): string {
  // Including the UTC date stops a window cached yesterday being served as
  // today's or tomorrow's.
  const day = new Date().toISOString().slice(0, 10);
  return `${context.mode}|${context.location.coordKey()}|${context.profile.crop}|${context.profile.growthStage}|${context.profile.soilType}|${context.profile.irrigationType}|${day}`;
}

/// Maps one `/advisory` payload onto the state for `tab`.
///
/// Each day reads **its own** decision (`windows[i].ai.overall`), so a global
/// highest-confidence verdict is never presented as a specific day's answer.
export function stateForTab(
  tab: ActionWindowTab,
  data: Record<string, unknown>,
  locationLabel: string,
  verifiedAt: Date,
): ActionWindowsState {
  const windows = jsonList(data["windows"]);
  const ai = jsonMap(data["ai"]);
  const backendSummary = jsonString(data["summary"]) ?? "";

  const windowAt = (index: number): Record<string, unknown> | null =>
    index < windows.length ? jsonMap(windows[index]) : null;

  const hourlyOf = (window: Record<string, unknown> | null, key: string): HourlySuitability[] => {
    const hourly = jsonMap(window?.["hourly"]) ?? {};
    return collapseHourlyCells(jsonList(hourly[key]));
  };

  const bestWindowOf = (window: Record<string, unknown> | null): string =>
    jsonString(window?.["best_window"]) ?? "";

  const today = windowAt(0);
  const tomorrow = windowAt(1);

  const dayState = (target: ActionWindowTab, window: Record<string, unknown> | null): ActionWindowsState => {
    if (window === null) return unavailableActionWindows(target, locationLabel);
    const decision = dayDecisionOrNone(window);
    const band = decision.choice ?? jsonString(window?.["suitability"]);
    return {
      selectedTab: target,
      irrigationWindows: hourlyOf(window, "irrigation"),
      sprayingWindows: hourlyOf(window, "spraying"),
      fieldWorkWindows: hourlyOf(window, "field_work"),
      fieldWorkStatus: bestWindowOf(window),
      summaryVerdict: verdictTextForBand(band),
      summaryExplanation: jsonString(window?.["summary"]) ?? backendSummary,
      status: AdvisoryStatus.Ready,
      // The System One badge is shown only when *this* day carries a
      // decision, with that day's confidence — not a global mean.
      source: dayDecisionIsPresent(decision) ? AdvisorySource.SystemOne : AdvisorySource.Thresholds,
      aiConfidence: decision.confidence,
      locationLabel,
      asOfUtc: verifiedAt,
    };
  };

  switch (tab) {
    case ActionWindowTab.Today:
      return dayState(ActionWindowTab.Today, today);
    case ActionWindowTab.Tomorrow:
      return dayState(ActionWindowTab.Tomorrow, tomorrow);
    case ActionWindowTab.SevenDay:
      if (windows.length === 0) return unavailableActionWindows(tab, locationLabel);
      // A week overview is legitimately an aggregate, so the backend's
      // overall verdict and mean confidence belong here.
      return {
        selectedTab: ActionWindowTab.SevenDay,
        irrigationWindows: dailySuitabilityCells(windows),
        sprayingWindows: dailySuitabilityCells(windows),
        fieldWorkWindows: dailySuitabilityCells(windows),
        fieldWorkStatus: "Next 7 days",
        summaryVerdict: "This week at a glance",
        summaryExplanation: backendSummary,
        status: AdvisoryStatus.Ready,
        source: aiApplied(ai) ? AdvisorySource.SystemOne : AdvisorySource.Thresholds,
        aiConfidence: aiMeanConfidence(ai),
        locationLabel,
        asOfUtc: verifiedAt,
      };
  }
}

const DEFAULT_ADVISORY_CONTEXT: AdvisoryContext = {
  location: DEFAULT_LOCATION,
  profile: DEFAULT_FARM_PROFILE,
  mode: "everyone",
};

export const useActionWindowsStore = create<ActionWindowsStore>((set, get) => ({
  state: unavailableActionWindows(ActionWindowTab.Today),
  context: DEFAULT_ADVISORY_CONTEXT,
  generation: 0,
  attempted: false,
  cache: new Map(),
  cachedContextKey: "",

  setContext: (context) => {
    if (contextKeyOf(context) !== contextKeyOf(get().context)) {
      get().invalidate();
      set({ state: unavailableActionWindows(get().state.selectedTab, context.location.name) });
    }
    set({ context });
  },

  selectTab: (tab) => {
    const store = get();
    const key = contextKeyOf(store.context);
    if (store.cachedContextKey !== key) {
      store.cache.clear();
      set({ cache: new Map(), cachedContextKey: key, attempted: false });
    }
    const cached = get().cache.get(tab);
    if (cached !== undefined) {
      set({ state: cached });
      return;
    }
    // Nothing verified for this tab: show an honest loading or unavailable
    // state, never a bundled favourable pattern.
    set({
      state: {
        ...unavailableActionWindows(tab, store.context.location.name),
        status: get().attempted ? AdvisoryStatus.Unavailable : AdvisoryStatus.Loading,
      },
    });
    if (!get().attempted) void get().refresh();
  },

  refresh: async () => {
    const store = get();
    set({ attempted: true });
    const generation = store.generation + 1;
    set({ generation });
    const contextKey = contextKeyOf(store.context);
    set({ cachedContextKey: contextKey });
    const { location, profile, mode } = store.context;
    set((s) => ({ state: { ...s.state, status: AdvisoryStatus.Loading } }));
    try {
      const data = await ApiClient.get(ApiEndpoints.advisory, {
        lat: location.lat,
        lon: location.lon,
        crop: profile.crop,
        days: 7,
        mode,
        // Farm context refines the backend's System One scoring (the same
        // judgment differs by growth stage and soil).
        growth_stage: profile.growthStage,
        soil: profile.soilType,
        irrigation: profile.irrigationType,
      });
      // The user moved, edited their farm or crossed midnight while the
      // request was in flight — this result no longer describes the screen.
      if (get().generation !== generation || contextKeyOf(get().context) !== contextKey) return;
      const verifiedAt = new Date();
      const today = stateForTab(ActionWindowTab.Today, data, location.name, verifiedAt);
      const tomorrow = stateForTab(ActionWindowTab.Tomorrow, data, location.name, verifiedAt);
      const sevenDay = stateForTab(ActionWindowTab.SevenDay, data, location.name, verifiedAt);
      const cache = new Map<ActionWindowTab, ActionWindowsState>([
        [ActionWindowTab.Today, today],
        [ActionWindowTab.Tomorrow, tomorrow],
        [ActionWindowTab.SevenDay, sevenDay],
      ]);
      set({ cache, state: cache.get(get().state.selectedTab) ?? today });
    } catch {
      if (get().generation !== generation) return;
      get().invalidate();
      const tab = get().state.selectedTab;
      const unavailable = unavailableActionWindows(tab, get().context.location.name);
      set({ state: unavailable, cache: new Map([[tab, unavailable]]) });
    }
  },

  invalidate: () => {
    set((s) => ({ cache: new Map(), attempted: false, generation: s.generation + 1 }));
  },
}));
