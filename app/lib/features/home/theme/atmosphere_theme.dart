import 'package:flutter/material.dart';

import '../../../models/weather.dart';

enum SkyPeriod {
  midnight,
  predawn,
  night,
  sunrise,
  morning,
  midday,
  afternoon,
  goldenHour,
  sunset,
  dusk,
  evening,
}

enum SkyCondition {
  clear,
  partlyCloudy,
  cloudy,
  overcast,
  fog,
  drizzle,
  rain,
  heavyRain,
  thunder,
  snow,
  windy,

  /// The backend sent no weather code and no matching condition text. This is
  /// deliberately not `clear`: an unknown sky must not be drawn as a sunny one.
  unknown,
}

class AtmospherePalette {
  const AtmospherePalette({
    required this.top,
    required this.mid,
    required this.bottom,
    required this.accent,
    required this.glow,
    required this.card,
    required this.text,
    required this.textMuted,
    required this.orbStart,
    required this.orbEnd,
    required this.showSun,
    required this.showMoon,
    required this.sunY,
    required this.moonY,
    this.horizonWarmth = 0.0,
  });

  final Color top;
  final Color mid;
  final Color bottom;
  final Color accent;
  final Color glow;
  final Color card;
  final Color text;
  final Color textMuted;
  final Color orbStart;
  final Color orbEnd;
  final bool showSun;
  final bool showMoon;
  final double sunY;
  final double moonY;
  /// 0–1 extra warm band near horizon (sunset/sunrise).
  final double horizonWarmth;

  AtmospherePalette copyWith({
    Color? top,
    Color? mid,
    Color? bottom,
    Color? accent,
    Color? glow,
    Color? card,
    Color? text,
    Color? textMuted,
    Color? orbStart,
    Color? orbEnd,
    bool? showSun,
    bool? showMoon,
    double? sunY,
    double? moonY,
    double? horizonWarmth,
  }) {
    return AtmospherePalette(
      top: top ?? this.top,
      mid: mid ?? this.mid,
      bottom: bottom ?? this.bottom,
      accent: accent ?? this.accent,
      glow: glow ?? this.glow,
      card: card ?? this.card,
      text: text ?? this.text,
      textMuted: textMuted ?? this.textMuted,
      orbStart: orbStart ?? this.orbStart,
      orbEnd: orbEnd ?? this.orbEnd,
      showSun: showSun ?? this.showSun,
      showMoon: showMoon ?? this.showMoon,
      sunY: sunY ?? this.sunY,
      moonY: moonY ?? this.moonY,
      horizonWarmth: horizonWarmth ?? this.horizonWarmth,
    );
  }
}

SkyPeriod periodFromLocalTime(DateTime now, DateTime? sunrise, DateTime? sunset) {
  final minutes = now.hour * 60 + now.minute;
  final rise = sunrise != null ? sunrise.hour * 60 + sunrise.minute : 6 * 60;
  final set = sunset != null ? sunset.hour * 60 + sunset.minute : 18 * 60 + 30;

  if (minutes < 75) return SkyPeriod.midnight;
  if (minutes < rise - 60) return SkyPeriod.night;
  if (minutes < rise - 25) return SkyPeriod.predawn;
  if (minutes < rise + 35) return SkyPeriod.sunrise;
  if (minutes < rise + 150) return SkyPeriod.morning;
  if (minutes < 13 * 60) return SkyPeriod.midday;
  if (minutes < set - 90) return SkyPeriod.afternoon;
  if (minutes < set - 25) return SkyPeriod.goldenHour;
  if (minutes < set + 25) return SkyPeriod.sunset;
  if (minutes < set + 55) return SkyPeriod.dusk;
  if (minutes < 22 * 60 + 30) return SkyPeriod.evening;
  return SkyPeriod.night;
}

