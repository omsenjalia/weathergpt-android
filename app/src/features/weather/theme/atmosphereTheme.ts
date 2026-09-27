/// The atmosphere engine — port of `lib/features/home/theme/atmosphere_theme.dart`.
/// 11 solar periods × 12 weather conditions drive the live sky palette.
/// An unknown sky is deliberately never drawn as a sunny one.

export enum SkyPeriod {
  Midnight = "midnight",
  Predawn = "predawn",
  Night = "night",
  Sunrise = "sunrise",
  Morning = "morning",
  Midday = "midday",
  Afternoon = "afternoon",
  GoldenHour = "goldenHour",
  Sunset = "sunset",
  Dusk = "dusk",
  Evening = "evening",
}

export enum SkyCondition {
  Clear = "clear",
  PartlyCloudy = "partlyCloudy",
  Cloudy = "cloudy",
  Overcast = "overcast",
  Fog = "fog",
  Drizzle = "drizzle",
  Rain = "rain",
  HeavyRain = "heavyRain",
  Thunder = "thunder",
  Snow = "snow",
  Windy = "windy",
  /// The backend sent no weather code and no matching condition text. This is
  /// deliberately not `clear`: an unknown sky must not be drawn as a sunny one.
  Unknown = "unknown",
}

export const SKY_PERIODS: readonly SkyPeriod[] = Object.values(SkyPeriod);
export const SKY_CONDITIONS: readonly SkyCondition[] = Object.values(SkyCondition);

export interface AtmospherePalette {
  top: string;
  mid: string;
  bottom: string;
  accent: string;
  glow: string;
  card: string;
  text: string;
  textMuted: string;
  orbStart: string;
  orbEnd: string;
  showSun: boolean;
  showMoon: boolean;
  sunY: number;
  moonY: number;
  /** 0–1 extra warm band near horizon (sunset/sunrise). */
  horizonWarmth: number;
}

type Rgba = readonly [number, number, number, number];

interface PaletteSpec {
  top: Rgba;
  mid: Rgba;
  bottom: Rgba;
  accent: Rgba;
  glow: Rgba;
  card: Rgba;
  text: Rgba;
  textMuted: Rgba;
  orbStart: Rgba;
  orbEnd: Rgba;
  showSun: boolean;
  showMoon: boolean;
  sunY: number;
  moonY: number;
  horizonWarmth?: number;
}

const P = (a: number, b: number, c: number, d = 255): Rgba => [a, b, c, d];

