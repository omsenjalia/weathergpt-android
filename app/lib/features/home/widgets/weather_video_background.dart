import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Lightweight gradient weather background.
class WeatherVideoBackground extends StatelessWidget {
  const WeatherVideoBackground({
    super.key,
    required this.condition,
    this.weatherCode,
    this.opacity = 0.5,
  });

  final String condition;
  final int? weatherCode;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(gradient: AppColors.gradientHero),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.bgPrimary.withValues(alpha: 0.3),
                AppColors.bgPrimary.withValues(alpha: 0.7),
                AppColors.bgPrimary,
              ],
              stops: const [0.0, 0.55, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}