SkyCondition conditionFromWeather(WeatherSnapshot w) {
  // `code == null` means the backend did not report one. Every numeric test is
  // guarded by [known] so a missing code can never fall through to `clear`.
  final code = w.weatherCode;
  final known = code != null;
  final c = w.condition.toLowerCase();
  final wind = w.windKmh?.toDouble() ?? 0;

  if ((known && code >= 95) || c.contains('thunder')) {
    return SkyCondition.thunder;
  }
  if ((known && (code == 65 || code == 67 || code == 82)) ||
      c.contains('heavy rain')) {
    return SkyCondition.heavyRain;
  }
  if ((known && code >= 51 && code <= 57) || c.contains('drizzle')) {
    return SkyCondition.drizzle;
  }
  if ((known && ((code >= 61 && code <= 67) || (code >= 80 && code <= 82))) ||
      c.contains('rain')) {
    return SkyCondition.rain;
  }
  if ((known && code >= 71 && code <= 77) || c.contains('snow')) {
    return SkyCondition.snow;
  }
  if ((known && code >= 45 && code <= 48) ||
      c.contains('fog') ||
      c.contains('mist')) {
    return SkyCondition.fog;
  }
  if ((known && code >= 3) || c.contains('overcast')) {
    return SkyCondition.overcast;
  }
  if ((known && code == 2) || c.contains('partly')) {
    return SkyCondition.partlyCloudy;
  }
  if ((known && code == 1) || c.contains('cloud')) return SkyCondition.cloudy;
  if (wind >= 35) return SkyCondition.windy;
  return known ? SkyCondition.clear : SkyCondition.unknown;
}

