import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../models/weather.dart';
import '../theme/atmosphere_theme.dart';
import 'weather_detail_sheets.dart';

/// Short display name for a provider id reported by the backend.
String providerDisplayName(String? id) {
  if (id == null) return 'home.source_not_reported'.tr();
  return switch (providerFromName(id)) {
    WeatherProvider.imd => 'IMD',
    WeatherProvider.weathernext => 'WeatherNext',
    WeatherProvider.accuweather => 'AccuWeather',
    WeatherProvider.openMeteo => 'Open-Meteo',
    WeatherProvider.unknown => id,
  };
}

/// Human label for a WMO code or condition string — small icon mapping shared
/// by the hourly and daily rows.
IconData iconForCondition(String? condition, int? code) {
  final c = (condition ?? '').toLowerCase();
  if ((code != null && code >= 95) || c.contains('thunder')) {
    return Icons.thunderstorm_rounded;
  }
  if ((code != null && code >= 71 && code <= 77) ||
      (code != null && code >= 85 && code <= 86) ||
      c.contains('snow')) {
    return Icons.ac_unit_rounded;
  }
  if ((code != null && code >= 51 && code <= 67) ||
      (code != null && code >= 80 && code <= 82) ||
      c.contains('rain') ||
      c.contains('drizzle') ||
      c.contains('shower')) {
    return Icons.water_drop_rounded;
  }
  if ((code != null && code >= 45 && code <= 48) || c.contains('fog')) {
    return Icons.foggy;
  }
  if (code == 3 || c.contains('overcast')) return Icons.cloud_rounded;
  if (code == 2 || c.contains('partly')) return Icons.cloud_queue_rounded;
  if (code == 1 || code == 0 || c.contains('clear') || c.contains('sun')) {
    return Icons.wb_sunny_rounded;
  }
  return Icons.help_outline_rounded;
}

String _num(num? v, {int digits = 0, String suffix = ''}) =>
    v == null ? '—' : '${v.toStringAsFixed(digits)}$suffix';

String uvBand(num? uv) {
  if (uv == null) return 'home.unavailable'.tr();
  if (uv < 3) return 'home.uv_low'.tr();
  if (uv < 6) return 'home.uv_moderate'.tr();
  if (uv < 8) return 'home.uv_high'.tr();
  if (uv < 11) return 'home.uv_very_high'.tr();
  return 'home.uv_extreme'.tr();
}

String aqiBand(num? aqi) {
  // European AQI bands (what the backend's Open-Meteo supplement reports).
  if (aqi == null) return 'home.unavailable'.tr();
  if (aqi <= 20) return 'home.aqi_good'.tr();
  if (aqi <= 40) return 'home.aqi_fair'.tr();
  if (aqi <= 60) return 'home.aqi_moderate'.tr();
  if (aqi <= 80) return 'home.aqi_poor'.tr();
  if (aqi <= 100) return 'home.aqi_very_poor'.tr();
  return 'home.aqi_extremely_poor'.tr();
}

Color aqiColor(num? aqi) {
  if (aqi == null) return Colors.white54;
  if (aqi <= 20) return const Color(0xFF34D399);
  if (aqi <= 40) return const Color(0xFFA3E635);
  if (aqi <= 60) return const Color(0xFFFBBF24);
  if (aqi <= 80) return const Color(0xFFFB923C);
  if (aqi <= 100) return const Color(0xFFF87171);
  return const Color(0xFFC084FC);
}

Color uvColor(num? uv) {
  if (uv == null) return Colors.white54;
  if (uv < 3) return const Color(0xFF34D399);
  if (uv < 6) return const Color(0xFFFBBF24);
  if (uv < 8) return const Color(0xFFFB923C);
  if (uv < 11) return const Color(0xFFF87171);
  return const Color(0xFFC084FC);
}

class _OverviewTile {
  const _OverviewTile({
    required this.title,
    required this.value,
    required this.caption,
    required this.icon,
    this.field,
    this.accent,
  });
  final String title;
  final String value;
  final String caption;
  final IconData icon;

  /// Backend field name used for per-field attribution.
  final String? field;
  final Color? accent;
}

