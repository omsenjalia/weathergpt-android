/// Canonical farm-profile option catalogs shared by the farmer onboarding step
/// and the farm profile editor.
///
/// These strings are **wire values**: `FarmProfile.crop`, `FarmProfile.soilType`
/// etc. are sent verbatim to `GET /advisory` (`crop`, `growth_stage`, `soil`,
/// `irrigation`) and to `POST /chat` farm context, so they stay in English and
/// are never passed through `.tr()`. Only the field *labels* are localized.
///
/// A single source of truth also prevents the editor crash where a stored value
/// was missing from a hardcoded dropdown list (`DropdownButtonFormField` throws
/// when `initialValue` is not among `items`).
library;

/// Crops the advisory backend recognises. Unknown crops degrade gracefully
/// server-side to generic guidance, so extending this list is safe.
const kFarmCrops = <String>[
  'Wheat',
  'Rice',
  'Cotton',
  'Maize',
  'Sugarcane',
  'Soybean',
  'Groundnut',
  'Mustard',
  'Potato',
  'Onion',
  'Tomato',
  'Pulses',
];

/// Growth stages in field order.
const kGrowthStages = <String>[
  'Sowing',
  'Germination',
  'Vegetative',
  'Flowering',
  'Fruiting',
  'Maturity',
  'Harvest',
];

/// Irrigation methods.
const kIrrigationTypes = <String>[
  'Borewell',
  'Canal',
  'Drip',
  'Sprinkler',
  'Rainfed',
];

/// Soil types, including common Indian soils.
const kSoilTypes = <String>[
  'Loamy',
  'Clay',
  'Sandy',
  'Silty',
  'Black',
  'Red',
  'Alluvial',
];

/// Returns [options] with [current] guaranteed present, so a dropdown never
/// throws when the stored value predates (or was typed outside) the catalog.
List<String> withCurrentOption(List<String> options, String current) =>
    options.contains(current) ? options : <String>[current, ...options];
