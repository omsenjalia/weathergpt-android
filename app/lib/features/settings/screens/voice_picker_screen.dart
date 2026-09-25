import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/atmosphere_background.dart';
import '../../home/providers/atmosphere_provider.dart';
import '../../voice/providers/tts_voice_provider.dart';
import '../models/tts_voice_option.dart';
import '../providers/settings_provider.dart';

/// Voice studio: preview every device voice for the current app language
/// and pick one. The choice is remembered per language and applied to the
/// next spoken answer; "System default" clears it.
class VoicePickerScreen extends ConsumerStatefulWidget {
  const VoicePickerScreen({super.key});

  @override
  ConsumerState<VoicePickerScreen> createState() => _VoicePickerScreenState();
}

class _VoicePickerScreenState extends ConsumerState<VoicePickerScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(ttsVoicePickerProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    // Immediate preview stop; autoDispose also guards the engine itself.
    try {
      ref.read(ttsVoicePickerProvider.notifier).stopPreview();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(atmospherePaletteProvider);
    final picker = ref.watch(ttsVoicePickerProvider);
    final notifier = ref.read(ttsVoicePickerProvider.notifier);
    final settings = ref.watch(settingsProvider);
    final selection = settings.ttsVoices[settings.language];
    final savedName =
        selection?.isDevice == true ? selection!.name : null;
    // A saved voice removed by an OS update reads as System default, which
    // is also what the voice surface falls back to when speaking.
    final selectedName =
        picker.loading ? savedName : resolveVoiceName(picker.voices, savedName);
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
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: Text('onboarding.back'.tr()),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 4),
                Text('voice_picker.title'.tr(),
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 7),
                Text('voice_picker.hint'.tr(),
                    style:
                        const TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 20),
                _VoiceRow(
                  title: 'settings.voice_default'.tr(),
                  subtitle: settings.ttsVoiceLocale,
                  selected: selectedName == null,
                  onTap: () => notifier.select(null),
                ),
                const SizedBox(height: 12),
                if (picker.loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (picker.failed)
                  _Message(
                    text: 'voice_picker.failed'.tr(),
                    actionLabel: 'chat.retry'.tr(),
                    onAction: notifier.load,
                  )
                else if (picker.voices.isEmpty)
                  _Message(
                    text: 'voice_picker.empty'.tr(),
                    actionLabel: 'chat.retry'.tr(),
                    onAction: notifier.load,
                  )
                else
                  for (final voice in picker.voices) ...[
                    _VoiceRow(
                      title: voice.friendlyName,
                      subtitle: voice.locale,
                      selected: voice.name == selectedName,
                      previewing: picker.previewing == voice.name,
                      onTap: () => notifier.select(voice),
                      onPreview: () => picker.previewing == voice.name
                          ? notifier.stopPreview()
                          : notifier.preview(
                              voice, 'voice_picker.sample'.tr()),
                    ),
                    const SizedBox(height: 12),
                  ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VoiceRow extends StatelessWidget {
  const _VoiceRow({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.previewing = false,
    this.onPreview,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final bool previewing;
  final VoidCallback onTap;
  final VoidCallback? onPreview;

  @override
  Widget build(BuildContext context) => Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            decoration: BoxDecoration(
              color: AppColors.glassFillStrong,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected
                    ? AppColors.accent
                    : AppColors.glassBorder,
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected
                      ? AppColors.accent
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                if (onPreview != null)
                  IconButton(
                    tooltip: previewing
                        ? 'voice_picker.stop'.tr()
                        : 'voice_picker.preview'.tr(),
                    onPressed: onPreview,
                    icon: Icon(
                      previewing
                          ? Icons.stop_circle_rounded
                          : Icons.play_circle_outline_rounded,
                      size: 30,
                      color: previewing
                          ? AppColors.accent
                          : AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
}

class _Message extends StatelessWidget {
  const _Message(
      {required this.text, required this.actionLabel, required this.onAction});

  final String text;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            Text(text,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      );
}