/// Tab body: grid of secondary conditions (AQI, UV, sun, …).
///
/// Every value is labelled with its unit and its meaning (e.g. UV "High").
/// Provider attribution — the small "via Open-Meteo" badges and the source
/// rows inside the detail sheets — is developer-only, so a WeatherNext screen
/// never names providers to regular users; developers still see exactly which
/// provider each value came from.
class WeatherOverviewGrid extends StatelessWidget {
  const WeatherOverviewGrid({
    super.key,
    required this.weather,
    required this.palette,
    this.showSourceBadges = true,
    this.showProvenance = false,
  });
  final WeatherSnapshot weather;
  final AtmospherePalette palette;
  final bool showSourceBadges;

  /// Show provider names / run ids inside the tapped detail sheets.
  final bool showProvenance;

  @override
  Widget build(BuildContext context) {
    final w = weather;
    final uvFromDaily = w.uvIndex == null && w.forecast.isNotEmpty && w.forecast.first.uvIndexMax != null;
    final uv = w.uvIndex ?? (uvFromDaily ? w.forecast.first.uvIndexMax : null);
    final missing = w.provenance.missingFields;

    String? reasonFor(String field, String label) {
      if (missing.contains(field)) return 'home.not_provided_by'.tr(namedArgs: {'label': label});
      if (w.fieldSources.sources.containsKey(field) && w.fieldSources.sources[field] == null) {
        return 'home.no_provider_for'.tr();
      }
      return null;
    }

    final tiles = <_OverviewTile>[
      _OverviewTile(
        title: 'home.aqi'.tr(),
        value: _num(w.aqi),
        caption: w.aqi == null ? (reasonFor('air_quality', 'AQI') ?? 'home.unavailable'.tr()) : aqiBand(w.aqi),
        icon: Icons.air_rounded,
        field: 'air_quality',
        accent: aqiColor(w.aqi),
      ),
      _OverviewTile(
        title: 'home.uv_index'.tr(),
        value: uv == null ? '—' : uv.toStringAsFixed(uv % 1 == 0 ? 0 : 1),
        caption: uv == null
            ? (reasonFor('uv_index', 'UV') ?? 'home.unavailable'.tr())
            : uvFromDaily
                ? '${uvBand(uv)} · ${'home.today_max'.tr()}'
                : uvBand(uv),
        icon: Icons.wb_sunny_outlined,
        field: uvFromDaily ? 'uv_index_max' : 'uv_index',
        accent: uvColor(uv),
      ),
      _OverviewTile(
        title: 'home.sunrise'.tr(),
        value: formatClock(w.sunrise),
        caption: w.sunrise == null ? (reasonFor('sunrise', 'sunrise') ?? 'home.unavailable'.tr()) : 'home.local_time'.tr(),
        icon: Icons.wb_twilight_rounded,
        field: 'sunrise',
        accent: const Color(0xFFFBBF24),
      ),
      _OverviewTile(
        title: 'home.sunset'.tr(),
        value: formatClock(w.sunset),
        caption: w.sunset == null ? (reasonFor('sunset', 'sunset') ?? 'home.unavailable'.tr()) : 'home.local_time'.tr(),
        icon: Icons.nights_stay_outlined,
        field: 'sunset',
        accent: const Color(0xFFFB923C),
      ),
      _OverviewTile(
        title: 'home.humidity'.tr(),
        value: _num(w.humidity, suffix: '%'),
        caption: w.humidity == null
            ? (reasonFor('humidity_percent', 'humidity') ?? 'home.unavailable'.tr())
            : w.humidity! >= 80
                ? 'home.humid'.tr()
                : w.humidity! <= 30
                    ? 'home.dry'.tr()
                    : 'home.comfortable'.tr(),
        icon: Icons.opacity_rounded,
        field: 'humidity_percent',
        accent: const Color(0xFF38BDF8),
      ),
      _OverviewTile(
        title: 'home.pressure'.tr(),
        value: _num(w.pressureHpa),
        caption: w.pressureHpa == null ? (reasonFor('pressure_hpa', 'pressure') ?? 'home.unavailable'.tr()) : 'hPa',
        icon: Icons.compress_rounded,
        field: 'pressure_hpa',
        accent: const Color(0xFFA78BFA),
      ),
      _OverviewTile(
        title: 'PM2.5',
        value: _num(w.pm25),
        caption: w.pm25 == null ? (reasonFor('air_quality', 'PM2.5') ?? 'home.unavailable'.tr()) : 'µg/m³',
        icon: Icons.blur_on_rounded,
        field: 'air_quality',
        accent: const Color(0xFF94A3B8),
      ),
      _OverviewTile(
        title: 'home.cloud_cover'.tr(),
        value: _num(w.cloudCover, suffix: '%'),
        caption: w.cloudCover == null
            ? (reasonFor('cloud_cover_percent', 'cloud cover') ?? 'home.unavailable'.tr())
            : 'home.sky_covered'.tr(),
        icon: Icons.cloud_outlined,
        field: 'cloud_cover_percent',
        accent: const Color(0xFFCBD5E1),
      ),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final cols = constraints.maxWidth > 560 ? 4 : 2;
      final tileWidth = (constraints.maxWidth - (cols - 1) * 10) / cols;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final t in tiles)
            SizedBox(
              width: tileWidth,
              child: _tile(context, t),
            ),
        ],
      );
    });
  }

  Widget _tile(BuildContext context, _OverviewTile t) {
    final unavailable = t.value == '—';
    final sourceId = t.field == null ? null : weather.fieldSources.providerFor(t.field!);
    final supplemented = t.field != null && weather.isSupplemented(t.field!);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => showMetricDetailSheet(
          context,
          weather: weather,
          palette: palette,
          title: t.title,
          value: t.value,
          caption: t.caption,
          icon: t.icon,
          field: t.field,
          accent: t.accent,
          showProvenance: showProvenance,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: BoxDecoration(
            color: palette.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(t.icon, size: 16, color: unavailable ? palette.textMuted : (t.accent ?? palette.accent)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      t.title.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w700,
                        color: palette.textMuted,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 16, color: palette.textMuted.withValues(alpha: 0.6)),
                ],
              ),
              const SizedBox(height: 12),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  t.value,
                  style: TextStyle(
                    fontSize: 26,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    color: unavailable ? palette.textMuted : palette.text,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                t.caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.2,
                  color: unavailable ? palette.textMuted.withValues(alpha: 0.8) : (t.accent ?? palette.textMuted),
                  fontWeight: unavailable ? FontWeight.w400 : FontWeight.w600,
                ),
              ),
              if (showSourceBadges && supplemented && !unavailable) ...[
                const SizedBox(height: 8),
                SourceBadge(label: providerDisplayName(sourceId), palette: palette),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Tiny "via <provider>" pill.
class SourceBadge extends StatelessWidget {
  const SourceBadge({super.key, required this.label, required this.palette, this.icon = Icons.alt_route_rounded});
  final String label;
  final AtmospherePalette palette;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 10, color: palette.textMuted),
            const SizedBox(width: 4),
            Text(
              'home.via'.tr(namedArgs: {'source': label}),
              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: palette.textMuted),
            ),
          ],
        ),
      );
}