AtmospherePalette paletteFor(SkyPeriod period, SkyCondition sky) {
  AtmospherePalette base = switch (period) {
    SkyPeriod.midnight => const AtmospherePalette(
        top: Color(0xFF01030A),
        mid: Color(0xFF060B18),
        bottom: Color(0xFF0C1222),
        accent: Color(0xFF818CF8),
        glow: Color(0xFF1E1B4B),
        card: Color(0xE60A0F1C),
        text: Color(0xFFF1F5F9),
        textMuted: Color(0xFF94A3B8),
        orbStart: Color(0xFFE2E8F0),
        orbEnd: Color(0xFF94A3B8),
        showSun: false,
        showMoon: true,
        sunY: 1.3,
        moonY: 0.20,
      ),
    SkyPeriod.predawn => const AtmospherePalette(
        top: Color(0xFF0B1225),
        mid: Color(0xFF1E293B),
        bottom: Color(0xFF334155),
        accent: Color(0xFF7DD3FC),
        glow: Color(0xFF1E3A5F),
        card: Color(0xE60F172A),
        text: Color(0xFFF8FAFC),
        textMuted: Color(0xFFCBD5E1),
        orbStart: Color(0xFFFEF3C7),
        orbEnd: Color(0xFFF59E0B),
        showSun: true,
        showMoon: true,
        sunY: 0.92,
        moonY: 0.18,
        horizonWarmth: 0.25,
      ),
    SkyPeriod.night => const AtmospherePalette(
        top: Color(0xFF070B16),
        mid: Color(0xFF0F172A),
        bottom: Color(0xFF1A2438),
        accent: Color(0xFF93C5FD),
        glow: Color(0xFF1E3A5F),
        card: Color(0xE60F172A),
        text: Color(0xFFF8FAFC),
        textMuted: Color(0xFF94A3B8),
        orbStart: Color(0xFFF1F5F9),
        orbEnd: Color(0xFFCBD5E1),
        showSun: false,
        showMoon: true,
        sunY: 1.3,
        moonY: 0.26,
      ),
    SkyPeriod.sunrise => const AtmospherePalette(
        top: Color(0xFF1E3A5F),
        mid: Color(0xFFC2410C),
        bottom: Color(0xFFFDBA74),
        accent: Color(0xFFFBBF24),
        glow: Color(0xFFEA580C),
        card: Color(0xE01C1917),
        text: Color(0xFFFFFBEB),
        textMuted: Color(0xFFE7E5E4),
        orbStart: Color(0xFFFEF08A),
        orbEnd: Color(0xFFEA580C),
        showSun: true,
        showMoon: false,
        sunY: 0.78,
        moonY: 1.3,
        horizonWarmth: 0.7,
      ),
    SkyPeriod.morning => const AtmospherePalette(
        top: Color(0xFF38BDF8),
        mid: Color(0xFF7DD3FC),
        bottom: Color(0xFFE0F2FE),
        accent: Color(0xFF0284C7),
        glow: Color(0xFF38BDF8),
        card: Color(0xCC0C4A6E),
        text: Color(0xFF0C4A6E),
        textMuted: Color(0xFF0369A1),
        orbStart: Color(0xFFFEF08A),
        orbEnd: Color(0xFFFBBF24),
        showSun: true,
        showMoon: false,
        sunY: 0.38,
        moonY: 1.3,
      ),
    SkyPeriod.midday => const AtmospherePalette(
        top: Color(0xFF0284C7),
        mid: Color(0xFF38BDF8),
        bottom: Color(0xFFBAE6FD),
        accent: Color(0xFFF59E0B),
        glow: Color(0xFFFBBF24),
        card: Color(0xCC0C4A6E),
        text: Color(0xFF0C4A6E),
        textMuted: Color(0xFF0369A1),
        orbStart: Color(0xFFFEF9C3),
        orbEnd: Color(0xFFF59E0B),
        showSun: true,
        showMoon: false,
        sunY: 0.14,
        moonY: 1.3,
      ),
    SkyPeriod.afternoon => const AtmospherePalette(
        top: Color(0xFF0369A1),
        mid: Color(0xFF0EA5E9),
        bottom: Color(0xFF7DD3FC),
        accent: Color(0xFF2DD4BF),
        glow: Color(0xFF38BDF8),
        card: Color(0xCC0F2744),
        text: Color(0xFFF0F9FF),
        textMuted: Color(0xFFBAE6FD),
        orbStart: Color(0xFFFDE68A),
        orbEnd: Color(0xFFFBBF24),
        showSun: true,
        showMoon: false,
        sunY: 0.40,
        moonY: 1.3,
      ),
    SkyPeriod.goldenHour => const AtmospherePalette(
        top: Color(0xFF1D4ED8),
        mid: Color(0xFFFB923C),
        bottom: Color(0xFFFDE68A),
        accent: Color(0xFFFBBF24),
        glow: Color(0xFFF97316),
        card: Color(0xE01C0A00),
        text: Color(0xFFFFFBEB),
        textMuted: Color(0xFFFED7AA),
        orbStart: Color(0xFFFED7AA),
        orbEnd: Color(0xFFEA580C),
        showSun: true,
        showMoon: false,
        sunY: 0.62,
        moonY: 1.3,
        horizonWarmth: 0.55,
      ),
    SkyPeriod.sunset => const AtmospherePalette(
        top: Color(0xFF312E81),
        mid: Color(0xFFEA580C),
        bottom: Color(0xFFFBBF24),
        accent: Color(0xFFFB923C),
        glow: Color(0xFFEA580C),
        card: Color(0xE01C0A00),
        text: Color(0xFFFFF7ED),
        textMuted: Color(0xFFFED7AA),
        orbStart: Color(0xFFFED7AA),
        orbEnd: Color(0xFFC2410C),
        showSun: true,
        showMoon: true,
        sunY: 0.82,
        moonY: 0.22,
        horizonWarmth: 0.85,
      ),
    SkyPeriod.dusk => const AtmospherePalette(
        top: Color(0xFF1E1B4B),
        mid: Color(0xFF4C1D95),
        bottom: Color(0xFF7C2D12),
        accent: Color(0xFFC4B5FD),
        glow: Color(0xFF5B21B6),
        card: Color(0xE00F172A),
        text: Color(0xFFF5F3FF),
        textMuted: Color(0xFFC4B5FD),
        orbStart: Color(0xFFE0E7FF),
        orbEnd: Color(0xFFA5B4FC),
        showSun: false,
        showMoon: true,
        sunY: 1.3,
        moonY: 0.28,
        horizonWarmth: 0.35,
      ),
    SkyPeriod.evening => const AtmospherePalette(
        top: Color(0xFF0F172A),
        mid: Color(0xFF1E1B4B),
        bottom: Color(0xFF1E3A5F),
        accent: Color(0xFFA78BFA),
        glow: Color(0xFF4C1D95),
        card: Color(0xE00F172A),
        text: Color(0xFFF5F3FF),
        textMuted: Color(0xFFC4B5FD),
        orbStart: Color(0xFFE0E7FF),
        orbEnd: Color(0xFFA5B4FC),
        showSun: false,
        showMoon: true,
        sunY: 1.3,
        moonY: 0.30,
      ),
  };

  return _ensureReadable(_applyWeather(base, sky, period));
}

