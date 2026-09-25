import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../models/weather.dart';
import '../theme/atmosphere_theme.dart';
import 'weather_detail_panels.dart';

const _sheetBg = Color(0xF50E1626);

Future<void> _showSheet(BuildContext context, {required Widget child}) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.62,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (ctx, controller) => Container(
          decoration: BoxDecoration(
            color: _sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
            ),
          ),
          child: ListView(
            controller: controller,
            padding: EdgeInsets.fromLTRB(20, 10, 20, 24 + MediaQuery.paddingOf(ctx).bottom),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              child,
            ],
          ),
        ),
      ),
    );

class _Row {
  const _Row(this.label, this.value, {this.icon, this.field, this.note});
  final String label;
  final String value;
  final IconData? icon;
  final String? field;
  final String? note;
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.subtitle, required this.palette, this.icon, this.trailing});
  final String title;
  final String subtitle;
  final AtmospherePalette palette;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: palette.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: palette.accent, size: 24),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 13, color: Colors.white60)),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      );
}

class _Rows extends StatelessWidget {
  const _Rows({required this.rows, required this.weather, required this.palette, this.showSources = false});
  final List<_Row> rows;
  final WeatherSnapshot weather;
  final AtmospherePalette palette;
  final bool showSources;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                child: Row(
                  children: [
                    if (rows[i].icon != null) ...[
                      Icon(rows[i].icon, size: 16, color: Colors.white54),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(rows[i].label, style: const TextStyle(fontSize: 13, color: Colors.white70)),
                          if (rows[i].note != null)
                            Text(rows[i].note!, style: const TextStyle(fontSize: 10.5, color: Colors.white38)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          rows[i].value,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: rows[i].value == '—' ? Colors.white38 : Colors.white,
                          ),
                        ),
                        if (showSources && rows[i].field != null && rows[i].value != '—' && weather.isSupplemented(rows[i].field!))
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: SourceBadge(
                              label: providerDisplayName(weather.fieldSources.providerFor(rows[i].field!)),
                              palette: palette,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
}

String _n(num? v, {int digits = 0, String suffix = ''}) => v == null ? '—' : '${v.toStringAsFixed(digits)}$suffix';

String _sourceLine(WeatherSnapshot w) {
  final p = w.provenance;
  final src = providerDisplayName(p.selectedSource ?? p.source);
  final extra = <String>[];
  if (p.runId != null) extra.add(p.runId!);
  if (p.model != null && p.runId == null) extra.add(p.model!);
  return extra.isEmpty ? src : '$src · ${extra.join(' · ')}';
}

/// Sheet footer. Provider names are developer-only ([showProvenance]); regular
/// users see just the ensemble note, which describes the numbers rather than
/// naming who computed them.
Widget _footer(WeatherSnapshot w, {bool showProvenance = false}) {
  final contributors = w.fieldSources.contributors
      .where((c) => providerFromName(c) != providerFromName(w.provenance.selectedSource ?? w.provenance.source))
      .map(providerDisplayName)
      .toList();
  if (!showProvenance && w.currentIsEnsembleMean != true) {
    return const SizedBox.shrink();
  }
  return Padding(
    padding: const EdgeInsets.only(top: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showProvenance) ...[
          Row(children: [
            const Icon(Icons.verified_outlined, size: 13, color: Colors.white38),
            const SizedBox(width: 6),
            Expanded(
              child: Text('${'home.source'.tr()}: ${_sourceLine(w)}',
                  style: const TextStyle(fontSize: 11, color: Colors.white38)),
            ),
          ]),
          if (contributors.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 19),
              child: Text(
                'home.secondary_fields_via'.tr(namedArgs: {'sources': contributors.join(', ')}),
                style: const TextStyle(fontSize: 11, color: Colors.white38),
              ),
            ),
        ],
        if (w.currentIsEnsembleMean == true)
          Padding(
            padding: EdgeInsets.only(top: showProvenance ? 4 : 0, left: 19),
            child: Text('home.ensemble_note'.tr(), style: const TextStyle(fontSize: 11, color: Colors.white38)),
          ),
      ],
    ),
  );
}

