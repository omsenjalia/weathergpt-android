import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/outlined_button_pill.dart';
import '../../home/providers/location_provider.dart';
import '../providers/anomaly_trends_provider.dart';
import '../providers/chart_point.dart';
import '../providers/historical_data_provider.dart';
import '../widgets/chart_theme.dart';
import 'historical_data_screen.dart' show Filter, Segmented;

class AnomalyTrendsScreen extends ConsumerWidget {
  const AnomalyTrendsScreen({super.key, this.initialMetric});
  final TrendMetric? initialMetric;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metric = ref.watch(anomalyTrendsProvider);
    final location = ref.watch(locationProvider);
    // Trend data comes from the same archive endpoint as the historical view,
    // so this screen can no longer disagree with it.
    final seriesAsync = ref.watch(historicalSeriesProvider(HistoricalDataState(
        metric: metric == TrendMetric.temperature
            ? HistoricalMetric.temperature
            : HistoricalMetric.rainfall)));
    final series = seriesAsync.value;
    final points = series?.points ?? const <ChartPoint>[];
    final warming = metric == TrendMetric.temperature;
    // Axes describe the returned records; a hardcoded 1996–2026 / 26–30 window
    // would silently crop or flatten whatever the archive actually holds.
    final values = points.map((p) => p.value).toList();
    final lowest = values.isEmpty ? 0.0 : values.reduce((a, b) => a < b ? a : b);
    final highest = values.isEmpty ? 1.0 : values.reduce((a, b) => a > b ? a : b);
    final span = (highest - lowest).abs() < 1e-6 ? 1.0 : highest - lowest;
    final minX = points.isEmpty ? 0.0 : points.first.x;
    final maxX = points.isEmpty ? 1.0 : points.last.x;
    final minY = lowest - span * 0.25;
    final maxY = highest + span * 0.25;
    final rangeLabel = series?.rangeLabel ?? 'No records';
    return Scaffold(
        appBar: AppBar(
            titleSpacing: 0,
            title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Anomaly & Trends',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  Text('⌖ ${location.name}',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary))
                ])),
        body: SafeArea(
            child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Segmented(
                          labels: const ['Temperature', 'Rainfall'],
                          selected: metric.index,
                          onChanged: (i) => ref
                              .read(anomalyTrendsProvider.notifier)
                              .select(TrendMetric.values[i])),
                      const SizedBox(height: 16),
                      Row(children: [
                        const Expanded(child: Filter(label: 'Annual Average')),
                        const SizedBox(width: 10),
                        Expanded(child: Filter(label: rangeLabel))
                      ]),
                      if (seriesAsync.isLoading)
                        const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: Text('Loading the archive…',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary)))
                      else if (seriesAsync.hasError)
                        const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: Text(
                                'The archive could not be reached, so no trend is drawn.',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.statusAmber)))
                      else if (series != null &&
                          series.status == ArchiveStatus.unsupported)
                        Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(series.detail ?? '',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.statusAmber)))
                      else if (series != null && !series.isAvailable)
                        const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: Text(
                                'The archive returned no records for this location.',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.statusAmber))),
                      const SizedBox(height: 20),
                      Text(
                          warming
                              ? 'Temperature trend ($rangeLabel)'
                              : 'Rainfall trend ($rangeLabel)',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 10),
                      SizedBox(
                          height: 220,
                          child: LineChart(LineChartData(
                              minX: minX,
                              maxX: maxX,
                              minY: minY,
                              maxY: maxY,
                              gridData: ResearchChartTheme.grid,
                              borderData: FlBorderData(show: false),
                              lineTouchData: ResearchChartTheme.lineTouch,
                              titlesData: _lineTitles,
                              lineBarsData: [
                                LineChartBarData(
                                    spots: points
                                        .map((p) => FlSpot(p.x, p.value))
                                        .toList(),
                                    isCurved: true,
                                    color: warming
                                        ? AppColors.statusRed
                                        : AppColors.researcherBlue,
                                    barWidth: 3,
                                    dotData: const FlDotData(show: false),
                                    belowBarData: BarAreaData(
                                        show: true,
                                        color: (warming
                                                ? AppColors.statusRed
                                                : AppColors.researcherBlue)
                                            .withValues(alpha: .08)))
                              ]))),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(
                            child: _Callout(
                                'Trend',
                                warming ? '+1.7°C' : '+22.3%',
                                warming ? 'over 30 years' : 'above normal',
                                warming
                                    ? AppColors.statusRed
                                    : AppColors.researcherBlue)),
                        const SizedBox(width: 10),
                        Expanded(
                            child: _Callout(
                                '2026 Average',
                                warming ? '28.8°C' : '412 mm',
                                warming ? '(+1.7°C)' : '(+22.3%)',
                                warming
                                    ? AppColors.statusRed
                                    : AppColors.researcherBlue))
                      ]),
                      const SizedBox(height: 14),
                      Text(
                          warming
                              ? 'Ahmedabad has become warmer over the last 30 years.'
                              : 'Ahmedabad rainfall is above its long-term average.',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                      const SizedBox(height: 24),
                      Row(children: [
                        const Expanded(
                            child: OutlinedButtonPill(label: 'View Details')),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButtonPill(
                            label: '↓ Export Data',
                            onPressed: () =>
                                ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Export prepared (demo only).')),
                            ),
                          ),
                        )
                      ]),
                    ]))));
  }
}

final _lineTitles = FlTitlesData(
    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    leftTitles: AxisTitles(
        sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 34,
            getTitlesWidget: (v, _) => Text(v.toStringAsFixed(0),
                style: ResearchChartTheme.axisStyle))),
    bottomTitles: AxisTitles(
        sideTitles: SideTitles(
            showTitles: true,
            interval: 5,
            getTitlesWidget: (v, _) => Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Text(v.toInt().toString(),
                    style: ResearchChartTheme.axisStyle)))));

class _Callout extends StatelessWidget {
  const _Callout(this.label, this.value, this.caption, this.color);
  final String label, value, caption;
  final Color color;
  @override
  Widget build(BuildContext context) => AppCard(
      padding: const EdgeInsets.all(14),
      radius: 12,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style:
                const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(height: 7),
        Text(value,
            style: TextStyle(
                color: color, fontSize: 20, fontWeight: FontWeight.w700)),
        Text(caption,
            style:
                const TextStyle(fontSize: 10, color: AppColors.textSecondary))
      ]));
}
