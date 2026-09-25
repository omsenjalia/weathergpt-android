class FarmProfile {
  const FarmProfile({
    required this.location,
    required this.crop,
    required this.growthStage,
    required this.farmSizeAcres,
    required this.irrigationType,
    required this.soilType,
  });

  final String location;
  final String crop;
  final String growthStage;
  final double farmSizeAcres;
  final String irrigationType;
  final String soilType;

  static const defaultProfile = FarmProfile(
    location: 'Anand, Gujarat',
    crop: 'Wheat',
    growthStage: 'Flowering',
    farmSizeAcres: 4,
    irrigationType: 'Borewell',
    soilType: 'Loamy',
  );

  FarmProfile copyWith(
          {String? location,
          String? crop,
          String? growthStage,
          double? farmSizeAcres,
          String? irrigationType,
          String? soilType}) =>
      FarmProfile(
        location: location ?? this.location,
        crop: crop ?? this.crop,
        growthStage: growthStage ?? this.growthStage,
        farmSizeAcres: farmSizeAcres ?? this.farmSizeAcres,
        irrigationType: irrigationType ?? this.irrigationType,
        soilType: soilType ?? this.soilType,
      );

  Map<String, dynamic> toMap() => {
        'location': location,
        'crop': crop,
        'growthStage': growthStage,
        'farmSizeAcres': farmSizeAcres,
        'irrigationType': irrigationType,
        'soilType': soilType,
      };

  factory FarmProfile.fromMap(Map<dynamic, dynamic> map) => FarmProfile(
        location: map['location'] as String? ?? defaultProfile.location,
        crop: map['crop'] as String? ?? defaultProfile.crop,
        growthStage:
            map['growthStage'] as String? ?? defaultProfile.growthStage,
        farmSizeAcres: (map['farmSizeAcres'] as num?)?.toDouble() ??
            defaultProfile.farmSizeAcres,
        irrigationType:
            map['irrigationType'] as String? ?? defaultProfile.irrigationType,
        soilType: map['soilType'] as String? ?? defaultProfile.soilType,
      );
}