/// Detail for one hourly bucket.
///
/// [showProvenance] gates every provider name in the sheet (per-row "via"
/// badges, source footer). It is true only in developer mode.
Future<void> showHourDetailSheet(
  BuildContext context, {
  required WeatherSnapshot weather,
  required AtmospherePalette palette,
  required HourlyPoint hour,
  required int index,
  required List<HourlyPoint> all,
  bool showProvenance = false,
}) {
  final local = hour.timeUtc == null ? null : weather.toLocationLocal(hour.timeUtc!);
  final title = local == null ? hour.label : DateFormat('EEEE, d MMM · h a').format(local);
  final subtitle = hour.condition ?? (hour.missingReason != null ? 'home.condition_unknown'.tr() : '—');
  final isUnknownCondition = hour.condition == null;

  // Trend vs previous / next hour.
  final prev = index > 0 ? all[index - 1] : null;
  final next = index + 1 < all.length ? all[index + 1] : null;
  String trend = '';
  if (prev != null) {
    final d = hour.tempC - prev.tempC;
    trend = d.abs() < 0.3 ? 'home.trend_steady'.tr() : (d > 0 ? 'home.trend_warming'.tr(namedArgs: {'d': d.abs().toStringAsFixed(1)}) : 'home.trend_cooling'.tr(namedArgs: {'d': d.abs().toStringAsFixed(1)}));
  } else if (next != null) {
    final d = next.tempC - hour.tempC;
    trend = d.abs() < 0.3 ? 'home.trend_steady'.tr() : (d > 0 ? 'home.trend_then_warmer'.tr() : 'home.trend_then_cooler'.tr());
  }

  final rows = <_Row>[
    _Row('home.temperature'.tr(), '${hour.tempC.toStringAsFixed(1)}°C', icon: Icons.thermostat_rounded, note: trend.isEmpty ? null : trend),
    if (hour.feelsLikeC != null) _Row('home.feels_like'.tr(), '${hour.feelsLikeC!.toStringAsFixed(1)}°C', icon: Icons.accessibility_new_rounded),
    _Row('home.rain_chance'.tr(), _n(hour.rainProbability, suffix: '%'), icon: Icons.umbrella_rounded,
        note: weather.currentIsEnsembleMean == true && hour.rainProbability != null ? 'home.rain_lower_bound'.tr() : null),
    _Row('home.precipitation'.tr(), hour.precipMm == null ? '—' : '${hour.precipMm!.toStringAsFixed(hour.precipMm! < 1 ? 2 : 1)} mm', icon: Icons.water_drop_outlined),
    _Row('home.wind'.tr(), hour.windKmh == null ? '—' : '${hour.windKmh!.toStringAsFixed(0)} km/h${hour.windDirection == null ? '' : ' ${windDirLabel(hour.windDirection)}'}', icon: Icons.air_rounded),
    _Row('home.humidity'.tr(), _n(hour.humidity, suffix: '%'), icon: Icons.opacity_rounded, field: 'humidity_percent'),
    if (hour.cloudCover != null) _Row('home.cloud_cover'.tr(), _n(hour.cloudCover, suffix: '%'), icon: Icons.cloud_outlined, field: 'cloud_cover_percent'),
    if (hour.pressureHpa != null) _Row('home.pressure'.tr(), _n(hour.pressureHpa, suffix: ' hPa'), icon: Icons.compress_rounded, field: 'pressure_hpa'),
    if (hour.uvIndex != null) _Row('home.uv_index'.tr(), '${_n(hour.uvIndex, digits: hour.uvIndex! % 1 == 0 ? 0 : 1)} · ${uvBand(hour.uvIndex)}', icon: Icons.wb_sunny_outlined, field: 'uv_index'),
    if (hour.weatherCode != null) _Row('home.wmo_code'.tr(), '${hour.weatherCode}', icon: Icons.tag_rounded, field: 'hourly_condition'),
    if (hour.timeUtc != null) _Row('UTC', DateFormat('yyyy-MM-dd HH:mm').format(hour.timeUtc!.toUtc()), icon: Icons.public),
  ];

  return _showSheet(
    context,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(
          title: title,
          subtitle: subtitle,
          palette: palette,
          icon: iconForCondition(hour.condition, hour.weatherCode),
          trailing: Text('${hour.tempC.round()}°',
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w300, color: Colors.white, height: 1)),
        ),
        if (isUnknownCondition && hour.missingReason != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: _note(Icons.info_outline, 'home.missing_reason'.tr(namedArgs: {'reason': hour.missingReason!})),
          ),
        const SizedBox(height: 16),
        _Rows(rows: rows, weather: weather, palette: palette, showSources: showProvenance),
        _footer(weather, showProvenance: showProvenance),
      ],
    ),
  );
}

