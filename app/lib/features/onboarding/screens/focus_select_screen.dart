import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/atmosphere_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../../home/providers/atmosphere_provider.dart';
import '../providers/onboarding_provider.dart';

class FocusSelectScreen extends ConsumerWidget {
  const FocusSelectScreen({super.key});

  static const _options = [
    (
      'everyone',
      Icons.person_outline,
      'persona.everyone',
      'persona.everyone_description'
    ),
    (
      'farmer',
      Icons.eco_outlined,
      'persona.farmer',
      'persona.farmer_description'
    ),
    (
      'researcher',
      Icons.bar_chart_outlined,
      'persona.researcher',
      'persona.researcher_description'
    ),
  ];

  Color _accent(String persona) => switch (persona) {
        'farmer' => AppColors.farmerGreen,
        'researcher' => AppColors.researcherBlue,
        _ => AppColors.accent,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(onboardingProvider).selectedPersona;
    final palette = ref.watch(atmospherePaletteProvider);
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Stack(
        fit: StackFit.expand,
        children: [
          AtmosphereBackground(
            palette: palette,
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
              child: Column(children: [
                Text('onboarding.focus_headline'.tr(),
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 7),
                Text('onboarding.focus_hint'.tr(),
                    style: const TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 30),
                ..._options.map((option) {
                  final active = option.$1 == selected;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => ref
                          .read(onboardingProvider.notifier)
                          .selectPersona(option.$1),
                      child: GlassCard(
                        borderColor: active
                            ? _accent(option.$1)
                            : AppColors.glassBorder,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                        radius: 20,
                        strong: active,
                        child: SizedBox(
                          height: 82,
                          child: Row(children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: active
                                    ? _accent(option.$1).withValues(alpha: 0.16)
                                    : Colors.white.withValues(alpha: 0.05),
                                border: Border.all(
                                  color: active
                                      ? _accent(option.$1)
                                      : AppColors.glassBorderStrong,
                                ),
                              ),
                              child: Icon(option.$2,
                                  color: active
                                      ? _accent(option.$1)
                                      : AppColors.textSecondary),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(option.$3.tr(),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 4),
                                  Text(option.$4.tr(),
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary)),
                                ],
                              ),
                            ),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: active
                                    ? _accent(option.$1)
                                    : Colors.transparent,
                                border: Border.all(
                                  color: active
                                      ? _accent(option.$1)
                                      : AppColors.glassBorderStrong,
                                  width: 1.8,
                                ),
                              ),
                              child: active
                                  ? const Icon(Icons.check,
                                      size: 14, color: Colors.white)
                                  : null,
                            ),
                          ]),
                        ),
                      ),
                    ),
                  );
                }),
                const Spacer(),
                PrimaryButton(
                    label: 'onboarding.continue'.tr(),
                    onPressed: () async {
                      // Farmers add their farm details on the next step; the
                      // profile stays editable later in Settings → Farm.
                      if (selected == 'farmer') {
                        context.go('/onboarding/farm');
                        return;
                      }
                      await ref
                          .read(onboardingProvider.notifier)
                          .completeOnboarding();
                      if (!context.mounted) return;
                      syncSettingsAfterOnboarding(ref);
                      if (context.mounted) context.go('/home');
                    }),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
