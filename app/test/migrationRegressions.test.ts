import { beforeEach, afterEach, describe, expect, it, vi } from "vitest";
import * as Location from "expo-location";
import * as Speech from "expo-speech";
import { listeners } from "./stubs/recognition";
import { ApiClient } from "../src/core/services/apiClient";
import { useChatStore, DEFAULT_CHAT_CONTEXT } from "../src/features/chat/chatStore";
import { useVoiceStore, VoiceStatus, DEFAULT_VOICE_CONTEXT } from "../src/features/voice/voiceStore";
import { useWeatherStore } from "../src/features/weather/weatherStore";
import { useLocationStore, AppLocation, DEFAULT_LOCATION } from "../src/features/location/locationStore";
import { DEFAULT_DEVELOPER_OPTIONS } from "../src/features/settings/developerOptionsStore";
import { stateForTab, AdvisoryStatus, useActionWindowsStore } from "../src/features/farm/farmStores";
import { ActionWindowTab } from "../src/features/farm/models/advisoryModels";
import { DEFAULT_FARM_PROFILE } from "../src/features/farm/models/farmProfile";
import { GeocodingService } from "../src/core/services/geocodingService";
import { MapLayer, MapProduct, windyEmbedUrl } from "../src/features/explore/exploreStores";

function deferred<T>() {
  let resolve!: (value: T) => void;
  let reject!: (error: Error) => void;
  const promise = new Promise<T>((yes, no) => { resolve = yes; reject = no; });
  return { promise, resolve, reject };
}

beforeEach(() => {
  useChatStore.getState().clear();
  useChatStore.getState().setContext(DEFAULT_CHAT_CONTEXT);
  useVoiceStore.getState().cancel();
  useVoiceStore.getState().setContext(DEFAULT_VOICE_CONTEXT);
  useWeatherStore.getState().clear();
  useLocationStore.setState({ hydrated: true, hasSelection: false, locationPrompted: false, location: DEFAULT_LOCATION });
});
afterEach(() => { vi.restoreAllMocks(); vi.useRealTimers(); });

describe("async generation guards", () => {
  it("drops chat replies after the location changes and sends the new coordinates", async () => {
    const response = deferred<Record<string, unknown>>();
    const post = vi.spyOn(ApiClient, "post").mockReturnValueOnce(response.promise).mockResolvedValue({ response: "new reply" });
    const first = useChatStore.getState().send("weather?");
    useChatStore.getState().setContext({ ...DEFAULT_CHAT_CONTEXT, location: new AppLocation("Delhi", 28, 77) });
    response.resolve({ response: "old reply" });
    await first;
    expect(useChatStore.getState().messages).toEqual([]);
    expect(useChatStore.getState().sending).toBe(false);
    await useChatStore.getState().send("weather here?");
    expect(post.mock.calls[1]?.[1]).toMatchObject({ lat: 28, lon: 77 });
  });
  it("retries failed chat without duplicating the user message", async () => {
    vi.spyOn(ApiClient, "post").mockRejectedValueOnce(new Error()).mockResolvedValueOnce({ response: "OK" });
    await useChatStore.getState().send("hello");
    await useChatStore.getState().retryLast();
    expect(useChatStore.getState().messages.map(m => m.role)).toEqual(["user", "assistant"]);
  });
  it("cancelled voice requests cannot restore a response", async () => {
    const response = deferred<Record<string, unknown>>();
    vi.spyOn(ApiClient, "post").mockReturnValue(response.promise);
    const pending = useVoiceStore.getState().submitQuery("rain?");
    useVoiceStore.getState().cancel();
    response.resolve({ response: "rain" });
    await pending;
    expect(useVoiceStore.getState().status).toBe(VoiceStatus.Idle);
    expect(useVoiceStore.getState().response).toBeNull();
  });
  it("clearing weather suppresses even a late fallback request", async () => {
    const response = deferred<Record<string, unknown>>();
    const get = vi.spyOn(ApiClient, "get").mockReturnValue(response.promise);
    const pending = useWeatherStore.getState().fetchWeather(DEFAULT_LOCATION, "everyone", DEFAULT_DEVELOPER_OPTIONS);
    useWeatherStore.getState().clear();
    response.reject(new Error("network"));
    await pending;
    expect(get).toHaveBeenCalledTimes(1);
    expect(useWeatherStore.getState().snapshot).toBeNull();
  });
  it("honours explicit unavailable without guessing from error wording", async () => {
    const get = vi.spyOn(ApiClient, "get").mockResolvedValue({ status: "unavailable", error: "No data" });
    await useWeatherStore.getState().fetchWeather(DEFAULT_LOCATION, "everyone", DEFAULT_DEVELOPER_OPTIONS);
    expect(get).toHaveBeenCalledTimes(1);
    expect(useWeatherStore.getState().error).toBe("No data");
    expect(useWeatherStore.getState().lastRequest?.usedLegacyFallback).toBe(false);
  });
});

