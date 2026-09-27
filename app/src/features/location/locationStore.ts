/// Location store — port of `lib/features/home/providers/location_provider.dart`.
/// Holds the active home location; on first launch asks the OS for location
/// permission once and, when granted, resolves the real position.
///
/// Behaviour contract (unchanged from the Flutter app):
/// - Runs at most once per install (`location_prompted` flag), so a user who
///   denied is never nagged again.
/// - Never overrides an explicit choice (`selected_location` already set).
/// - Every failure path silently keeps the default location; the home-screen
///   prompt bar is the visible fallback.
///
import { create } from "zustand";
import * as Location from "expo-location";

import { AppLocation, DEFAULT_LOCATION } from "../../models/location";

export { AppLocation, DEFAULT_LOCATION };
import { GeocodingService } from "../../core/services/geocodingService";
import { loadJson, saveJson, StorageKeys } from "../../lib/persistence";

interface LocationStore {
  location: AppLocation;
  locationPrompted: boolean;
  hydrated: boolean;
  hasSelection: boolean;
  generation: number;
  hydrate: () => Promise<void>;
  select: (location: AppLocation) => Promise<void>;
  maybeAutoLocate: () => Promise<void>;
  selectFromGps: () => Promise<AppLocation | null>;
  canAskOs: () => Promise<boolean>;
}

async function currentPosition(): Promise<{ lat: number; lon: number } | null> {
  try {
    const permission = await Location.requestForegroundPermissionsAsync();
    if (!permission.granted) return null;
    let timer: ReturnType<typeof setTimeout> | undefined;
    try {
      const position = await Promise.race([
        Location.getCurrentPositionAsync({ accuracy: Location.Accuracy.Balanced }),
        new Promise<null>((resolve) => { timer = setTimeout(() => resolve(null), 12_000); }),
      ]);
      return position ? { lat: position.coords.latitude, lon: position.coords.longitude } : null;
    } finally {
      clearTimeout(timer);
    }
  } catch {
    return null;
  }
}

export const useLocationStore = create<LocationStore>((set, get) => ({
  location: DEFAULT_LOCATION,
  locationPrompted: false,
  hydrated: false,
  hasSelection: false,
  generation: 0,

  hydrate: async () => {
    if (get().hydrated) return;
    const [stored, prompted] = await Promise.all([
      loadJson<Record<string, unknown> | null>(StorageKeys.selectedLocation),
      loadJson<boolean | null>(StorageKeys.locationPrompted),
    ]);
    set({
      location: stored !== null ? AppLocation.fromMap(stored) : DEFAULT_LOCATION,
      hasSelection: stored !== null,
      locationPrompted: prompted === true,
      hydrated: true,
    });
  },

  select: async (location) => {
    set((s) => ({ location, hasSelection: true, generation: s.generation + 1 }));
    await saveJson(StorageKeys.selectedLocation, location.toMap());
  },

  maybeAutoLocate: async () => {
    await get().hydrate();
    if (get().locationPrompted || get().hasSelection) return;
    set({ locationPrompted: true });
    await saveJson(StorageKeys.locationPrompted, true);
    if (get().hasSelection) return;
    await get().selectFromGps();
  },

  selectFromGps: async () => {
    const generation = get().generation + 1;
    set({ generation });
    const pos = await currentPosition();
    if (pos === null) return null;
    const name = await GeocodingService.reverseName(pos.lat, pos.lon);
    const loc = new AppLocation(name, pos.lat, pos.lon);
    if (get().generation !== generation) return null;
    await get().select(loc);
    return loc;
  },

  canAskOs: async () => {
    try {
      const permission = await Location.getForegroundPermissionsAsync();
      return permission.granted || permission.canAskAgain;
    } catch { return false; }
  },
}));
