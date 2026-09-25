import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/text_styles.dart';
import '../../../models/weather.dart';
import '../theme/atmosphere_theme.dart';
import 'weather_detail_panels.dart';

/// The big temperature card at the top of the home screen.
///
/// Apple-Weather proportions: an oversized thin reading, the condition with
/// its icon, then compact high/low pills. Every value respects strict null
/// semantics — a missing reading is an em dash, never a fabricated zero.
class WeatherHeroCard extends StatelessWidget {
  const WeatherHeroCard({super.key, required this.weather, required this.palette});
  final WeatherSnapshot weather;
  final AtmospherePalette palette;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('EEEE, MMM d').format(weather.localNow());
    final unknownCondition = weather.condition == '—';
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - t)),
          child: child,
        ),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: palette.glow.withValues(alpha: 0.25),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(date,
                style: TextStyle(
                    color: palette.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2)),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    weather.temperatureC == null
                        ? '—'
                        : '${weather.temperatureC!.round()}°',
                    style: AppTextStyles.numeric(TextStyle(
                      fontSize: 88,
                      height: 0.95,
                      fontWeight: FontWeight.w200,
                      letterSpacing: -4,
                      color: palette.text,
                    )),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: palette.accent.withValues(alpha: 0.14),
                    border: Border.all(
                      color: palette.accent.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Icon(
                      iconForCondition(weather.condition, weather.weatherCode),
                      size: 32,
                      color: palette.accent),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
                unknownCondition
                    ? 'home.condition_unknown'.tr()
                    : weather.condition,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: palette.text)),
            const SizedBox(height: 14),
            // Wrap (not Row): on narrow screens the low pill flows to the
            // next line instead of being clipped by the card edge.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (weather.feelsLikeC != null)
                  _pill(
                    icon: Icons.thermostat_rounded,
                    label:
                        '${'home.feels_like'.tr()} ${weather.feelsLikeC!.round()}°',
                    palette: palette,
                  ),
                _pill(
                  icon: Icons.arrow_upward_rounded,
                  label: 'H ${weather.highC?.round() ?? '—'}°',
                  palette: palette,
                  strong: true,
                ),
                _pill(
                  icon: Icons.arrow_downward_rounded,
                  label: 'L ${weather.lowC?.round() ?? '—'}°',
                  palette: palette,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill({
    required String label,
    required AtmospherePalette palette,
    IconData? icon,
    bool strong = false,
  }) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: strong ? 0.10 : 0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: strong ? 0.14 : 0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 12,
                  color: strong
                      ? palette.text
                      : palette.textMuted.withValues(alpha: 0.9)),
              const SizedBox(width: 4),
            ],
            Text(label,
                style: AppTextStyles.numeric(TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: strong ? palette.text : palette.textMuted))),
          ],
        ),
      );
}
