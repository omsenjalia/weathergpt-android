import 'package:flutter/material.dart';

/// WeatherGPT visual system — deep navy + teal/sky accents.
abstract final class AppColors {
  static const bgPrimary = Color(0xFF0B1220);
  static const bgElevated = Color(0xFF101A2C);
  static const surfaceCard = Color(0xFF152036);
  static const surfaceCardAlt = Color(0xFF1A2740);
  static const borderSubtle = Color(0xFF243149);
  static const borderStrong = Color(0xFF334155);

  // Brand
  static const accent = Color(0xFF2DD4BF); // teal
  static const accentSoft = Color(0xFF5EEAD4);
  static const sky = Color(0xFF38BDF8);
  static const skyDeep = Color(0xFF0EA5E9);

  // Personas (kept for routing logic)
  static const farmerGreen = Color(0xFF34D399);
  static const farmerGreenGlow = Color(0xFF6EE7B7);
  static const researcherBlue = Color(0xFF60A5FA);
  static const researcherBlueGlow = Color(0xFF93C5FD);

  // Status
  static const statusRed = Color(0xFFF87171);
  static const statusAmber = Color(0xFFFBBF24);
  static const statusGreenText = Color(0xFF34D399);

  // Text
  static const textPrimary = Color(0xFFF8FAFC);
  static const textSecondary = Color(0xFF94A3B8);
  static const textTertiary = Color(0xFF64748B);

  // CTA
  static const ctaWhite = Color(0xFFF8FAFC);
  static const ctaTextDark = Color(0xFF0B1220);

  static const gradientHero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0F2744), Color(0xFF0B3B3A), Color(0xFF0B1220)],
  );

  static const gradientAccent = LinearGradient(
    colors: [Color(0xFF2DD4BF), Color(0xFF38BDF8)],
  );

  // ---- Glass system -------------------------------------------------------
  // Frosted surfaces used across the app. Fills are translucent dark navy so
  // white text stays readable on every sky — including bright daylight —
  // exactly how professional weather apps keep cards legible over a bright
  // gradient. Hairline white borders keep edges crisp on all densities.
  static const glassFill = Color(0x99101930); // ~60% dark navy
  static const glassFillStrong = Color(0xC0101930); // ~75% dark navy
  static const glassBorder = Color(0x1FFFFFFF); // ~12% white
  static const glassBorderStrong = Color(0x33FFFFFF); // ~20% white

  /// Deep scrim laid over the sky gradient so text-heavy screens stay
  /// readable without hiding the atmosphere.
  static const scrim = Color(0xB20B1220); // ~70% bgPrimary

  static const glassBlurRadius = 24.0;

}
