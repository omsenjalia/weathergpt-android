import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/atmosphere_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../../farmer/models/farm_profile_model.dart';
import '../../farmer/models/farm_voice_parser.dart';
import '../../farmer/providers/farm_profile_provider.dart';
import '../../home/providers/atmosphere_provider.dart';
import '../providers/farm_voice_provider.dart';
import '../providers/onboarding_provider.dart';

/// Voice alternative to the farm form: the assistant speaks six questions,
/// parses the spoken answers on-device into farm profile values, then shows
/// a tap-to-correct review.
///
/// The mic never auto-starts (that would record the TTS echo) — the user
/// taps it to answer, which stops any playback first. Every question also
/// has tappable chips, so a denied mic or missing STT never blocks progress.
class FarmVoiceScreen extends ConsumerStatefulWidget {
  const FarmVoiceScreen({super.key, this.initialDraft});

  /// Unsaved answers handed over from the form; lands straight on review.
  final Map<String, dynamic>? initialDraft;

  @override
  ConsumerState<FarmVoiceScreen> createState() => _FarmVoiceScreenState();
}

class _FarmVoiceScreenState extends ConsumerState<FarmVoiceScreen> {
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Post-frame: .tr() needs a fully-mounted context.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final notifier = ref.read(farmVoiceOnboardingProvider.notifier);
      notifier.configure(
        questions: [for (final s in kFarmVoiceSteps) s.questionKey.tr()],
        retryPrompt: 'farm.voice_not_caught'.tr(),
        reviewPrompt: 'farm.voice_review_title'.tr(),
        micNeeded: 'farm.voice_mic_needed'.tr(),
        sttUnavailable: 'farm.voice_stt_unavailable'.tr(),
      );
      final draft = widget.initialDraft;
      if (draft != null) {
        notifier.loadDraft(draft);
      } else {
        notifier.start();
      }
    });
  }

  @override
  void dispose() {
    // Stops audio immediately; autoDispose also guards the provider itself.
    ref.read(farmVoiceOnboardingProvider.notifier).shutdown();
    super.dispose();
  }

  Map<String, dynamic> _currentDraft() =>
      ref.read(farmVoiceOnboardingProvider.notifier).draftProfile().toMap();

  void _backToChoice() =>
      context.go('/onboarding/farm', extra: _currentDraft());

  void _typeInstead() =>
      context.go('/onboarding/farm-form', extra: _currentDraft());

  Future<void> _useGps() async {
    final ok = await ref
        .read(farmVoiceOnboardingProvider.notifier)
        .useGpsLocation();
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('location.not_available'.tr())));
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final notifier = ref.read(farmVoiceOnboardingProvider.notifier);
    notifier.shutdown();
    await ref.read(farmProfileProvider.notifier).save(notifier.draftProfile());
    await ref.read(onboardingProvider.notifier).completeOnboarding();
    if (!mounted) return;
    syncSettingsAfterOnboarding(ref);
    if (mounted) context.go('/home');
  }

  String _valueFor(FarmProfile draft, String field) => switch (field) {
        'location' => draft.location,
        'crop' => draft.crop,
        'growthStage' => draft.growthStage,
        'farmSize' =>
          '${formatVoiceFarmSize(draft.farmSizeAcres)} ${'farmer.acres'.tr()}',
        'irrigation' => draft.irrigationType,
        'soil' => draft.soilType,
        _ => '',
      };

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(atmospherePaletteProvider);
    final voice = ref.watch(farmVoiceOnboardingProvider);
    final notifier = ref.read(farmVoiceOnboardingProvider.notifier);
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
                    onPressed: _backToChoice,
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: Text('onboarding.back'.tr()),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 4),
                if (voice.isReview)
                  _buildReview(context, notifier)
                else
                  _buildQuestion(context, voice, notifier),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestion(
      BuildContext context, FarmVoiceState voice, FarmVoiceNotifier notifier) {
    final step = voice.currentStep;
    final listening = voice.status == FarmVoiceStatus.listening;
    final total = kFarmVoiceSteps.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'farm.voice_step_of'.tr(namedArgs: {
            'step': '${voice.step + 1}',
            'total': '$total',
          }),
          style: const TextStyle(
              color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: (voice.step + 1) / total,
          color: AppColors.farmerGreen,
          backgroundColor: AppColors.borderSubtle,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: 16),
        GlassCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          radius: 20,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(step.questionKey.tr(),
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              IconButton(
                tooltip: 'farm.voice_repeat'.tr(),
                onPressed: notifier.repeatQuestion,
                icon: const Icon(Icons.volume_up_rounded,
                    color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        if (voice.errorMessage != null) ...[
          const SizedBox(height: 12),
          GlassCard(
            padding: const EdgeInsets.all(12),
            radius: 14,
            child: Row(
              children: [
                const Icon(Icons.mic_off_rounded,
                    size: 18, color: Colors.amber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(voice.errorMessage!,
                      style: const TextStyle(
                          color: Colors.amber, fontSize: 13)),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        Center(
          child: Material(
            color:
                listening ? Colors.redAccent : AppColors.farmerGreen,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: notifier.toggleMic,
              child: SizedBox(
                width: 76,
                height: 76,
                child: Icon(
                  listening ? Icons.stop_rounded : Icons.mic_rounded,
                  size: 34,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildMicStatus(context, voice),
        const SizedBox(height: 20),
        if (step.chips != null)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final chip in step.chips!)
                ActionChip(
                  label: Text(step.field == 'farmSize'
                      ? '$chip ${'farmer.acres'.tr()}'
                      : chip),
                  onPressed: () => notifier.answerWithOption(chip),
                ),
            ],
          )
        else
          Center(
            child: OutlinedButton.icon(
              onPressed: _useGps,
              icon: const Icon(Icons.my_location_rounded, size: 18),
              label: Text('farm.voice_use_my_location'.tr()),
            ),
          ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: voice.step > 0 ? notifier.prevStep : null,
              child: Text('onboarding.back'.tr(),
                  style: const TextStyle(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: notifier.skipStep,
              child: Text('farm.voice_skip'.tr(),
                  style: const TextStyle(color: AppColors.textSecondary)),
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: _typeInstead,
              child: Text('farm.voice_type_instead'.tr(),
                  style: const TextStyle(color: AppColors.textSecondary)),
            ),
            const Text('·',
                style: TextStyle(color: AppColors.textSecondary)),
            TextButton(
              onPressed: notifier.startOver,
              child: Text('farm.voice_start_over'.tr(),
                  style: const TextStyle(color: AppColors.textSecondary)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMicStatus(BuildContext context, FarmVoiceState voice) {
    final listening = voice.status == FarmVoiceStatus.listening;
    if (listening) {
      final text = voice.transcript.isEmpty
          ? 'farm.voice_listening'.tr()
          : '“${voice.transcript}”';
      return Text(text,
          textAlign: TextAlign.center,
          style:
              const TextStyle(color: AppColors.textSecondary, fontSize: 14));
    }
    if (voice.heardValue != null) {
      return Text(
        '✓ ${'farm.voice_heard'.tr()}: ${voice.heardValue}',
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
            color: AppColors.farmerGreen,
            fontSize: 14,
            fontWeight: FontWeight.w600),
      );
    }
    if (voice.retryHint) {
      return Text('farm.voice_not_caught'.tr(),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.amber, fontSize: 14));
    }
    return Text('farm.voice_tap_to_speak'.tr(),
        textAlign: TextAlign.center,
        style: const TextStyle(
            color: AppColors.textSecondary, fontSize: 14));
  }

  Widget _buildReview(BuildContext context, FarmVoiceNotifier notifier) {
    final draft = notifier.draftProfile();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('farm.voice_review_title'.tr(),
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 7),
        Text('farmer.profile_complete_hint'.tr(),
            style: const TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 20),
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          radius: 20,
          child: Column(
            children: [
              for (var i = 0; i < kFarmVoiceSteps.length; i++) ...[
                if (i > 0)
                  const Divider(
                      height: 1, color: AppColors.borderSubtle),
                InkWell(
                  onTap: () => notifier.jumpToStep(i),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                kFarmVoiceSteps[i].labelKey.tr(),
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _valueFor(
                                    draft, kFarmVoiceSteps[i].field),
                                style: const TextStyle(fontSize: 15),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.edit_rounded,
                            size: 18,
                            color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        PrimaryButton(
          label: 'farm.voice_save'.tr(),
          disabled: _saving,
          onPressed: _save,
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: _saving ? null : _typeInstead,
              child: Text('farm.voice_type_instead'.tr(),
                  style: const TextStyle(color: AppColors.textSecondary)),
            ),
            const Text('·',
                style: TextStyle(color: AppColors.textSecondary)),
            TextButton(
              onPressed: _saving ? null : notifier.startOver,
              child: Text('farm.voice_start_over'.tr(),
                  style: const TextStyle(color: AppColors.textSecondary)),
            ),
          ],
        ),
      ],
    );
  }
}