/// Detail for one forecast day, including that day's hourly strip.
///
/// [showProvenance] gates every provider name in the sheet. It is true only
/// in developer mode.
Future<void> showDayDetailSheet(
  BuildContext context, {
  required WeatherSnapshot weather,
  required AtmospherePalette palette,
  required DayForecast day,
  required int index,
  bool showProvenance = false,
}) {
  final date = day.dateUtc;
  final title = date == null ? day.date : DateFormat('EEEE, d MMMM').format(date.toUtc());
  final partial = day.coversFullDay == false;

  // Hours belonging to this local date.
  final hours = weather.hourly.where((h) {
    if (h.timeUtc == null) return false;
    final l = weather.toLocationLocal(h.timeUtc!);
    return DateFormat('yyyy-MM-dd').format(l) == day.date;
  }).toList();

  final rows = <_Row>[
    _Row('home.high_low'.tr(), '${_n(day.highC)}° / ${_n(day.lowC)}°', icon: Icons.thermostat_rounded,
        note: day.statistic == 'ensemble_mean' ? 'home.ensemble_mean'.tr() : null),
    if (day.hasEnvelope)
      _Row('home.temp_spread'.tr(), '${day.lowP10C!.round()}° – ${day.highP90C!.round()}°', icon: Icons.unfold_more_rounded,
          note: 'home.envelope_note'.tr()),
    _Row('home.rain_chance'.tr(), _n(day.rainProbability, suffix: '%'), icon: Icons.umbrella_rounded,
        note: day.statistic == 'ensemble_mean' && day.rainProbability != null ? 'home.rain_lower_bound'.tr() : null),
    _Row(
      'home.precipitation'.tr(),
      day.precipMm == null ? '—' : '${day.precipMm!.toStringAsFixed(day.precipMm! < 10 ? 1 : 0)} mm',
      icon: Icons.water_drop_outlined,
      note: partial
          ? 'home.covers_only'.tr(namedArgs: {'interval': day.precipIntervalLabel ?? '${day.hoursCovered ?? '?'}h'})
          : day.precipIntervalLabel,
    ),
    _Row('home.max_wind'.tr(), day.windKmhMax == null ? '—' : '${day.windKmhMax!.toStringAsFixed(0)} km/h', icon: Icons.air_rounded),
    _Row('home.sunrise'.tr(), formatClock(day.sunrise), icon: Icons.wb_twilight_rounded, field: index == 0 ? 'sunrise' : null,
        note: showProvenance && day.fieldSources['sunrise'] != null && index != 0 ? 'home.via'.tr(namedArgs: {'source': providerDisplayName(day.fieldSources['sunrise'])}) : null),
    _Row('home.sunset'.tr(), formatClock(day.sunset), icon: Icons.nights_stay_outlined, field: index == 0 ? 'sunset' : null,
        note: showProvenance && day.fieldSources['sunset'] != null && index != 0 ? 'home.via'.tr(namedArgs: {'source': providerDisplayName(day.fieldSources['sunset'])}) : null),
    if (day.uvIndexMax != null)
      _Row('home.uv_max'.tr(), '${_n(day.uvIndexMax, digits: day.uvIndexMax! % 1 == 0 ? 0 : 1)} · ${uvBand(day.uvIndexMax)}', icon: Icons.wb_sunny_outlined,
          field: index == 0 ? 'uv_index_max' : null,
          note: showProvenance && day.fieldSources['uv_index_max'] != null && index != 0 ? 'home.via'.tr(namedArgs: {'source': providerDisplayName(day.fieldSources['uv_index_max'])}) : null),
    if (day.weatherCode != null) _Row('home.wmo_code'.tr(), '${day.weatherCode}', icon: Icons.tag_rounded),
    if (day.hoursCovered != null) _Row('home.hours_in_day'.tr(), '${day.hoursCovered} / 24', icon: Icons.schedule_rounded),
  ];

  return _showSheet(
    context,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(
          title: title,
          subtitle: day.condition,
          palette: palette,
          icon: iconForCondition(day.condition, day.weatherCode),
          trailing: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${_n(day.highC)}°', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: Colors.white, height: 1)),
              Text('${_n(day.lowC)}°', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w400, color: Colors.white54, height: 1.2)),
            ],
          ),
        ),
        if (partial)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: _note(Icons.hourglass_bottom_rounded, 'home.partial_day_detail'.tr(namedArgs: {'n': '${day.hoursCovered ?? '?'}'})),
          ),
        if (hours.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('home.hour_by_hour'.tr(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white54, letterSpacing: 0.6)),
          const SizedBox(height: 8),
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: hours.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (ctx, i) {
                final h = hours[i];
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => showHourDetailSheet(ctx, weather: weather, palette: palette, hour: h, index: i, all: hours, showProvenance: showProvenance),
                  child: Container(
                    width: 60,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(h.label, style: const TextStyle(fontSize: 10.5, color: Colors.white54)),
                        Icon(iconForCondition(h.condition, h.weatherCode), size: 16,
                            color: h.condition == null ? Colors.white24 : palette.accent),
                        Text('${h.tempC.round()}°', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                        Text(h.rainProbability == null ? '—' : '${h.rainProbability!.round()}%',
                            style: const TextStyle(fontSize: 10, color: Colors.white54)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 16),
        _Rows(rows: rows, weather: weather, palette: palette, showSources: showProvenance),
        _footer(weather, showProvenance: showProvenance),
      ],
    ),
  );
}

