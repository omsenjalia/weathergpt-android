import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/services/api_client.dart';
import '../../../core/services/request_log.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/weather.dart';
import '../../home/providers/location_provider.dart';
import '../../home/providers/weather_provider.dart';
import '../../home/theme/atmosphere_theme.dart';
import '../providers/developer_options_provider.dart';
import '../providers/settings_provider.dart';

/// Backend health for the selected provider chain (`/v2/weather/health`).
final backendHealthProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ApiClient.instance.get(ApiEndpoints.v2WeatherHealth);
});

/// Developer-only screen: the current snapshot's full state, per-field
/// sources, provider chain decisions, request log and backend health.
class DebugScreen extends ConsumerStatefulWidget {
  const DebugScreen({super.key});

  @override
  ConsumerState<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends ConsumerState<DebugScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 5, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dev = ref.watch(developerOptionsProvider);
    if (!dev.enabled) {
      return Scaffold(
        appBar: AppBar(title: const Text('Debug')),
        body: const Center(child: Text('Enable developer options in Settings first.')),
      );
    }
    final weatherAsync = ref.watch(weatherProvider);
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        title: const Text('Debug'),
        actions: [
          IconButton(
            tooltip: 'Refetch weather',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(weatherProvider);
              ref.invalidate(backendHealthProvider);
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AppColors.accent,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(text: 'State'),
            Tab(text: 'Sources'),
            Tab(text: 'Provenance'),
            Tab(text: 'Requests'),
            Tab(text: 'Backend'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _StateTab(weatherAsync: weatherAsync),
          _SourcesTab(weatherAsync: weatherAsync),
          _ProvenanceTab(weatherAsync: weatherAsync),
          const _RequestsTab(),
          const _BackendTab(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared bits
// ---------------------------------------------------------------------------

Widget _section(String title, {Widget? trailing}) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Row(children: [
        Expanded(
          child: Text(title.toUpperCase(),
              style: const TextStyle(fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w700, color: AppColors.textTertiary)),
        ),
        if (trailing != null) trailing,
      ]),
    );

Widget _card(Widget child) => Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );

class _KV extends StatelessWidget {
  const _KV(this.k, this.v, {this.mono = false, this.color});
  final String k;
  final String v;
  final bool mono;
  final Color? color;

  @override
  Widget build(BuildContext context) => InkWell(
        onLongPress: () {
          Clipboard.setData(ClipboardData(text: v));
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied $k')));
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 132,
                child: Text(k, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
              ),
              Expanded(
                child: Text(
                  v,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontFamily: mono ? 'monospace' : null,
                    fontWeight: FontWeight.w600,
                    color: color ?? (v == '—' || v == 'null' ? AppColors.textTertiary : AppColors.textPrimary),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

Widget _kvList(List<(String, String)> rows, {Map<String, Color>? colors, bool mono = false}) => _card(
      Column(children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const Divider(height: 1, color: AppColors.borderSubtle),
          _KV(rows[i].$1, rows[i].$2, mono: mono, color: colors?[rows[i].$1]),
        ],
      ]),
    );

String _s(Object? v) => v == null ? '—' : '$v';
String _dt(DateTime? d) => d == null ? '—' : '${DateFormat('yyyy-MM-dd HH:mm:ss').format(d.toUtc())}Z';
String _ago(DateTime? d) {
  if (d == null) return '—';
  final diff = DateTime.now().toUtc().difference(d.toUtc());
  if (diff.inMinutes < 1) return '${diff.inSeconds}s ago';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ${diff.inMinutes % 60}m ago';
  return '${diff.inDays}d ${diff.inHours % 24}h ago';
}

String _providerName(String? id) {
  if (id == null) return '—';
  return switch (providerFromName(id)) {
    WeatherProvider.imd => 'IMD',
    WeatherProvider.weathernext => 'WeatherNext',
    WeatherProvider.accuweather => 'AccuWeather',
    WeatherProvider.openMeteo => 'Open-Meteo',
    WeatherProvider.unknown => id,
  };
}

Color _providerColor(String? id) => switch (providerFromName(id)) {
      WeatherProvider.weathernext => const Color(0xFF4285F4),
      WeatherProvider.openMeteo => const Color(0xFFFB923C),
      WeatherProvider.imd => const Color(0xFF34D399),
      WeatherProvider.accuweather => const Color(0xFFF87171),
      WeatherProvider.unknown => AppColors.textSecondary,
    };

Widget _errorBox(Object e) => _card(Padding(
      padding: const EdgeInsets.all(14),
      child: Text('$e', style: const TextStyle(color: AppColors.statusRed)),
    ));

Widget _loading() => const Padding(
      padding: EdgeInsets.all(40),
      child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
    );

Widget _jsonBlock(BuildContext context, Object? data, {String title = 'Raw JSON'}) {
  final text = const JsonEncoder.withIndent('  ').convert(data);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _section(title, trailing: TextButton.icon(
        onPressed: () {
          Clipboard.setData(ClipboardData(text: text));
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied JSON')));
        },
        icon: const Icon(Icons.copy_rounded, size: 14),
        label: const Text('Copy'),
      )),
      _card(Container(
        constraints: const BoxConstraints(maxHeight: 420),
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          child: SelectableText(text, style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppColors.textSecondary, height: 1.35)),
        ),
      )),
    ],
  );
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class _StateTab extends ConsumerWidget {
  const _StateTab({required this.weatherAsync});
  final AsyncValue<WeatherSnapshot> weatherAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dev = ref.watch(developerOptionsProvider);
    final settings = ref.watch(settingsProvider);
    final location = ref.watch(locationProvider);
    final req = ref.watch(lastWeatherRequestProvider);
    final bottom = MediaQuery.paddingOf(context).bottom + 24;

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 4, 16, bottom),
      children: [
        _section('Request'),
        _kvList([
          ('Backend', ApiClient.instance.baseUrl),
          ('Endpoint', req?.endpoint ?? '—'),
          ('Legacy fallback', req == null ? '—' : (req.usedLegacyFallback ? 'YES — /v2 failed' : 'no')),
          if (req?.v2Error != null) ('v2 error', req!.v2Error!),
          ('Query', req == null ? '—' : req.query.entries.map((e) => '${e.key}=${e.value}').join('\n')),
          ('Mode', '${settings.mode.wire} (persona: ${settings.userPersona})'),
          ('Language', settings.language),
          ('Location', '${location.name}\n${location.lat}, ${location.lon}'),
        ], mono: true, colors: {
          'Legacy fallback': req?.usedLegacyFallback == true ? AppColors.statusAmber : AppColors.statusGreenText,
        }),
        _section('Developer overrides'),
        _kvList([
          ('Source pin', dev.sourcePin.label),
          ('Hourly hours', '${dev.hourlyHours}'),
          ('Forecast days', '${dev.forecastDays}'),
          ('Supplement', dev.supplementSecondaryFields ? 'on (fill nulls from Open-Meteo)' : 'OFF (raw provider only)'),
          ('v2 → legacy fallback', dev.disableV2Fallback ? 'DISABLED' : 'enabled'),
          ('Forced period', dev.forcePeriod?.name ?? 'auto'),
          ('Forced sky', dev.forceSky?.name ?? 'auto'),
          ('Video sky', dev.disableVideoSky ? 'disabled' : 'enabled'),
          ('Request log', dev.logRequests ? 'on' : 'off'),
        ]),
        weatherAsync.when(
          loading: () => _loading(),
          error: (e, _) => Column(children: [_section('Snapshot'), _errorBox(e)]),
          data: (w) {
            final sunrise = parseWeatherTime(w.sunrise);
            final sunset = parseWeatherTime(w.sunset);
            final period = dev.forcePeriod ?? periodFromLocalTime(DateTime.now(), sunrise, sunset);
            final sky = dev.forceSky ?? conditionFromWeather(w);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _section('Snapshot'),
                _kvList([
                  ('Parsed from', w.endpoint ?? '—'),
                  ('Fetched', '${_dt(w.fetchedAtUtc)} (${_ago(w.fetchedAtUtc)})'),
                  ('City', w.cityName),
                  ('Timezone', _s(w.timezoneId)),
                  ('UTC offset', w.utcOffset == null ? '—' : '${w.utcOffset!.inMinutes >= 0 ? '+' : '-'}${(w.utcOffset!.inMinutes.abs() ~/ 60).toString().padLeft(2, '0')}:${(w.utcOffset!.inMinutes.abs() % 60).toString().padLeft(2, '0')}'),
                  ('Local now', DateFormat('yyyy-MM-dd HH:mm').format(w.localNow())),
                  ('Degraded', w.degraded == null ? 'not reported (derived: ${w.provenance.fallback})' : '${w.degraded}'),
                  ('Hourly points', '${w.hourly.length}${w.hourlyAvailable == null ? '' : ' of ${w.hourlyAvailable} available'}'),
                  ('Daily rows', '${w.forecast.length}'),
                  ('Resolved period', period.name),
                  ('Resolved sky', sky.name),
                ], colors: {
                  'Degraded': (w.degraded ?? w.provenance.fallback) ? AppColors.statusAmber : AppColors.statusGreenText,
                }),
                _section('Current block'),
                _kvList([
                  ('Valid at', '${_dt(w.currentTimeUtc)} ${w.currentIsEnsembleMean == true ? '(ensemble mean, nearest step)' : ''}'),
                  ('Temperature', _s(w.temperatureC)),
                  ('Feels like', _s(w.feelsLikeC)),
                  ('Condition', '${w.condition} (code ${_s(w.weatherCode)})'),
                  ('High / low', '${_s(w.highC)} / ${_s(w.lowC)}'),
                  ('Humidity', _s(w.humidity)),
                  ('Wind', '${_s(w.windKmh)} km/h ${_s(w.windDirection)}°'),
                  ('Pressure', _s(w.pressureHpa)),
                  ('Rain prob', _s(w.rainProbability)),
                  ('Precip (step)', _s(w.precipMm)),
                  ('Cloud cover', _s(w.cloudCover)),
                  ('UV', _s(w.uvIndex)),
                  ('Sunrise / sunset', '${_s(w.sunrise)} / ${_s(w.sunset)}'),
                  ('AQI / PM2.5', '${_s(w.aqi)} / ${_s(w.pm25)}'),
                  ('Temp spread', w.temperatureSpread == null ? '—' : '${w.temperatureSpread!.p10C}–${w.temperatureSpread!.p90C} (${w.temperatureSpread!.memberCount ?? '?'} members)'),
                  ('Precip 24h', w.precipNext24h == null ? '—' : '${w.precipNext24h!.totalMm} mm ${w.precipNext24h!.isComplete ? '' : '(partial)'}'),
                ]),
                _section('Missing / null reasons'),
                _kvList([
                  ('missing_fields', w.provenance.missingFields.isEmpty ? '—' : w.provenance.missingFields.join(', ')),
                  ('current.missing_reason', _s((w.rawPayload?['current'] as Map?)?['missing_reason'])),
                  ('hourly w/o condition', '${w.hourly.where((h) => h.condition == null).length} / ${w.hourly.length}'),
                  ('hourly w/o humidity', '${w.hourly.where((h) => h.humidity == null).length} / ${w.hourly.length}'),
                  ('daily w/o sunrise', '${w.forecast.where((d) => d.sunrise == null).length} / ${w.forecast.length}'),
                ]),
                if (w.rawPayload != null) _jsonBlock(context, w.rawPayload, title: 'Raw payload'),
              ],
            );
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Sources
// ---------------------------------------------------------------------------

class _SourcesTab extends StatelessWidget {
  const _SourcesTab({required this.weatherAsync});
  final AsyncValue<WeatherSnapshot> weatherAsync;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom + 24;
    return weatherAsync.when(
      loading: () => _loading(),
      error: (e, _) => ListView(padding: const EdgeInsets.all(16), children: [_errorBox(e)]),
      data: (w) {
        final fs = w.fieldSources;
        final primary = w.provenance.selectedSource ?? w.provenance.source;
        final rows = fs.sources.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
        return ListView(
          padding: EdgeInsets.fromLTRB(16, 4, 16, bottom),
          children: [
            _section('Selected source'),
            _card(Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: _providerColor(primary), shape: BoxShape.circle)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_providerName(primary), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    Text('requested: ${_s(w.provenance.requestedSource)} · policy ${_s(w.provenance.selectionPolicyVersion)}',
                        style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                  ]),
                ),
              ]),
            )),
            _section('Per-field attribution', trailing: Text('${fs.sources.length} fields', style: const TextStyle(fontSize: 11, color: AppColors.textTertiary))),
            if (fs.isEmpty)
              _card(const Padding(
                padding: EdgeInsets.all(14),
                child: Text('Backend sent no field_sources. Every rendered value is attributed to the selected source; '
                    'a "—" means the provider did not supply it. Update the backend to get per-field attribution.',
                    style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
              ))
            else
              _card(Column(children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: AppColors.borderSubtle),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    child: Row(children: [
                      Expanded(child: Text(rows[i].key, style: const TextStyle(fontSize: 12.5, fontFamily: 'monospace'))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _providerColor(rows[i].value).withValues(alpha: rows[i].value == null ? 0.05 : 0.18),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          rows[i].value == null ? 'no provider' : _providerName(rows[i].value),
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                              color: rows[i].value == null ? AppColors.textTertiary : _providerColor(rows[i].value)),
                        ),
                      ),
                    ]),
                  ),
                ],
              ])),
            _section('Supplement (secondary provider)'),
            _kvList([
              ('Provider', _providerName(fs.supplementProvider)),
              ('Enabled', '${fs.supplementEnabled}'),
              ('Attempted', '${fs.supplementAttempted}'),
              ('Cache hit', '${fs.supplementCacheHit}'),
              ('Filled', fs.supplementFilled.isEmpty ? '—' : fs.supplementFilled.join(', ')),
              ('Errors', fs.supplementErrors.isEmpty ? '—' : fs.supplementErrors.join('\n')),
            ], colors: {'Errors': fs.supplementErrors.isEmpty ? AppColors.textTertiary : AppColors.statusRed}),
            _section('Per-day attribution'),
            _card(Column(children: [
              for (var i = 0; i < w.forecast.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: AppColors.borderSubtle),
                _KV(
                  w.forecast[i].date,
                  [
                    'source=${_s(w.forecast[i].source)}',
                    'stat=${_s(w.forecast[i].statistic)}',
                    'hours=${_s(w.forecast[i].hoursCovered)}',
                    if (w.forecast[i].fieldSources.isNotEmpty)
                      'filled: ${w.forecast[i].fieldSources.entries.map((e) => '${e.key}←${_providerName(e.value)}').join(', ')}',
                  ].join('\n'),
                  mono: true,
                ),
              ],
            ])),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Provenance
