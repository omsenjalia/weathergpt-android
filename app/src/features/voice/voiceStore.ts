/// Voice store — port of `lib/features/voice/providers/voice_provider.dart`.
///
/// Speech runs on Bhashini (via the backend) when the backend reports it
/// configured: TTS audio from /v2/speech/tts, and a recorded WAV of each
/// question re-transcribed by /v2/speech/asr. The device engines
/// (expo-speech, native/web recognition) are the fallback, and the live
/// interim transcript always comes from the device recognizer.

import { create } from "zustand";
import * as Speech from "expo-speech";
import { ExpoSpeechRecognitionModule } from "expo-speech-recognition";

import { ApiEndpoints } from "../../core/config/apiEndpoints";
import { apiErrorMessage, isAppApiError } from "../../core/errors/appErrors";
import { buildAgentRequestContext, agentContextPayload, FarmContext } from "../../core/models/requestContext";
import { MarkdownUtils } from "../../core/utils/markdownUtils";
import { ApiClient } from "../../core/services/apiClient";
import { AppLocation, DEFAULT_LOCATION } from "../location/locationStore";
import { DEFAULT_FARM_PROFILE, FarmProfile } from "../farm/models/farmProfile";
import { mapBackendAnswer, VoiceResponse } from "./mappers/voiceResponseMapper";
import { SpeechService, speakWithBhashini, stopPlayback, TtsGender } from "./speechService";

export enum VoiceStatus {
  Idle = "idle",
  Listening = "listening",
  Processing = "processing",
  Speaking = "speaking",
  Done = "done",
  Error = "error",
}

export interface VoiceState {
  status: VoiceStatus;
  transcript: string;
  response: VoiceResponse | null;
  errorMessage: string | null;
}

export interface VoiceContext {
  language: string;
  userPersona: string;
  ttsVoiceLocale: string;
  ttsSpeed: number;
  /// Bhashini voice. Ignored by the on-device fallback.
  ttsGender?: TtsGender;
  location: AppLocation;
  profile: FarmProfile;
  profileCompleted?: boolean;
}

export const DEFAULT_VOICE_CONTEXT: VoiceContext = {
  language: "en",
  userPersona: "everyone",
  ttsVoiceLocale: "en-US",
  ttsSpeed: 0.85,
  location: DEFAULT_LOCATION,
  profile: DEFAULT_FARM_PROFILE,
};

export function speechRecognitionAvailable(): boolean {
  try { return ExpoSpeechRecognitionModule.isRecognitionAvailable(); } catch { return false; }
}

let recognitionSubscriptions: Array<{ remove: () => void }> = [];
/// WAV of the current utterance when the recognizer can persist audio.
let recordedAudioUri: string | null = null;
/// Set while dictating: receives the final transcript instead of /chat.
let dictationHandler: ((text: string) => void) | null = null;

function supportsRecording(): boolean {
  try { return ExpoSpeechRecognitionModule.supportsRecording(); } catch { return false; }
}

function cleanupRecognition() {
  recognitionSubscriptions.forEach((subscription) => subscription.remove());
  recognitionSubscriptions = [];
}

const STT_LOCALES: Record<string, string> = {
  en: "en_US", hi: "hi_IN", gu: "gu_IN", mr: "mr_IN", ta: "ta_IN",
  te: "te_IN", kn: "kn_IN", ml: "ml_IN", bn: "bn_IN", pa: "pa_IN",
};

interface VoiceStore extends VoiceState {
  generation: number;
  context: VoiceContext;
  silenceTimer: ReturnType<typeof setTimeout> | null;
  setContext: (context: VoiceContext) => void;
  /// Listens and asks WeatherGPT (full voice-assistant turn).
  startListening: () => Promise<void>;
  /// Listens and hands the transcript to `onText` instead of asking
  /// (chat dictation, farm voice onboarding). Status returns to Idle.
  startDictation: (onText: (text: string) => void) => Promise<void>;
  stopListening: () => Promise<void>;
  submitQuery: (text: string) => Promise<void>;
  speak: (text: string) => Promise<void>;
  stopSpeaking: () => void;
  cancel: () => void;
}

