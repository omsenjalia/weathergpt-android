import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../../core/utils/markdown_utils.dart';
import '../../farmer/models/farm_options.dart';
import '../../farmer/models/farm_profile_model.dart';
import '../../farmer/models/farm_voice_parser.dart';
import '../../farmer/providers/farm_profile_provider.dart';
import '../../home/providers/location_provider.dart';
import 'onboarding_provider.dart';

/// One scripted question in the farmer voice onboarding loop.
class FarmVoiceStep {
  const FarmVoiceStep({
    required this.field,
    required this.questionKey,
    required this.labelKey,
    this.chips,
  });

  /// FarmProfile field: location, crop, growthStage, farmSize, irrigation, soil.
  final String field;
  final String questionKey;
  final String labelKey;

  /// Tappable answer chips. Null means free speech only (location).
  final List<String>? chips;
}

/// Common farm sizes offered as tap chips on the size question.
const kFarmSizeChips = <String>['1', '2', '4', '5', '10'];

const kFarmVoiceSteps = <FarmVoiceStep>[
  FarmVoiceStep(
      field: 'location',
      questionKey: 'farm.voice_q_location',
      labelKey: 'farmer.location'),
  FarmVoiceStep(
      field: 'crop',
      questionKey: 'farm.voice_q_crop',
      labelKey: 'farmer.crop',
      chips: kFarmCrops),
  FarmVoiceStep(
      field: 'growthStage',
      questionKey: 'farm.voice_q_stage',
      labelKey: 'farmer.growth_stage',
      chips: kGrowthStages),
  FarmVoiceStep(
      field: 'farmSize',
      questionKey: 'farm.voice_q_size',
      labelKey: 'farmer.farm_size',
      chips: kFarmSizeChips),
  FarmVoiceStep(
      field: 'irrigation',
      questionKey: 'farm.voice_q_irrigation',
      labelKey: 'farmer.irrigation_type',
      chips: kIrrigationTypes),
  FarmVoiceStep(
      field: 'soil',
      questionKey: 'farm.voice_q_soil',
      labelKey: 'farmer.soil_type',
      chips: kSoilTypes),
];

enum FarmVoiceStatus { idle, speaking, listening }

class FarmVoiceState {
  const FarmVoiceState({
    this.step = 0,
    this.values = const {},
    this.status = FarmVoiceStatus.idle,
    this.transcript = '',
    this.heardValue,
    this.retryHint = false,
    this.errorMessage,
  });

  final int step;

  /// Collected wire values by [FarmVoiceStep.field] (farmSize as text).
  final Map<String, String> values;
  final FarmVoiceStatus status;

  /// Live STT partials while listening.
  final String transcript;

  /// Last accepted value, shown as a ✓ chip before auto-advance.
  final String? heardValue;

  /// True after an unparseable answer: show the "didn't catch that" hint.
  final bool retryHint;

  /// Non-blocking banner (mic denied / STT missing): chips and typing
  /// keep working, so this never bricks the flow.
  final String? errorMessage;

  bool get isReview => step >= kFarmVoiceSteps.length;

  FarmVoiceStep get currentStep =>
      kFarmVoiceSteps[step.clamp(0, kFarmVoiceSteps.length - 1)];

  FarmVoiceState copyWith({
    int? step,
    Map<String, String>? values,
    FarmVoiceStatus? status,
    String? transcript,
    String? heardValue,
    bool? retryHint,
    String? errorMessage,
  }) =>
      FarmVoiceState(
        step: step ?? this.step,
        values: values ?? this.values,
        status: status ?? this.status,
        transcript: transcript ?? this.transcript,
        heardValue: heardValue ?? this.heardValue,
        retryHint: retryHint ?? this.retryHint,
        errorMessage: errorMessage ?? this.errorMessage,
      );
}

/// Guided voice onboarding: speaks each question, captures the spoken answer
/// and parses it on-device into farm profile values.
///
/// Deliberately independent from the main [voiceProvider]: onboarding runs
/// before settings are synced, so locales come from the onboarding language,
/// and transcripts are parsed locally instead of submitted to `/chat`.
/// TTS never auto-triggers the mic (that would record its own echo) — the
/// user taps the mic to answer, which stops any playback first (barge-in).
class FarmVoiceNotifier extends StateNotifier<FarmVoiceState> {
  FarmVoiceNotifier(this._ref) : super(const FarmVoiceState());

  final Ref _ref;
  final _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  Timer? _silenceTimer;
  Timer? _advanceTimer;

  /// Bumped on every step change and shutdown so late STT callbacks and
  /// timers from a previous step can never fire into the new one.
  int _stepToken = 0;

  /// Localized utterances injected by the screen (which owns BuildContext).
  List<String> _questions = const [];
  String _retryPrompt = '';
  String _reviewPrompt = '';
  String _micNeeded = '';
  String _sttUnavailable = '';

  void configure({
    required List<String> questions,
    required String retryPrompt,
    required String reviewPrompt,
    required String micNeeded,
    required String sttUnavailable,
  }) {
    _questions = questions;
    _retryPrompt = retryPrompt;
    _reviewPrompt = reviewPrompt;
    _micNeeded = micNeeded;
    _sttUnavailable = sttUnavailable;
  }

