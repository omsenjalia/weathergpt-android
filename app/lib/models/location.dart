/// Location models and presets, extracted from the home/explore providers
/// so any layer can reference them without provider machinery.
library;

class AppLocation {
  const AppLocation({
    required this.name,
    required this.lat,
    required this.lon,
  });

  final String name;
  final double lat;
  final double lon;

  Map<String, dynamic> toMap() => {'name': name, 'lat': lat, 'lon': lon};

  factory AppLocation.fromMap(Map<dynamic, dynamic> map) => AppLocation(
        name: map['name'] as String? ?? 'Ahmedabad, Gujarat',
        lat: (map['lat'] as num?)?.toDouble() ?? 23.0225,
        lon: (map['lon'] as num?)?.toDouble() ?? 72.5714,
      );
}

class SavedLocation {
  const SavedLocation({required this.name, required this.lat, required this.lon});

  final String name;
  final double lat;
  final double lon;

  Map<String, dynamic> toMap() => {'name': name, 'lat': lat, 'lon': lon};

  factory SavedLocation.fromMap(Map<dynamic, dynamic> map) => SavedLocation(
        name: map['name'] as String,
        lat: (map['lat'] as num).toDouble(),
        lon: (map['lon'] as num).toDouble(),
      );
}

const kDefaultLocation = AppLocation(
  name: 'Ahmedabad, Gujarat',
  lat: 23.0225,
  lon: 72.5714,
);

const kPresetLocations = <AppLocation>[
  AppLocation(name: 'Ahmedabad, Gujarat', lat: 23.0225, lon: 72.5714),
  AppLocation(name: 'Mumbai, Maharashtra', lat: 19.0760, lon: 72.8777),
  AppLocation(name: 'Delhi, India', lat: 28.6139, lon: 77.2090),
  AppLocation(name: 'Bengaluru, Karnataka', lat: 12.9716, lon: 77.5946),
  AppLocation(name: 'Chennai, Tamil Nadu', lat: 13.0827, lon: 80.2707),
  AppLocation(name: 'Kolkata, West Bengal', lat: 22.5726, lon: 88.3639),
  AppLocation(name: 'Hyderabad, Telangana', lat: 17.3850, lon: 78.4867),
  AppLocation(name: 'Pune, Maharashtra', lat: 18.5204, lon: 73.8567),
  AppLocation(name: 'Jaipur, Rajasthan', lat: 26.9124, lon: 75.7873),
  AppLocation(name: 'Anand, Gujarat', lat: 22.5645, lon: 72.9289),
];
