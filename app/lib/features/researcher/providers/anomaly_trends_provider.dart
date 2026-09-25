import 'package:flutter_riverpod/flutter_riverpod.dart';

enum TrendMetric { temperature, rainfall }

class TrendNotifier extends StateNotifier<TrendMetric> {
  TrendNotifier({TrendMetric initial = TrendMetric.temperature})
      : super(initial);
  void select(TrendMetric metric) => state = metric;
}

final anomalyTrendsProvider =
    StateNotifierProvider<TrendNotifier, TrendMetric>((ref) => TrendNotifier());
