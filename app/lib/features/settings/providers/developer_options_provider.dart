import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../home/theme/atmosphere_theme.dart';

/// Which provider the app asks the backend to use. `auto` lets the backend
/// run its IMD → WeatherNext → AccuWeather → Open-Meteo policy; anything else
/// is an explicit pin and the backend returns that provider or an honest
/// `unavailable` — it never silently substitutes another one.
enum DevSourcePin { auto, weathernext, openMeteo, accuweather, imd }

extension DevSourcePinWire on DevSourcePin {
  String get wire => switch (this) {
        DevSourcePin.auto => 'auto',
        DevSourcePin.weathernext => 'weathernext',
        DevSourcePin.openMeteo => 'open_meteo',
        DevSourcePin.accuweather => 'accuweather',
        DevSourcePin.imd => 'imd',
      };

  String get label => switch (this) {
        DevSourcePin.auto => 'Auto (backend policy)',
        DevSourcePin.weathernext => 'WeatherNext (pinned)',
        DevSourcePin.openMeteo => 'Open-Meteo (pinned)',
        DevSourcePin.accuweather => 'AccuWeather (pinned)',
        DevSourcePin.imd => 'IMD (pinned)',
      };
}

/// WeatherNext model generation to request when the source is pinned or auto.
enum DevWnModel { wn3, wn2 }

extension DevWnModelWire on DevWnModel {
  String get wire => this == DevWnModel.wn3 ? 'weathernext_3' : 'weathernext_2';
  String get label => this == DevWnModel.wn3 ? 'WeatherNext 3 (0.1°)' : 'WeatherNext 2';
}

class DeveloperOptions {
  const DeveloperOptions({
    this.enabled = false,
    this.forcePeriod,
    this.forceSky,
    this.forceTtsLocale,
    this.forceTtsSpeed,
    this.disableVideoSky = false,
    this.showProvenanceOnHome = false,
    this.showFieldSourceBadges = true,
    this.sourcePin = DevSourcePin.auto,
    this.wnModel = DevWnModel.wn3,
    this.hourlyHours = 48,
    this.forecastDays = 7,
    this.supplementSecondaryFields = true,
    this.disableV2Fallback = false,
    this.logRequests = true,
  });

  final bool enabled;
  final SkyPeriod? forcePeriod;
  final SkyCondition? forceSky;
  final String? forceTtsLocale;
  final double? forceTtsSpeed;
  final bool disableVideoSky;

  /// Show the source / run / freshness chip row on the home screen. Off by
  /// default: provider names are developer-only, and the full attribution
  /// always lives on the Debug screen.
  final bool showProvenanceOnHome;

  /// Show a small "via Open-Meteo" badge on tiles whose value did not come
  /// from the selected provider. Applies only when developer mode is on —
  /// regular users never see provider names.
  final bool showFieldSourceBadges;

  /// Explicit provider pin sent as `requested_source`.
  final DevSourcePin sourcePin;
  final DevWnModel wnModel;

  /// Hourly buckets to request (1–168).
  final int hourlyHours;

  /// Daily rows to request (1–15).
  final int forecastDays;

  /// Ask the backend to fill sunrise/UV/AQI/humidity gaps from Open-Meteo.
  final bool supplementSecondaryFields;

  /// When true, a `/v2/weather` failure surfaces as an error instead of
  /// silently retrying the legacy `/weather` endpoint.
  final bool disableV2Fallback;

  /// Record every backend request/response summary for the Debug screen.
  final bool logRequests;