/// Detail for one overview tile (AQI, UV, sunrise…): what it means and — in
/// developer mode only — where it came from.
///
/// [showProvenance] gates the source row, the run row and every provider name.
/// Regular users get the value, its meaning and an honest unavailable note.
Future<void> showMetricDetailSheet(
  BuildContext context, {
  required WeatherSnapshot weather,
  required AtmospherePalette palette,
  required String title,
  required String value,
  required String caption,
  required IconData icon,
  String? field,
  Color? accent,
  bool showProvenance = false,
}) {
  final w = weather;
  final sourceId = field == null ? null : w.fieldSources.providerFor(field);
  final primary = w.provenance.selectedSource ?? w.provenance.source;
  final unavailable = value == '—';
  final explicitNull = field != null && w.fieldSources.sources.containsKey(field) && sourceId == null;

  String explanation;
  final f = field ?? '';
  if (f == 'air_quality') {
    explanation = 'home.explain_aqi'.tr();
  } else if (f.startsWith('uv')) {
    explanation = 'home.explain_uv'.tr();
  } else if (f == 'sunrise' || f == 'sunset') {
    explanation = 'home.explain_sun'.tr();
  } else if (f == 'humidity_percent') {
    explanation = 'home.explain_humidity'.tr();
  } else if (f == 'pressure_hpa') {
    explanation = 'home.explain_pressure'.tr();
  } else if (f == 'cloud_cover_percent') {
    explanation = 'home.explain_cloud'.tr();
  } else {
    explanation = '';
  }

  final rows = <_Row>[
    _Row('home.value'.tr(), value, icon: icon),
    if (!unavailable) _Row('home.meaning'.tr(), caption, icon: Icons.lightbulb_outline_rounded),
    if (showProvenance)
      _Row(
        'home.source'.tr(),
        unavailable
            ? (explicitNull ? 'home.no_provider_for'.tr() : 'home.source_not_reported'.tr())
            : providerDisplayName(sourceId ?? primary),
        icon: Icons.hub_outlined,
        note: !unavailable && sourceId != null && providerFromName(sourceId) != providerFromName(primary)
            ? 'home.supplemented_note'.tr(namedArgs: {'primary': providerDisplayName(primary)})
            : null,
      ),
    if (f == 'air_quality' && w.pm25 != null) _Row('PM2.5', '${w.pm25!.toStringAsFixed(0)} µg/m³', icon: Icons.blur_on_rounded),
    if (f == 'air_quality' && w.aqi != null) _Row('home.scale'.tr(), 'European AQI (0–100+)', icon: Icons.straighten_rounded),
    if ((f == 'sunrise' || f == 'sunset') && w.timezoneId != null) _Row('home.timezone'.tr(), w.timezoneId!, icon: Icons.schedule_rounded),
    if (f == 'pressure_hpa' && w.rawPayload?['current'] is Map && (w.rawPayload!['current'] as Map)['pressure_type'] != null)
      _Row('home.pressure_type'.tr(), '${(w.rawPayload!['current'] as Map)['pressure_type']}'.toUpperCase(), icon: Icons.layers_outlined),
    if (showProvenance && w.provenance.runId != null) _Row('home.run'.tr(), w.provenance.runId!, icon: Icons.memory_rounded),
  ];

  return _showSheet(
    context,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(
          title: title,
          subtitle: unavailable ? 'home.unavailable'.tr() : caption,
          palette: palette,
          icon: icon,
          trailing: Text(value,
              style: TextStyle(fontSize: 34, fontWeight: FontWeight.w600, color: unavailable ? Colors.white38 : (accent ?? Colors.white), height: 1)),
        ),
        if (explanation.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(explanation, style: const TextStyle(fontSize: 13, color: Colors.white70, height: 1.4)),
        ],
        if (unavailable) ...[
          const SizedBox(height: 12),
          _note(
            Icons.info_outline,
            showProvenance
                ? (explicitNull
                    ? 'home.unavailable_explicit'.tr()
                    : 'home.unavailable_generic'.tr(namedArgs: {'primary': providerDisplayName(primary)}))
                : 'home.unavailable_generic_short'.tr(),
          ),
        ],
        const SizedBox(height: 16),
        _Rows(rows: rows, weather: weather, palette: palette, showSources: false),
        _footer(weather, showProvenance: showProvenance),
      ],
    ),
  );
}

Widget _note(IconData icon, String text) => Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFBBF24).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFBBF24).withValues(alpha: 0.35)),
      ),
      child: Row(children: [
        Icon(icon, size: 16, color: const Color(0xFFFBBF24)),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.3))),
      ]),
    );
