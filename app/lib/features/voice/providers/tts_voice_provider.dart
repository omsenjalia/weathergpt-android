import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../settings/models/tts_voice_option.dart';
import '../../settings/providers/developer_options_provider.dart';
import '../../settings/providers/settings_provider.dart';

class TtsVoicePickerState {
  const TtsVoicePickerState({
    this.loading = true,
    this.voices = const [],
    this.previewing,
    this.failed = false,
  });

  final bool loading;

  /// Device voices filtered to the current app language.
  final List<TtsVoiceOption> voices;

  /// Engine name of the voice currently previewing, if any.
  final String? previewing;
  final bool failed;
}

/// Voice studio engine: enumerates device voices, previews them with the
/// user's speech-speed setting, and persists one choice per app language.
///
/// Owns a dedicated [FlutterTts] instance (the plugin is a method-channel
/// singleton underneath, so this never fights the main voice surface) and
/// is auto-disposed when the picker closes, stopping any preview.
class TtsVoicePickerNotifier extends StateNotifier<TtsVoicePickerState> {
  TtsVoicePickerNotifier(this._ref) : super(const TtsVoicePickerState());

  final Ref _ref;
  final FlutterTts _tts = FlutterTts();

  Future<void> load() async {
    state = const TtsVoicePickerState();
    try {
      _tts.setCompletionHandler(() {
        if (!mounted || state.previewing == null) return;
        state = TtsVoicePickerState(voices: state.voices);
      });
      final raw = await _tts.getVoices;
      if (!mounted) return;
      final lang = _ref.read(settingsProvider).language;
      state = TtsVoicePickerState(
          voices: filterVoicesForLanguage(parseTtsVoices(raw), lang));
    } catch (_) {
      if (!mounted) return;
      state = const TtsVoicePickerState(loading: false, failed: true);
    }
  }

  /// Speaks [sample] with [option], stopping any current preview first.
  /// Best-effort: TTS failures just clear the previewing state.
  Future<void> preview(TtsVoiceOption option, String sample) async {
    try {
      await _tts.stop();
      await _tts.setLanguage(option.locale);
      final settings = _ref.read(settingsProvider);
      final dev = _ref.read(developerOptionsProvider);
      final speed = (dev.enabled && dev.forceTtsSpeed != null)
          ? dev.forceTtsSpeed!
          : settings.ttsSpeed;
      await _tts.setSpeechRate((speed * 0.55).clamp(0.25, 0.75));
      await _tts.setVoice(option.toVoiceMap());
      if (!mounted) return;
      state = TtsVoicePickerState(
          voices: state.voices, previewing: option.name);
      await _tts.speak(sample);
    } catch (_) {
      if (!mounted) return;
      state = TtsVoicePickerState(voices: state.voices);
    }
  }

  Future<void> stopPreview() async {
    try {
      await _tts.stop();
    } catch (_) {}
    if (!mounted) return;
    state = TtsVoicePickerState(voices: state.voices);
  }

  /// Persists [option] as this language's voice (null = system default).
  /// Takes effect on the next spoken answer; no audio side effects here.
  Future<void> select(TtsVoiceOption? option) async {
    final settings = _ref.read(settingsProvider.notifier);
    final lang = _ref.read(settingsProvider).language;
    if (option == null) {
      await settings.clearTtsVoice(lang);
    } else {
      await settings.updateTtsVoice(
          lang, TtsVoiceSelection(name: option.name, locale: option.locale));
    }
  }

  @override
  void dispose() {
    try {
      _tts.stop();
    } catch (_) {}
    super.dispose();
  }
}

final ttsVoicePickerProvider = StateNotifierProvider.autoDispose<
    TtsVoicePickerNotifier, TtsVoicePickerState>(
  (ref) => TtsVoicePickerNotifier(ref),
);
