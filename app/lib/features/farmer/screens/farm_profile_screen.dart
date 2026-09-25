import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../models/farm_options.dart';
import '../models/farm_profile_model.dart';
import '../providers/farm_profile_provider.dart';

class FarmProfileScreen extends ConsumerStatefulWidget {
  const FarmProfileScreen({super.key});
  @override
  ConsumerState<FarmProfileScreen> createState() => _FarmProfileScreenState();
}

class _FarmProfileScreenState extends ConsumerState<FarmProfileScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(farmProfileProvider);
    return Scaffold(
      appBar: AppBar(
          title: Text('farmer.farm_profile'.tr(),
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
      body: SafeArea(
          child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Column(children: [
          _ProfileTabs(
              selected: _tab,
              onChanged: (value) => setState(() => _tab = value)),
          const SizedBox(height: 18),
          Expanded(
              child: _tab == 0
                  ? _Details(profile: profile)
                  : _Crops(profile: profile)),
          if (_tab == 0)
            PrimaryButton(
                label: 'farmer.edit_farm_profile'.tr(),
                onPressed: () => _openEditor(profile)),
        ]),
      )),
    );
  }

  Future<void> _openEditor(FarmProfile profile) =>
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => _FarmProfileEditor(initialProfile: profile),
      ));
}

class _ProfileTabs extends StatelessWidget {
  const _ProfileTabs({required this.selected, required this.onChanged});
  final int selected;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => Row(
      children: ['farmer.details_tab'.tr(), 'farmer.crops_tab'.tr()]
          .asMap()
          .entries
          .map((entry) => Expanded(
                child: GestureDetector(
                    onTap: () => onChanged(entry.key),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                          border: Border(
                              bottom: BorderSide(
                                  color: selected == entry.key
                                      ? AppColors.farmerGreen
                                      : AppColors.borderSubtle,
                                  width: 2))),
                      child: Text(entry.value,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: selected == entry.key
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary)),
                    )),
              ))
          .toList());
}

class _Details extends StatelessWidget {
  const _Details({required this.profile});
  final FarmProfile profile;
  @override
  Widget build(BuildContext context) => ListView(children: [
        _InfoRow(
            icon: Icons.location_on_outlined,
            label: 'farmer.location'.tr(),
            value: profile.location),
        _InfoRow(
            icon: Icons.eco_outlined,
            label: 'farmer.crop'.tr(),
            value: profile.crop),
        _InfoRow(
            icon: Icons.spa_outlined,
            label: 'farmer.growth_stage'.tr(),
            value: profile.growthStage),
        _InfoRow(
            icon: Icons.landscape_outlined,
            label: 'farmer.farm_size'.tr(),
            value:
                '${profile.farmSizeAcres.toStringAsFixed(profile.farmSizeAcres % 1 == 0 ? 0 : 1)} ${'farmer.acres'.tr()}'),
        _InfoRow(
            icon: Icons.water_drop_outlined,
            label: 'farmer.irrigation_type'.tr(),
            value: profile.irrigationType),
        _InfoRow(
            icon: Icons.grass_outlined,
            label: 'farmer.soil_type'.tr(),
            value: profile.soilType),
      ]);
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              Icon(icon, color: AppColors.textPrimary, size: 27),
              const SizedBox(width: 15),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(label,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    Text(value,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                  ])),
            ])),
      );
}

class _Crops extends StatelessWidget {
  const _Crops({required this.profile});
  final FarmProfile profile;
  @override
  Widget build(BuildContext context) => ListView(children: [
        AppCard(
            child: Row(children: [
          const Icon(Icons.eco_outlined, color: AppColors.farmerGreen),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(profile.crop,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(profile.growthStage,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13))
              ]))
        ])),
      ]);
}

class _FarmProfileEditor extends ConsumerStatefulWidget {
  const _FarmProfileEditor({required this.initialProfile});
  final FarmProfile initialProfile;
  @override
  ConsumerState<_FarmProfileEditor> createState() => _FarmProfileEditorState();
}

class _FarmProfileEditorState extends ConsumerState<_FarmProfileEditor> {
  late final TextEditingController _location =
      TextEditingController(text: widget.initialProfile.location);
  late final TextEditingController _size = TextEditingController(
      text: widget.initialProfile.farmSizeAcres.toString());
  late String _crop = widget.initialProfile.crop;
  late String _stage = widget.initialProfile.growthStage;
  late String _irrigation = widget.initialProfile.irrigationType;
  late String _soil = widget.initialProfile.soilType;

  @override
  void dispose() {
    _location.dispose();
    _size.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar:
            AppBar(title: Text('farmer.edit_farm_profile'.tr())),
        body: SafeArea(
            child: ListView(padding: const EdgeInsets.all(20), children: [
          _TextField(label: 'farmer.location'.tr(), controller: _location),
          _TextField(
              label: 'farmer.farm_size'.tr(),
              controller: _size,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true)),
          _Select(
              label: 'farmer.crop'.tr(),
              value: _crop,
              values: withCurrentOption(kFarmCrops, _crop),
              onChanged: (value) => setState(() => _crop = value!)),
          _Select(
              label: 'farmer.growth_stage'.tr(),
              value: _stage,
              values: withCurrentOption(kGrowthStages, _stage),
              onChanged: (value) => setState(() => _stage = value!)),
          _Select(
              label: 'farmer.irrigation_type'.tr(),
              value: _irrigation,
              values: withCurrentOption(kIrrigationTypes, _irrigation),
              onChanged: (value) => setState(() => _irrigation = value!)),
          _Select(
              label: 'farmer.soil_type'.tr(),
              value: _soil,
              values: withCurrentOption(kSoilTypes, _soil),
              onChanged: (value) => setState(() => _soil = value!)),
          const SizedBox(height: 18),
          PrimaryButton(
              label: 'farmer.save_changes'.tr(), onPressed: _save),
        ])),
      );

  Future<void> _save() async {
    final size = double.tryParse(_size.text.trim());
    if (size == null || size <= 0 || _location.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('farmer.invalid_details'.tr())));
      return;
    }
    await ref.read(farmProfileProvider.notifier).save(FarmProfile(
        location: _location.text.trim(),
        crop: _crop,
        growthStage: _stage,
        farmSizeAcres: size,
        irrigationType: _irrigation,
        soilType: _soil));
    if (mounted) Navigator.of(context).pop();
  }
}

class _TextField extends StatelessWidget {
  const _TextField(
      {required this.label, required this.controller, this.keyboardType});
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
            labelText: label,
            filled: true,
            fillColor: AppColors.surfaceCard,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderSubtle))),
      ));
}

class _Select extends StatelessWidget {
  const _Select(
      {required this.label,
      required this.value,
      required this.values,
      required this.onChanged});
  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String?> onChanged;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
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
                borderSide: const BorderSide(color: AppColors.borderSubtle))),
        items: values
            .map((item) => DropdownMenuItem(value: item, child: Text(item)))
            .toList(),
      ));
}
