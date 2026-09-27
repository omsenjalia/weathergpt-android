import { createRequire } from "node:module";
import { afterEach, expect, it, vi } from "vitest";
const require = createRequire(import.meta.url);
const { configureRelease } = require("../scripts/configure-android-release.cjs");
const configureApp = require("../app.config.js");
const config = require("../app.json").expo;

afterEach(() => vi.unstubAllEnvs());

it("preserves the Flutter package ID and applies a valid nightly version", () => {
  vi.stubEnv("ANDROID_VERSION_CODE", "30000000");
  vi.stubEnv("APP_VERSION", "1.0.0-nightly.20260926");
  const app = configureApp({ config });
  expect(app.android.package).toBe("com.weathergpt.weathergpt_mobile");
  expect(app.android.versionCode).toBe(30000000);
  expect(app.version).toBe("1.0.0-nightly.20260926");
});
it.each(["NaN", "-1", "1.5", "2100000001"])("rejects invalid Android version %s", (value) => {
  vi.stubEnv("ANDROID_VERSION_CODE", value);
  expect(() => configureApp({ config })).toThrow("version code");
});
it("changes only release signing and references secrets through environment", () => {
  const template = 'signingConfigs { debug {} } buildTypes { debug { signingConfig signingConfigs.debug } release { signingConfig signingConfigs.debug } }';
  const result = configureRelease(template);
  expect(result).toContain('debug { signingConfig signingConfigs.debug }');
  expect(result).toContain('release { signingConfig signingConfigs.release }');
  expect(result).toContain('System.getenv("KEYSTORE_PASSWORD")');
});
it("fails closed when Expo's signing template changes", () => {
  expect(() => configureRelease('android {}')).toThrow("refusing to publish");
});
