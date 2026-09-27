/// Bhashini speech client (via the backend's /v2/speech/* proxy).
///
/// - TTS: text → base64 WAV → played with expo-audio.
/// - ASR: a recorded WAV → transcript.
///
/// Bhashini is used only once a health probe confirms the backend has it
/// configured. Any failure falls back to on-device speech (expo-speech /
/// the native recognizer) and backs off from Bhashini for a few minutes, so a
/// misconfigured deployment never costs a failed request per utterance.

import { Platform } from "react-native";
import { createAudioPlayer, setAudioModeAsync, AudioPlayer } from "expo-audio";
import { File, Paths } from "expo-file-system";

import { ApiEndpoints } from "../../core/config/apiEndpoints";
import { ApiClient } from "../../core/services/apiClient";

export type TtsGender = "female" | "male";

const BACKOFF_MS = 5 * 60_000;

let configured = false;
let disabledUntil = 0;

export const SpeechService = {
  /// Probes the backend once at startup (and after a backoff expires).
  async probe(): Promise<boolean> {
    try {
      const data = await ApiClient.get(ApiEndpoints.speechHealth);
      configured = data["configured"] === true;
    } catch {
      configured = false;
    }
    return configured;
  },

  available(): boolean {
    return configured && Date.now() >= disabledUntil;
  },

  markFailed(): void {
    disabledUntil = Date.now() + BACKOFF_MS;
  },

  /// Test / developer hook.
  reset(state: { configured: boolean }): void {
    configured = state.configured;
    disabledUntil = 0;
  },

  async synthesize(text: string, language: string, gender: TtsGender): Promise<string> {
    const data = await ApiClient.post(ApiEndpoints.speechTts, { text, language, gender });
    const audio = data["audio_base64"];
    if (typeof audio !== "string" || audio === "") throw new Error("Bhashini returned no audio");
    return audio;
  },

  async transcribe(fileUri: string, language: string): Promise<string> {
    const base64 = await new File(fileUri).base64();
    const data = await ApiClient.post(ApiEndpoints.speechAsr, { audio_base64: base64, language, audio_format: "wav" });
    return typeof data["transcript"] === "string" ? data["transcript"].trim() : "";
  },
};

// ---------------------------------------------------------------------------
// Playback

let current: AudioPlayer | null = null;
let currentFile: File | null = null;
let audioModeSet = false;
const cache = new Map<string, string>();
const CACHE_LIMIT = 12;

async function sourceFor(base64: string): Promise<string> {
  if (Platform.OS === "web") return `data:audio/wav;base64,${base64}`;
  const file = new File(Paths.cache, `tts-${Date.now()}.wav`);
  file.write(base64, { encoding: "base64" });
  currentFile = file;
  return file.uri;
}

export function stopPlayback(): void {
  try {
    current?.pause();
    current?.remove();
  } catch {
    // already released
  }
  current = null;
  try {
    currentFile?.delete();
  } catch {
    // cache file already gone
  }
  currentFile = null;
}

/// Speaks `text` with Bhashini. Resolves once playback has *started*;
/// `onDone` fires when it finishes or is stopped. Throws when Bhashini or
/// playback fails so the caller can fall back to on-device TTS.
export async function speakWithBhashini(
  text: string,
  opts: { language: string; gender: TtsGender; rate: number; isCurrent: () => boolean; onDone: () => void },
): Promise<void> {
  const key = `${opts.language}|${opts.gender}|${text}`;
  let audio = cache.get(key);
  if (audio === undefined) {
    audio = await SpeechService.synthesize(text, opts.language, opts.gender);
    cache.set(key, audio);
    if (cache.size > CACHE_LIMIT) cache.delete(cache.keys().next().value!);
  }
  if (!opts.isCurrent()) return;

  if (!audioModeSet) {
    audioModeSet = true;
    await setAudioModeAsync({ playsInSilentMode: true }).catch(() => undefined);
  }
  stopPlayback();
  const player = createAudioPlayer(await sourceFor(audio));
  current = player;
  // Settings expose 0.3–1.0 for the device engine; map onto a natural range.
  player.setPlaybackRate(Math.min(1.25, Math.max(0.75, 0.55 + opts.rate * 0.55)));
  let finished = false;
  const finish = () => {
    if (finished) return;
    finished = true;
    sub.remove();
    if (current === player) stopPlayback();
    opts.onDone();
  };
  const sub = player.addListener("playbackStatusUpdate", (status) => {
    if (status.didJustFinish) finish();
  });
  player.play();
}
