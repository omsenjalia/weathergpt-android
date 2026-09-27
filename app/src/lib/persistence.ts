/// Persistence layer — replaces Hive boxes with AsyncStorage (the RN
/// equivalent). Every store reads/writes plain JSON under a namespaced key.

import AsyncStorage from "@react-native-async-storage/async-storage";

export async function loadJson<T>(key: string): Promise<T | null> {
  try {
    const raw = await AsyncStorage.getItem(key);
    if (raw === null) return null;
    return JSON.parse(raw) as T;
  } catch {
    return null;
  }
}

export async function saveJson(key: string, value: unknown): Promise<void> {
  try {
    await AsyncStorage.setItem(key, JSON.stringify(value));
  } catch {
    // Storage full or unavailable — the app keeps working in memory only.
  }
}

export const StorageKeys = {
  settings: "wg.settings",
  selectedLocation: "wg.selected_location",
  locationPrompted: "wg.location_prompted",
  farmProfile: "wg.farm_profile",
  farmProfileCompleted: "wg.farm_profile_completed",
  savedLocations: "wg.saved_locations",
  onboardingComplete: "wg.onboarding_complete",
  developerOptions: "wg.developer_options",
  locationBannerDismissed: "wg.location_banner_dismissed",
} as const;
