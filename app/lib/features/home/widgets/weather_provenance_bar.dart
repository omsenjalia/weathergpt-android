import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../models/weather.dart';
import '../theme/atmosphere_theme.dart';

/// Source / freshness + WeatherNext status.
/// Shows WeatherNext badge when selected_source is weathernext,
/// and fallback warning when weathernext failed.
class WeatherProvenanceBar extends StatelessWidget {
  const WeatherProvenanceBar({
    super.key,
    required this.weather,
    required this.palette,
    this.showEnrichments = true,
    this.nowUtc,
  });

  final WeatherSnapshot weather;
  final AtmospherePalette palette;
  final bool showEnrichments;
  final DateTime? nowUtc;

  static const _label = TextStyle(fontSize: 10.5, height: 1.1);
  static const _value = TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, height: 1.1);

  String _sourceLabel() {
    final p = weather.provenance;
    if (!p.hasSource) return 'home.source_not_reported'.tr();
    final name = p.selectedSource ?? p.source!;
    return switch (p.provider) {
      WeatherProvider.imd => 'IMD',
      WeatherProvider.weathernext => 'WeatherNext',
      WeatherProvider.accuweather => 'AccuWeather',
      WeatherProvider.openMeteo => 'Open-Meteo',
      WeatherProvider.unknown => name,
    };
  }

  String _displayName(String id) => switch (providerFromName(id)) {
        WeatherProvider.imd => 'IMD',
        WeatherProvider.weathernext => 'WeatherNext',
        WeatherProvider.accuweather => 'AccuWeather',
        WeatherProvider.openMeteo => 'Open-Meteo',
        WeatherProvider.unknown => id,
      };

  String? _freshnessLabel() {
    final stamp = weather.provenance.effectiveAtUtc;
    if (stamp == null) return null;
    final stale = weather.provenance.isStaleAt(nowUtc ?? DateTime.now().toUtc());
    final time = DateFormat('HH:mm').format(stamp.toLocal());
    return stale ? 'home.data_stale'.tr(namedArgs: {'time': time}) : 'home.updated'.tr(namedArgs: {'time': time});
  }

  @override
  Widget build(BuildContext context) {
    final spread = weather.temperatureSpread;
    final rain = weather.precipNext24h;
    final freshness = _freshnessLabel();
    final prov = weather.provenance;

    final chips = <Widget>[
      _chip(
        icon: prov.fallback ? Icons.report_gmailerrorred_outlined : Icons.public,
        label: prov.fallback ? 'home.source_fallback'.tr() : 'home.source'.tr(),
        value: _sourceLabel(),
        warn: prov.fallback,
        accent: prov.isWeatherNext ? const Color(0xFF4285F4) : null,
      ),
      if (freshness != null)
        _chip(
          icon: prov.isStaleAt(nowUtc ?? DateTime.now().toUtc()) ? Icons.history_toggle_off : Icons.schedule,
          label: prov.isStaleAt(nowUtc ?? DateTime.now().toUtc()) ? 'home.stale'.tr() : 'home.fresh'.tr(),
          value: freshness,
          warn: prov.isStaleAt(nowUtc ?? DateTime.now().toUtc()),
        ),
      if (prov.runId != null) _chip(icon: Icons.memory, label: 'home.run'.tr(), value: prov.runId!),
      if (prov.model != null) _chip(icon: Icons.model_training, label: 'Model', value: prov.model!),
      if (showEnrichments && spread != null)
        _chip(icon: Icons.unfold_more, label: 'home.temp_spread'.tr(), value: '${spread.p10C.round()}°–${spread.p90C.round()}°'),
      if (showEnrichments && rain != null)
        _chip(
          icon: Icons.water_drop_outlined,
          label: rain.isComplete ? 'home.next_24h_rain'.tr() : 'home.next_24h_rain_partial'.tr(),
          value: '${rain.totalMm.toStringAsFixed(rain.totalMm < 10 ? 1 : 0)} mm',
          warn: !rain.isComplete,
        ),
      if (prov.weatherNextFailed)
        _chip(
          icon: Icons.warning_amber_rounded,
          label: 'WeatherNext',
          value: prov.fallbackReasons.firstWhere((r) => r.isWeatherNext && r.isRealFailure).humanReason,
          warn: true,
        ),
      if (weather.fieldSources.contributors.length > 1 ||
          weather.fieldSources.contributors.any((c) => providerFromName(c) != prov.provider))
        _chip(
          icon: Icons.alt_route_rounded,
          label: 'home.secondary'.tr(),
          value: weather.fieldSources.contributors
              .where((c) => providerFromName(c) != prov.provider)
              .map(_displayName)
              .join(', '),
        ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Wrap(spacing: 6, runSpacing: 6, children: chips),
    );
  }

  Widget _chip({required IconData icon, required String label, required String value, bool warn = false, Color? accent}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: warn
                ? const Color(0xFFFBBF24).withValues(alpha: 0.5)
                : accent != null
                    ? accent.withValues(alpha: 0.5)
                    : const Color(0x33FFFFFF),
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: accent ?? palette.textMuted),
          const SizedBox(width: 5),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label.toUpperCase(), style: _label.copyWith(color: palette.textMuted)),
            Text(value, style: _value.copyWith(color: palette.text)),
          ]),
        ]),
      );
}