/// Keep the content layer legible even when a bright clip is behind it.
///
/// Most home-screen surfaces are intentionally dark glass. A few daytime
/// palettes used dark text with that same dark glass, which made the copy
/// disappear whenever the background video changed. Normalize those
/// combinations here so every weather/time scenario has a safe text color.
AtmospherePalette _ensureReadable(AtmospherePalette palette) {
  if (palette.card.computeLuminance() >= 0.45) return palette;

  return palette.copyWith(
    card: palette.card.withValues(alpha: 0.92),
    accent: palette.accent.computeLuminance() < 0.25
        ? const Color(0xFF67E8F9)
        : palette.accent,
    text: const Color(0xFFF8FAFC),
    textMuted: const Color(0xFFD6E2EE),
  );
}

AtmospherePalette _applyWeather(
  AtmospherePalette base,
  SkyCondition sky,
  SkyPeriod period,
) {
  final night = period == SkyPeriod.night ||
      period == SkyPeriod.midnight ||
      period == SkyPeriod.evening ||
      period == SkyPeriod.dusk;

  switch (sky) {
    case SkyCondition.thunder:
      return AtmospherePalette(
        top: Color.lerp(base.top, const Color(0xFF0F172A), 0.7)!,
        mid: Color.lerp(base.mid, const Color(0xFF1E293B), 0.65)!,
        bottom: Color.lerp(base.bottom, const Color(0xFF334155), 0.55)!,
        accent: const Color(0xFFA78BFA),
        glow: const Color(0xFF6D28D9),
        card: Color.lerp(base.card, const Color(0xFF020617), 0.5)!,
        text: const Color(0xFFF8FAFC),
        textMuted: const Color(0xFFCBD5E1),
        orbStart: base.orbStart,
        orbEnd: base.orbEnd,
        showSun: false,
        showMoon: night,
        sunY: base.sunY,
        moonY: base.moonY,
      );
    case SkyCondition.heavyRain:
    case SkyCondition.rain:
    case SkyCondition.drizzle:
      final darken = sky == SkyCondition.heavyRain ? 0.6 : 0.45;
      return AtmospherePalette(
        top: Color.lerp(base.top, const Color(0xFF1E293B), darken)!,
        mid: Color.lerp(base.mid, const Color(0xFF334155), darken * 0.9)!,
        bottom: Color.lerp(base.bottom, const Color(0xFF475569), darken * 0.7)!,
        accent: const Color(0xFF38BDF8),
        glow: const Color(0xFF0EA5E9),
        card: Color.lerp(base.card, const Color(0xFF0F172A), 0.35)!,
        text: const Color(0xFFF8FAFC),
        textMuted: const Color(0xFFCBD5E1),
        orbStart: base.orbStart,
        orbEnd: base.orbEnd,
        showSun: false,
        showMoon: night,
        sunY: base.sunY,
        moonY: base.moonY,
      );
    case SkyCondition.snow:
      return AtmospherePalette(
        top: Color.lerp(base.top, const Color(0xFF64748B), 0.4)!,
        mid: Color.lerp(base.mid, const Color(0xFF94A3B8), 0.35)!,
        bottom: Color.lerp(base.bottom, const Color(0xFFE2E8F0), 0.3)!,
        accent: const Color(0xFFE0F2FE),
        glow: const Color(0xFF94A3B8),
        card: Color.lerp(base.card, const Color(0xFF1E293B), 0.3)!,
        text: const Color(0xFFF8FAFC),
        textMuted: const Color(0xFFE2E8F0),
        orbStart: base.orbStart,
        orbEnd: base.orbEnd,
        showSun: base.showSun && !night,
        showMoon: night,
        sunY: base.sunY,
        moonY: base.moonY,
      );
    case SkyCondition.fog:
      return AtmospherePalette(
        top: Color.lerp(base.top, const Color(0xFF94A3B8), 0.5)!,
        mid: Color.lerp(base.mid, const Color(0xFFCBD5E1), 0.45)!,
        bottom: Color.lerp(base.bottom, const Color(0xFFE2E8F0), 0.4)!,
        accent: base.accent,
        glow: const Color(0xFF94A3B8),
        card: base.card,
        text: night ? base.text : const Color(0xFF1E293B),
        textMuted: night ? base.textMuted : const Color(0xFF475569),
        orbStart: base.orbStart,
        orbEnd: base.orbEnd,
        showSun: false,
        showMoon: false,
        sunY: base.sunY,
        moonY: base.moonY,
      );
    case SkyCondition.unknown:
    case SkyCondition.overcast:
      return AtmospherePalette(
        top: Color.lerp(base.top, const Color(0xFF475569), 0.4)!,
        mid: Color.lerp(base.mid, const Color(0xFF64748B), 0.35)!,
        bottom: Color.lerp(base.bottom, const Color(0xFF94A3B8), 0.3)!,
        accent: base.accent,
        glow: base.glow,
        card: base.card,
        text: night ? base.text : const Color(0xFF0F172A),
        textMuted: night ? base.textMuted : const Color(0xFF334155),
        orbStart: base.orbStart,
        orbEnd: base.orbEnd,
        showSun: false,
        showMoon: night,
        sunY: base.sunY,
        moonY: base.moonY,
      );
    case SkyCondition.cloudy:
    case SkyCondition.partlyCloudy:
      return AtmospherePalette(
        top: Color.lerp(base.top, const Color(0xFF64748B), 0.15)!,
        mid: Color.lerp(base.mid, const Color(0xFF94A3B8), 0.12)!,
        bottom: base.bottom,
        accent: base.accent,
        glow: base.glow,
        card: base.card,
        text: base.text,
        textMuted: base.textMuted,
        orbStart: base.orbStart,
        orbEnd: base.orbEnd,
        showSun: base.showSun,
        showMoon: base.showMoon,
        sunY: base.sunY,
        moonY: base.moonY,
        horizonWarmth: base.horizonWarmth,
      );
    case SkyCondition.windy:
    case SkyCondition.clear:
      return base;
  }
}

DateTime? parseWeatherTime(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  try {
    var s = raw.trim();
    if (s.length == 16 && s.contains('T')) s = '$s:00';
    return DateTime.tryParse(s);
  } catch (_) {
    return null;
  }
}

String formatClock(String? raw) {
  final dt = parseWeatherTime(raw);
  if (dt == null) return '—';
  final h = dt.hour;
  final m = dt.minute.toString().padLeft(2, '0');
  final period = h >= 12 ? 'PM' : 'AM';
  final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
  return '$h12:$m $period';
}

String windDirLabel(num? deg) {
  if (deg == null) return '—';
  const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
  final i = ((deg % 360) / 45).round() % 8;
  return dirs[i];
}
