import { vi } from "vitest";

export const players: Array<{ source: unknown; listeners: Map<string, (s: any) => void> }> = [];

export const setAudioModeAsync = vi.fn(async () => {});
export const createAudioPlayer = vi.fn((source: unknown) => {
  const listeners = new Map<string, (s: any) => void>();
  players.push({ source, listeners });
  return {
    play: vi.fn(),
    pause: vi.fn(),
    remove: vi.fn(),
    setPlaybackRate: vi.fn(),
    addListener: vi.fn((name: string, cb: (s: any) => void) => {
      listeners.set(name, cb);
      return { remove: () => listeners.delete(name) };
    }),
  };
});