  DeveloperOptions copyWith({
    bool? enabled,
    SkyPeriod? forcePeriod,
    SkyCondition? forceSky,
    String? forceTtsLocale,
    double? forceTtsSpeed,
    bool? disableVideoSky,
    bool? showProvenanceOnHome,
    bool? showFieldSourceBadges,
    DevSourcePin? sourcePin,
    DevWnModel? wnModel,
    int? hourlyHours,
    int? forecastDays,
    bool? supplementSecondaryFields,
    bool? disableV2Fallback,
    bool? logRequests,
    bool clearPeriod = false,
    bool clearSky = false,
    bool clearTtsLocale = false,
    bool clearTtsSpeed = false,
  }) =>
      DeveloperOptions(
        enabled: enabled ?? this.enabled,
        forcePeriod: clearPeriod ? null : (forcePeriod ?? this.forcePeriod),
        forceSky: clearSky ? null : (forceSky ?? this.forceSky),
        forceTtsLocale:
            clearTtsLocale ? null : (forceTtsLocale ?? this.forceTtsLocale),
        forceTtsSpeed:
            clearTtsSpeed ? null : (forceTtsSpeed ?? this.forceTtsSpeed),
        disableVideoSky: disableVideoSky ?? this.disableVideoSky,
        showProvenanceOnHome: showProvenanceOnHome ?? this.showProvenanceOnHome,
        showFieldSourceBadges:
            showFieldSourceBadges ?? this.showFieldSourceBadges,
        sourcePin: sourcePin ?? this.sourcePin,
        wnModel: wnModel ?? this.wnModel,
        hourlyHours: hourlyHours ?? this.hourlyHours,
        forecastDays: forecastDays ?? this.forecastDays,
        supplementSecondaryFields:
            supplementSecondaryFields ?? this.supplementSecondaryFields,
        disableV2Fallback: disableV2Fallback ?? this.disableV2Fallback,
        logRequests: logRequests ?? this.logRequests,
      );

  /// Options that affect the weather request itself. Only these apply when
  /// developer mode is *on*; with it off the app always uses defaults.
  bool get isRequestCustomised =>
      sourcePin != DevSourcePin.auto ||
      wnModel != DevWnModel.wn3 ||
      hourlyHours != 48 ||
      forecastDays != 7 ||
      !supplementSecondaryFields;
}

class DeveloperOptionsNotifier extends StateNotifier<DeveloperOptions> {
  DeveloperOptionsNotifier() : super(_load());

  static const _boxName = 'settings';

  static T? _enumByName<T extends Enum>(List<T> values, Object? name) {
    if (name is! String) return null;
    for (final v in values) {
      if (v.name == name) return v;
    }
    return null;
  }

  static DeveloperOptions _load() {
    if (!Hive.isBoxOpen(_boxName)) return const DeveloperOptions();
    final box = Hive.box(_boxName);
    final enabled = box.get('dev_enabled', defaultValue: false) == true;
    return DeveloperOptions(
      enabled: enabled,
      forcePeriod: _enumByName(SkyPeriod.values, box.get('dev_force_period')),
      forceSky: _enumByName(SkyCondition.values, box.get('dev_force_sky')),
      forceTtsLocale: box.get('dev_tts_locale') as String?,
      forceTtsSpeed: (box.get('dev_tts_speed') as num?)?.toDouble(),
      disableVideoSky: box.get('dev_disable_video_sky') == true,
      showProvenanceOnHome: box.get('dev_show_provenance_home') == true,
      showFieldSourceBadges:
          box.get('dev_show_field_source_badges', defaultValue: true) == true,
      sourcePin: _enumByName(DevSourcePin.values, box.get('dev_source_pin')) ??
          DevSourcePin.auto,
      wnModel: _enumByName(DevWnModel.values, box.get('dev_wn_model')) ??
          DevWnModel.wn3,
      hourlyHours:
          ((box.get('dev_hourly_hours') as num?)?.toInt() ?? 48).clamp(1, 168).toInt(),
      forecastDays:
          ((box.get('dev_forecast_days') as num?)?.toInt() ?? 7).clamp(1, 15).toInt(),
      supplementSecondaryFields:
          box.get('dev_supplement', defaultValue: true) == true,
      disableV2Fallback: box.get('dev_disable_v2_fallback') == true,
      logRequests: box.get('dev_log_requests', defaultValue: true) == true,
    );
  }

