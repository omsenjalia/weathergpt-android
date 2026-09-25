import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/atmosphere_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../../home/providers/atmosphere_provider.dart';
import '../providers/onboarding_provider.dart';

class LanguageSelectScreen extends ConsumerWidget {
  const LanguageSelectScreen({super.key});

  static const _languages = [
    ('en', '🇬🇧', 'English', ''),
    ('hi', '🇮🇳', 'हिंदी', 'Hindi'),
    ('gu', '🇮🇳', 'ગુજરાતી', 'Gujarati'),
    ('mr', '🇮🇳', 'मराठी', 'Marathi'),
    ('ta', '🇮🇳', 'தமிழ்', 'Tamil'),
    ('te', '🇮🇳', 'తెలుగు', 'Telugu'),
    ('kn', '🇮🇳', 'ಕನ್ನಡ', 'Kannada'),
    ('ml', '🇮🇳', 'മലയാളം', 'Malayalam'),
    ('bn', '🇧🇩', 'বাংলা', 'Bengali'),
  ];

  Future<void> _continue(BuildContext context, WidgetRef ref) async {
    final code = ref.read(onboardingProvider).selectedLanguage;
    await Hive.box('settings').put('language', code);
    // Map language → TTS voice locale for later speech
    const ttsMap = {
      'en': 'en-US',
      'hi': 'hi-IN',
      'gu': 'gu-IN',
      'mr': 'mr-IN',
      'ta': 'ta-IN',
      'te': 'te-IN',
      'kn': 'kn-IN',
      'ml': 'ml-IN',
      'bn': 'bn-IN',
    };
    await Hive.box('settings').put('tts_voice_locale', ttsMap[code] ?? 'en-US');
    if (context.mounted) {
      await context.setLocale(Locale(code));
      if (context.mounted) context.go('/onboarding/focus');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(onboardingProvider).selectedLanguage;
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
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  ref.read(onboardingProvider.notifier).selectLanguage('en');
                  context.setLocale(const Locale('en'));
                  context.go('/onboarding/focus');
                },
                child: Text('onboarding.skip'.tr(),
                    style: const TextStyle(color: AppColors.textPrimary)),
              ),
            ),
            const Icon(Icons.language_outlined, size: 36),
            const SizedBox(height: 12),
            Text('onboarding.choose_language'.tr(),
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text('onboarding.language_hint'.tr(),
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 18),
            Expanded(
              child: ListView.separated(
                itemCount: _languages.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  if (index == _languages.length) {
                    return GlassCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      radius: 18,
                      child: SizedBox(
                          height: 54,
                          child: Row(children: [
                            const Icon(Icons.more_horiz,
                                color: AppColors.textSecondary),
                            const SizedBox(width: 16),
                            Expanded(
                                child: Text('onboarding.more_languages'.tr(),
                                    style: const TextStyle(
                                        color: AppColors.textSecondary))),
                            const Icon(Icons.chevron_right,
                                color: AppColors.textSecondary),
                          ])),
                    );
                  }
                  final language = _languages[index];
                  final isSelected = selected == language.$1;
                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () async {
                      ref.read(onboardingProvider.notifier).selectLanguage(language.$1);
                      await context.setLocale(Locale(language.$1));
                    },
                    child: GlassCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      radius: 18,
                      strong: isSelected,
                      child: SizedBox(
                          height: 54,
                          child: Row(children: [
                            Text(language.$2,
                                style: const TextStyle(fontSize: 24)),
                            const SizedBox(width: 14),
                            Expanded(
                                child: language.$4.isEmpty
                                    ? Text(language.$3,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700))
                                    : Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                            Text(language.$3,
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.w700)),
                                            Text(language.$4,
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    color: AppColors
                                                        .textSecondary)),
                                          ])),
                            _SelectionDot(selected: isSelected),
                          ])),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            PrimaryButton(
                label: 'onboarding.continue'.tr(), onPressed: () => _continue(context, ref)),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectionDot extends StatelessWidget {
  const _SelectionDot({required this.selected});
  final bool selected;
  @override
  Widget build(BuildContext context) => Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? AppColors.farmerGreen : Colors.transparent,
            border: Border.all(
                color: selected
                    ? AppColors.farmerGreen
                    : AppColors.glassBorderStrong,
                width: 1.8)),
        child: selected
            ? const Icon(Icons.check, size: 14, color: Colors.white)
            : null,
      );
}
