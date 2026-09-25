import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../theme/atmosphere_theme.dart';

/// Overview / Hourly / 7-day segmented control with a sliding gradient pill.
class WeatherSegmentTabs extends StatelessWidget {
  const WeatherSegmentTabs({
    super.key,
    required this.index,
    required this.onChanged,
    required this.palette,
  });
  final int index;
  final ValueChanged<int> onChanged;
  final AtmospherePalette palette;

  @override
  Widget build(BuildContext context) {
    final labels = [
      'home.tab_overview'.tr(),
      'home.tab_hourly'.tr(),
      'home.tab_7day'.tr(),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              // Map index across the full -1..1 span: for 3 tabs
              // 0 → -1 (left), 1 → 0 (centre), 2 → +1 (right).
              alignment: Alignment(
                labels.length > 1
                    ? -1.0 + 2.0 * index / (labels.length - 1)
                    : 0.0,
                0,
              ),
              child: FractionallySizedBox(
                widthFactor: 1 / labels.length,
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: Container(
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          palette.accent.withValues(alpha: 0.30),
                          palette.accent.withValues(alpha: 0.18),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: palette.accent.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Row(
              children: List.generate(labels.length, (i) {
                final sel = i == index;
                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(i),
                    child: SizedBox(
                      height: 42,
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
                            color: sel ? palette.text : palette.textMuted,
                          ),
                          child: Text(labels[i], maxLines: 1),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