const PERIOD_PALETTES: Record<SkyPeriod, PaletteSpec> = {
  [SkyPeriod.Midnight]: {
    top: P(1, 3, 10), mid: P(6, 11, 24), bottom: P(12, 18, 34),
    accent: P(129, 140, 248), glow: P(30, 27, 75), card: P(10, 15, 28, 0.9),
    text: P(241, 245, 249), textMuted: P(148, 163, 184),
    orbStart: P(226, 232, 240), orbEnd: P(148, 163, 184),
    showSun: false, showMoon: true, sunY: 1.3, moonY: 0.2,
  },
  [SkyPeriod.Predawn]: {
    top: P(11, 18, 37), mid: P(30, 41, 59), bottom: P(51, 65, 85),
    accent: P(125, 211, 252), glow: P(30, 58, 95), card: P(15, 23, 42, 0.9),
    text: P(248, 250, 252), textMuted: P(203, 213, 225),
    orbStart: P(254, 243, 199), orbEnd: P(245, 158, 11),
    showSun: true, showMoon: true, sunY: 0.92, moonY: 0.18, horizonWarmth: 0.25,
  },
  [SkyPeriod.Night]: {
    top: P(7, 11, 22), mid: P(15, 23, 42), bottom: P(26, 36, 56),
    accent: P(147, 197, 253), glow: P(30, 58, 95), card: P(15, 23, 42, 0.9),
    text: P(248, 250, 252), textMuted: P(148, 163, 184),
    orbStart: P(241, 245, 249), orbEnd: P(203, 213, 225),
    showSun: false, showMoon: true, sunY: 1.3, moonY: 0.26,
  },
  [SkyPeriod.Sunrise]: {
    top: P(30, 58, 95), mid: P(194, 65, 12), bottom: P(253, 186, 116),
    accent: P(251, 191, 36), glow: P(234, 88, 12), card: P(28, 25, 23, 0.88),
    text: P(255, 251, 235), textMuted: P(231, 229, 228),
    orbStart: P(254, 240, 138), orbEnd: P(234, 88, 12),
    showSun: true, showMoon: false, sunY: 0.78, moonY: 1.3, horizonWarmth: 0.7,
  },
  [SkyPeriod.Morning]: {
    top: P(56, 189, 248), mid: P(125, 211, 252), bottom: P(224, 242, 254),
    accent: P(2, 132, 199), glow: P(56, 189, 248), card: P(12, 74, 110, 0.8),
    text: P(12, 74, 110), textMuted: P(3, 105, 161),
    orbStart: P(254, 240, 138), orbEnd: P(251, 191, 36),
    showSun: true, showMoon: false, sunY: 0.38, moonY: 1.3,
  },
  [SkyPeriod.Midday]: {
    top: P(2, 132, 199), mid: P(56, 189, 248), bottom: P(186, 230, 253),
    accent: P(245, 158, 11), glow: P(251, 191, 36), card: P(12, 74, 110, 0.8),
    text: P(12, 74, 110), textMuted: P(3, 105, 161),
    orbStart: P(254, 249, 195), orbEnd: P(245, 158, 11),
    showSun: true, showMoon: false, sunY: 0.14, moonY: 1.3,
  },
  [SkyPeriod.Afternoon]: {
    top: P(3, 105, 161), mid: P(14, 165, 233), bottom: P(125, 211, 252),
    accent: P(45, 212, 191), glow: P(56, 189, 248), card: P(15, 39, 68, 0.8),
    text: P(240, 249, 255), textMuted: P(186, 230, 253),
    orbStart: P(253, 230, 138), orbEnd: P(251, 191, 36),
    showSun: true, showMoon: false, sunY: 0.4, moonY: 1.3,
  },
  [SkyPeriod.GoldenHour]: {
    top: P(29, 78, 216), mid: P(251, 146, 60), bottom: P(253, 230, 138),
    accent: P(251, 191, 36), glow: P(249, 115, 22), card: P(28, 10, 0, 0.88),
    text: P(255, 251, 235), textMuted: P(254, 215, 170),
    orbStart: P(254, 215, 170), orbEnd: P(234, 88, 12),
    showSun: true, showMoon: false, sunY: 0.62, moonY: 1.3, horizonWarmth: 0.55,
  },
  [SkyPeriod.Sunset]: {
    top: P(49, 46, 129), mid: P(234, 88, 12), bottom: P(251, 191, 36),
    accent: P(251, 146, 60), glow: P(234, 88, 12), card: P(28, 10, 0, 0.88),
    text: P(255, 247, 237), textMuted: P(254, 215, 170),
    orbStart: P(254, 215, 170), orbEnd: P(194, 65, 12),
    showSun: true, showMoon: true, sunY: 0.82, moonY: 0.22, horizonWarmth: 0.85,
  },
  [SkyPeriod.Dusk]: {
    top: P(30, 27, 75), mid: P(76, 29, 149), bottom: P(124, 45, 18),
    accent: P(196, 181, 253), glow: P(91, 33, 182), card: P(15, 23, 42, 0.88),
    text: P(245, 243, 255), textMuted: P(196, 181, 253),
    orbStart: P(224, 231, 255), orbEnd: P(165, 180, 252),
    showSun: false, showMoon: true, sunY: 1.3, moonY: 0.28, horizonWarmth: 0.35,
  },
  [SkyPeriod.Evening]: {
    top: P(15, 23, 42), mid: P(30, 27, 75), bottom: P(30, 58, 95),
    accent: P(167, 139, 250), glow: P(76, 29, 149), card: P(15, 23, 42, 0.88),
    text: P(245, 243, 255), textMuted: P(196, 181, 253),
    orbStart: P(224, 231, 255), orbEnd: P(165, 180, 252),
    showSun: false, showMoon: true, sunY: 1.3, moonY: 0.3,
  },
};

