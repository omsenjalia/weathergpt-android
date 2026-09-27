/// One backend round-trip as seen by the app — port of
/// `lib/core/services/request_log.dart`. Enough to debug "why does the home
/// screen show —" without reading device logs. Ring buffer of the most recent
/// backend requests, backed by a zustand store.

import { create } from "zustand";

export interface RequestLogEntry {
  id: number;
  startedAt: Date;
  method: string;
  path: string;
  query: Record<string, unknown>;
  statusCode?: number | null;
  durationMs?: number | null;
  error?: string | null;
  /// Free-form one-liner: selected source, run, counts.
  summary?: string | null;
}

export function requestLogOk(entry: RequestLogEntry): boolean {
  return !entry.error && (entry.statusCode ?? 0) < 400;
}

export function requestQueryString(query: Record<string, unknown>): string {
  return Object.entries(query)
    .map(([key, value]) => `${key}=${encodeURIComponent(String(value))}`)
    .join("&");
}

const MAX_ENTRIES = 60;

interface RequestLogState {
  entries: RequestLogEntry[];
  enabled: boolean;
  record: (entry: Omit<RequestLogEntry, "id">) => void;
  setEnabled: (enabled: boolean) => void;
  clear: () => void;
}

let nextId = 1;

export const useRequestLogStore = create<RequestLogState>((set) => ({
  entries: [],
  enabled: true,
  record: (entry) =>
    set((state) => {
      if (!state.enabled) return state;
      const withId: RequestLogEntry = { ...entry, id: nextId++ };
      return { entries: [withId, ...state.entries].slice(0, MAX_ENTRIES) };
    }),
  setEnabled: (enabled) => set({ enabled }),
  clear: () => set({ entries: [] }),
}));

export function recordRequest(entry: Omit<RequestLogEntry, "id">): void {
  useRequestLogStore.getState().record(entry);
}