// ---------------------------------------------------------------------------

class _ProvenanceTab extends StatelessWidget {
  const _ProvenanceTab({required this.weatherAsync});
  final AsyncValue<WeatherSnapshot> weatherAsync;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom + 24;
    return weatherAsync.when(
      loading: () => _loading(),
      error: (e, _) => ListView(padding: const EdgeInsets.all(16), children: [_errorBox(e)]),
      data: (w) {
        final p = w.provenance;
        final ageH = p.issuedAtUtc == null ? null : DateTime.now().toUtc().difference(p.issuedAtUtc!).inMinutes / 60;
        return ListView(
          padding: EdgeInsets.fromLTRB(16, 4, 16, bottom),
          children: [
            _section('Run'),
            _kvList([
              ('Model', '${_s(p.model)} (v${_s(p.modelVersion)})'),
              ('Run id', _s(p.runId)),
              ('Init time', '${_dt(p.issuedAtUtc)}${ageH == null ? '' : '  (${ageH.toStringAsFixed(1)} h old)'}'),
              ('Served at', _dt(p.retrievedAtUtc)),
              ('Validity', '${_dt(p.validityStartUtc)}\n→ ${_dt(p.validityEndUtc)}'),
              ('Horizon', p.horizonHours == null ? '—' : '${p.horizonHours} h'),
              ('Freshness', '${_s(p.freshnessStatus)}${p.isStale == true ? ' (STALE)' : ''}'),
              ('Coverage', p.coverageCompleteness == null ? '—' : '${(p.coverageCompleteness! * 100).toStringAsFixed(0)}%'),
              ('Ensemble', p.isEnsemble == null ? '—' : '${p.isEnsemble} (${_s(p.expectedMemberCount)} members)'),
              ('Latency', p.latencyMs == null ? '—' : '${p.latencyMs!.toStringAsFixed(0)} ms'),
              ('Served from cache', '${p.servedFromCache}'),
            ], mono: true, colors: {'Freshness': p.isStale == true ? AppColors.statusAmber : AppColors.statusGreenText}),
            _section('Grid'),
            _kvList([
              ('Surface', _s(p.surface)),
              ('Table', _s(p.table)),
              ('Resolution', p.resolutionDeg == null ? '—' : '${p.resolutionDeg}°'),
              ('Sampled cell', p.sampledLat == null ? '—' : '${p.sampledLat}, ${p.sampledLon}'),
              ('Distance', p.distanceKm == null ? '—' : '${p.distanceKm!.toStringAsFixed(2)} km'),
              ('Spatial method', _s(p.spatialMethod)),
              ('Sources', p.sources.isEmpty ? '—' : p.sources.join('\n')),
            ], mono: true),
            _section('Provider chain', trailing: Text('tried: ${p.triedProviders.join(' → ')}', style: const TextStyle(fontSize: 11, color: AppColors.textTertiary))),
            if (p.fallbackReasons.isEmpty)
              _card(const Padding(padding: EdgeInsets.all(14), child: Text('No fallbacks — first provider answered.', style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary))))
            else
              _card(Column(children: [
                for (var i = 0; i < p.fallbackReasons.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: AppColors.borderSubtle),
                  _FallbackRow(reason: p.fallbackReasons[i]),
                ],
              ])),
            _section('Methods (how derived values were computed)'),
            if (p.methods.isEmpty)
              _card(const Padding(padding: EdgeInsets.all(14), child: Text('—', style: TextStyle(color: AppColors.textTertiary))))
            else
              _kvList([for (final e in p.methods.entries) (e.key, '${e.value}')], mono: true),
            if (p.queryDiagnostics.isNotEmpty) ...[
              _section('Query diagnostics'),
              _kvList([for (final e in p.queryDiagnostics.entries) (e.key, e.value is List ? (e.value as List).join(', ') : '${e.value}')], mono: true),
            ],
          ],
        );
      },
    );
  }
}

