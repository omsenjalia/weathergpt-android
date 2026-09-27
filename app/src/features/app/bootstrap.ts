/// App-level wiring that used to live inline in the root layout: store
/// hydration, keeping chat/voice request context in sync with settings, and
/// the live sky palette.

import { useEffect, useMemo, useState } from "react";
import {
  useFonts,
  Manrope_300Light,
  Manrope_400Regular,
  Manrope_500Medium,
  Manrope_600SemiBold,
  Manrope_700Bold,
  Manrope_800ExtraBold,
} from "@expo-google-fonts/manrope";

import { selectMode, useSettingsStore } from "../settings/settingsStore";
import { useDeveloperOptionsStore } from "../settings/developerOptionsStore";
import { useLocationStore } from "../location/locationStore";
import { useFarmProfileStore } from "../farm/farmStores";
import { useSavedLocationsStore } from "../explore/exploreStores";
import { useChatStore } from "../chat/chatStore";
import { useVoiceStore } from "../voice/voiceStore";
import { SkyScene, skyScene, useWeatherStore } from "../weather/weatherStore";
import { SpeechService } from "../voice/speechService";

/// Hydrates every persisted store and loads fonts. Resolves once; a failed
/// font load falls back to the system font rather than blocking the app.
export function useAppReady(): boolean {
  const [hydrated, setHydrated] = useState(false);
  const [fontsLoaded, fontError] = useFonts({
    Manrope_300Light,
    Manrope_400Regular,
    Manrope_500Medium,
    Manrope_600SemiBold,
    Manrope_700Bold,
    Manrope_800ExtraBold,
  });

  useEffect(() => {
    void Promise.all([
      useSettingsStore.getState().hydrate(),
      useDeveloperOptionsStore.getState().hydrate(),
      useLocationStore.getState().hydrate(),
      useFarmProfileStore.getState().hydrate(),
      useSavedLocationsStore.getState().hydrate(),
    ]).finally(() => setHydrated(true));
    // Non-blocking: speech stays on-device until the backend confirms Bhashini.
    void SpeechService.probe();
  }, []);

  return hydrated && (fontsLoaded || fontError !== null);
}

/// Pushes the current language, persona, location and farm profile into the
/// chat and voice stores. Their `setContext` resets any in-flight request
/// when the context actually changes (generation guard).
export function useAgentContextSync(enabled: boolean): void {
  const language = useSettingsStore((s) => s.language);
  const userPersona = useSettingsStore((s) => s.userPersona);
  const ttsVoiceLocale = useSettingsStore((s) => s.ttsVoiceLocale);
  const ttsSpeed = useSettingsStore((s) => s.ttsSpeed);
  const ttsGender = useSettingsStore((s) => s.ttsGender);
  const location = useLocationStore((s) => s.location);
  const profile = useFarmProfileStore((s) => s.profile);
  const profileCompleted = useFarmProfileStore((s) => s.completed);

  useEffect(() => {
    if (!enabled) return;
    const persona = selectMode({ ...useSettingsStore.getState(), userPersona });
    const context = { language, userPersona: persona, location, profile, profileCompleted };
    useChatStore.getState().setContext(context);
    useVoiceStore.getState().setContext({ ...context, ttsVoiceLocale, ttsSpeed, ttsGender });
  }, [enabled, language, userPersona, ttsVoiceLocale, ttsSpeed, ttsGender, location, profile, profileCompleted]);
}

/// Sky scene (period, condition, palette) from wall-clock time and the live
/// snapshot, re-evaluated every minute so dawn and dusk transition without a
/// refresh.
export function useSkyScene(): SkyScene {
  const snapshot = useWeatherStore((s) => s.snapshot);
  const forcePeriod = useDeveloperOptionsStore((s) => (s.enabled ? s.forcePeriod : null));
  const forceSky = useDeveloperOptionsStore((s) => (s.enabled ? s.forceSky : null));
  const [now, setNow] = useState(() => new Date());

  useEffect(() => {
    const timer = setInterval(() => setNow(new Date()), 60_000);
    return () => clearInterval(timer);
  }, []);

  return useMemo(() => skyScene(now, snapshot, { forcePeriod, forceSky }), [now, snapshot, forcePeriod, forceSky]);
}
