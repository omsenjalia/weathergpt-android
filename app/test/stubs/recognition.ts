import { vi } from "vitest";
export const listeners = new Map<string, (event: any) => void>();
export const ExpoSpeechRecognitionModule = {
  isRecognitionAvailable: vi.fn(() => true),
  requestPermissionsAsync: vi.fn(async () => ({ granted: true })),
  start: vi.fn(), stop: vi.fn(), abort: vi.fn(),
  addListener: vi.fn((name: string, handler: (event: any) => void) => {
    listeners.set(name, handler);
    return { remove: () => listeners.delete(name) };
  }),
};
