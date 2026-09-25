import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/outlined_button_pill.dart';
import '../providers/comparison_provider.dart';
import '../widgets/chart_theme.dart';
import 'historical_data_screen.dart' show Filter;

class ComparisonScreen extends ConsumerWidget {
  const ComparisonScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultAsync = ref.watch(comparisonProvider);
    final result = resultAsync.value;
    final years = result?.years ?? const <double>[];

    return Scaffold(
      appBar: AppBar(
          title: const Text('Compare Locations',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // The header states what the archive actually returned instead of a
            // fixed "Monsoon (Jun-Sep)" label the data may not support.
            Filter(
                label: result == null
                    ? 'Loading…'
                    : result.isEmpty
                        ? 'No comparison data'
                        : '${result.metric} · ${years.first.toInt()} – ${years.last.toInt()}'),
            const SizedBox(height: 16),
            if (resultAsync.isLoading)
              const _Notice(
                  icon: Icons.hourglass_top_rounded,
                  text: 'Loading the comparison…')
            else if (resultAsync.hasError)
              const _Notice(
                  icon: Icons.cloud_off_rounded,
                  text:
                      'The comparison could not be loaded. Nothing is estimated in its place.')
            else if (result != null && result.isEmpty)
              _Notice(icon: Icons.place_outlined, text: result.detail ?? ''),
            if (result != null && !result.isEmpty) ...[
              Wrap(
                  spacing: 18,
                  runSpacing: 8,
                  children: result.locations.map(_Legend.new).toList()),
              const SizedBox(height: 16),
              SizedBox(
                  height: 230, child: BarChart(_chartData(result, years))),
              const SizedBox(height: 16),
              Text('Total ${result.metric} (mm)',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              _Table(result: result),
            ],
            const SizedBox(height: 24),
            const OutlinedButtonPill(label: 'View Detailed Analysis  →'),
          ]),
        ),
      ),
    );
  }

  BarChartData _chartData(ComparisonResult result, List<double> years) =>
      BarChartData(
        // Axis derived from the returned data rather than a fixed 650 mm.
        maxY: result.maxValue <= 0 ? 10 : result.maxValue * 1.15,
        gridData: ResearchChartTheme.grid,
        borderData: FlBorderData(show: false),
        barTouchData: ResearchChartTheme.barTouch,
        titlesData: _titles,
        barGroups: [
          for (var i = 0; i < years.length; i++)
            BarChartGroupData(
              x: years[i].toInt(),
              barsSpace: 3,
              barRods: [
                for (final location in result.locations)
                  // A year this location has no record for is skipped, not
                  // drawn as a zero-height bar that reads like "no rainfall".
                  if (location.valueFor(years[i]) != null)
                    BarChartRodData(
                        toY: location.valueFor(years[i])!,
                        color: Color(location.colorValue),
                        width: 7,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(2))),
              ],
            ),
        ],
      );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: AppColors.statusAmber),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                      height: 1.35))),
        ]),
      );
}

class _Legend extends StatelessWidget {
  const _Legend(this.location);
  final ComparedLocation location;
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
                color: Color(location.colorValue), shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(location.name,
            style:
                const TextStyle(fontSize: 11, color: AppColors.textSecondary))
      ]);
}

final _titles = FlTitlesData(
    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    leftTitles: AxisTitles(
        sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 32,
            getTitlesWidget: (v, _) => Text(v.toInt().toString(),
                style: ResearchChartTheme.axisStyle))),
    bottomTitles: AxisTitles(
        sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (v, _) => Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Text(v.toInt().toString(),
                    style: ResearchChartTheme.axisStyle)))));

class _Table extends StatelessWidget {
  const _Table({required this.result});
  final ComparisonResult result;

  @override
  Widget build(BuildContext context) {
    final columns = result.lastTwoYears;
    return AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        radius: 12,
        child: Table(children: [
          TableRow(children: [
            const Padding(
                padding: EdgeInsets.all(5),
                child: Text('Location',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 11))),
            for (final year in columns)
              Padding(
                  padding: const EdgeInsets.all(5),
                  child: Text(year.toInt().toString(),
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 11))),
          ]),
          for (final location in result.locations)
            TableRow(children: [
              Padding(
                  padding: const EdgeInsets.all(5),
                  child:
                      Text(location.name, style: const TextStyle(fontSize: 12))),
              for (final year in columns)
                Padding(
                    padding: const EdgeInsets.all(5),
                    child: Text(
                        // No record is rendered as an em dash, never as 0.
                        location.valueFor(year)?.toStringAsFixed(0) ?? '—',
                        style: const TextStyle(fontSize: 12))),
            ]),
        ]));
  }
}
