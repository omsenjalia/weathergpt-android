import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/models/json_values.dart';
import '../../../core/services/api_client.dart';
import '../../explore/providers/saved_locations_provider.dart';
import 'chart_point.dart';

/// Series colours assigned by position so the palette stays stable across
/// fetches. Purely presentational.
const List<int> comparisonPalette = <int>[
  0xFF3B82F6,
  0xFFF59E0B,
  0xFF22C55E,
  0xFFA78BFA,
  0xFFF472B6,
];

class ComparedLocation {
  const ComparedLocation(this.name, this.colorValue, this.points);

  final String name;
  final int colorValue;
  final List<ChartPoint> points;

  /// Value recorded for [year], or `null` when this location has no record for
  /// it. A gap is a gap — it is never drawn as zero.
  double? valueFor(double year) {
    for (final point in points) {
      if (point.x == year) return point.value;
    }
    return null;
  }

  /// Sum of the records actually returned.
  double? get total => points.isEmpty
      ? null
      : points.map((p) => p.value).reduce((a, b) => a + b);
}

class ComparisonResult {
  const ComparisonResult({
    required this.locations,
    this.metric = 'rainfall',
    this.detail,
  });

  final List<ComparedLocation> locations;
  final String metric;

  /// Reason nothing is shown, e.g. fewer than two saved locations.
  final String? detail;

  bool get isEmpty => locations.isEmpty;

  /// Sorted union of the years present in the response, so the axis and table
  /// describe the data instead of a hardcoded 2021–2025 range.
  List<double> get years {
    final values = <double>{};
    for (final location in locations) {
      for (final point in location.points) {
        values.add(point.x);
      }
    }
    return values.toList()..sort();
  }

  /// Last two years present, used by the summary table.
  List<double> get lastTwoYears {
    final all = years;
    return all.length <= 2 ? all : all.sublist(all.length - 2);
  }

  double get maxValue {
    var max = 0.0;
    for (final location in locations) {
      for (final point in location.points) {
        if (point.value > max) max = point.value;
      }
    }
    return max;
  }

  /// Parses `{ metric, locations: [{ name, points: [{ year, value }] }] }`.
  factory ComparisonResult.fromJson(Map<String, dynamic> data) {
    final locations = <ComparedLocation>[];
    for (final item in jsonList(data['locations'])) {
      final row = jsonMap(item);
      if (row == null) continue;
      final name = jsonString(row['name']);
      if (name == null) continue;
      final points = <ChartPoint>[];
      for (final pointItem in jsonList(row['points'])) {
        final pointRow = jsonMap(pointItem);
        if (pointRow == null) continue;
        final x = jsonDouble(pointRow['year'] ?? pointRow['x']);
        final value = jsonDouble(pointRow['value'] ?? pointRow['y']);
        if (x == null || value == null) continue;
        points.add(ChartPoint(x, value));
      }
      if (points.isEmpty) continue;
      locations.add(ComparedLocation(
        name,
        comparisonPalette[locations.length % comparisonPalette.length],
        points,
      ));
    }
    return ComparisonResult(
      locations: locations,
      metric: jsonString(data['metric']) ?? 'rainfall',
      detail: locations.isEmpty
          ? 'The comparison endpoint returned no series for these locations.'
          : null,
    );
  }
}

/// Comparison across the user's saved locations, fetched from `/comparison`.
///
/// The previous version charted a bundled table of five invented years for
/// three fixed cities. Locations now come from what the user actually saved,
/// and values come from the archive.
final comparisonProvider = FutureProvider<ComparisonResult>((ref) async {
  final saved = ref.watch(savedLocationsProvider);
  if (saved.length < 2) {
    return const ComparisonResult(
      locations: [],
      detail: 'Save at least two locations to compare them.',
    );
  }
  final bounded = saved.take(comparisonPalette.length);
  final locationsParam =
      bounded.map((l) => '${l.name},${l.lat},${l.lon}').join(';');
  final data = await ApiClient.instance.get(ApiEndpoints.comparison, query: {
    'locations': locationsParam,
    'metric': 'rainfall',
  });
  return ComparisonResult.fromJson(data);
});
