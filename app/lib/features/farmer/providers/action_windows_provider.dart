import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/models/json_values.dart';
import '../../../core/services/api_client.dart';
import '../../home/providers/location_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../models/advisory_models.dart';
import 'farm_profile_provider.dart';

export '../models/advisory_models.dart';

enum AdvisoryStatus { loading, ready, unavailable }

class ActionWindowsState {
  const ActionWindowsState({
    required this.selectedTab,
    required this.irrigationWindows,
    required this.sprayingWindows,
    required this.fieldWorkWindows,
    required this.fieldWorkStatus,
    required this.summaryVerdict,
    required this.summaryExplanation,
    this.status = AdvisoryStatus.ready,
    this.source = AdvisorySource.thresholds,
    this.aiConfidence,
    this.locationLabel = '',
    this.asOfUtc,
  });

  /// Explicit "no verified windows" state.
  ///
  /// There is deliberately **no** bundled favourable baseline. Shipping a demo
  /// irrigation/spraying pattern as if it were live advice is the exact failure
  /// the implementation plan calls out; when the backend cannot be reached the
  /// farmer sees an unavailable state instead.
  factory ActionWindowsState.unavailable(ActionWindowTab tab,
          {String locationLabel = ''}) =>
      ActionWindowsState(
        selectedTab: tab,
        irrigationWindows: const [],
        sprayingWindows: const [],
        fieldWorkWindows: const [],
        fieldWorkStatus: '',
        summaryVerdict: '',
        summaryExplanation: '',
        status: AdvisoryStatus.unavailable,
        source: AdvisorySource.offline,
        locationLabel: locationLabel,
      );

  final ActionWindowTab selectedTab;
  final List<HourlySuitability> irrigationWindows;
  final List<HourlySuitability> sprayingWindows;
  final List<HourlySuitability> fieldWorkWindows;
  final String fieldWorkStatus;
  final String summaryVerdict;
  final String summaryExplanation;
  final AdvisoryStatus status;
  final AdvisorySource source;

  /// Confidence of the decision actually shown, when the backend reported one.
  final double? aiConfidence;
  final String locationLabel;

  /// When this advisory was verified against the backend, in UTC. A
  /// timestamped last-known result is honest; a silent cached one is not.
  final DateTime? asOfUtc;

  /// True when a high-confidence System One answer actually shaped this state.
  bool get aiAssisted => source == AdvisorySource.systemOne;

  /// True when there is anything to draw. Drives the explicit unavailable
  /// panel — empty bars must not be mistaken for "all neutral".
  bool get hasWindows =>
      irrigationWindows.isNotEmpty ||
      sprayingWindows.isNotEmpty ||
      fieldWorkWindows.isNotEmpty;

  ActionWindowsState copyWith({
    AdvisoryStatus? status,
    AdvisorySource? source,
    double? aiConfidence,
    String? locationLabel,
    DateTime? asOfUtc,
  }) =>
      ActionWindowsState(
        selectedTab: selectedTab,
        irrigationWindows: irrigationWindows,
        sprayingWindows: sprayingWindows,
        fieldWorkWindows: fieldWorkWindows,
        fieldWorkStatus: fieldWorkStatus,
        summaryVerdict: summaryVerdict,
        summaryExplanation: summaryExplanation,
        status: status ?? this.status,
        source: source ?? this.source,
        aiConfidence: aiConfidence ?? this.aiConfidence,
        locationLabel: locationLabel ?? this.locationLabel,
        asOfUtc: asOfUtc ?? this.asOfUtc,
      );
}

class ActionWindowsNotifier extends StateNotifier<ActionWindowsState> {
  ActionWindowsNotifier(this._ref)
      : super(ActionWindowsState.unavailable(ActionWindowTab.today)) {
    // Location or farm-profile changes invalidate every cached window: a
    // "tomorrow" computed for another field or another place must not survive.
    _ref.listen(locationProvider, (_, __) => _invalidateAndRefresh());
    _ref.listen(farmProfileProvider, (_, __) => _invalidateAndRefresh());
  }

  final Ref _ref;
  final Map<ActionWindowTab, ActionWindowsState> _cache = {};
  bool _attempted = false;
  int _generation = 0;

  /// Identity of the context a cached advisory was computed for.
  String _contextKey() {
    final location = _ref.read(locationProvider);
    final profile = _ref.read(farmProfileProvider);
    // Including the UTC date stops a window cached yesterday being served as
    // today's or tomorrow's.
    final day = DateTime.now().toUtc().toIso8601String().substring(0, 10);
    return '${location.lat},${location.lon}|${profile.crop}|'
        '${profile.growthStage}|${profile.soilType}|${profile.irrigationType}|$day';
  }

  String _locationLabel() => _ref.read(locationProvider).name;

  void _dropCacheIfContextChanged() {
    final key = _contextKey();
    if (_cachedContextKey == key) return;
    _cache.clear();
    _cachedContextKey = key;
    _attempted = false;
  }

  String _cachedContextKey = '';

  void _invalidateAndRefresh() {
    _cache.clear();
    _attempted = false;
    _generation++;
    refresh();
  }

  void selectTab(ActionWindowTab tab) {
    _dropCacheIfContextChanged();
    final cached = _cache[tab];
    if (cached != null) {
      state = cached;
      return;
    }
    // Nothing verified for this tab: show an honest loading or unavailable
    // state, never a bundled favourable pattern.
    state = ActionWindowsState.unavailable(
      tab,
      locationLabel: _locationLabel(),
    ).copyWith(status: _attempted ? AdvisoryStatus.unavailable : AdvisoryStatus.loading);
    if (!_attempted) refresh();
  }