  Future<void> _persist() async {
    final box = await Hive.openBox(_boxName);
    await box.put('dev_enabled', state.enabled);
    await box.put('dev_force_period', state.forcePeriod?.name);
    await box.put('dev_force_sky', state.forceSky?.name);
    await box.put('dev_tts_locale', state.forceTtsLocale);
    await box.put('dev_tts_speed', state.forceTtsSpeed);
    await box.put('dev_disable_video_sky', state.disableVideoSky);
    await box.put('dev_show_provenance_home', state.showProvenanceOnHome);
    await box.put('dev_show_field_source_badges', state.showFieldSourceBadges);
    await box.put('dev_source_pin', state.sourcePin.name);
    await box.put('dev_wn_model', state.wnModel.name);
    await box.put('dev_hourly_hours', state.hourlyHours);
    await box.put('dev_forecast_days', state.forecastDays);
    await box.put('dev_supplement', state.supplementSecondaryFields);
    await box.put('dev_disable_v2_fallback', state.disableV2Fallback);
    await box.put('dev_log_requests', state.logRequests);
  }

  Future<void> setEnabled(bool v) async {
    state = state.copyWith(enabled: v);
    await _persist();
  }

  Future<void> setForcePeriod(SkyPeriod? p) async {
    state = p == null
        ? state.copyWith(clearPeriod: true)
        : state.copyWith(forcePeriod: p);
    await _persist();
  }

  Future<void> setForceSky(SkyCondition? s) async {
    state = s == null
        ? state.copyWith(clearSky: true)
        : state.copyWith(forceSky: s);
    await _persist();
  }

  Future<void> setForceTtsLocale(String? locale) async {
    state = locale == null
        ? state.copyWith(clearTtsLocale: true)
        : state.copyWith(forceTtsLocale: locale);
    await _persist();
  }

  Future<void> setForceTtsSpeed(double? speed) async {
    state = speed == null
        ? state.copyWith(clearTtsSpeed: true)
        : state.copyWith(forceTtsSpeed: speed);
    await _persist();
  }

  Future<void> setDisableVideoSky(bool v) async {
    state = state.copyWith(disableVideoSky: v);
    await _persist();
  }

  Future<void> setShowProvenanceOnHome(bool v) async {
    state = state.copyWith(showProvenanceOnHome: v);
    await _persist();
  }

  Future<void> setShowFieldSourceBadges(bool v) async {
    state = state.copyWith(showFieldSourceBadges: v);
    await _persist();
  }

  Future<void> setSourcePin(DevSourcePin v) async {
    state = state.copyWith(sourcePin: v);
    await _persist();
  }

  Future<void> setWnModel(DevWnModel v) async {
    state = state.copyWith(wnModel: v);
    await _persist();
  }

  Future<void> setHourlyHours(int v) async {
    state = state.copyWith(hourlyHours: v.clamp(1, 168).toInt());
    await _persist();
  }

  Future<void> setForecastDays(int v) async {
    state = state.copyWith(forecastDays: v.clamp(1, 15).toInt());
    await _persist();
  }

  Future<void> setSupplementSecondaryFields(bool v) async {
    state = state.copyWith(supplementSecondaryFields: v);
    await _persist();
  }

  Future<void> setDisableV2Fallback(bool v) async {
    state = state.copyWith(disableV2Fallback: v);
    await _persist();
  }

  Future<void> setLogRequests(bool v) async {
    state = state.copyWith(logRequests: v);
    await _persist();
  }

  Future<void> reset() async {
    state = DeveloperOptions(enabled: state.enabled);
    await _persist();
  }
}

final developerOptionsProvider =
    StateNotifierProvider<DeveloperOptionsNotifier, DeveloperOptions>(
  (ref) => DeveloperOptionsNotifier(),
);
