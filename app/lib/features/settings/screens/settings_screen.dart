import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/atmosphere_background.dart';
import '../models/tts_voice_option.dart';
import '../providers/settings_provider.dart';
import '../providers/developer_options_provider.dart';
import '../../farmer/providers/farm_profile_provider.dart';
import '../../home/providers/atmosphere_provider.dart';
import '../../home/theme/atmosphere_theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const _languages = [
    ('en', 'English'),
    ('hi', 'हिंदी'),
    ('gu', 'ગુજરાતી'),
    ('mr', 'मराठी'),
    ('ta', 'தமிழ்'),
    ('te', 'తెలుగు'),
    ('kn', 'ಕನ್ನಡ'),
    ('ml', 'മലയാളം'),
    ('bn', 'বাংলা'),
  ];

  static const _ttsLocales = {
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    final dev = ref.watch(developerOptionsProvider);
    final devN = ref.read(developerOptionsProvider.notifier);
    final farm = ref.watch(farmProfileProvider);
    final farmCompleted = ref.watch(farmProfileCompletedProvider);
    final isFarmer = settings.userPersona == 'farmer';
    final bottom = MediaQuery.paddingOf(context).bottom + 108;
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
            bottom: false,
            child: ListView(
              padding: EdgeInsets.fromLTRB(20, 16, 20, bottom),
              children: [
            const Text('Settings',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6)),
            const SizedBox(height: 6),
            Text('Language, voice, and experience',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.82),
                  fontWeight: FontWeight.w500,
                )),
            const SizedBox(height: 24),
            _section('Language'),
            _card(
              // RadioGroup owns the group value in current Flutter releases;
              // per-tile groupValue/onChanged are deprecated.
              child: RadioGroup<String>(
                groupValue: settings.language,
                onChanged: (v) async {
                  if (v == null) return;
                  await n.updateLanguage(v);
                  await n.updateTtsVoiceLocale(_ttsLocales[v] ?? 'en-US');
                  if (context.mounted) await context.setLocale(Locale(v));
                },
                child: Column(
                  children: [
                    for (final (code, label) in _languages)
                      RadioListTile<String>(
                        value: code,
                        activeColor: AppColors.accent,
                        title: Text(label),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _section('Experience'),
            _card(
              child: RadioGroup<String>(
                groupValue: settings.userPersona,
                onChanged: (v) async {
                  if (v == null) return;
                  await n.updatePersona(v);
                  // A fresh farmer without farm details lands straight on the
                  // profile editor so advisories are tuned from day one.
                  if (v == 'farmer' &&
                      !ref.read(farmProfileCompletedProvider) &&
                      context.mounted) {
                    context.push('/farmer/farm-profile');
                  }
                },
                child: Column(
                  children: [
                    for (final (id, key) in [
                      ('everyone', 'persona.everyone'),
                      ('farmer', 'persona.farmer'),
                      ('researcher', 'persona.researcher'),
                    ])
                      RadioListTile<String>(
                        value: id,
                        activeColor: AppColors.accent,
                        title: Text(key.tr()),
                      ),
                  ],
                ),
              ),
            ),
            if (isFarmer) ...[
              const SizedBox(height: 20),
              _section('farmer.farm_profile'.tr()),
              _card(
                child: Column(
                  children: [
                    if (!farmCompleted)
                      ListTile(
                        leading: const Icon(Icons.eco_outlined,
                            color: AppColors.statusAmber),
                        title: Text('farmer.complete_profile'.tr()),
                        subtitle:
                            Text('farmer.profile_complete_hint'.tr()),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () =>
                            context.push('/farmer/farm-profile'),
                      )
                    else
                      ListTile(
                        leading: const Icon(Icons.agriculture_outlined,
                            color: AppColors.farmerGreen),
                        title: Text(farm.location),
                        subtitle: Text(
                            '${farm.crop} · ${farm.growthStage} · ${farm.farmSizeAcres.toStringAsFixed(farm.farmSizeAcres % 1 == 0 ? 0 : 1)} ${'farmer.acres'.tr()}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () =>
                            context.push('/farmer/farm-profile'),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            _section('Voice'),
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    leading: const Icon(Icons.record_voice_over_outlined,
                        color: AppColors.accent),
                    title: Text('settings.voice_title'.tr()),
                    subtitle: Text(_voiceLabel(settings)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/settings/voice'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('Speech speed'),
                    subtitle: Text(
                      settings.ttsSpeed < 0.7
                          ? 'Slow'
                          : settings.ttsSpeed > 1.0
                              ? 'Fast'
                              : 'Normal',
                    ),
                  ),
                  Slider(
                    value: settings.ttsSpeed.clamp(0.4, 1.2),
                    min: 0.4,
                    max: 1.2,
                    activeColor: AppColors.accent,
                    onChanged: n.updateTtsSpeed,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _section('Developer'),
            _card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Enable developer options'),
                    subtitle: const Text('Data source pins, debug screen, sky & TTS overrides'),
                    value: dev.enabled,
                    activeThumbColor: AppColors.accent,
                    onChanged: devN.setEnabled,
                  ),
                  if (dev.enabled) ...[
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.bug_report_outlined, color: AppColors.accent),
                      title: const Text('Debug & state'),
                      subtitle: const Text('Snapshot, per-field sources, provider chain, request log, backend health'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/debug'),
                    ),
                    const Divider(height: 1),
                    const ListTile(
                      dense: true,
                      title: Text('DATA SOURCE', style: TextStyle(fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w700, color: Colors.white54)),
                    ),
                    ListTile(
                      title: const Text('Pin forecast source'),
                      subtitle: Text(dev.sourcePin.label),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      child: DropdownButtonFormField<DevSourcePin>(
                        initialValue: dev.sourcePin,
                        items: [
                          for (final v in DevSourcePin.values)
                            DropdownMenuItem(value: v, child: Text(v.label)),
                        ],
                        onChanged: (v) {
                          if (v != null) devN.setSourcePin(v);
                        },
                      ),
                    ),
                    ListTile(
                      title: const Text('Hourly horizon'),
                      subtitle: Text('${dev.hourlyHours} h requested (backend caps at provider horizon)'),
                    ),
                    Slider(
                      value: dev.hourlyHours.toDouble(),
                      min: 6,
                      max: 168,
                      divisions: 27,
                      label: '${dev.hourlyHours} h',
                      activeColor: AppColors.accent,
                      onChanged: (v) => devN.setHourlyHours(v.round()),
                    ),
                    ListTile(
                      title: const Text('Forecast days'),
                      subtitle: Text('${dev.forecastDays} days requested'),
                    ),
                    Slider(
                      value: dev.forecastDays.toDouble(),
                      min: 1,
                      max: 15,
                      divisions: 14,
                      label: '${dev.forecastDays} d',
                      activeColor: AppColors.accent,
                      onChanged: (v) => devN.setForecastDays(v.round()),
                    ),
                    SwitchListTile(
                      title: const Text('Fill missing fields from Open-Meteo'),
                      subtitle: const Text('Humidity, UV, sunrise/sunset, AQI… when the primary source lacks them. Off = raw provider only.'),
                      value: dev.supplementSecondaryFields,
                      activeThumbColor: AppColors.accent,
                      onChanged: devN.setSupplementSecondaryFields,
                    ),
                    SwitchListTile(
                      title: const Text('Disable legacy /weather fallback'),
                      subtitle: const Text('Surface /v2/weather errors instead of silently retrying the old endpoint'),
                      value: dev.disableV2Fallback,
                      activeThumbColor: AppColors.accent,
                      onChanged: devN.setDisableV2Fallback,
                    ),
                    const Divider(height: 1),
                    const ListTile(
                      dense: true,
                      title: Text('DISPLAY', style: TextStyle(fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w700, color: Colors.white54)),
                    ),
                    SwitchListTile(
                      title: const Text('Show provenance bar on Home'),
                      subtitle: const Text('Source / run / freshness chips under the hero card'),
                      value: dev.showProvenanceOnHome,
                      activeThumbColor: AppColors.accent,
                      onChanged: devN.setShowProvenanceOnHome,
                    ),
                    SwitchListTile(
                      title: const Text('Per-field source badges'),
                      subtitle: const Text('Mark tiles that came from a secondary provider'),
                      value: dev.showFieldSourceBadges,
                      activeThumbColor: AppColors.accent,
                      onChanged: devN.setShowFieldSourceBadges,
                    ),
                    SwitchListTile(
                      title: const Text('Record request log'),
                      subtitle: const Text('Keep the last 60 backend calls for the Debug screen'),
                      value: dev.logRequests,
                      activeThumbColor: AppColors.accent,
                      onChanged: devN.setLogRequests,
                    ),
                    const Divider(height: 1),
                    const ListTile(
                      dense: true,
                      title: Text('SKY & TTS OVERRIDES', style: TextStyle(fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w700, color: Colors.white54)),
                    ),
                    ListTile(
                      title: const Text('Force time of day'),
                      subtitle: Text(dev.forcePeriod?.name ?? 'Auto (device time)'),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      child: DropdownButtonFormField<String>(
                        initialValue: dev.forcePeriod?.name ?? 'auto',
                        items: [
                          const DropdownMenuItem(value: 'auto', child: Text('Auto')),
                          ...SkyPeriod.values.map(
                            (e) => DropdownMenuItem(value: e.name, child: Text(e.name)),
                          ),
                        ],
                        onChanged: (v) {
                          if (v == null || v == 'auto') {
                            devN.setForcePeriod(null);
                          } else {
                            devN.setForcePeriod(SkyPeriod.values.byName(v));
                          }
                        },
                      ),
                    ),
                    ListTile(
                      title: const Text('Force weather condition'),
                      subtitle: Text(dev.forceSky?.name ?? 'Auto (live weather)'),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      child: DropdownButtonFormField<String>(
                        initialValue: dev.forceSky?.name ?? 'auto',
                        items: [
                          const DropdownMenuItem(value: 'auto', child: Text('Auto')),
                          ...SkyCondition.values.map(
                            (e) => DropdownMenuItem(value: e.name, child: Text(e.name)),
                          ),
                        ],
                        onChanged: (v) {
                          if (v == null || v == 'auto') {
                            devN.setForceSky(null);
                          } else {
                            devN.setForceSky(SkyCondition.values.byName(v));
                          }
                        },
                      ),
                    ),
                    SwitchListTile(
                      title: const Text('Disable animated sky'),
                      subtitle: const Text('Use gradient only'),
                      value: dev.disableVideoSky,
                      activeThumbColor: AppColors.accent,
                      onChanged: devN.setDisableVideoSky,
                    ),
                    ListTile(
                      title: const Text('TTS locale override'),
                      subtitle: Text(dev.forceTtsLocale ?? settings.ttsVoiceLocale),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      child: DropdownButtonFormField<String>(
                        initialValue: dev.forceTtsLocale ?? 'default',
                        items: const [
                          DropdownMenuItem(value: 'default', child: Text('Use app setting')),
                          DropdownMenuItem(value: 'en-US', child: Text('en-US')),
                          DropdownMenuItem(value: 'en-IN', child: Text('en-IN')),
                          DropdownMenuItem(value: 'hi-IN', child: Text('hi-IN')),
                          DropdownMenuItem(value: 'gu-IN', child: Text('gu-IN')),
                          DropdownMenuItem(value: 'mr-IN', child: Text('mr-IN')),
                          DropdownMenuItem(value: 'ta-IN', child: Text('ta-IN')),
                          DropdownMenuItem(value: 'te-IN', child: Text('te-IN')),
                          DropdownMenuItem(value: 'bn-IN', child: Text('bn-IN')),
                        ],
                        onChanged: (v) {
                          if (v == null || v == 'default') {
                            devN.setForceTtsLocale(null);
                          } else {
                            devN.setForceTtsLocale(v);
                          }
                        },
                      ),
                    ),
                    ListTile(
                      title: const Text('TTS speed override'),
                      subtitle: Text(
                        dev.forceTtsSpeed == null
                            ? 'Use app setting (${settings.ttsSpeed.toStringAsFixed(2)})'
                            : dev.forceTtsSpeed!.toStringAsFixed(2),
                      ),
                    ),
                    Slider(
                      value: (dev.forceTtsSpeed ?? settings.ttsSpeed).clamp(0.4, 1.2),
                      min: 0.4,
                      max: 1.2,
                      activeColor: AppColors.accent,
                      onChanged: (v) => devN.setForceTtsSpeed(v),
                    ),
                    TextButton(
                      onPressed: () => devN.reset(),
                      child: const Text('Reset developer overrides'),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 26),
            Center(
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: AppColors.gradientAccent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.wb_cloudy_rounded,
                        size: 24, color: Colors.black),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'common.weather_gpt'.tr(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'settings.footer'.tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.white.withValues(alpha: 0.65),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Subtitle for the Voice row: the saved voice's friendly name, or
  /// System default when nothing (valid) is stored for this language.
  String _voiceLabel(SettingsState settings) {
    final sel = settings.ttsVoices[settings.language];
    if (sel == null || !sel.isValid || !sel.isDevice) {
      return 'settings.voice_default'.tr();
    }
    return TtsVoiceOption(name: sel.name, locale: sel.locale).friendlyName;
  }

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 4),
        child: Text(
          t.toUpperCase(),
          style: TextStyle(
            fontSize: 11.5,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.75),
          ),
        ),
      );

  Widget _card({required Widget child}) => Container(
        decoration: BoxDecoration(
          color: AppColors.glassFillStrong,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.glassBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      );
}