function rgba(c: Rgba): string {
  const [r, g, b, a] = c;
  return a >= 255 ? `rgb(${r}, ${g}, ${b})` : `rgba(${r}, ${g}, ${b}, ${a})`;
}

function lerp(a: number, b: number, t: number): number {
  return a + (b - a) * t;
}

function lerpColor(a: Rgba, b: Rgba, t: number): Rgba {
  return [lerp(a[0], b[0], t), lerp(a[1], b[1], t), lerp(a[2], b[2], t), lerp(a[3], b[3], t)];
}

function luminance(c: Rgba): number {
  const channel = (v: number) => {
    const s = v / 255;
    return s <= 0.03928 ? s / 12.92 : Math.pow((s + 0.055) / 1.055, 2.4);
  };
  return 0.2126 * channel(c[0]) + 0.7152 * channel(c[1]) + 0.0722 * channel(c[2]);
}

export function periodFromLocalTime(
  now: Date,
  sunrise: Date | null,
  sunset: Date | null,
): SkyPeriod {
  const minutes = now.getHours() * 60 + now.getMinutes();
  const rise = sunrise !== null ? sunrise.getHours() * 60 + sunrise.getMinutes() : 6 * 60;
  const set = sunset !== null ? sunset.getHours() * 60 + sunset.getMinutes() : 18 * 60 + 30;

  if (minutes < 75) return SkyPeriod.Midnight;
  if (minutes < rise - 60) return SkyPeriod.Night;
  if (minutes < rise - 25) return SkyPeriod.Predawn;
  if (minutes < rise + 35) return SkyPeriod.Sunrise;
  if (minutes < rise + 150) return SkyPeriod.Morning;
  if (minutes < 13 * 60) return SkyPeriod.Midday;
  if (minutes < set - 90) return SkyPeriod.Afternoon;
  if (minutes < set - 25) return SkyPeriod.GoldenHour;
  if (minutes < set + 25) return SkyPeriod.Sunset;
  if (minutes < set + 55) return SkyPeriod.Dusk;
  if (minutes < 22 * 60 + 30) return SkyPeriod.Evening;
  return SkyPeriod.Night;
}

/// Minimal shape of the weather snapshot the condition classifier needs, so
/// the theme engine does not depend on the model layer.
export interface SkyWeatherInput {
  weatherCode?: number | null;
  condition: string;
  windKmh?: number | null;
}

export function conditionFromWeather(w: SkyWeatherInput): SkyCondition {
  // `code == null` means the backend did not report one. Every numeric test is
  // guarded by `known` so a missing code can never fall through to `clear`.
  const code = w.weatherCode ?? null;
  const known = code !== null;
  const c = w.condition.toLowerCase();
  const wind = w.windKmh ?? 0;

  if ((known && code >= 95) || c.includes("thunder")) return SkyCondition.Thunder;
  if ((known && (code === 65 || code === 67 || code === 82)) || c.includes("heavy rain")) return SkyCondition.HeavyRain;
  if ((known && code >= 51 && code <= 57) || c.includes("drizzle")) return SkyCondition.Drizzle;
  if ((known && ((code >= 61 && code <= 67) || (code >= 80 && code <= 82))) || c.includes("rain")) return SkyCondition.Rain;
  if ((known && code >= 71 && code <= 77) || c.includes("snow")) return SkyCondition.Snow;
  if ((known && code >= 45 && code <= 48) || c.includes("fog") || c.includes("mist")) return SkyCondition.Fog;
  if ((known && code >= 3) || c.includes("overcast")) return SkyCondition.Overcast;
  if ((known && code === 2) || c.includes("partly")) return SkyCondition.PartlyCloudy;
  if ((known && code === 1) || c.includes("cloud")) return SkyCondition.Cloudy;
  if (wind >= 35) return SkyCondition.Windy;
  return known ? SkyCondition.Clear : SkyCondition.Unknown;
}

