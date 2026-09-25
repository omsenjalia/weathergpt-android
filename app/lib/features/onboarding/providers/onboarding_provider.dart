import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/services/api_client.dart';
import '../../settings/providers/settings_provider.dart';

/// Language → TTS voice locale, shared by the language step and the final
/// [OnboardingNotifier.completeOnboarding] write so a skipped language step
/// can never leave the TTS locale behind.
const kOnboardingTtsLocales = <String, String>{
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

class OnboardingState {
  const OnboardingState({
    this.selectedLanguage = 'en',
    this.selectedPersona = 'everyone',
    this.currentStep = 0,
  });

  final String selectedLanguage;
  final String selectedPersona;
  final int currentStep;

  OnboardingState copyWith({
    String? selectedLanguage,
    String? selectedPersona,
    int? currentStep,
  }) =>
      OnboardingState(
        selectedLanguage: selectedLanguage ?? this.selectedLanguage,
        selectedPersona: selectedPersona ?? this.selectedPersona,
        currentStep: currentStep ?? this.currentStep,
      );
}

class OnboardingNotifier extends StateNotifier<OnboardingState> {
  OnboardingNotifier() : super(const OnboardingState());

  void selectLanguage(String code) =>
      state = state.copyWith(selectedLanguage: code, currentStep: 1);

  void selectPersona(String persona) =>
      state = state.copyWith(selectedPersona: persona, currentStep: 2);

  Future<void> completeOnboarding() async {
    final box = Hive.box('settings');
    await box.put('language', state.selectedLanguage);
    await box.put('tts_voice_locale',
        kOnboardingTtsLocales[state.selectedLanguage] ?? 'en-US');
    await box.put('user_persona', state.selectedPersona);
    await box.put('onboarding_complete', true);
  }
}

final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingState>(
  (ref) => OnboardingNotifier(),
);

/// Call right after [OnboardingNotifier.completeOnboarding].
///
/// Onboarding writes straight to Hive; without this, [settingsProvider] keeps
/// its pre-onboarding state (default persona/language) until the next app
/// restart, so the first home screen would fetch the wrong mode. Invalidating
/// reloads settings from Hive immediately, and the API language header is
/// synced so the first backend call already speaks the chosen language.
void syncSettingsAfterOnboarding(WidgetRef ref) {
  ApiClient.instance.setLanguage(ref.read(onboardingProvider).selectedLanguage);
  ref.invalidate(settingsProvider);
}
