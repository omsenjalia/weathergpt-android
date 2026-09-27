/// Explore stores — ports of
/// `lib/features/explore/providers/saved_locations_provider.dart` and
/// `lib/features/explore/providers/map_provider.dart`.

import { create } from "zustand";

import { loadJson, saveJson, StorageKeys } from "../../lib/persistence";
import { SavedLocation } from "../../models/location";

interface SavedLocationsStore {
  locations: SavedLocation[];
  hydrated: boolean;
  hydrate: () => Promise<void>;
  add: (location: SavedLocation) => Promise<void>;
  remove: (location: SavedLocation) => Promise<void>;
}

export const useSavedLocationsStore = create<SavedLocationsStore>((set, get) => ({
  locations: [],
  hydrated: false,

  hydrate: async () => {
    if (get().hydrated) return;
    const stored = await loadJson<unknown[] | null>(StorageKeys.savedLocations);
    const locations = (Array.isArray(stored) ? stored : [])
      .filter((item): item is Record<string, unknown> => item !== null && typeof item === "object")
      .map((item) => SavedLocation.fromMap(item));
    set({ locations, hydrated: true });
  },

  add: async (location) => {
    if (get().locations.some((item) => item.name === location.name)) return;
    const locations = [...get().locations, location];
    set({ locations });
    await saveJson(StorageKeys.savedLocations, locations.map((item) => item.toMap()));
  },

  remove: async (location) => {
    const locations = get().locations.filter((item) => item.name !== location.name);
    set({ locations });
    await saveJson(StorageKeys.savedLocations, locations.map((item) => item.toMap()));
  },
}));

// ---------------------------------------------------------------------------
// Windy map

/// Windy embed overlay ids (must match embed.windy.com `overlay=` values).
export enum MapLayer {
  Wind = "wind",
  Rain = "rain",
  Temp = "temp",
  Clouds = "clouds",
  Radar = "radar",
  Waves = "waves",
  Pressure = "pressure",
  Thunder = "thunder",
  Snow = "snow",
  Humidity = "humidity",
  Cape = "cape",
}

export enum MapProduct {
  Ecmwf = "ecmwf",
  Gfs = "gfs",
  Icon = "icon",
  Nems = "nems",
}

export const MAP_LAYER_LABEL: Record<MapLayer, string> = {
  [MapLayer.Wind]: "Wind",
  [MapLayer.Rain]: "Rain",
  [MapLayer.Temp]: "Temp",
  [MapLayer.Clouds]: "Clouds",
  [MapLayer.Radar]: "Radar",
  [MapLayer.Waves]: "Waves",
  [MapLayer.Pressure]: "Pressure",
  [MapLayer.Thunder]: "Thunder",
  [MapLayer.Snow]: "Snow",
  [MapLayer.Humidity]: "Humidity",
  [MapLayer.Cape]: "CAPE",
};

export const MAP_ALL_LAYERS: readonly MapLayer[] = [
  MapLayer.Wind, MapLayer.Rain, MapLayer.Temp, MapLayer.Clouds, MapLayer.Radar,
  MapLayer.Waves, MapLayer.Pressure, MapLayer.Thunder, MapLayer.Snow,
  MapLayer.Humidity, MapLayer.Cape,
];

export interface MapState {
  activeLayer: MapLayer;
  product: MapProduct;
  lat: number;
  lon: number;
  zoom: number;
  /// Windy's own layer menu (researcher control). Off by default.
  showMenu?: boolean;
  /// Location marker at the centre. On by default.
  showMarker?: boolean;
}

/// Layers offered to everyone; researchers get the full catalog.
export const MAP_BASIC_LAYERS: readonly MapLayer[] = [
  MapLayer.Wind, MapLayer.Rain, MapLayer.Temp, MapLayer.Clouds, MapLayer.Radar, MapLayer.Pressure,
];

export const MAP_PRODUCTS: readonly MapProduct[] = [MapProduct.Ecmwf, MapProduct.Gfs, MapProduct.Icon, MapProduct.Nems];

interface MapStore extends MapState {
  setLayer: (layer: MapLayer) => void;
  setProduct: (product: MapProduct) => void;
  setCenter: (lat: number, lon: number, zoom?: number) => void;
  setZoom: (zoom: number) => void;
  zoomIn: () => void;
  zoomOut: () => void;
  toggleMenu: () => void;
  toggleMarker: () => void;
}

function clampZoom(zoom: number): number {
  return Math.min(Math.max(zoom, 3), 12);
}

export const useMapStore = create<MapStore>((set, get) => ({
  activeLayer: MapLayer.Wind,
  product: MapProduct.Ecmwf,
  lat: 23.0225,
  lon: 72.5714,
  zoom: 6,
  showMenu: false,
  showMarker: true,

  setLayer: (layer) => set({ activeLayer: layer }),
  setProduct: (product) => set({ product }),
  setCenter: (lat, lon, zoom) => set({ lat, lon, zoom: zoom ?? get().zoom }),
  setZoom: (zoom) => set({ zoom: clampZoom(zoom) }),
  zoomIn: () => get().setZoom(get().zoom + 1),
  zoomOut: () => get().setZoom(get().zoom - 1),
  toggleMenu: () => set({ showMenu: !get().showMenu }),
  toggleMarker: () => set({ showMarker: !get().showMarker }),
}));

/// Builds the windy.com embed URL for the current map state.
export function windyEmbedUrl(state: MapState): string {
  return `https://embed.windy.com/embed2.html?lat=${state.lat}&lon=${state.lon}&detailLat=${state.lat}&detailLon=${state.lon}&zoom=${state.zoom}&product=${state.product}&level=surface&overlay=${state.activeLayer}&menu=${state.showMenu === true ? "true" : ""}&message=true&marker=${state.showMarker === false ? "" : "true"}&calendar=now&pressure=&type=map&location=coordinates&detail=&metricWind=default&metricTemp=default&radarRange=-1`;
}

/// Google DeepMind Weather Lab (WeatherNext) centred on the map position.
/// It needs a Google sign-in, so the app opens it in the system browser.
export function weatherLabUrl(state: Pick<MapState, "lat" | "lon" | "zoom">): string {
  const zoom = (Math.min(Math.max(state.zoom, 3), 12) * 0.85).toFixed(2);
  return `https://deepmind.google.com/science/weatherlab?cyclones_enabled=false&weather_enabled=true&weather_model=weathernext3&weather_layers=total_precipitation_1hr_mean&zoom=${zoom}&center=${state.lat},${state.lon}`;
}
