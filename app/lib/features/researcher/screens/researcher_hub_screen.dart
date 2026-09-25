import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/atmosphere_background.dart';
import '../../../core/widgets/hub_card.dart';
import '../../home/providers/atmosphere_provider.dart';

/// Researcher hub — the dedicated "Lab" tab with the three analysis tools.
class ResearcherHubScreen extends ConsumerWidget {
  const ResearcherHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(atmospherePaletteProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          AtmosphereBackground(
            palette: palette,
            glowOverride: AppColors.researcherBlue,
          ),
          SafeArea(
            bottom: false,
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                MediaQuery.paddingOf(context).bottom + 96,
              ),
              children: [
                Text(
                  'persona.researcher'.tr(),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'persona.researcher_description'.tr(),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                HubCard(
                  icon: Icons.history_rounded,
                  accent: AppColors.researcherBlue,
                  title: 'researcher.historical_weather'.tr(),
                  onTap: () => context.push('/researcher/historical'),
                ),
                const SizedBox(height: 12),
                HubCard(
                  icon: Icons.compare_arrows_rounded,
                  accent: AppColors.researcherBlue,
                  title: 'researcher.compare_locations'.tr(),
                  onTap: () => context.push('/researcher/comparison'),
                ),
                const SizedBox(height: 12),
                HubCard(
                  icon: Icons.trending_up_rounded,
                  accent: AppColors.researcherBlue,
                  title: 'researcher.anomaly_trends'.tr(),
                  onTap: () => context.push('/researcher/trends'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
