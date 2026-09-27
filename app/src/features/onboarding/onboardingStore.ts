/// Onboarding store — port of
/// `lib/features/onboarding/providers/onboarding_provider.dart`.

import { create } from "zustand";

import { saveJson, StorageKeys } from "../../lib/persistence";
import { LANGUAGE_META, LanguageCode } from "../../i18n";
import { useSettingsStore } from "../settings/settingsStore";
import { setApiLanguage } from "../../core/services/apiClient";

export interface OnboardingState {
  selectedLanguage: LanguageCode;
  selectedPersona: string;
  currentStep: number;
}

interface OnboardingStore extends OnboardingState {
  selectLanguage: (code: LanguageCode) => void;
  selectPersona: (persona: string) => void;
  completeOnboarding: () => Promise<void>;
}

export const useOnboardingStore = create<OnboardingStore>((set, get) => ({
  selectedLanguage: "en",
  selectedPersona: "everyone",
  currentStep: 0,

  selectLanguage: (code) => set({ selectedLanguage: code, currentStep: 1 }),

  selectPersona: (persona) => set({ selectedPersona: persona, currentStep: 2 }),

  completeOnboarding: async () => {
    const state = get();
    await Promise.all([
      saveJson(StorageKeys.onboardingComplete, true),
      saveJson(StorageKeys.settings, {
        ...flattenSettings(),
        language: state.selectedLanguage,
        ttsVoiceLocale: LANGUAGE_META[state.selectedLanguage].ttsLocale,
        userPersona: state.selectedPersona,
      }),
    ]);
    // Sync the live stores so the first home fetch already uses the chosen
    // language and mode (port of syncSettingsAfterOnboarding).
    setApiLanguage(state.selectedLanguage);
    await useSettingsStore.getState().hydrate();
    await useSettingsStore.getState().updateLanguage(state.selectedLanguage);
    await useSettingsStore.getState().updatePersona(state.selectedPersona);
    await useSettingsStore.getState().updateTtsVoiceLocale(LANGUAGE_META[state.selectedLanguage].ttsLocale);
  },
}));

function flattenSettings(): Record<string, unknown> {
  const settings = useSettingsStore.getState();
  return {
    displayName: settings.displayName,
    email: settings.email,
    language: settings.language,
    userPersona: settings.userPersona,
    units: settings.units,
    ttsVoiceLocale: settings.ttsVoiceLocale,
    ttsSpeed: settings.ttsSpeed,
    ttsVoices: {},
    notificationsEnabled: settings.notificationsEnabled,
  };
}

export function isOnboardingComplete(): Promise<boolean> {
  return import("../../lib/persistence").then(({ loadJson }) => loadJson<boolean | null>(StorageKeys.onboardingComplete).then((v) => v === true));
}
