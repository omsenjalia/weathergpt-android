import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppTextStyles {
  static TextTheme get textTheme => GoogleFonts.interTextTheme().copyWith(
        displayLarge:
            GoogleFonts.inter(fontSize: 60, fontWeight: FontWeight.w700),
        headlineSmall:
            GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700),
        titleLarge:
            GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600),
        bodyMedium:
            GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w400),
        labelMedium:
            GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
      );

  /// Numerals that keep a constant width while a value animates or updates
  /// (temperature counts, metric readouts) so nothing jitters sideways.
  static TextStyle numeric(TextStyle base) => base.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  /// Section eyebrow — the small uppercase label above card groups.
  static const TextStyle sectionLabel = TextStyle(
    fontSize: 11.5,
    letterSpacing: 1.3,
    fontWeight: FontWeight.w700,
  );
}