class _FallbackRow extends StatelessWidget {
  const _FallbackRow({required this.reason});
  final FallbackReason reason;

  @override
  Widget build(BuildContext context) {
    final real = reason.isRealFailure;
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 14),
      childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      leading: Icon(real ? Icons.error_outline_rounded : Icons.block_rounded, size: 18,
          color: real ? AppColors.statusAmber : AppColors.textTertiary),
      title: Text('${_providerName(reason.provider)} — ${reason.humanReason}',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: real ? AppColors.textPrimary : AppColors.textSecondary)),
      subtitle: Text(real ? 'configured provider failed' : 'not configured — not a degradation',
          style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
      children: [
        SelectableText(const JsonEncoder.withIndent('  ').convert(reason.raw),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Requests
// ---------------------------------------------------------------------------

class _RequestsTab extends ConsumerWidget {
  const _RequestsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final log = ref.watch(requestLogProvider);
    final bottom = MediaQuery.paddingOf(context).bottom + 24;
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 4, 16, bottom),
      children: [
        _section('Recent backend requests', trailing: TextButton(
          onPressed: () => ref.read(requestLogProvider.notifier).clear(),
          child: const Text('Clear'),
        )),
        if (log.isEmpty)
          _card(const Padding(padding: EdgeInsets.all(14), child: Text('No requests recorded yet.', style: TextStyle(color: AppColors.textSecondary))))
        else
          _card(Column(children: [
            for (var i = 0; i < log.length; i++) ...[
              if (i > 0) const Divider(height: 1, color: AppColors.borderSubtle),
              _RequestRow(entry: log[i]),
            ],
          ])),
      ],
    );
  }
}

