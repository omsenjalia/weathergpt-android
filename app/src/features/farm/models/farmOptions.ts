/// Canonical farm-profile option catalogs — port of
/// `lib/features/farmer/models/farm_options.dart`.
///
/// These strings are **wire values**: `FarmProfile.crop`, `FarmProfile.soilType`
/// etc. are sent verbatim to `GET /advisory` and to `POST /chat` farm context,
/// so they stay in English and are never passed through the translator.

export const FARM_CROPS: readonly string[] = [
  "Wheat", "Rice", "Cotton", "Maize", "Sugarcane", "Soybean",
  "Groundnut", "Mustard", "Potato", "Onion", "Tomato", "Pulses",
];

export const GROWTH_STAGES: readonly string[] = [
  "Sowing", "Germination", "Vegetative", "Flowering", "Fruiting", "Maturity", "Harvest",
];

export const IRRIGATION_TYPES: readonly string[] = [
  "Borewell", "Canal", "Drip", "Sprinkler", "Rainfed",
];

export const SOIL_TYPES: readonly string[] = [
  "Loamy", "Clay", "Sandy", "Silty", "Black", "Red", "Alluvial",
];

/// Returns `options` with `current` guaranteed present, so a picker never
/// breaks when the stored value predates (or was typed outside) the catalog.
export function withCurrentOption(options: readonly string[], current: string): string[] {
  return options.includes(current) ? [...options] : [current, ...options];
}
