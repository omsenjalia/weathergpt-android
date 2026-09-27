import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import * as Speech from "expo-speech";

import { listeners } from "./stubs/recognition";
import { ApiClient } from "../src/core/services/apiClient";
import { ApiEndpoints } from "../src/core/config/apiEndpoints";
import { useVoiceStore, VoiceStatus, DEFAULT_VOICE_CONTEXT } from "../src/features/voice/voiceStore";

beforeEach(() => {
  useVoiceStore.getState().cancel();
  useVoiceStore.getState().setContext({ ...DEFAULT_VOICE_CONTEXT, language: "hi", ttsVoiceLocale: "hi-IN" });
  vi.mocked(Speech.speak).mockClear();
});
afterEach(() => {
  vi.restoreAllMocks();
});

describe("on-device speech", () => {
  it("speaks cleaned text with the device voice and never calls the backend", async () => {
    const post = vi.spyOn(ApiClient, "post");
    const get = vi.spyOn(ApiClient, "get");
    await useVoiceStore.getState().speak("**Rain** likely tomorrow");
    expect(Speech.speak).toHaveBeenCalledTimes(1);
    expect(vi.mocked(Speech.speak).mock.calls[0]?.[0]).toBe("Rain likely tomorrow");
    expect(vi.mocked(Speech.speak).mock.calls[0]?.[1]).toMatchObject({ language: "hi-IN" });
    expect(post).not.toHaveBeenCalled();
    expect(get).not.toHaveBeenCalled();
    expect(useVoiceStore.getState().status).toBe(VoiceStatus.Speaking);
  });

  it("asks WeatherGPT with the device recognizer's transcript", async () => {
    const post = vi.spyOn(ApiClient, "post").mockResolvedValue({ response: "OK" });
    await useVoiceStore.getState().startListening();
    listeners.get("result")?.({ results: [{ transcript: "rain tomorrow" }] });
    listeners.get("end")?.(null);
    await vi.waitFor(() => expect(post).toHaveBeenCalledWith(ApiEndpoints.chat, expect.anything()));
    expect(post).toHaveBeenCalledTimes(1);
    expect(post.mock.calls[0]?.[1]).toMatchObject({ message: "rain tomorrow", language: "hi" });
  });

  it("dictation hands the transcript back instead of asking WeatherGPT", async () => {
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