const THUNDER_TOP = P(15, 23, 42);
const THUNDER_MID = P(30, 41, 59);
const THUNDER_BOTTOM = P(51, 65, 85);
const THUNDER_CARD = P(2, 6, 23, 0.5);
const RAIN_TOP = P(30, 41, 59);
const RAIN_MID = P(51, 65, 85);
const RAIN_BOTTOM = P(71, 85, 105);
const RAIN_CARD = P(15, 23, 42, 0.35);
const SNOW_TOP = P(100, 116, 139);
const SNOW_MID = P(148, 163, 184);
const SNOW_BOTTOM = P(226, 232, 240);
const SNOW_CARD = P(30, 41, 59, 0.3);
const FOG_TOP = P(148, 163, 184);
const FOG_MID = P(203, 213, 225);
const FOG_BOTTOM = P(226, 232, 240);
const OVERCAST_TOP = P(71, 85, 105);
const OVERCAST_MID = P(100, 116, 139);
const OVERCAST_BOTTOM = P(148, 163, 184);
const CLOUDY_TOP = P(100, 116, 139);
const CLOUDY_MID = P(148, 163, 184);

function applyWeather(
  base: PaletteSpec,
  sky: SkyCondition,
  period: SkyPeriod,
): PaletteSpec {
  const night =
    period === SkyPeriod.Night ||
    period === SkyPeriod.Midnight ||
    period === SkyPeriod.Evening ||
    period === SkyPeriod.Dusk;

  switch (sky) {
    case SkyCondition.Thunder:
      return {
        ...base,
        top: lerpColor(base.top, THUNDER_TOP, 0.7),
        mid: lerpColor(base.mid, THUNDER_MID, 0.65),
        bottom: lerpColor(base.bottom, THUNDER_BOTTOM, 0.55),
        accent: P(167, 139, 250),
        glow: P(109, 40, 217),
        card: lerpColor(base.card, THUNDER_CARD, 0.5),
        text: P(248, 250, 252),
        textMuted: P(203, 213, 225),
        showSun: false,
        showMoon: night,
      };
    case SkyCondition.HeavyRain:
    case SkyCondition.Rain:
    case SkyCondition.Drizzle: {
      const darken = sky === SkyCondition.HeavyRain ? 0.6 : 0.45;
      return {
        ...base,
        top: lerpColor(base.top, RAIN_TOP, darken),
        mid: lerpColor(base.mid, RAIN_MID, darken * 0.9),
        bottom: lerpColor(base.bottom, RAIN_BOTTOM, darken * 0.7),
        accent: P(56, 189, 248),
        glow: P(14, 165, 233),
        card: lerpColor(base.card, RAIN_CARD, 0.35),
        text: P(248, 250, 252),
        textMuted: P(203, 213, 225),
        showSun: false,
        showMoon: night,
      };
    }
    case SkyCondition.Snow:
      return {
        ...base,
        top: lerpColor(base.top, SNOW_TOP, 0.4),
        mid: lerpColor(base.mid, SNOW_MID, 0.35),
        bottom: lerpColor(base.bottom, SNOW_BOTTOM, 0.3),
        accent: P(224, 242, 254),
        glow: P(148, 163, 184),
        card: lerpColor(base.card, SNOW_CARD, 0.3),
        text: P(248, 250, 252),
        textMuted: P(226, 232, 240),
        showSun: base.showSun && !night,
        showMoon: night,
      };
    case SkyCondition.Fog:
      return {
        ...base,
        top: lerpColor(base.top, FOG_TOP, 0.5),
        mid: lerpColor(base.mid, FOG_MID, 0.45),
        bottom: lerpColor(base.bottom, FOG_BOTTOM, 0.4),
        glow: P(148, 163, 184),
        text: night ? base.text : P(30, 41, 59),
        textMuted: night ? base.textMuted : P(71, 85, 105),
        showSun: false,
        showMoon: false,
      };
    case SkyCondition.Unknown:
    case SkyCondition.Overcast:
      return {
        ...base,
        top: lerpColor(base.top, OVERCAST_TOP, 0.4),
        mid: lerpColor(base.mid, OVERCAST_MID, 0.35),
        bottom: lerpColor(base.bottom, OVERCAST_BOTTOM, 0.3),
        text: night ? base.text : P(15, 23, 42),
        textMuted: night ? base.textMuted : P(51, 65, 85),
        showSun: false,
        showMoon: night,
      };
    case SkyCondition.Cloudy:
    case SkyCondition.PartlyCloudy:
      return {
        ...base,
        top: lerpColor(base.top, CLOUDY_TOP, 0.15),
        mid: lerpColor(base.mid, CLOUDY_MID, 0.12),
      };
    case SkyCondition.Windy:
    case SkyCondition.Clear:
      return base;
  }
}

