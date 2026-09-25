import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/atmosphere_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../home/providers/atmosphere_provider.dart';
import '../providers/onboarding_provider.dart';

/// Talk-vs-type choice shown to first-time farmers before the farm step.
///
/// Both paths collect the same six details and hand drafts to each other via
/// route extras, so switching mid-flow never loses answers. Skipping keeps
/// the default farm profile, exactly like skipping the form.
class FarmChoiceScreen extends ConsumerWidget {
  const FarmChoiceScreen({super.key, this.initialDraft});

  /// Unsaved answers carried over from the form or voice flow, forwarded to
  /// whichever path the user picks.
  final Map<String, dynamic>? initialDraft;

  Future<void> _skip(BuildContext context, WidgetRef ref) async {
    await ref.read(onboardingProvider.notifier).completeOnboarding();
    if (!context.mounted) return;
    syncSettingsAfterOnboarding(ref);
    if (context.mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(atmospherePaletteProvider);
    final bottom = MediaQuery.paddingOf(context).bottom + 20;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Stack(
        fit: StackFit.expand,
        children: [
          AtmosphereBackground(palette: palette),
          SafeArea(
            child: ListView(
              padding: EdgeInsets.fromLTRB(20, 12, 20, bottom),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => context.go('/onboarding/focus'),
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: Text('onboarding.back'.tr()),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 4),
                Text('onboarding.farm_choice_title'.tr(),
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 7),
                Text('onboarding.farm_choice_subtitle'.tr(),
                    style:
                        const TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 24),
                _ChoiceCard(
                  icon: Icons.mic_rounded,
                  title: 'onboarding.farm_choice_talk'.tr(),
                  description: 'onboarding.farm_choice_talk_desc'.tr(),
                  onTap: () => context.go('/onboarding/farm-voice',
                      extra: initialDraft),
                ),
                const SizedBox(height: 12),
                _ChoiceCard(
                  icon: Icons.keyboard_alt_outlined,
                  title: 'onboarding.farm_choice_type'.tr(),
                  description: 'onboarding.farm_choice_type_desc'.tr(),
                  onTap: () => context.go('/onboarding/farm-form',
                      extra: initialDraft),
                ),
                const SizedBox(height: 20),
                Center(
                  child: TextButton(
                    onPressed: () => _skip(context, ref),
                    child: Text('onboarding.skip_for_now'.tr(),
                        style:
                            const TextStyle(color: AppColors.textSecondary)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: GlassCard(
            padding: const EdgeInsets.all(16),
            radius: 20,
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.farmerGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon,
                      color: AppColors.farmerGreen, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(description,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      );
}
