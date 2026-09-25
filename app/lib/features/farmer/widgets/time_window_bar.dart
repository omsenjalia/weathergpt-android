import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../providers/action_windows_provider.dart';

class TimeWindowBar extends StatelessWidget {
  const TimeWindowBar({super.key, required this.values, this.height = 16});
  final List<HourlySuitability> values;
  final double height;

  Color _color(Suitability value) => switch (value) {
        Suitability.good => AppColors.farmerGreen,
        Suitability.caution => AppColors.statusAmber,
        Suitability.avoid => AppColors.borderSubtle,
        Suitability.neutral => AppColors.textTertiary,
      };

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        child: Row(
          children: values
              .map((value) => Expanded(
                    flex: value.hours,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                          color: _color(value.suitability),
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ))
              .toList(),
        ),
      );
}