  String _language() =>
      _ref.read(onboardingProvider).selectedLanguage.toLowerCase();

  String _ttsLocale() => kOnboardingTtsLocales[_language()] ?? 'en-US';

  /// Mirrors the main voice surface's mapping (see voice_provider.dart).
  String _sttLocale() {
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
    return map[_language()] ?? 'en_US';
  }

  // -------------------------------------------------------------------------
  // Flow control (all void: screens call these from button handlers)
  // -------------------------------------------------------------------------

  /// Asks the current question aloud.
  void start() => _greetStep();

  void repeatQuestion() {
    // Stop any active listen first so TTS never plays into a hot mic.
    _stopListeningEngine();
    if (state.status == FarmVoiceStatus.listening) {
      state = state.copyWith(status: FarmVoiceStatus.idle, transcript: '');
    }
    if (state.isReview) {
      _speak(_reviewPrompt);
    } else {
      _speak(_questionFor(state.step));
    }
  }

  /// Mic toggle: starts listening, or finishes early and parses what was
  /// heard so far. Always stops playback first (barge-in).
  void toggleMic() {
    if (state.isReview) return;
    if (state.status == FarmVoiceStatus.listening) {
      _finishListening();
    } else {
      _startListening();
    }
  }

  /// Accepts a tapped chip value directly (no parsing needed).
  void answerWithOption(String value) {
    if (state.isReview) return;
    _accept(state.currentStep.field, value);
  }

  /// Keeps the current/seeded value for this step and moves on.
  void skipStep() {
    if (state.isReview) return;
    _goto(state.step + 1);
  }

  void prevStep() {
    if (state.step <= 0 || state.isReview) return;
    _goto(state.step - 1);
  }

  void jumpToStep(int step) {
    if (step < 0 || step >= kFarmVoiceSteps.length) return;
    _goto(step);
  }

  void startOver() {
    _stopListeningEngine();
    state = const FarmVoiceState();
    _greetStep();
  }

  /// Seeds answers from a form handoff and lands on the review screen, so a
  /// user switching from typing hears "is this correct?" and only re-answers
  /// what is wrong.
  void loadDraft(Map<dynamic, dynamic> draft) {
    final profile = FarmProfile.fromMap(draft);
    _advanceTimer?.cancel();
    _stepToken++;
    state = FarmVoiceState(
      step: kFarmVoiceSteps.length,
      values: {
        'location': profile.location,
        'crop': profile.crop,
        'growthStage': profile.growthStage,
        'farmSize': formatVoiceFarmSize(profile.farmSizeAcres),
        'irrigation': profile.irrigationType,
        'soil': profile.soilType,
      },
    );
    _speak(_reviewPrompt);
  }

  /// Collected answers merged over the stored profile (fresh installs: the
  /// defaults), ready to save.
  FarmProfile draftProfile() {
    final base = _ref.read(farmProfileProvider);
    final v = state.values;
    return FarmProfile(
      location: _nonEmpty(v['location']) ?? base.location,
      crop: _nonEmpty(v['crop']) ?? base.crop,
      growthStage: _nonEmpty(v['growthStage']) ?? base.growthStage,
      farmSizeAcres:
          double.tryParse(v['farmSize'] ?? '') ?? base.farmSizeAcres,
      irrigationType: _nonEmpty(v['irrigation']) ?? base.irrigationType,
      soilType: _nonEmpty(v['soil']) ?? base.soilType,
    );
  }

  static String? _nonEmpty(String? s) =>
      (s == null || s.trim().isEmpty) ? null : s.trim();

  /// Fills the location answer from GPS. Also sets the app's home location,
  /// so Home opens on the real city. Returns false when denied/unavailable.
  Future<bool> useGpsLocation() async {
    if (state.isReview || state.currentStep.field != 'location') return false;
    final token = _stepToken;
    final loc = await _ref.read(locationProvider.notifier).selectFromGps();
    if (loc == null) return false;
    if (token != _stepToken) {
      // The user moved on while the GPS prompt was up: keep the fix but
      // don't auto-advance some other step.
      state = state
          .copyWith(values: {...state.values, 'location': loc.name.trim()});
      return true;
    }
    _accept('location', loc.name.trim());
    return true;
  }

  /// Stops all audio and timers. Call before leaving the flow; also runs on
  /// dispose via autoDispose.
  void shutdown() {
    _stepToken++;
    _stopListeningEngine();
    _advanceTimer?.cancel();
    try {
      _tts.stop();
    } catch (_) {}
    if (state.status != FarmVoiceStatus.idle) {
      state = state.copyWith(status: FarmVoiceStatus.idle, transcript: '');
    }
  }