  Future<void> refresh() async {
    _attempted = true;
    final generation = ++_generation;
    final contextKey = _contextKey();
    _cachedContextKey = contextKey;
    final location = _ref.read(locationProvider);
    final profile = _ref.read(farmProfileProvider);
    final mode = _ref.read(settingsProvider).mode;
    state = state.copyWith(status: AdvisoryStatus.loading);
    try {
      final data = await ApiClient.instance.get(ApiEndpoints.advisory, query: {
        'lat': location.lat,
        'lon': location.lon,
        'crop': profile.crop,
        'days': 7,
        'mode': mode.wire,
        // Farm context refines the backend's System One scoring (the same
        // judgment differs by growth stage and soil).
        'growth_stage': profile.growthStage,
        'soil': profile.soilType,
        'irrigation': profile.irrigationType,
      });
      // The user moved, edited their farm or crossed midnight while the request
      // was in flight — this result no longer describes what is on screen.
      if (generation != _generation || contextKey != _contextKey()) return;
      final verifiedAt = DateTime.now().toUtc();
      final today = stateForTab(
          ActionWindowTab.today, data, location.name, verifiedAt);
      final tomorrow = stateForTab(
          ActionWindowTab.tomorrow, data, location.name, verifiedAt);
      final sevenDay = stateForTab(
          ActionWindowTab.sevenDay, data, location.name, verifiedAt);
      _cache
        ..[ActionWindowTab.today] = today
        ..[ActionWindowTab.tomorrow] = tomorrow
        ..[ActionWindowTab.sevenDay] = sevenDay;
      state = _cache[state.selectedTab] ?? today;
    } on AppApiError {
      if (generation != _generation) return;
      _markUnavailable();
    } catch (_) {
      if (generation != _generation) return;
      _markUnavailable();
    }
  }

  void _markUnavailable() {
    final tab = state.selectedTab;
    final unavailable = ActionWindowsState.unavailable(tab,
        locationLabel: _locationLabel());
    _cache[tab] = unavailable;
    state = unavailable;
  }

  /// Maps one `/advisory` payload onto the state for [tab].
  ///
  /// Each day reads **its own** decision (`windows[i].ai.overall`), so a global
  /// highest-confidence verdict is never presented as a specific day's answer.
  @visibleForTesting
  static ActionWindowsState stateForTab(
    ActionWindowTab tab,
    Map<String, dynamic> data,
    String locationLabel,
    DateTime verifiedAt,
  ) {
    final windows = jsonList(data['windows']);
    final ai = jsonMap(data['ai']);
    final backendSummary = jsonString(data['summary']) ?? '';

    Map<String, dynamic>? windowAt(int index) {
      if (index >= windows.length) return null;
      return jsonMap(windows[index]);
    }

    List<HourlySuitability> hourlyOf(Map<String, dynamic>? window, String key) {
      final hourly = jsonMap(window?['hourly']) ?? const <String, dynamic>{};
      return collapseHourlyCells(jsonList(hourly[key]));
    }

    String bestWindowOf(Map<String, dynamic>? window) =>
        jsonString(window?['best_window']) ?? 'Good Conditions';

    final today = windowAt(0);
    final tomorrow = windowAt(1) ?? today;

    /// Builds a single-day state from that day's own evidence.
    ActionWindowsState dayState(
        ActionWindowTab target, Map<String, dynamic>? window) {
      final decision = dayDecisionFrom(window);
      final band = decision.choice ?? jsonString(window?['suitability']);
      return ActionWindowsState(
        selectedTab: target,
        irrigationWindows: hourlyOf(window, 'irrigation'),
        sprayingWindows: hourlyOf(window, 'spraying'),
        fieldWorkWindows: hourlyOf(window, 'field_work'),
        fieldWorkStatus: bestWindowOf(window),
        summaryVerdict: verdictTextForBand(band),
        summaryExplanation: jsonString(window?['summary']) ?? backendSummary,
        status: AdvisoryStatus.ready,
        // The System One badge is shown only when *this* day carries a
        // decision, with that day's confidence — not a global mean.
        source: decision.isPresent
            ? AdvisorySource.systemOne
            : AdvisorySource.thresholds,
        aiConfidence: decision.confidence,
        locationLabel: locationLabel,
        asOfUtc: verifiedAt,
      );
    }

    switch (tab) {
      case ActionWindowTab.today:
        return dayState(ActionWindowTab.today, today);
      case ActionWindowTab.tomorrow:
        return dayState(ActionWindowTab.tomorrow, tomorrow);
      case ActionWindowTab.sevenDay:
        // A week overview is legitimately an aggregate, so the backend's
        // overall verdict and mean confidence belong here.
        return ActionWindowsState(
          selectedTab: ActionWindowTab.sevenDay,
          irrigationWindows: dailySuitabilityCells(windows),
          sprayingWindows: dailySuitabilityCells(windows),
          fieldWorkWindows: dailySuitabilityCells(windows),
          fieldWorkStatus: 'Next 7 days',
          summaryVerdict: 'This week at a glance',
          summaryExplanation: backendSummary,
          status: AdvisoryStatus.ready,
          source: aiApplied(ai)
              ? AdvisorySource.systemOne
              : AdvisorySource.thresholds,
          aiConfidence: aiMeanConfidence(ai),
          locationLabel: locationLabel,
          asOfUtc: verifiedAt,
        );
    }
  }
}

final actionWindowsProvider =
    StateNotifierProvider<ActionWindowsNotifier, ActionWindowsState>(
  (ref) => ActionWindowsNotifier(ref),
);
