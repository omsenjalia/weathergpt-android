/// Chat store — port of `lib/features/chat/providers/chat_provider.dart`.
/// Bumped generation guard: a late response from a superseded context is
/// discarded rather than appended to a different conversation.

import { create } from "zustand";

import { ApiEndpoints } from "../../core/config/apiEndpoints";
import { apiErrorMessage, isAppApiError } from "../../core/errors/appErrors";
import { buildAgentRequestContext, agentContextPayload, FarmContext } from "../../core/models/requestContext";
import { ApiClient } from "../../core/services/apiClient";
import { AppLocation, DEFAULT_LOCATION } from "../location/locationStore";
import { FarmProfile, DEFAULT_FARM_PROFILE } from "../farm/models/farmProfile";

export interface ChatMessage {
  role: "user" | "assistant";
  content: string;
  at: Date;
  /// Additive response metadata from the backend (`meta` in /chat responses).
  meta?: Record<string, unknown> | null;
  card?: Record<string, unknown> | null;

  toWire(): Record<string, unknown>;
}

export function createChatMessage(
  role: "user" | "assistant",
  content: string,
  opts?: { meta?: Record<string, unknown> | null; card?: Record<string, unknown> | null; at?: Date },
): ChatMessage {
  return {
    role,
    content,
    at: opts?.at ?? new Date(),
    meta: opts?.meta ?? null,
    card: opts?.card ?? null,
    toWire() {
      return { role: this.role, content: this.content };
    },
  };
}

interface ChatContext {
  language: string;
  userPersona: string;
  location: AppLocation;
  profile: FarmProfile;
  profileCompleted?: boolean;
}

interface ChatStore {
  messages: ChatMessage[];
  sending: boolean;
  error: string | null;
  generation: number;
  context: ChatContext;
  setContext: (context: ChatContext) => void;
  send: (text: string) => Promise<void>;
  retryLast: () => Promise<void>;
  clear: () => void;
}

export const DEFAULT_CHAT_CONTEXT: ChatContext = {
  language: "en",
  userPersona: "everyone",
  location: DEFAULT_LOCATION,
  profile: DEFAULT_FARM_PROFILE,
};

/// Assembles the /chat request body from the current settings, location and
/// saved farm profile. Farm context comes from the same source `/advisory`
/// uses instead of assuming a crop; mode and farm fields are built by
/// `buildAgentRequestContext` so chat and voice cannot drift.
export function buildChatPayload(
  context: ChatContext,
  messages: ChatMessage[],
  message: string,
): Record<string, unknown> {
  const requestContext = buildAgentRequestContext({
    profilePersona: context.userPersona,
    farm: context.profileCompleted === false ? undefined : {
      crop: context.profile.crop,
      growthStage: context.profile.growthStage,
      soilType: context.profile.soilType,
      irrigationType: context.profile.irrigationType,
    } satisfies FarmContext,
  });
  return {
    message,
    messages: messages.map((m) => m.toWire()),
    location: context.location.name,
    lat: context.location.lat,
    lon: context.location.lon,
    language: context.language,
    ...agentContextPayload(requestContext),
  };
}

export const useChatStore = create<ChatStore>((set, get) => ({
  messages: [],
  sending: false,
  error: null,
  generation: 0,
  context: DEFAULT_CHAT_CONTEXT,

  setContext: (context) => {
    if (JSON.stringify(context) !== JSON.stringify(get().context)) {
      get().clear();
      set({ context });
    }
  },

  send: async (text) => {
    const trimmed = text.trim();
    if (trimmed === "" || get().sending) return;
    const generation = get().generation;
    const next = [...get().messages, createChatMessage("user", trimmed)];
    set({ messages: next, sending: true, error: null });
    try {
      const result = await ApiClient.post(ApiEndpoints.chat, buildChatPayload(get().context, next, trimmed));
      // Context changed while the request was in flight: drop the answer.
      if (generation !== get().generation) return;
      const reply = typeof result["response"] === "string" ? result["response"] : "";
      const meta = result["meta"] !== null && typeof result["meta"] === "object" ? (result["meta"] as Record<string, unknown>) : null;
      const card = result["card"] !== null && typeof result["card"] === "object" ? (result["card"] as Record<string, unknown>) : null;
      set({
        sending: false,
        messages: [...next, createChatMessage("assistant", reply, { meta, card })],
      });
    } catch (error) {
      if (generation !== get().generation) return;
      set({ sending: false, error: isAppApiError(error) ? apiErrorMessage(error) : "Could not reach WeatherGPT. Try again." });
    }
  },

  retryLast: async () => {
    if (get().sending || !get().error) return;
    const messages = get().messages;
    const lastUser = messages[messages.length - 1];
    if (!lastUser || lastUser.content.trim() === "") return;
    set({ messages: messages.slice(0, -1) });
    await get().send(lastUser.content);
  },

  clear: () => {
    set((state) => ({ generation: state.generation + 1, messages: [], sending: false, error: null }));
  },
}));