/// Tab body: horizontal scroll of hourly temperatures, tap for detail.
class WeatherHourlyPanel extends StatelessWidget {
  const WeatherHourlyPanel({super.key, required this.weather, required this.palette, this.maxHours = 48, this.showProvenance = false});
  final WeatherSnapshot weather;
  final AtmospherePalette palette;
  final int maxHours;

  /// Show provider names / run ids inside the tapped detail sheets.
  final bool showProvenance;

  @override
  Widget build(BuildContext context) {
    final nowUtc = DateTime.now().toUtc();
    final cutoff = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day, nowUtc.hour);
    // Never show hours that are already over; the backend does the same, but
    // an older cached payload may still contain them.
    var hours = weather.hourly.where((h) => h.timeUtc == null || !h.timeUtc!.isBefore(cutoff)).toList();
    if (hours.isEmpty) hours = weather.hourly;
    if (hours.isEmpty) {
      return _empty('home.hourly_unavailable'.tr());
    }
    final shown = hours.take(maxHours).toList();
    final temps = shown.map((h) => h.tempC).toList();
    final minT = temps.reduce((a, b) => a < b ? a : b);
    final maxT = temps.reduce((a, b) => a > b ? a : b);
    final span = (maxT - minT).abs() < 1 ? 1.0 : (maxT - minT);

