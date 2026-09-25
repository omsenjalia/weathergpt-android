import 'package:flutter/material.dart';

import '../theme/atmosphere_theme.dart';
import 'atmosphere_background.dart';

/// Lightweight animated sky layer using atmospheric custom painter and gradient transitions.
class AtmosphereVideoBackground extends StatelessWidget {
  const AtmosphereVideoBackground({
    super.key,
    required this.palette,
    required this.sky,
    required this.period,
  });

  final AtmospherePalette palette;
  final SkyCondition sky;
  final SkyPeriod period;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Palette gradient (base sky)
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [palette.top, palette.mid, palette.bottom],
            ),
          ),
        ),
        // Live vector particles: rain, stars, sun/moon, clouds
        AtmosphereBackground(
          particlesOnly: false,
          palette: palette,
          sky: sky,
          period: period,
        ),
        // Contrast veil
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.15),
                Colors.transparent,
                Colors.black.withValues(alpha: 0.20),
                Colors.black.withValues(alpha: 0.50),
              ],
              stops: const [0.0, 0.28, 0.62, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}
