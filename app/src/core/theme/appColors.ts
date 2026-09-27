/// WeatherGPT visual system — deep navy + teal/sky accents. Port of
/// `lib/core/theme/app_colors.dart`.

export const AppColors = {
  bgPrimary: "#0B1220",
  bgElevated: "#101A2C",
  surfaceCard: "#152036",
  surfaceCardAlt: "#1A2740",
  borderSubtle: "#243149",
  borderStrong: "#334155",

  // Brand
  accent: "#2DD4BF",
  accentSoft: "#5EEAD4",
  sky: "#38BDF8",
  skyDeep: "#0EA5E9",

  // Personas
  farmerGreen: "#34D399",
  farmerGreenGlow: "#6EE7B7",
  researcherBlue: "#60A5FA",
  researcherBlueGlow: "#93C5FD",

  // Status
  statusRed: "#F87171",
  statusAmber: "#FBBF24",
  statusGreenText: "#34D399",

  // Text
  textPrimary: "#F8FAFC",
  textSecondary: "#94A3B8",
  textTertiary: "#64748B",

  // CTA
  ctaWhite: "#F8FAFC",
  ctaTextDark: "#0B1220",

  gradientHero: ["#0F2744", "#0B3B3A", "#0B1220"] as const,
  gradientAccent: ["#2DD4BF", "#38BDF8"] as const,

  // ---- Glass system -------------------------------------------------------
  // Frosted surfaces used across the app. Fills are translucent dark navy so
  // white text stays readable on every sky — including bright daylight.
  glassFill: "rgba(16, 25, 48, 0.60)",
  glassFillStrong: "rgba(16, 25, 48, 0.75)",
  glassBorder: "rgba(255, 255, 255, 0.12)",
  glassBorderStrong: "rgba(255, 255, 255, 0.20)",

  /// Deep scrim laid over the sky gradient so text-heavy screens stay
  /// readable without hiding the atmosphere.
  scrim: "rgba(11, 18, 32, 0.70)",

  glassBlurRadius: 24,
} as const;

export type AppColorName = keyof typeof AppColors;