/// Keep the content layer legible even when a bright clip is behind it.
/// Most home-screen surfaces are intentionally dark glass. A few daytime
/// palettes used dark text with that same dark glass, which made the copy
/// disappear whenever the background changed. Normalize those combinations.
function ensureReadable(palette: PaletteSpec): PaletteSpec {
  if (luminance(palette.card) >= 0.45) return palette;
  const cardAlpha = Math.min(0.92, palette.card[3] + 0.02);
  return {
    ...palette,
    card: [palette.card[0], palette.card[1], palette.card[2], cardAlpha],
    accent: luminance(palette.accent) < 0.25 ? P(103, 232, 249) : palette.accent,
    text: P(248, 250, 252),
    textMuted: P(214, 226, 238),
  };
}

export function paletteFor(period: SkyPeriod, sky: SkyCondition): AtmospherePalette {
  const base = PERIOD_PALETTES[period];
  const spec = ensureReadable(applyWeather(base, sky, period));
  return {
    top: rgba(spec.top),
    mid: rgba(spec.mid),
    bottom: rgba(spec.bottom),
    accent: rgba(spec.accent),
    glow: rgba(spec.glow),
    card: rgba(spec.card),
    text: rgba(spec.text),
    textMuted: rgba(spec.textMuted),
    orbStart: rgba(spec.orbStart),
    orbEnd: rgba(spec.orbEnd),
    showSun: spec.showSun,
    showMoon: spec.showMoon,
    sunY: spec.sunY,
    moonY: spec.moonY,
    horizonWarmth: spec.horizonWarmth ?? 0,
  };
}

export function parseWeatherTime(raw: string | null | undefined): Date | null {
  if (raw === null || raw === undefined || raw.trim() === "") return null;
  try {
    let s = raw.trim();
    if (s.length === 16 && s.includes("T")) s = `${s}:00`;
    const d = new Date(s);
    return Number.isNaN(d.getTime()) ? null : d;
  } catch {
    return null;
  }
}

export function formatClock(raw: string | null | undefined): string {
  const dt = parseWeatherTime(raw);
  if (dt === null) return "—";
  const h = dt.getHours();
  const m = String(dt.getMinutes()).padStart(2, "0");
  const period = h >= 12 ? "PM" : "AM";
  const h12 = h === 0 ? 12 : h > 12 ? h - 12 : h;
  return `${h12}:${m} ${period}`;
}

export function windDirLabel(deg: number | null | undefined): string {
  if (deg === null || deg === undefined) return "—";
  const dirs = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"];
  const i = Math.round(((deg % 360) + 360) % 360 / 45) % 8;
  return dirs[i];
}