function sttLocale(language: string): string {
  return STT_LOCALES[language.toLowerCase()] ?? "en_US";
}

export const useVoiceStore = create<VoiceStore>((set, get) => ({
  status: VoiceStatus.Idle,
  transcript: "",
  response: null,
  errorMessage: null,
  generation: 0,
  context: DEFAULT_VOICE_CONTEXT,
  silenceTimer: null,

  setContext: (context) => {
    if (JSON.stringify(context) !== JSON.stringify(get().context)) {
      get().cancel();
      set({ context });
    }
  },

  startDictation: async (onText) => {
    await get().startListening();
    dictationHandler = onText;
  },

  startListening: async () => {
    get().cancel();
    const generation = get().generation;
    set({ status: VoiceStatus.Processing });
    try {
      if (!speechRecognitionAvailable()) throw new Error("unavailable");
      const permission = await ExpoSpeechRecognitionModule.requestPermissionsAsync();
      if (generation !== get().generation) return;
      if (!permission.granted) throw new Error("permission denied");
      recognitionSubscriptions = [
        ExpoSpeechRecognitionModule.addListener("result", (event) => {
          if (generation !== get().generation) return;
          set({ transcript: event.results[0]?.transcript ?? "" });
        }),
        ExpoSpeechRecognitionModule.addListener("error", (event) => {
          if (generation !== get().generation) return;
          cleanupRecognition();
          set({ status: VoiceStatus.Error, errorMessage: event.message || "Could not recognize speech. Please type your question." });
        }),
        ExpoSpeechRecognitionModule.addListener("audioend", (event) => {
          if (generation === get().generation && event?.uri) recordedAudioUri = event.uri;
        }),
        ExpoSpeechRecognitionModule.addListener("end", () => {
          cleanupRecognition();
          if (generation !== get().generation || get().status !== VoiceStatus.Listening) return;
          void finishUtterance(generation);
        }),
      ];
      recordedAudioUri = null;
      const record = SpeechService.available() && supportsRecording();
      set({ status: VoiceStatus.Listening });
      ExpoSpeechRecognitionModule.start({
        lang: sttLocale(get().context.language).replace("_", "-"),
        interimResults: true,
        continuous: false,
        // 16 kHz 16-bit PCM WAV is what Bhashini ASR expects (Android default;
        // iOS needs it spelled out).
        ...(record ? { recordingOptions: { persist: true, outputSampleRate: 16000, outputEncoding: "pcmFormatInt16" } } : {}),
      });
    } catch {
      if (generation !== get().generation) return;
      cleanupRecognition();
      set({ status: VoiceStatus.Error, errorMessage: "Speech recognition unavailable or permission denied. You can still type a question." });
    }
  },

  stopListening: async () => {
    if (get().status !== VoiceStatus.Listening) return;
    // Submit on the end event so the native final result is not discarded.
    ExpoSpeechRecognitionModule.stop();
  },

  submitQuery: async (text) => {
    if (get().silenceTimer !== null) clearTimeout(get().silenceTimer!);
    cleanupRecognition();
    ExpoSpeechRecognitionModule.abort();
    void Speech.stop();
    set({ status: VoiceStatus.Processing, transcript: text, response: null, errorMessage: null });
    const generation = get().generation + 1;
    set({ generation });
    try {
      const context = get().context;
      const transcript = get().transcript.trim();
      if (transcript === "") {
        set({ status: VoiceStatus.Error, errorMessage: "No speech detected. Try again or pick a suggestion." });
        return;
      }

      // Validated mode plus the user's real farm profile, built by the same
      // helper the chat surface uses so both send identical context.
      const requestContext = buildAgentRequestContext({
        profilePersona: context.userPersona,
        farm: context.profileCompleted === false ? undefined : {
          crop: context.profile.crop,
          growthStage: context.profile.growthStage,
          soilType: context.profile.soilType,
          irrigationType: context.profile.irrigationType,
        } satisfies FarmContext,
      });

      // Always use /chat — /voice multipart is optional and often unavailable.
      const postChat = (msg: string) =>
        ApiClient.post(ApiEndpoints.chat, {
          message: msg,
          location: context.location.name,
          lat: context.location.lat,
          lon: context.location.lon,
          language: context.language,
          ...agentContextPayload(requestContext),
        });

      const result = await postChat(transcript);
      const responseText = typeof result["response"] === "string" ? result["response"] : "";
      // Never silently replace the user's question with a different weather ask.
      // A newer question superseded this one: never render the stale answer.
      if (generation !== get().generation) return;
      set({
        status: VoiceStatus.Done,
        response: mapBackendAnswer(transcript, responseText, result),
      });
    } catch (error) {
      if (generation !== get().generation) return;
      set({
        status: VoiceStatus.Error,
        errorMessage: isAppApiError(error) ? apiErrorMessage(error) : "WeatherGPT took too long to answer. Please try again.",
      });
    }
  },

  speak: async (text) => {
    const generation = get().generation;
    await Speech.stop();
    if (generation !== get().generation) return;
    const clean = MarkdownUtils.forSpeech(text);
    if (!clean) { set({ status: VoiceStatus.Done }); return; }
    set({ status: VoiceStatus.Speaking });
    const done = () => {
      if (generation === get().generation) set({ status: VoiceStatus.Done });
    };
    const context = get().context;
    if (SpeechService.available()) {
      try {
        await speakWithBhashini(clean, {
          language: context.language,
          gender: context.ttsGender ?? "female",
          rate: context.ttsSpeed,
          isCurrent: () => generation === get().generation,
          onDone: done,
        });
        return;
      } catch {
        // Bhashini failed: fall through to the device voice for this and the
        // next few minutes.
        SpeechService.markFailed();
        if (generation !== get().generation) return;
      }
    }
    try {
      Speech.speak(clean, {
        language: get().context.ttsVoiceLocale,
        rate: get().context.ttsSpeed,
        onDone: done,
        onStopped: done,
        onError: done,
      });
    } catch { done(); }
  },

  stopSpeaking: () => {
    stopPlayback();
    void Speech.stop();
    set({ status: VoiceStatus.Done });
  },

  cancel: () => {
    cleanupRecognition();
    if (get().silenceTimer !== null) clearTimeout(get().silenceTimer!);
    set((s) => ({ generation: s.generation + 1, status: VoiceStatus.Idle, transcript: "", response: null, errorMessage: null, silenceTimer: null }));
    try { ExpoSpeechRecognitionModule.abort(); } catch { /* no recognition service */ }
    recordedAudioUri = null;
    dictationHandler = null;
    stopPlayback();
    void Speech.stop();
  },
}));

/// End of an utterance: prefer Bhashini's transcript of the recorded WAV,
/// fall back to the device recognizer's.
async function finishUtterance(generation: number): Promise<void> {
  const store = useVoiceStore;
  const uri = recordedAudioUri;
  recordedAudioUri = null;
  let transcript = store.getState().transcript;
  if (uri !== null && SpeechService.available()) {
    store.setState({ status: VoiceStatus.Processing });
    try {
      const heard = await SpeechService.transcribe(uri, store.getState().context.language);
      if (heard !== "") transcript = heard;
    } catch {
      SpeechService.markFailed();
    }
    if (generation !== store.getState().generation) return;
  }
  const handler = dictationHandler;
  if (handler !== null) {
    dictationHandler = null;
    store.setState({ status: VoiceStatus.Idle, transcript: "" });
    const text = transcript.trim();
    if (text !== "") handler(text);
    else store.setState({ status: VoiceStatus.Error, errorMessage: "No speech detected. Try again or type instead." });
    return;
  }
  await store.getState().submitQuery(transcript);
}
