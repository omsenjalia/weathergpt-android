import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../../core/constants/api_endpoints.dart';
import '../../../core/models/request_context.dart';
import '../../../core/services/api_client.dart';
import '../../../core/utils/markdown_utils.dart';
import '../../farmer/providers/farm_profile_provider.dart';
import '../mappers/voice_response_mapper.dart';
import '../../home/providers/location_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../settings/providers/developer_options_provider.dart';

// Re-exported so existing screens keep importing these types from here.
export '../mappers/voice_response_mapper.dart';

enum VoiceStatus { idle, listening, processing, speaking, done, error }

class VoiceState {
  const VoiceState(
      {this.status = VoiceStatus.idle,
      this.transcript = '',
      this.response,
      this.errorMessage});
  final VoiceStatus status;
  final String transcript;
  final VoiceResponse? response;
  final String? errorMessage;
  VoiceState copyWith(
          {VoiceStatus? status,
          String? transcript,
          VoiceResponse? response,
          String? errorMessage}) =>
      VoiceState(
          status: status ?? this.status,
          transcript: transcript ?? this.transcript,
          response: response ?? this.response,
          errorMessage: errorMessage ?? this.errorMessage);
}

class VoiceNotifier extends StateNotifier<VoiceState> {
  VoiceNotifier(this._ref) : super(const VoiceState());
  final Ref _ref;
  final _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();

  /// Monotonic guard so a slow answer cannot overwrite a newer question, and a
  /// cancelled session cannot resurrect itself after the user starts another.
  int _generation = 0;

  /// Map app language code → speech_to_text locale id.
  String _sttLocale() {
    final lang = _ref.read(settingsProvider).language.toLowerCase();
    const map = {
      'en': 'en_US',
      'hi': 'hi_IN',
      'gu': 'gu_IN',
      'mr': 'mr_IN',
      'ta': 'ta_IN',
      'te': 'te_IN',
      'kn': 'kn_IN',
      'ml': 'ml_IN',
      'bn': 'bn_IN',
      'pa': 'pa_IN',
    };
    return map[lang] ?? 'en_US';
  }

  Timer? _silenceTimer;