class _RequestRow extends StatelessWidget {
  const _RequestRow({required this.entry});
  final RequestLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final color = entry.ok ? AppColors.statusGreenText : AppColors.statusRed;
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 14),
      childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      leading: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
        child: Text('${entry.statusCode ?? 'ERR'}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      ),
      title: Text('${entry.method} ${entry.path}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'monospace')),
      subtitle: Text(
        '${DateFormat('HH:mm:ss').format(entry.startedAt)} · ${entry.durationMs ?? '?'} ms${entry.summary == null ? '' : ' · ${entry.summary}'}',
        style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
      ),
      children: [
        SelectableText(
          [
            if (entry.query.isNotEmpty) '?${entry.queryString}',
            if (entry.error != null) 'error: ${entry.error}',
            if (entry.summary != null) entry.summary!,
          ].join('\n'),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Backend health
// ---------------------------------------------------------------------------

class _BackendTab extends ConsumerWidget {
  const _BackendTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(backendHealthProvider);
    final bottom = MediaQuery.paddingOf(context).bottom + 24;
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 4, 16, bottom),
      children: [
        _section('GET ${ApiEndpoints.v2WeatherHealth}', trailing: IconButton(
          icon: const Icon(Icons.refresh_rounded, size: 18),
          onPressed: () => ref.invalidate(backendHealthProvider),
        )),
        health.when(
          loading: () => _loading(),
          error: (e, _) => _errorBox(e),
          data: (h) {
            final providers = (h['provider_health'] as Map?)?.cast<String, dynamic>() ?? {};
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kvList([
                  ('Status', _s(h['status'])),
                  ('Policy', _s(h['selection_policy_version'])),
                  ('Priority', (h['provider_priority'] as List?)?.join(' → ') ?? '—'),
                  ('Generated', _s(h['generated_at'])),
                ]),
                _section('Providers'),
                _card(Column(children: [
                  for (final e in providers.entries) ...[
                    if (e.key != providers.keys.first) const Divider(height: 1, color: AppColors.borderSubtle),
                    _ProviderHealthRow(name: e.key, data: (e.value as Map).cast<String, dynamic>()),
                  ],
                ])),
                _jsonBlock(context, h, title: 'Raw health JSON'),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ProviderHealthRow extends StatelessWidget {
  const _ProviderHealthRow({required this.name, required this.data});
  final String name;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final configured = data['configured'] == true;
    final eligible = data['eligible'] == true;
    final breaker = data['circuit_breaker_open'] == true;
    final cap = (data['capability'] as Map?)?.cast<String, dynamic>() ?? {};
    final color = breaker
        ? AppColors.statusRed
        : eligible
            ? AppColors.statusGreenText
            : configured
                ? AppColors.statusAmber
                : AppColors.textTertiary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_providerName(name), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
            Text(
              [
                configured ? 'configured' : 'not configured',
                eligible ? 'eligible' : 'ineligible: ${_s(data['reason'])}',
                if (breaker) 'CIRCUIT OPEN',
                'failures=${_s(data['consecutive_failures'])}',
                'max ${_s(cap['max_days'])}d',
                if (cap['has_ensemble'] == true) 'ensemble',
                'fresh≤${_s(cap['freshness_budget_hours'])}h',
              ].join(' · '),
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ]),
        ),
      ]),
    );
  }
}