    String? lastDay;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'home.next_hours'.tr(namedArgs: {'n': '${shown.length}'}),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: palette.textMuted),
            ),
            const Spacer(),
            if (weather.currentIsEnsembleMean == true)
              Text('home.ensemble_mean'.tr(),
                  style: TextStyle(fontSize: 11, color: palette.textMuted)),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 152,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: shown.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final h = shown[i];
              final local = h.timeUtc == null ? null : weather.toLocationLocal(h.timeUtc!);
              final dayKey = local == null ? null : '${local.month}-${local.day}';
              final newDay = dayKey != null && dayKey != lastDay && i != 0;
              lastDay = dayKey;
              final isNow = i == 0;
              final rain = h.rainProbability;
              final pct = ((h.tempC - minT) / span).clamp(0.0, 1.0).toDouble();
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => showHourDetailSheet(context, weather: weather, palette: palette, hour: h, index: i, all: shown, showProvenance: showProvenance),
                  child: Container(
                    width: 74,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                    decoration: BoxDecoration(
                      color: isNow ? palette.accent.withValues(alpha: 0.16) : palette.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isNow ? palette.accent.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isNow ? 'home.now'.tr() : (newDay && local != null ? DateFormat('EEE').format(local) : h.label),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: newDay || isNow ? FontWeight.w700 : FontWeight.w500,
                            color: isNow ? palette.accent : palette.textMuted,
                          ),
                        ),
                        if (newDay && local != null)
                          Text(h.label, style: TextStyle(fontSize: 9.5, color: palette.textMuted)),
                        Icon(iconForCondition(h.condition, h.weatherCode), size: 20,
                            color: h.condition == null ? palette.textMuted.withValues(alpha: 0.5) : palette.accent),
                        Text('${h.tempC.round()}°',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: palette.text)),
                        // Tiny temperature bar – relative to the visible range.
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: SizedBox(
                            height: 3,
                            width: 40,
                            child: Stack(children: [
                              Container(color: Colors.white.withValues(alpha: 0.08)),
                              FractionallySizedBox(
                                widthFactor: 0.25 + 0.75 * pct,
                                child: Container(color: palette.accent.withValues(alpha: 0.8)),
                              ),
                            ]),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.water_drop, size: 10,
                                color: (rain ?? 0) >= 30 ? const Color(0xFF38BDF8) : palette.textMuted.withValues(alpha: 0.6)),
                            const SizedBox(width: 2),
                            Text(rain == null ? '—' : '${rain.round()}%',
                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: palette.textMuted)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'home.tap_for_details'.tr(),
          style: TextStyle(fontSize: 10.5, color: palette.textMuted.withValues(alpha: 0.7)),
        ),
      ],
    );
  }

  Widget _empty(String text) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(children: [
          Icon(Icons.info_outline, size: 16, color: palette.textMuted),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: palette.textMuted))),
        ]),
      );
}

/// Tab body: 7-day forecast list, tap a row for detail.
class WeatherDailyPanel extends StatelessWidget {
  const WeatherDailyPanel({super.key, required this.weather, required this.palette, this.maxDays = 7, this.showProvenance = false});
  final WeatherSnapshot weather;
  final AtmospherePalette palette;
  final int maxDays;

  /// Show provider names / run ids inside the tapped detail sheets.
  final bool showProvenance;

  @override
  Widget build(BuildContext context) {
    final days = weather.forecast.take(maxDays).toList();
    if (days.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Text('home.forecast_unavailable'.tr(), style: TextStyle(color: palette.textMuted)),
      );
    }
    final highs = days.map((d) => d.highC).whereType<double>().toList();
    final lows = days.map((d) => d.lowC).whereType<double>().toList();
    final overallMax = highs.isEmpty ? null : highs.reduce((a, b) => a > b ? a : b);
    final overallMin = lows.isEmpty ? null : lows.reduce((a, b) => a < b ? a : b);
    final range = (overallMax != null && overallMin != null && overallMax > overallMin) ? overallMax - overallMin : null;

