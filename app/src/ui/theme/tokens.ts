/// Design tokens — the single source of truth for colour, type, spacing,
/// radius and motion. Screens and components consume these semantic names;
/// raw hex values never appear outside this file (sky gradients excepted,
/// which come from the atmosphere engine).

import { Platform, TextStyle } from "react-native";

// ---------------------------------------------------------------------------
// Colour

const palette = {
  navy950: "#060B16",
  navy900: "#0A1120",
  navy850: "#0E1628",
  navy800: "#131D33",
  slate400: "#94A3B8",
  slate500: "#64748B",
  teal300: "#5EEAD4",
  teal400: "#2DD4BF",
  sky300: "#7DD3FC",
  sky400: "#38BDF8",
  green400: "#4ADE80",
  amber400: "#FBBF24",
  red400: "#F87171",
  blue400: "#60A5FA",
  white: "#FFFFFF",
} as const;

export const Colors = {
  // Canvas
  canvas: palette.navy900,
  canvasDeep: palette.navy950,
  surfaceSolid: palette.navy850,
  surfaceRaised: palette.navy800,

  // Translucent surfaces laid over the live sky
  surface: "rgba(9, 15, 30, 0.42)",
  surfaceStrong: "rgba(9, 15, 30, 0.62)",
  surfacePressed: "rgba(255, 255, 255, 0.08)",
  surfaceInset: "rgba(255, 255, 255, 0.06)",
  hairline: "rgba(255, 255, 255, 0.10)",
  hairlineStrong: "rgba(255, 255, 255, 0.18)",
  scrimTop: "rgba(6, 11, 22, 0.18)",
  scrimBottom: "rgba(6, 11, 22, 0.62)",
  overlay: "rgba(3, 6, 14, 0.72)",

  // Text
  text: "#F8FAFC",
  textSecondary: "rgba(241, 245, 249, 0.72)",
  textTertiary: "rgba(241, 245, 249, 0.50)",
  textInverse: palette.navy950,

  // Brand — one accent, used for primary actions and selection only
  accent: palette.teal400,
  accentSoft: "rgba(45, 212, 191, 0.16)",
  accentText: palette.teal300,
  onAccent: palette.navy950,

  // Data colours
  rain: palette.sky300,
  tempWarm: "#FDBA74",
  tempCool: palette.sky400,

  // Status (semantic, never decorative)
  good: palette.green400,
  caution: palette.amber400,
  danger: palette.red400,
  info: palette.blue400,
  neutral: "rgba(148, 163, 184, 0.45)",

  // Personas
  farmer: palette.green400,
  researcher: palette.blue400,
} as const;

export type ColorToken = keyof typeof Colors;

/// Adds alpha to a #RRGGBB colour.
export function withAlpha(hex: string, alpha: number): string {
  const m = /^#([0-9a-f]{6})$/i.exec(hex);
  if (m === null) return hex;
  const n = parseInt(m[1]!, 16);
  return `rgba(${(n >> 16) & 255}, ${(n >> 8) & 255}, ${n & 255}, ${alpha})`;
}

// ---------------------------------------------------------------------------
// Spacing & radius (4-pt grid)

export const Space = {
  xxs: 2,
  xs: 4,
  sm: 8,
  md: 12,
  lg: 16,
  xl: 20,
  xxl: 24,
  xxxl: 32,
  huge: 48,
} as const;

export const Radius = {
  xs: 6,
  sm: 10,
  md: 14,
  lg: 20,
  xl: 26,
  pill: 999,
} as const;

/// Screen gutters and the space reserved for the floating tab bar.
export const Layout = {
  gutter: 20,
  maxContentWidth: 640,
  tabBarHeight: 64,
  tabBarClearance: 112,
  hitSlop: { top: 10, bottom: 10, left: 10, right: 10 },
  minTouch: 44,
} as const;

// ---------------------------------------------------------------------------
// Typography

export const FontFamily = {
  light: "Manrope_300Light",
  regular: "Manrope_400Regular",
  medium: "Manrope_500Medium",
  semibold: "Manrope_600SemiBold",
  bold: "Manrope_700Bold",
  extrabold: "Manrope_800ExtraBold",
} as const;

const tabular: TextStyle = Platform.OS === "android" ? {} : { fontVariant: ["tabular-nums"] };

export const Type = {
  /// The hero temperature. Light weight, tight tracking.
  display: { fontFamily: FontFamily.light, fontSize: 96, lineHeight: 100, letterSpacing: -4, ...tabular },
  largeTitle: { fontFamily: FontFamily.bold, fontSize: 30, lineHeight: 36, letterSpacing: -0.6 },
  title: { fontFamily: FontFamily.bold, fontSize: 22, lineHeight: 28, letterSpacing: -0.3 },
  headline: { fontFamily: FontFamily.semibold, fontSize: 17, lineHeight: 22, letterSpacing: -0.1 },
  body: { fontFamily: FontFamily.regular, fontSize: 15, lineHeight: 22 },
  bodyStrong: { fontFamily: FontFamily.semibold, fontSize: 15, lineHeight: 22 },
  callout: { fontFamily: FontFamily.medium, fontSize: 14, lineHeight: 20 },
  subhead: { fontFamily: FontFamily.regular, fontSize: 13, lineHeight: 18 },
  footnote: { fontFamily: FontFamily.medium, fontSize: 12, lineHeight: 16 },
  caption: { fontFamily: FontFamily.medium, fontSize: 11, lineHeight: 14, letterSpacing: 0.2 },
  /// Section eyebrow above a card — small, sentence case, never shouting.
  eyebrow: { fontFamily: FontFamily.semibold, fontSize: 12, lineHeight: 16, letterSpacing: 0.3 },
  metric: { fontFamily: FontFamily.semibold, fontSize: 28, lineHeight: 32, letterSpacing: -0.6, ...tabular },
  numeric: { fontFamily: FontFamily.semibold, fontSize: 15, lineHeight: 20, ...tabular },
  mono: { fontFamily: Platform.select({ ios: "Menlo", android: "monospace", default: "ui-monospace, Menlo, monospace" }), fontSize: 12, lineHeight: 17 },
} satisfies Record<string, TextStyle>;

export type TypeVariant = keyof typeof Type;

// ---------------------------------------------------------------------------
// Motion

export const Motion = {
  fast: 140,
  base: 220,
  slow: 360,
  pressScale: 0.97,
} as const;
