import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/atmosphere_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../../farmer/models/farm_options.dart';
import '../../farmer/models/farm_profile_model.dart';
import '../../farmer/providers/farm_profile_provider.dart';
import '../../home/providers/atmosphere_provider.dart';
import '../providers/onboarding_provider.dart';

/// Extra onboarding step shown only when the user picks the **farmer**
/// persona. Crop advice, spray/irrigation windows and chat farm context are
/// all tuned to these details, so capturing them up front makes the first
/// farmer session useful immediately.
///
/// Everything here stays editable later in **Settings → Farm profile** (and
/// in the Farm tab), and skipping keeps the default profile.
///
/// First-time farmers choose between this form and the voice conversation
/// ([FarmVoiceScreen]) on the choice step; both hand unsaved drafts to each
/// other via route extras, so switching never loses answers.
class FarmDetailsScreen extends ConsumerStatefulWidget {
  const FarmDetailsScreen({super.key, this.initialDraft});

  /// Unsaved answers handed over from the voice flow, shown for editing.
  final Map<String, dynamic>? initialDraft;

  @override
  ConsumerState<FarmDetailsScreen> createState() => _FarmDetailsScreenState();
}

class _FarmDetailsScreenState extends ConsumerState<FarmDetailsScreen> {
  late final TextEditingController _location;
  late final TextEditingController _size;
  late String _crop;
  late String _stage;
  late String _irrigation;
  late String _soil;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final draft = widget.initialDraft;
    _initFrom(draft != null
        ? FarmProfile.fromMap(draft)
        : ref.read(farmProfileProvider));
  }

  @override
  void dispose() {
    _location.dispose();
    _size.dispose();
    super.dispose();
  }

  void _initFrom(FarmProfile profile) {
    _location = TextEditingController(text: profile.location);
    _size = TextEditingController(
        text: profile.farmSizeAcres
            .toStringAsFixed(profile.farmSizeAcres % 1 == 0 ? 0 : 1));
    _crop = profile.crop;
    _stage = profile.growthStage;
    _irrigation = profile.irrigationType;
    _soil = profile.soilType;
  }

  /// Current field values as a handoff map. Unlike saving, this never
  /// validates: unparsable entries fall back to the stored profile so the
  /// other flow can fix them.
  Map<String, dynamic> _currentDraftMap() {
    final base = ref.read(farmProfileProvider);
    final size = double.tryParse(_size.text.trim());
    return {
      'location': _location.text.trim().isEmpty
          ? base.location
          : _location.text.trim(),
      'crop': _crop,
      'growthStage': _stage,
      'farmSizeAcres':
          (size == null || size <= 0) ? base.farmSizeAcres : size,
      'irrigationType': _irrigation,
      'soilType': _soil,
    };
  }

  Future<void> _finish({required bool save}) async {
    if (_saving) return;
    if (save) {
      final size = double.tryParse(_size.text.trim());
      if (_location.text.trim().isEmpty || size == null || size <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('farmer.invalid_details'.tr())));
        return;
      }
      setState(() => _saving = true);
      await ref.read(farmProfileProvider.notifier).save(FarmProfile(
            location: _location.text.trim(),
            crop: _crop,
            growthStage: _stage,
            farmSizeAcres: size,
            irrigationType: _irrigation,
            soilType: _soil,
          ));
    }
    await ref.read(onboardingProvider.notifier).completeOnboarding();
    if (!mounted) return;
    syncSettingsAfterOnboarding(ref);
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
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
                    onPressed: () => context.go('/onboarding/farm',
                        extra: _currentDraftMap()),
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: Text('onboarding.back'.tr()),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 4),
                Text('onboarding.farm_headline'.tr(),
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 7),
                Text('onboarding.farm_hint'.tr(),
                    style:
                        const TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 20),
                GlassCard(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  radius: 20,
                  child: Column(children: [
                    _TextField(
                      label: 'farmer.location'.tr(),
                      hint: 'onboarding.farm_location_hint'.tr(),
                      controller: _location,
                    ),
                    _TextField(
                      label: 'farmer.farm_size'.tr(),
                      hint: 'onboarding.farm_size_hint'.tr(),
                      controller: _size,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                    _Select(
                      label: 'farmer.crop'.tr(),
                      value: _crop,
                      values: withCurrentOption(kFarmCrops, _crop),
                      onChanged: (v) => setState(() => _crop = v!),
                    ),
                    _Select(
                      label: 'farmer.growth_stage'.tr(),
                      value: _stage,
                      values: withCurrentOption(kGrowthStages, _stage),
                      onChanged: (v) => setState(() => _stage = v!),
                    ),
                    _Select(
                      label: 'farmer.irrigation_type'.tr(),
                      value: _irrigation,
                      values: withCurrentOption(kIrrigationTypes, _irrigation),
                      onChanged: (v) => setState(() => _irrigation = v!),
                    ),
                    _Select(
                      label: 'farmer.soil_type'.tr(),
                      value: _soil,
                      values: withCurrentOption(kSoilTypes, _soil),
                      onChanged: (v) => setState(() => _soil = v!),
                    ),
                  ]),
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: 'onboarding.continue'.tr(),
                  disabled: _saving,
                  onPressed: () => _finish(save: true),
                ),
                const SizedBox(height: 4),
                Center(
                  child: TextButton(
                    onPressed: _saving ? null : () => _finish(save: false),
                    child: Text('onboarding.skip_for_now'.tr(),
                        style:
                            const TextStyle(color: AppColors.textSecondary)),
                  ),
                ),
                Center(
                  child: TextButton.icon(
                    onPressed: _saving
                        ? null
                        : () => context.go('/onboarding/farm-voice',
                            extra: _currentDraftMap()),
                    icon: const Icon(Icons.mic_rounded, size: 18),
                    label: Text('farm.voice_talk_instead'.tr()),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary),
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

class _TextField extends StatelessWidget {
  const _TextField({
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            filled: true,
            fillColor: AppColors.surfaceCard,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderSubtle)),
          ),
        ),
      );
}

class _Select extends StatelessWidget {
  const _Select({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: DropdownButtonFormField<String>(
          initialValue: value,
          onChanged: onChanged,
          dropdownColor: AppColors.surfaceCard,
          decoration: InputDecoration(
            labelText: label,
            filled: true,
            fillColor: AppColors.surfaceCard,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderSubtle)),
          ),
          items: values
              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
        ),
      );
}
