import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

abstract final class ResearchChartTheme {
  static const axisStyle =
      TextStyle(color: AppColors.textSecondary, fontSize: 11);
  static FlGridData get grid => FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) =>
            const FlLine(color: AppColors.borderSubtle, strokeWidth: 1),
      );
  static BarTouchData get barTouch => BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (_) => AppColors.surfaceCardAlt,
          getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
            rod.toY.toStringAsFixed(rod.toY < 50 ? 1 : 0),
            axisStyle.copyWith(color: AppColors.textPrimary),
          ),
        ),
      );
  static LineTouchData get lineTouch => LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => AppColors.surfaceCardAlt,
          getTooltipItems: (spots) => spots
              .map((spot) => LineTooltipItem(spot.y.toStringAsFixed(1),
                  axisStyle.copyWith(color: AppColors.textPrimary)))
              .toList(),
        ),
      );
}
