/// Structured card the backend may attach to a `/chat` or `/voice` answer —
/// port of `lib/features/voice/models/voice_card.dart`.
///
/// The card is **optional and additive**: when the backend sends text only,
/// there are no stats and no forecast rows, and the UI must say so rather than
/// substitute plausible-looking numbers. Nothing here is derived client-side
/// from the prose.

import { jsonDouble, jsonList, jsonMap, jsonString } from "../../../core/models/jsonValues";

/// Visual intent of one stat, as named by the backend. Colour stays a UI
/// concern — the app maps the tone, it does not accept colour values.
export enum CardTone {
  Neutral = "neutral",
  Good = "good",
  Caution = "caution",
  Avoid = "avoid",
}

export function cardToneFromName(value: unknown): CardTone {
  switch (jsonString(value)?.toLowerCase()) {
    case "good":
    case "safe":
    case "favourable":
      return CardTone.Good;
    case "caution":
    case "watch":
      return CardTone.Caution;
    case "avoid":
    case "poor":
    case "risk":
      return CardTone.Avoid;
    default:
      return CardTone.Neutral;
  }
}

export interface VoiceCardStat {
  label: string;
  value: string;
  tone: CardTone;
}

export interface VoiceCardDay {
  label: string;
  temperature: string;
  /// Rendered as sent. A missing value stays `null` and shows an em dash; it
  /// is never rendered as `0 mm`.
  rainfall: string | null;
  condition: string | null;
}

export interface VoiceCard {
  label: string | null;
  verdict: string | null;
  explanation: string | null;
  ctaLabel: string | null;
  stats: VoiceCardStat[];
  forecast: VoiceCardDay[];
  /// Data source / run the card is attributed to, when the backend says.
  source: string | null;
  /// Decision confidence, kept distinct from any weather-event probability.
  confidence: number | null;
}

/// Parses an optional card. Returns `null` when the backend sent none, so
/// callers can distinguish "no card" from "empty card".
export function voiceCardFromJson(raw: unknown): VoiceCard | null {
  const data = jsonMap(raw);
  if (data === null) return null;

  const stats: VoiceCardStat[] = [];
  for (const item of jsonList(data["stats"])) {
    const row = jsonMap(item);
    if (row === null) continue;
    const label = jsonString(row["label"]);
    const value = jsonString(row["value"]);
    if (label === null || value === null) continue;
    stats.push({ label, value, tone: cardToneFromName(row["tone"]) });
  }

  const forecast: VoiceCardDay[] = [];
  for (const item of jsonList(data["forecast"])) {
    const row = jsonMap(item);
    if (row === null) continue;
    const label = jsonString(row["day"] ?? row["label"] ?? row["date"]);
    if (label === null) continue;
    forecast.push({
      label,
      temperature: jsonString(row["temperature"] ?? row["temp"]) ?? "—",
      rainfall: jsonString(row["rainfall"] ?? row["rainfall_mm"] ?? row["precip_mm"]),
      condition: jsonString(row["condition"] ?? row["icon"]),
    });
  }

  return {
    label: jsonString(data["label"]),
    verdict: jsonString(data["verdict"]),
    explanation: jsonString(data["explanation"]),
    ctaLabel: jsonString(data["cta_label"] ?? data["cta"]),
    stats,
    forecast,
    source: jsonString(data["source"] ?? data["provider"]),
    confidence: jsonDouble(data["confidence"]),
  };
}