describe("native location and voice", () => {
  it("does not prompt over an explicit saved location", async () => {
    const gps = vi.spyOn(Location, "requestForegroundPermissionsAsync");
    gps.mockClear();
    useLocationStore.setState({ hasSelection: true });
    await useLocationStore.getState().maybeAutoLocate();
    expect(gps).not.toHaveBeenCalled();
  });
  it("does not replace manual selection with an older GPS result", async () => {
    const name = deferred<string>();
    vi.spyOn(GeocodingService, "reverseName").mockReturnValue(name.promise);
    const pending = useLocationStore.getState().selectFromGps();
    await vi.waitFor(() => expect(GeocodingService.reverseName).toHaveBeenCalled());
    const manual = new AppLocation("Mumbai", 19, 72);
    await useLocationStore.getState().select(manual);
    name.resolve("GPS place");
    expect(await pending).toBeNull();
    expect(useLocationStore.getState().location).toEqual(manual);
  });
  it("submits recognition's final transcript only on end", async () => {
    const post = vi.spyOn(ApiClient, "post").mockResolvedValue({ response: "OK" });
    await useVoiceStore.getState().startListening();
    listeners.get("result")?.({ results: [{ transcript: "rain tomorrow" }], isFinal: true });
    await useVoiceStore.getState().stopListening();
    expect(post).not.toHaveBeenCalled();
    listeners.get("end")?.(null);
    await vi.waitFor(() => expect(post).toHaveBeenCalled());
    expect(post.mock.calls[0]?.[1]).toMatchObject({ message: "rain tomorrow" });
  });
  it("keeps Speaking status until the TTS completion callback", async () => {
    await useVoiceStore.getState().speak("Hello");
    expect(useVoiceStore.getState().status).toBe(VoiceStatus.Speaking);
    const args = vi.mocked(Speech.speak).mock.calls.slice(-1)[0];
    args?.[1]?.onDone?.();
    expect(useVoiceStore.getState().status).toBe(VoiceStatus.Done);
  });
});

describe("honest advisory and maps", () => {
  it("does not label today's windows as tomorrow's", () => {
    const result = stateForTab(ActionWindowTab.Tomorrow, { windows: [{ best_window: "Today only" }] }, "Delhi", new Date());
    expect(result.status).toBe(AdvisoryStatus.Unavailable);
    expect(result.fieldWorkStatus).toBe("");
  });
  it("empty advisory is unavailable for the week", () => {
    expect(stateForTab(ActionWindowTab.SevenDay, {}, "Delhi", new Date()).status).toBe(AdvisoryStatus.Unavailable);
  });
  it("changing mode invalidates the advisory cache", () => {
    const store = useActionWindowsStore.getState();
    store.setContext({ location: DEFAULT_LOCATION, profile: DEFAULT_FARM_PROFILE, mode: "farmer" });
    const generation = useActionWindowsStore.getState().generation;
    store.setContext({ location: DEFAULT_LOCATION, profile: DEFAULT_FARM_PROFILE, mode: "everyone" });
    expect(useActionWindowsStore.getState().generation).toBeGreaterThan(generation);
  });
  it("uses the selected Windy model", () => {
    const url = windyEmbedUrl({ activeLayer: MapLayer.Rain, product: MapProduct.Gfs, lat: 23, lon: 72, zoom: 6 });
    expect(new URL(url).searchParams.get("product")).toBe("gfs");
  });
});

import { formatTemperature } from "../src/core/utils/temperature";
import { useSettingsStore, selectMode } from "../src/features/settings/settingsStore";
it("honours temperature units without converting missing readings to zero", () => {
  expect(formatTemperature(0, "fahrenheit")).toBe("32°F");
  expect(formatTemperature(30, "celsius")).toBe("30°C");
  expect(formatTemperature(null, "fahrenheit")).toBe("—");
});
it("keeps persona fields current after Zustand merges", async () => {
  await useSettingsStore.getState().updatePersona("farmer");
  expect(useSettingsStore.getState().mode).toBe("farmer");
  expect(selectMode(useSettingsStore.getState())).toBe("farmer");
  await useSettingsStore.getState().updatePersona("everyone");
  expect(useSettingsStore.getState().mode).toBe("everyone");
});
it("changing language also selects the matching speech locale", async () => {
  await useSettingsStore.getState().updateLanguage("hi");
  expect(useSettingsStore.getState().ttsVoiceLocale).toBe("hi-IN");
});

import { useFarmProfileStore } from "../src/features/farm/farmStores";
import { buildChatPayload } from "../src/features/chat/chatStore";
it("farm saves resolve actual coordinates before marking the profile complete", async () => {
  const place = new AppLocation("Delhi, India", 28.6, 77.2);
  vi.spyOn(GeocodingService, "search").mockResolvedValue(place);
  await useFarmProfileStore.getState().save({ ...DEFAULT_FARM_PROFILE, location: "Delhi" });
  expect(useLocationStore.getState().location).toEqual(place);
  expect(useFarmProfileStore.getState().profile.location).toBe(place.name);
});
it("a failed farm geocode does not save a misleading new location", async () => {
  vi.spyOn(GeocodingService, "search").mockResolvedValue(null);
  const before = useFarmProfileStore.getState().profile;
  await expect(useFarmProfileStore.getState().save({ ...before, location: "Missing town" })).rejects.toThrow("Could not find");
  expect(useFarmProfileStore.getState().profile).toBe(before);
});
it("does not submit assumed farm details when onboarding was skipped", () => {
  const payload = buildChatPayload({ ...DEFAULT_CHAT_CONTEXT, userPersona: "farmer", profileCompleted: false }, [], "rain?");
  expect(payload.crop).toBe("");
  expect(payload.growth_stage).toBeUndefined();
  expect(payload.soil).toBeUndefined();
});
