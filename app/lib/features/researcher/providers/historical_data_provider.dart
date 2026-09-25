import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/models/json_values.dart';
import '../../../core/services/api_client.dart';
import '../../home/providers/location_provider.dart';
import 'chart_point.dart';

enum HistoricalMetric { rainfall, temperature, humidity }

/// Metric name as the archive API expects it.
String metricParam(HistoricalMetric metric) => switch (metric) {
      HistoricalMetric.rainfall => 'rainfall',
      HistoricalMetric.temperature => 'temperature',
      HistoricalMetric.humidity => 'humidity',
    };

class HistoricalDataState {
  const HistoricalDataState(
      {this.metric = HistoricalMetric.rainfall, this.monthly = false});
  final HistoricalMetric metric;

  /// When true, month-of-year climatology is requested; when false, a yearly
  /// archive series.
  final bool monthly;

  HistoricalDataState copyWith({HistoricalMetric? metric, bool? monthly}) =>
      HistoricalDataState(
        metric: metric ?? this.metric,
        monthly: monthly ?? this.monthly,
      );

  /// Family cache key: two equal states must not trigger a second request.
  @override
  bool operator ==(Object other) =>
      other is HistoricalDataState &&
      other.metric == metric &&
      other.monthly == monthly;

  @override
  int get hashCode => Object.hash(metric, monthly);
}

class HistoricalDataNotifier extends StateNotifier<HistoricalDataState> {
  HistoricalDataNotifier() : super(const HistoricalDataState());
  void setMetric(HistoricalMetric value) =>
      state = state.copyWith(metric: value);
  void setMonthly(bool value) => state = state.copyWith(monthly: value);
}

final historicalDataProvider =
    StateNotifierProvider<HistoricalDataNotifier, HistoricalDataState>(
  (ref) => HistoricalDataNotifier(),
);

/// Why a series could not be shown. Distinct reasons matter: "the archive has
/// nothing for this place" and "this API does not serve that view" are
/// different facts and must not be rendered identically.
enum ArchiveStatus { available, empty, unsupported }

class HistoricalSeries {
  const HistoricalSeries({
    required this.metric,
    required this.points,
    this.status = ArchiveStatus.available,
    this.detail,
    this.source,
  });

  final HistoricalMetric metric;
  final List<ChartPoint> points;
  final ArchiveStatus status;

  /// Human-readable reason for a non-available series.
  final String? detail;
  final String? source;

  bool get isAvailable => status == ArchiveStatus.available && points.isNotEmpty;

  int? get firstYear => points.isEmpty ? null : points.first.x.toInt();
  int? get lastYear => points.isEmpty ? null : points.last.x.toInt();

  /// Actual coverage of the returned data, e.g. "2001 – 2024". The UI shows
  /// this instead of a hardcoded range so the label cannot overstate coverage.
  String? get rangeLabel =>
      firstYear == null ? null : '$firstYear – $lastYear';

  /// Parses `{ metric, points: [{ year, value }] }`. Rows without both a year
  /// and a finite value are dropped rather than plotted as zero.
  factory HistoricalSeries.fromJson(
      HistoricalMetric metric, Map<String, dynamic> data) {
    final points = <ChartPoint>[];
    for (final item in jsonList(data['points'])) {
      final row = jsonMap(item);
      if (row == null) continue;
      final x = jsonDouble(row['year'] ?? row['x']);
      final value = jsonDouble(row['value'] ?? row['y']);
      if (x == null || value == null) continue;
      points.add(ChartPoint(x, value, label: jsonString(row['label'])));
    }
    return HistoricalSeries(
      metric: metric,
      points: points,
      status:
          points.isEmpty ? ArchiveStatus.empty : ArchiveStatus.available,
      source: jsonString(data['source'] ?? data['provider']),
    );
  }
}

/// Archive series for the current selection, fetched from `/historical`.
///
/// The previous version of this screen charted bundled constant series, which
/// presented invented numbers as an observed climate record. Data now comes
/// from the archive API, and a view the API does not serve says so.
final historicalSeriesProvider = FutureProvider.family<HistoricalSeries,
    HistoricalDataState>((ref, state) async {
  if (state.monthly) {
    // `/historical` serves yearly points only. Month-of-year climatology is a
    // different product; inventing it from a bundled table is not an option.
    return HistoricalSeries(
      metric: state.metric,
      points: const [],
      status: ArchiveStatus.unsupported,
      detail: 'Month-of-year climatology is not served by the archive API.',
    );
  }
  final location = ref.watch(locationProvider);
  final data = await ApiClient.instance.get(ApiEndpoints.historical, query: {
    'lat': location.lat,
    'lon': location.lon,
    'metric': metricParam(state.metric),
  });
  return HistoricalSeries.fromJson(state.metric, data);
});

double longTermAverage(List<ChartPoint> points) {
  if (points.isEmpty) return 0;
  return points.map((p) => p.value).reduce((a, b) => a + b) / points.length;
}

/// Percent deviation of the latest point from the mean of the *returned*
/// points. This is a display statistic over whatever window the archive gave
/// back — it is not a climate-normal calculation, and the UI labels it as a
/// deviation rather than an anomaly against a 30-year baseline.
double anomalyPercent(List<ChartPoint> points) {
  final avg = longTermAverage(points);
  if (avg == 0 || points.isEmpty) return 0;
  return ((points.last.value - avg) / avg) * 100;
}

String metricLabel(HistoricalMetric m) => switch (m) {
      HistoricalMetric.rainfall => 'Rainfall',
      HistoricalMetric.temperature => 'Temperature',
      HistoricalMetric.humidity => 'Humidity',
    };

String metricUnit(HistoricalMetric m) => switch (m) {
      HistoricalMetric.rainfall => 'mm',
      HistoricalMetric.temperature => '°C',
      HistoricalMetric.humidity => '%',
    };
