import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/text_styles.dart';
import '../../../models/weather.dart';
import '../theme/atmosphere_theme.dart';

/// Horizontal strip of quick weather metrics — glass tiles, each with its
/// own accent, a small proportional gauge and strict em-dash null semantics.
class WeatherMetricStrip extends StatelessWidget {
  const WeatherMetricStrip({super.key, required this.weather, required this.palette});
  final WeatherSnapshot weather;
  final AtmospherePalette palette;

  @override
  Widget build(BuildContext context) {
    final w = weather;
    final items = [
      (
        Icons.water_drop_outlined,
        w.rainProbability?.round(),
        w.rainProbability == null ? '—' : '${w.rainProbability!.round()}%',
        'home.rain_chance'.tr(),
        const Color(0xFF38BDF8),
        w.rainProbability == null ? 0.0 : (w.rainProbability! / 100).clamp(0.05, 1.0),
      ),
      (
        Icons.air,
        w.windKmh?.round(),
        w.windKmh == null
            ? '—'
            : '${w.windKmh!.toStringAsFixed(0)}${w.windDirection == null ? '' : ' ${windDirLabel(w.windDirection)}'}',
        'home.wind_kmh'.tr(),
        const Color(0xFF2DD4BF),
        w.windKmh == null ? 0.0 : (w.windKmh! / 60).clamp(0.05, 1.0),
      ),
      (
        Icons.opacity,
        w.humidity?.round(),
        w.humidity == null ? '—' : '${w.humidity!.round()}%',
        'home.humidity'.tr(),
        const Color(0xFF60A5FA),
        w.humidity == null ? 0.0 : (w.humidity! / 100).clamp(0.05, 1.0),
      ),
      (
        Icons.compress,
        w.pressureHpa?.round(),
        w.pressureHpa == null ? '—' : '${w.pressureHpa!.round()}',
        'home.pressure_hpa'.tr(),
        const Color(0xFFA78BFA),
        w.pressureHpa == null
            ? 0.0
            : ((w.pressureHpa! - 960) / 90).clamp(0.05, 1.0),
      ),
      (
        Icons.cloud_outlined,
        w.cloudCover?.round(),
        w.cloudCover == null ? '—' : '${w.cloudCover!.round()}%',
        'home.cloud_cover'.tr(),
        const Color(0xFFCBD5E1),
        w.cloudCover == null ? 0.0 : (w.cloudCover! / 100).clamp(0.05, 1.0),
      ),
    ];
    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final (icon, _, display, label, accent, gauge) = items[i];
          final unavailable = display == '—';
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 400 + i * 80),
            curve: Curves.easeOut,
            builder: (context, t, child) => Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset(0, 12 * (1 - t)),
                child: child,
              ),
            ),
            child: Container(
              width: 104,
              padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
              decoration: BoxDecoration(
                color: palette.card,
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(9),
                      color: accent.withValues(alpha: 0.14),
                    ),
                    child: Icon(icon, size: 15, color: accent),
                  ),
                  const Spacer(),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(display,
                        style: AppTextStyles.numeric(TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: unavailable
                                ? palette.textMuted
                                : palette.text))),
                  ),
                  const SizedBox(height: 2),
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 10.5, color: palette.textMuted)),
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: SizedBox(
                      height: 3,
                      child: Stack(
                        children: [
                          Container(
                              color:
                                  Colors.white.withValues(alpha: 0.10)),
                          FractionallySizedBox(
                            widthFactor: unavailable ? 0 : gauge,
                            child: Container(
                                color: accent.withValues(alpha: 0.85)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
