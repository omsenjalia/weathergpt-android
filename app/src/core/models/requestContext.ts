/// Request context shared by every agent-facing call (`/chat`, `/voice`) —
/// port of `lib/core/models/request_context.dart`. Chat and voice must send
/// *identical* context so the same question produces the same answer from
/// either surface, and so a UI/backend parity fixture can assert it.

import { AppMode, legacyFarmerModeFor, resolveAppMode } from "./appMode";

/// The farm details a farmer request may carry. The app never infers crop,
/// growth stage, soil or irrigation state from the weather — these come from
/// the user's saved profile or not at all.
export interface FarmContext {
  crop: string;
  growthStage?: string | null;
  soilType?: string | null;
  irrigationType?: string | null;
}

export function farmContextIsEmpty(farm: FarmContext | null | undefined): boolean {
  if (!farm) return true;
  return (
    farm.crop.trim() === "" &&
    (farm.growthStage ?? "").trim() === "" &&
    (farm.soilType ?? "").trim() === "" &&
    (farm.irrigationType ?? "").trim() === ""
  );
}

export interface AgentRequestContext {
  mode: AppMode;
  farm: FarmContext | null;
}

export function includesFarmContext(ctx: AgentRequestContext): boolean {
  return ctx.farm !== null && !farmContextIsEmpty(ctx.farm);
}

/// Body fields describing mode and farm context. `mode` is authoritative;
/// `farmer_mode` is kept only for backward compatibility with the current
/// backend and is derived from `mode`, so the two can never disagree.
export function agentContextPayload(ctx: AgentRequestContext): Record<string, unknown> {
  const farm = includesFarmContext(ctx) ? ctx.farm! : null;
  return {
    mode: ctx.mode,
    farmer_mode: legacyFarmerModeFor(ctx.mode),
    crop: farm?.crop ?? "",
    ...(farm && (farm.growthStage ?? "").trim() !== "" ? { growth_stage: farm.growthStage } : {}),
    ...(farm && (farm.soilType ?? "").trim() !== "" ? { soil: farm.soilType } : {}),
    ...(farm && (farm.irrigationType ?? "").trim() !== "" ? { irrigation: farm.irrigationType } : {}),
  };
}

/// Builds the context for one request. `profilePersona` is the raw persisted
/// persona string; it is validated here so an unrecognised value can never be
/// sent, and never escalates. Farm context is attached only for farmer mode —
/// Everyone and Researcher requests carry no private farm context.
export function buildAgentRequestContext(opts: {
  profilePersona: string;
  legacyFarmerMode?: boolean;
  farm?: FarmContext | null;
}): AgentRequestContext {
  const { profilePersona, legacyFarmerMode = false, farm = null } = opts;
  const mode = resolveAppMode({
    mode: profilePersona,
    legacyFarmerMode,
    // A persona this build does not know de-escalates rather than throwing,
    // because the value came from storage rather than from a caller.
    strict: false,
  });
  return { mode, farm: mode === "farmer" ? farm : null };
}
