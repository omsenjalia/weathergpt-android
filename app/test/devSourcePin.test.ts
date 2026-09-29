import { expect, it } from "vitest";

import { saveJson, StorageKeys } from "../src/lib/persistence";
import { DevSourcePin, useDeveloperOptionsStore } from "../src/features/settings/developerOptionsStore";

it("a saved AccuWeather pin (removed from backend v3, which answers 422) hydrates as auto", async () => {
  await saveJson(StorageKeys.developerOptions, { enabled: true, sourcePin: "accuweather", forecastDays: 5 });
  await useDeveloperOptionsStore.getState().hydrate();
  const state = useDeveloperOptionsStore.getState();
  expect(state.sourcePin).toBe(DevSourcePin.Auto);
  expect(state.forecastDays).toBe(5);
  expect(state.enabled).toBe(true);
});