    final todayLocal = weather.localNow();
    final todayKey = DateFormat('yyyy-MM-dd').format(todayLocal);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(
            'home.day_forecast'.tr(namedArgs: {'n': '${days.length}'}),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: palette.textMuted),
          ),
          const Spacer(),
          if (days.length < maxDays && weather.forecastDays < maxDays)
            Text('home.days_available'.tr(namedArgs: {'n': '${weather.forecastDays}'}),
                style: TextStyle(fontSize: 11, color: palette.textMuted)),
        ]),
        const SizedBox(height: 10),
        ...days.asMap().entries.map((entry) {
          final i = entry.key;
          final d = entry.value;
          final isToday = d.date == todayKey || (i == 0 && d.date.isEmpty);
          final label = isToday
              ? 'common.today'.tr()
              : d.dateUtc == null
                  ? d.date
                  : DateFormat('EEE').format(d.dateUtc!.toUtc());
          final dateSmall = d.dateUtc == null ? '' : DateFormat('d MMM').format(d.dateUtc!.toUtc());
          final partial = d.coversFullDay == false;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => showDayDetailSheet(context, weather: weather, palette: palette, day: d, index: i, showProvenance: showProvenance),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isToday ? palette.accent.withValues(alpha: 0.10) : palette.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isToday ? palette.accent.withValues(alpha: 0.45) : Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 58,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(label,
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: isToday ? palette.accent : palette.text)),
                            if (dateSmall.isNotEmpty)
                              Text(dateSmall, style: TextStyle(fontSize: 10.5, color: palette.textMuted)),
                          ],
                        ),
                      ),
                      Icon(iconForCondition(d.condition, d.weatherCode), size: 20,
                          color: d.condition == '—' ? palette.textMuted.withValues(alpha: 0.5) : palette.accent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(d.condition,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: palette.text, fontSize: 13, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 2),
                            Row(children: [
                              Icon(Icons.water_drop, size: 10,
                                  color: (d.rainProbability ?? 0) >= 30 ? const Color(0xFF38BDF8) : palette.textMuted),
                              const SizedBox(width: 2),
                              Text(
                                d.rainProbability == null ? '—' : '${d.rainProbability!.round()}%',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: palette.textMuted),
                              ),
                              if (d.precipMm != null && d.precipMm! >= 0.1) ...[
                                const SizedBox(width: 6),
                                Text(
                                  '${d.precipMm!.toStringAsFixed(d.precipMm! < 10 ? 1 : 0)} mm${partial ? '*' : ''}',
                                  style: TextStyle(fontSize: 11, color: palette.textMuted),
                                ),
                              ],
                            ]),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _TempRange(
                        low: d.lowC,
                        high: d.highC,
                        overallMin: overallMin,
                        range: range,
                        palette: palette,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
        if (days.any((d) => d.coversFullDay == false))
          Text('home.partial_day_note'.tr(),
              style: TextStyle(fontSize: 10.5, color: palette.textMuted.withValues(alpha: 0.8))),
        Text('home.tap_for_details'.tr(),
            style: TextStyle(fontSize: 10.5, color: palette.textMuted.withValues(alpha: 0.7))),
      ],
    );
  }
}

/// "24° ▬▬▬ 32°" range bar, positioned within the week's overall span.
class _TempRange extends StatelessWidget {
  const _TempRange({
    required this.low,
    required this.high,
    required this.overallMin,
    required this.range,
    required this.palette,
  });
  final double? low;
  final double? high;
  final double? overallMin;
  final double? range;
  final AtmospherePalette palette;

  @override
  Widget build(BuildContext context) {
    final lowText = low == null ? '—' : '${low!.round()}°';
    final highText = high == null ? '—' : '${high!.round()}°';
    double start = 0, end = 1;
    if (low != null && high != null && overallMin != null && range != null && range! > 0) {
      start = ((low! - overallMin!) / range!).clamp(0.0, 1.0).toDouble();
      end = ((high! - overallMin!) / range!).clamp(0.0, 1.0).toDouble();
      if (end - start < 0.08) end = (start + 0.08).clamp(0.0, 1.0).toDouble();
    }
    return SizedBox(
      width: 118,
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(lowText,
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: palette.textMuted)),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: LayoutBuilder(builder: (_, c) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: SizedBox(
                  height: 5,
                  child: Stack(children: [
                    Container(color: Colors.white.withValues(alpha: 0.10)),
                    Positioned(
                      left: c.maxWidth * start,
                      width: c.maxWidth * (end - start),
                      top: 0,
                      bottom: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            const Color(0xFF38BDF8).withValues(alpha: 0.9),
                            palette.accent,
                            const Color(0xFFFB923C).withValues(alpha: 0.9),
                          ]),
                        ),
                      ),
                    ),
                  ]),
                ),
              );
            }),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 30,
            child: Text(highText,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: palette.text)),
          ),
        ],
      ),
    );
  }
}