  Future<void> startListening() async {
    state = const VoiceState(status: VoiceStatus.processing);
    try {
      final mic = await Permission.microphone.request();
      if (!mic.isGranted) {
        state = const VoiceState(
            status: VoiceStatus.error,
            errorMessage:
                'Microphone access is needed to listen. You can still use a suggested question.');
        return;
      }

      // Prefer speech-to-text only. Dual record+STT is a common crash source
      // on Android when the temp path is invalid or the plugin races.
      final available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' && state.status == VoiceStatus.listening) {
            stopListening();
          }
        },
        onError: (_) {
          if (state.status == VoiceStatus.listening) stopListening();
        },
      );
      if (!available) {
        state = const VoiceState(
            status: VoiceStatus.error,
            errorMessage:
                'Speech recognition is not available on this device.');
        return;
      }

      state = const VoiceState(status: VoiceStatus.listening);
      final localeId = _sttLocale();
      await _speech.listen(
        onResult: (result) {
          state = state.copyWith(transcript: result.recognizedWords);
          _restartSilenceTimer();
          if (result.finalResult) {
            stopListening();
          }
        },
        listenOptions: stt.SpeechListenOptions(
          localeId: localeId,
          partialResults: true,
          listenMode: stt.ListenMode.confirmation,
          cancelOnError: true,
        ),
      );
      _restartSilenceTimer();
    } catch (e) {
      state = const VoiceState(
          status: VoiceStatus.error,
          errorMessage:
              'Could not start listening. Please try again.');
    }
  }

  void _restartSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(const Duration(milliseconds: 2500), stopListening);
  }

  Future<void> stopListening() async {
    if (state.status != VoiceStatus.listening) return;
    _silenceTimer?.cancel();
    try {
      await _speech.stop();
    } catch (_) {}
    state = state.copyWith(status: VoiceStatus.processing);
    await submitToBackend();
  }

  Future<void> submitQuery(String text) async {
    _silenceTimer?.cancel();
    state = VoiceState(status: VoiceStatus.processing, transcript: text);
    await submitToBackend();
  }

  Future<void> submitToBackend({String? audioPath}) async {
    final generation = ++_generation;
    try {
      final settings = _ref.read(settingsProvider);
      final location = _ref.read(locationProvider);
      final profile = _ref.read(farmProfileProvider);
      final transcript = state.transcript.trim();
      if (transcript.isEmpty) {
        state = const VoiceState(
            status: VoiceStatus.error,
            errorMessage: 'No speech detected. Try again or pick a suggestion.');
        return;
      }

      // Validated mode plus the user's real farm profile, built by the same
      // helper the chat surface uses so both send identical context.
      final context = buildAgentRequestContext(
        profilePersona: settings.userPersona,
        farm: FarmContext(
          crop: profile.crop,
          growthStage: profile.growthStage,
          soilType: profile.soilType,
          irrigationType: profile.irrigationType,
        ),
      );

      // Always use /chat — /voice multipart is optional and often unavailable.
      Future<Map<String, dynamic>> postChat(String msg) =>
          ApiClient.instance.post(ApiEndpoints.chat, data: {
        'message': msg,
        'location': location.name,
        'lat': location.lat,
        'lon': location.lon,
        'language': settings.language,
        ...context.toPayload(),
      });

      var result = await postChat(transcript);
      var responseText = '${result['response'] ?? ''}';
      // Backend sometimes returns a generic empty-fail; retry with a simpler weather ask.
      if (responseText.toLowerCase().contains("couldn't fetch live weather")) {
        final city = location.name.split(',').first.trim();
        final simplified =
            'What is the weather forecast for $city including rain chances tomorrow?';
        try {
          result = await postChat(simplified);
          final retry = '${result['response'] ?? ''}';
          if (retry.isNotEmpty &&
              !retry.toLowerCase().contains("couldn't fetch live weather")) {
            responseText = retry;
          }
        } catch (_) {}
      }
      // A newer question superseded this one: never render the stale answer.
      if (generation != _generation) return;
      state = state.copyWith(
        status: VoiceStatus.done,
        response: mapBackendAnswer(transcript, responseText, raw: result),
      );
    } on AppApiError catch (error) {
      if (generation != _generation) return;
      state = state.copyWith(
          status: VoiceStatus.error, errorMessage: error.message);
    } catch (e) {
      if (generation != _generation) return;
      state = state.copyWith(
          status: VoiceStatus.error,
          errorMessage: 'WeatherGPT took too long to answer. Please try again.');
    }
  }


  Future<void> speak(String text) async {
    state = state.copyWith(status: VoiceStatus.speaking);
    try {
      final voice = _ref.read(settingsProvider);
      final dev = _ref.read(developerOptionsProvider);
      await _tts.stop();
      final locale = (dev.enabled && dev.forceTtsLocale != null)
          ? dev.forceTtsLocale!
          : voice.ttsVoiceLocale;
      await _tts.setLanguage(locale);
      // FlutterTts: ~0.5 is natural on Android; UI stores 0.3–1.0.
      final speed = (dev.enabled && dev.forceTtsSpeed != null)
          ? dev.forceTtsSpeed!
          : voice.ttsSpeed;
      final rate = (speed * 0.55).clamp(0.25, 0.75);
      await _tts.setSpeechRate(rate);
      // Per-language voice picked in the voice studio. Skipped when a dev
      // locale override changes the language (a saved English voice must
      // never speak Hindi); unknown names fall back to the locale default.
      final selection = voice.ttsVoices[voice.language];
      if (selection != null &&
          selection.isDevice &&
          selection.isValid &&
          locale.toLowerCase().startsWith(voice.language.toLowerCase())) {
        try {
          await _tts.setVoice(
              {'name': selection.name, 'locale': selection.locale});
        } catch (_) {}
      }
      final clean = MarkdownUtils.forSpeech(text);
      if (clean.isNotEmpty) {
        await _tts.speak(clean);
      }
    } catch (_) {}
    state = state.copyWith(status: VoiceStatus.done);
  }

  Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }

  void cancel() {
    _generation++;
    _silenceTimer?.cancel();
    try {
      _speech.stop();
    } catch (_) {}
    try {
      _tts.stop();
    } catch (_) {}
    state = const VoiceState();
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    try {
      _speech.stop();
    } catch (_) {}
    try {
      _tts.stop();
    } catch (_) {}
    super.dispose();
  }
}

final voiceProvider = StateNotifierProvider<VoiceNotifier, VoiceState>(
    (ref) => VoiceNotifier(ref));
