import path from "node:path";
import { defineConfig } from "vitest/config";

// React Native / Expo ship Flow syntax and native globals that node-side test
// runners cannot parse or define. The unit tests exercise pure TypeScript
// modules only, so the RN runtime and AsyncStorage are aliased to lightweight
// stubs. Run `bun run test` (Vitest), not Bun's built-in test runner.
const rnStub = path.resolve(__dirname, "test/stubs/reactNative.ts");
const asyncStorageStub = path.resolve(__dirname, "test/stubs/asyncStorage.ts");

export default defineConfig({
  resolve: {
    alias: {
      "react-native": rnStub,
      "@react-native-async-storage/async-storage": asyncStorageStub,
      "expo-modules-core": rnStub,
      "expo-constants": rnStub,
      "expo-speech": path.resolve(__dirname, "test/stubs/speech.ts"),
      "expo-location": path.resolve(__dirname, "test/stubs/location.ts"),
      "expo-speech-recognition": path.resolve(__dirname, "test/stubs/recognition.ts"),
    },
  },
  define: {
    __DEV__: "false",
  },
  test: {
    include: ["test/**/*.test.ts"],
    environment: "node",
  },
});
