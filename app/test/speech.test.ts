import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import * as Speech from "expo-speech";

import { listeners } from "./stubs/recognition";
import { players } from "./stubs/audio";
import { ApiClient } from "../src/core/services/apiClient";
import { ApiEndpoints } from "../src/core/config/apiEndpoints";
import { SpeechService } from "../src/features/voice/speechService";
import { useVoiceStore, VoiceStatus, DEFAULT_VOICE_CONTEXT } from "../src/features/voice/voiceStore";

beforeEach(() => {
  useVoiceStore.getState().cancel();
  useVoiceStore.getState().setContext({ ...DEFAULT_VOICE_CONTEXT, language: "hi", ttsGender: "male" });
  SpeechService.reset({ configured: true });
  players.length = 0;
  vi.mocked(Speech.speak).mockClear();
});
afterEach(() => {
  vi.restoreAllMocks();
  SpeechService.reset({ configured: false });
});

describe("Bhashini speech", () => {
  it("probes the backend and only trusts an explicit configured flag", async () => {
    vi.spyOn(ApiClient, "get").mockResolvedValueOnce({ configured: true }).mockResolvedValueOnce({ configured: "yes" });
    expect(await SpeechService.probe()).toBe(true);
    expect(await SpeechService.probe()).toBe(false);
    vi.spyOn(ApiClient, "get").mockRejectedValueOnce(new Error("offline"));
    expect(await SpeechService.probe()).toBe(false);
  });

  it("speaks with Bhashini audio and stays Speaking until playback finishes", async () => {
    const post = vi.spyOn(ApiClient, "post").mockResolvedValue({ audio_base64: "UklGRgAAAA==" });
    await useVoiceStore.getState().speak("**Rain** likely tomorrow");
    expect(post).toHaveBeenCalledWith(ApiEndpoints.speechTts, { text: "Rain likely tomorrow", language: "hi", gender: "male" });
    expect(Speech.speak).not.toHaveBeenCalled();
    expect(useVoiceStore.getState().status).toBe(VoiceStatus.Speaking);
    players[0]!.listeners.get("playbackStatusUpdate")?.({ didJustFinish: true });
    expect(useVoiceStore.getState().status).toBe(VoiceStatus.Done);
  });

  it("falls back to the device voice and backs off after a Bhashini failure", async () => {
    const post = vi.spyOn(ApiClient, "post").mockRejectedValue(new Error("503"));
    await useVoiceStore.getState().speak("Hello there");
    expect(Speech.speak).toHaveBeenCalledTimes(1);
    expect(SpeechService.available()).toBe(false);
    await useVoiceStore.getState().speak("Second answer");
    expect(post).toHaveBeenCalledTimes(1);
    expect(Speech.speak).toHaveBeenCalledTimes(2);
  });

  it("prefers Bhashini's transcript of the recorded question", async () => {
    const post = vi.spyOn(ApiClient, "post").mockImplementation(async (path) =>
      path === ApiEndpoints.speechAsr ? { transcript: "कल बारिश होगी?" } : { response: "हाँ" },
    );
    await useVoiceStore.getState().startListening();
    listeners.get("result")?.({ results: [{ transcript: "kal barish" }] });
    listeners.get("audioend")?.({ uri: "file:///cache/q.wav" });
    listeners.get("end")?.(null);
    await vi.waitFor(() => expect(post).toHaveBeenCalledWith(ApiEndpoints.chat, expect.anything()));
    expect(post.mock.calls[0]?.[0]).toBe(ApiEndpoints.speechAsr);
    expect(post.mock.calls[0]?.[1]).toMatchObject({ language: "hi", audio_format: "wav" });
    expect(post.mock.calls[1]?.[1]).toMatchObject({ message: "कल बारिश होगी?" });
  });

  it("keeps the device transcript when Bhashini hears nothing or fails", async () => {
    const post = vi.spyOn(ApiClient, "post").mockImplementation(async (path) => {
      if (path === ApiEndpoints.speechAsr) throw new Error("502");
      return { response: "OK" };
    });
    await useVoiceStore.getState().startListening();
    listeners.get("result")?.({ results: [{ transcript: "rain tomorrow" }] });
    listeners.get("audioend")?.({ uri: "file:///cache/q.wav" });
    listeners.get("end")?.(null);
    await vi.waitFor(() => expect(post).toHaveBeenCalledWith(ApiEndpoints.chat, expect.anything()));
    expect(post.mock.calls.at(-1)?.[1]).toMatchObject({ message: "rain tomorrow" });
  });

  it("dictation hands the transcript back instead of asking WeatherGPT", async () => {
    SpeechService.reset({ configured: false });
    const post = vi.spyOn(ApiClient, "post");
    const heard: string[] = [];
    await useVoiceStore.getState().startDictation((text) => heard.push(text));
    listeners.get("result")?.({ results: [{ transcript: "  wheat  " }] });
    listeners.get("end")?.(null);
    await vi.waitFor(() => expect(heard).toEqual(["wheat"]));
    expect(post).not.toHaveBeenCalled();
    expect(useVoiceStore.getState().status).toBe(VoiceStatus.Idle);
  });
});
