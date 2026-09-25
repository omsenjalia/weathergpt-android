import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/markdown_utils.dart';
import '../../../core/widgets/app_card.dart';
import '../providers/voice_provider.dart';

class RecommendationCard extends StatelessWidget {
  const RecommendationCard({super.key, required this.response});
  final VoiceResponse response;

  @override
  Widget build(BuildContext context) {
    final summary = MarkdownUtils.forSpeech(response.verdict);
    return Container(
      decoration: BoxDecoration(
        color: response.accent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: AppCard(
          radius: 14,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_iconFor(response.type), color: response.accent, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    response.label,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 11),
              Text(
                summary,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(ResultType type) => switch (type) {
        ResultType.irrigation || ResultType.cropStatus => Icons.eco_outlined,
        ResultType.rainForecast => Icons.umbrella_outlined,
        ResultType.researchQuery => Icons.insights_outlined,
        ResultType.general => Icons.check_circle_outline,
      };
}
