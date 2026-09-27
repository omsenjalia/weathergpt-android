/// Location models and presets — port of `lib/models/location.dart`.

export class AppLocation {
  constructor(
    readonly name: string,
    readonly lat: number,
    readonly lon: number,
  ) {}

  toMap(): Record<string, unknown> {
    return { name: this.name, lat: this.lat, lon: this.lon };
  }

  static fromMap(map: Record<string, unknown>): AppLocation {
    const lat = typeof map["lat"] === "number" ? map["lat"] : 23.0225;
    const lon = typeof map["lon"] === "number" ? map["lon"] : 72.5714;
    const name = typeof map["name"] === "string" ? map["name"] : "Ahmedabad, Gujarat";
    return new AppLocation(name, lat, lon);
  }

  /// `lat,lon` — used in advisory cache keys.
  coordKey(): string {
    return `${this.lat},${this.lon}`;
  }
}

export class SavedLocation {
  constructor(
    readonly name: string,
    readonly lat: number,
    readonly lon: number,
  ) {}

  toMap(): Record<string, unknown> {
    return { name: this.name, lat: this.lat, lon: this.lon };
  }

  static fromMap(map: Record<string, unknown>): SavedLocation {
    return new SavedLocation(
      String(map["name"] ?? ""),
      Number(map["lat"] ?? 0),
      Number(map["lon"] ?? 0),
    );
  }
}

export const DEFAULT_LOCATION = new AppLocation("Ahmedabad, Gujarat", 23.0225, 72.5714);

export const PRESET_LOCATIONS: readonly AppLocation[] = [
  new AppLocation("Ahmedabad, Gujarat", 23.0225, 72.5714),
  new AppLocation("Mumbai, Maharashtra", 19.076, 72.8777),
  new AppLocation("Delhi, India", 28.6139, 77.209),
  new AppLocation("Bengaluru, Karnataka", 12.9716, 77.5946),
  new AppLocation("Chennai, Tamil Nadu", 13.0827, 80.2707),
  new AppLocation("Kolkata, West Bengal", 22.5726, 88.3639),
  new AppLocation("Hyderabad, Telangana", 17.385, 78.4867),
  new AppLocation("Pune, Maharashtra", 18.5204, 73.8567),
  new AppLocation("Jaipur, Rajasthan", 26.9124, 75.7873),
  new AppLocation("Anand, Gujarat", 22.5645, 72.9289),
];
