/// Settings store — port of `lib/features/settings/providers/settings_provider.dart`.
/// Language, persona, units and TTS preferences, persisted to AsyncStorage.
/// The persona is stored as its canonical wire name; unknown values are
/// rejected rather than persisted, so a future build can never read a typo as
/// a privileged mode.

import { create } from "zustand";

import { setApiLanguage } from "../../core/services/apiClient";
import { AppMode, appModeFromName, appModeWire, AppModeException } from "../../core/models/appMode";
import { TtsVoiceSelection, ttsSelectionFromMap, ttsSelectionToMap, ttsSelectionIsValid } from "./models/ttsVoiceOption";
import { loadJson, saveJson, StorageKeys } from "../../lib/persistence";
import { isSupportedLanguage, LanguageCode, LANGUAGE_META } from "../../i18n";

export enum TemperatureUnit {
  Celsius = "celsius",
  Fahrenheit = "fahrenheit",
}

export interface SettingsState {
  displayName: string | null;
  email: string | null;
  language: LanguageCode;
  userPersona: string;
  units: TemperatureUnit;
  ttsVoiceLocale: string;
  ttsSpeed: number;
  /// Persisted voice choice per app language code ('en' -> selection).
  ttsVoices: Record<string, TtsVoiceSelection>;
  notificationsEnabled: Record<string, boolean>;
  hydrated: boolean;

  /// Validated product mode derived from the persisted persona string.
  /// A persona value this build does not recognise de-escalates to `everyone`;
  /// it never escalates.
  readonly mode: AppMode;
  readonly hasRecognisedPersona: boolean;
}

interface SettingsStore extends SettingsState {
  hydrate: () => Promise<void>;
  updateProfile: (name: string, email: string) => Promise<void>;
  updateLanguage: (code: LanguageCode) => Promise<void>;
  updatePersona: (persona: string) => Promise<void>;
  updateUnits: (units: TemperatureUnit) => Promise<void>;
  updateTtsSpeed: (speed: number) => Promise<void>;
  updateTtsVoiceLocale: (locale: string) => Promise<void>;
  updateTtsVoice: (langCode: string, selection: TtsVoiceSelection) => Promise<void>;
  clearTtsVoice: (langCode: string) => Promise<void>;
  updateNotificationPref: (key: string, enabled: boolean) => Promise<void>;
}

function computeMode(userPersona: string): AppMode {
  return appModeFromName(userPersona) ?? "everyone";
}

function persist(state: SettingsState): void {
  void saveJson(StorageKeys.settings, {
    displayName: state.displayName,
    email: state.email,
    language: state.language,
    userPersona: state.userPersona,
    units: state.units,
    ttsVoiceLocale: state.ttsVoiceLocale,
    ttsSpeed: state.ttsSpeed,
    ttsVoices: Object.fromEntries(
      Object.entries(state.ttsVoices).map(([k, v]) => [k, ttsSelectionToMap(v)]),
    ),
    notificationsEnabled: state.notificationsEnabled,
  });
}

export const useSettingsStore = create<SettingsStore>((set, get) => ({
  displayName: null,
  email: null,
  language: "en",
  userPersona: "everyone",
  units: TemperatureUnit.Celsius,
  ttsVoiceLocale: "en-US",
  ttsSpeed: 0.85,
  ttsVoices: {},
  notificationsEnabled: {
    weather_alerts: true,
    imd_warnings: true,
    daily_summary: false,
  },
  hydrated: false,
  mode: "everyone",
  hasRecognisedPersona: true,

  hydrate: async () => {
    if (get().hydrated) return;
    const raw = await loadJson<Record<string, unknown> | null>(StorageKeys.settings);
    const voices: Record<string, TtsVoiceSelection> = {};
    if (raw && typeof raw["ttsVoices"] === "object" && raw["ttsVoices"] !== null) {
      for (const [key, value] of Object.entries(raw["ttsVoices"] as Record<string, unknown>)) {
        if (value === null || typeof value !== "object") continue;
        const selection = ttsSelectionFromMap(value as Record<string, unknown>);
        if (ttsSelectionIsValid(selection)) voices[key] = selection;
      }
    }
    const language = isSupportedLanguage(raw?.["language"]) ? raw!["language"] as LanguageCode : "en";
    const persona = typeof raw?.["userPersona"] === "string" ? raw["userPersona"] as string : "everyone";
    setApiLanguage(language);
    set({
      displayName: typeof raw?.["displayName"] === "string" ? raw["displayName"] as string : null,
      email: typeof raw?.["email"] === "string" ? raw["email"] as string : null,
      language,
      userPersona: persona,
      mode: computeMode(persona),
      hasRecognisedPersona: appModeFromName(persona) !== null,
      units: raw?.["units"] === TemperatureUnit.Fahrenheit ? TemperatureUnit.Fahrenheit : TemperatureUnit.Celsius,
      ttsVoiceLocale: typeof raw?.["ttsVoiceLocale"] === "string" ? raw["ttsVoiceLocale"] as string : "en-US",
      ttsSpeed: typeof raw?.["ttsSpeed"] === "number" ? raw["ttsSpeed"] as number : 0.85,
      ttsVoices: voices,
      notificationsEnabled:
        raw && typeof raw["notificationsEnabled"] === "object" && raw["notificationsEnabled"] !== null
          ? raw["notificationsEnabled"] as Record<string, boolean>
          : { weather_alerts: true, imd_warnings: true, daily_summary: false },
      hydrated: true,
    });
  },

  updateProfile: async (name, email) => {
    set({ displayName: name, email });
    persist(get());
  },

  updateLanguage: async (code) => {
    set({ language: code, ttsVoiceLocale: LANGUAGE_META[code].ttsLocale });
    setApiLanguage(code);
    persist(get());
  },

  updatePersona: async (persona) => {
    const mode = appModeFromName(persona);
    if (mode === null) throw new AppModeException(persona);
    set({ userPersona: appModeWire(mode), mode, hasRecognisedPersona: true });
    persist(get());
  },

  updateUnits: async (units) => {
    set({ units });
    persist(get());
  },

  updateTtsSpeed: async (speed) => {
    set({ ttsSpeed: Number.isFinite(speed) ? Math.min(1, Math.max(0.3, speed)) : 0.85 });
    persist(get());
  },

  updateTtsVoiceLocale: async (locale) => {
    set({ ttsVoiceLocale: locale });
    persist(get());
  },

  updateTtsVoice: async (langCode, selection) => {
    const voices = { ...get().ttsVoices, [langCode]: selection };
    set({ ttsVoices: voices });
    persist(get());
  },

  clearTtsVoice: async (langCode) => {
    if (!(langCode in get().ttsVoices)) return;
    const voices = { ...get().ttsVoices };
    delete voices[langCode];
    set({ ttsVoices: voices });
    persist(get());
  },

  updateNotificationPref: async (key, enabled) => {
    const prefs = { ...get().notificationsEnabled, [key]: enabled };
    set({ notificationsEnabled: prefs });
    persist(get());
  },
}));

/// Selector mirroring the Dart `settings.mode` getter (zustand stores keep
/// plain state, so the derived value is exposed as a selector).
export function selectMode(state: SettingsState): AppMode {
  return computeMode(state.userPersona);
}
