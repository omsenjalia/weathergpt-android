/// Farm profile model — port of
/// `lib/features/farmer/models/farm_profile_model.dart`.

export interface FarmProfile {
  location: string;
  crop: string;
  growthStage: string;
  farmSizeAcres: number;
  irrigationType: string;
  soilType: string;
}

export const DEFAULT_FARM_PROFILE: FarmProfile = {
  location: "Anand, Gujarat",
  crop: "Wheat",
  growthStage: "Flowering",
  farmSizeAcres: 4,
  irrigationType: "Borewell",
  soilType: "Loamy",
};

export function farmProfileFromMap(map: Record<string, unknown> | null | undefined): FarmProfile {
  if (!map) return { ...DEFAULT_FARM_PROFILE };
  return {
    location: typeof map["location"] === "string" ? map["location"] : DEFAULT_FARM_PROFILE.location,
    crop: typeof map["crop"] === "string" ? map["crop"] : DEFAULT_FARM_PROFILE.crop,
    growthStage: typeof map["growthStage"] === "string" ? map["growthStage"] : DEFAULT_FARM_PROFILE.growthStage,
    farmSizeAcres: typeof map["farmSizeAcres"] === "number" ? map["farmSizeAcres"] : DEFAULT_FARM_PROFILE.farmSizeAcres,
    irrigationType: typeof map["irrigationType"] === "string" ? map["irrigationType"] : DEFAULT_FARM_PROFILE.irrigationType,
    soilType: typeof map["soilType"] === "string" ? map["soilType"] : DEFAULT_FARM_PROFILE.soilType,
  };
}

export function farmProfileToMap(profile: FarmProfile): Record<string, unknown> {
  return {
    location: profile.location,
    crop: profile.crop,
    growthStage: profile.growthStage,
    farmSizeAcres: profile.farmSizeAcres,
    irrigationType: profile.irrigationType,
    soilType: profile.soilType,
  };
}
