import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/atmosphere_background.dart';
import '../../../core/widgets/hub_card.dart';
import '../../home/providers/atmosphere_provider.dart';

/// Farmer hub — the dedicated "Farm" tab. Every farmer tool lives one tap
/// from here instead of inside Settings.
class FarmerHubScreen extends ConsumerWidget {
  const FarmerHubScreen({super.key});

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
            glowOverride: AppColors.farmerGreen,
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
                  'persona.farmer'.tr(),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'persona.farmer_description'.tr(),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                HubCard(
                  icon: Icons.schedule_rounded,
                  accent: AppColors.farmerGreen,
                  title: 'home.action_windows'.tr(),
                  onTap: () => context.push('/farmer/action-windows'),
                ),
                const SizedBox(height: 12),
                HubCard(
                  icon: Icons.agriculture_outlined,
                  accent: AppColors.farmerGreen,
                  title: 'farmer.farm_profile'.tr(),
                  onTap: () => context.push('/farmer/farm-profile'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