  @override
  void dispose() {
    shutdown();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Internals
  // -------------------------------------------------------------------------

  String _questionFor(int step) =>
      step < _questions.length ? _questions[step] : '';

  void _greetStep() {
    _advanceTimer?.cancel();
    _stepToken++;
    _speak(state.isReview ? _reviewPrompt : _questionFor(state.step));
  }

  void _stopListeningEngine() {
    _silenceTimer?.cancel();
    try {
      _speech.stop();
    } catch (_) {}
  }

  void _goto(int step) {
    _stopListeningEngine();
    state = FarmVoiceState(step: step, values: state.values);
    _greetStep();
  }

  void _accept(String field, String value) {
    final token = ++_stepToken;
    _advanceTimer?.cancel();
    _stopListeningEngine();
    // Fresh state: the ✓ is set while any error banner clears.
    state = FarmVoiceState(
      step: state.step,
      values: {...state.values, field: value},
      heardValue: value,
    );
    // Brief beat so the ✓ lands before the next question is asked. Redoing
    // (back) or leaving cancels it via the token.
    _advanceTimer = Timer(const Duration(milliseconds: 1100), () {
      if (token != _stepToken) return;
      _goto(state.step + 1);
    });
  }

  Future<void> _speak(String text) async {
    final clean = MarkdownUtils.forSpeech(text);
    if (clean.isEmpty) return;
    if (!state.isReview) {
      state = state.copyWith(status: FarmVoiceStatus.speaking);
    }
    try {
      await _tts.stop();
      await _tts.setLanguage(_ttsLocale());
      // Same mapping as the main voice surface: UI stores ~0.85, Android
      // wants ~0.47 for natural pacing.
      await _tts.setSpeechRate((0.85 * 0.55).clamp(0.25, 0.75));
      await _tts.speak(clean);
    } catch (_) {}
    if (state.status == FarmVoiceStatus.speaking) {
      state = state.copyWith(status: FarmVoiceStatus.idle);
    }
  }

  Future<void> _startListening() async {
    _stepToken++;
    final token = _stepToken;
    try {
      await _tts.stop();
    } catch (_) {}
    try {
      final mic = await Permission.microphone.request();
      if (token != _stepToken) return;
      if (!mic.isGranted) {
        state = state.copyWith(errorMessage: _micNeeded);
        return;
      }
      final available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' && state.status == FarmVoiceStatus.listening) {
            _finishListening();
          }
        },
        onError: (_) {
          if (state.status == FarmVoiceStatus.listening) _finishListening();
        },
      );
      if (token != _stepToken) return;
      if (!available) {
        state = state.copyWith(errorMessage: _sttUnavailable);
        return;
      }
      // Fresh state (not copyWith: the stale ✓ must clear, not carry over).
      state = FarmVoiceState(
        step: state.step,
        values: state.values,
        status: FarmVoiceStatus.listening,
      );
      await _speech.listen(
        onResult: (result) {
          if (state.status != FarmVoiceStatus.listening) return;
          state = state.copyWith(transcript: result.recognizedWords);
          _restartSilenceTimer();
          if (result.finalResult) _finishListening();
        },
        listenOptions: stt.SpeechListenOptions(
          localeId: _sttLocale(),
          partialResults: true,
          listenMode: stt.ListenMode.confirmation,
          cancelOnError: true,
        ),
      );
      _restartSilenceTimer();
    } catch (_) {
      if (token != _stepToken) return;
      state = state.copyWith(errorMessage: _sttUnavailable);
    }
  }

  void _restartSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(const Duration(milliseconds: 2500), _finishListening);
  }

  Future<void> _finishListening() async {
    if (state.status != FarmVoiceStatus.listening) return;
    _silenceTimer?.cancel();
    final token = _stepToken;
    final heard = state.transcript;
    state = state.copyWith(status: FarmVoiceStatus.idle);
    try {
      await _speech.stop();
    } catch (_) {}
    if (token != _stepToken) return;
    _resolveTranscript(heard);
  }

  void _resolveTranscript(String heard) {
    final text = heard.trim();
    // Pure silence: stay idle without nagging.
    if (text.isEmpty || state.isReview) return;
    String? accepted;
    switch (state.currentStep.field) {
      case 'location':
        accepted = text.length > 80 ? text.substring(0, 80).trim() : text;
      case 'crop':
        accepted = parseVoiceCrop(text);
      case 'growthStage':
        accepted = parseVoiceGrowthStage(text);
      case 'farmSize':
        final acres = parseVoiceFarmSize(text);
        accepted = acres == null ? null : formatVoiceFarmSize(acres);
      case 'irrigation':
        accepted = parseVoiceIrrigation(text);
      case 'soil':
        accepted = parseVoiceSoil(text);
    }
    if (accepted == null || accepted.isEmpty) {
      state = state.copyWith(transcript: '', retryHint: true);
      _speak(_retryPrompt);
    } else {
      _accept(state.currentStep.field, accepted);
    }
  }
}

/// Voice onboarding conversation. Auto-disposed when the flow is left so no
/// audio or timers survive navigation; Talk↔Type handoffs travel via route
/// extras, not this provider.
final farmVoiceOnboardingProvider =
    StateNotifierProvider.autoDispose<FarmVoiceNotifier, FarmVoiceState>(
  (ref) => FarmVoiceNotifier(ref),
);
