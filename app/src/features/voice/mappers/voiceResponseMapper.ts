/// Maps a backend chat/voice answer onto the result card — port of
/// `lib/features/voice/mappers/voice_response_mapper.dart`.
///
/// The card's numbers come **only** from a structured VoiceCard the backend
/// chose to send. When the backend answers with prose alone, the card carries
/// no stats and no forecast rows — substituting a plausible-looking rain
/// percentage, soil-moisture reading, growth stage or fixed weekday forecast
/// is precisely the behaviour the implementation plan prohibits.

import { AppColors } from "../../../core/theme/appColors";
import { MarkdownUtils } from "../../../core/utils/markdownUtils";
import { CardTone, VoiceCard, VoiceCardDay, voiceCardFromJson } from "../models/voiceCard";

export enum ResultType {
  Irrigation = "irrigation",
  RainForecast = "rainForecast",
  General = "general",
  CropStatus = "cropStatus",
  ResearchQuery = "researchQuery",
}

export interface ResultStat {
  label: string;
  value: string;
  color: string;
}

export interface ForecastDay {
  day: string;
  icon: string;
  temperature: string;
  rainfall: string;
}

export interface VoiceResponse {
  transcript: string;
  type: ResultType;
  accent: string;
  label: string;
  verdict: string;
  explanation: string;
  stats: ResultStat[];
  forecast: ForecastDay[];
  ctaLabel: string;
}

const GREETINGS = new Set([
  "hi", "hello", "hey", "yo", "sup", "help", "thanks", "thank you", "namaste",
  "namaskar", "hola", "હેલો", "હાય", "નમસ્તે", "नमस्ते", "हैलो", "हाय",
]);

/// Greetings / intro replies should not show irrigation/rain mock cards.
export function looksLikeGreetingOrIntro(query: string, lowerBody: string): boolean {
  const q = query.trim().toLowerCase();
  if (GREETINGS.has(q)) return true;
  if (q.startsWith("what do you") || q.startsWith("who are you")) return true;
  if (
    lowerBody.includes("i'm **weathergpt**") ||
    lowerBody.includes("i am weathergpt") ||
    lowerBody.includes("couldn't fetch live weather") ||
    lowerBody.includes("try asking:") ||
    lowerBody.includes("weathergpt છું") ||
    lowerBody.includes("weathergpt हूं") ||
    lowerBody.includes("weathergpt हूँ")
  ) {
    return true;
  }
  const hasNumbers = /\d+\s*°|\d+\s*mm|\d+%/.test(lowerBody);
  if (
    !hasNumbers &&
    lowerBody.includes("weathergpt") &&
    (lowerBody.includes("help") ||
      lowerBody.includes("ask") ||
      lowerBody.includes("સલાહ") ||
      lowerBody.includes("જણાવો") ||
      lowerBody.includes("advisor") ||
      lowerBody.includes("હવામાન"))
  ) {
    return true;
  }
  return false;
}

/// Classifies the ask so the card can pick its chrome (accent, label, CTA).
/// Classification only chooses presentation. It never produces values: the
/// numbers on a card come from the backend or not at all.
export function typeForQuery(normalizedQuery: string, isMeta: boolean): ResultType {
  if (isMeta) return ResultType.General;
  if (normalizedQuery.includes("irrigat")) return ResultType.Irrigation;
  if (normalizedQuery.includes("rain") || normalizedQuery.includes("forecast")) return ResultType.RainForecast;
  if (normalizedQuery.includes("crop") || normalizedQuery.includes("wheat")) return ResultType.CropStatus;
  return ResultType.General;
}

interface Chrome {
  accent: string;
  label: string;
  ctaLabel: string;
}

/// Presentation-only defaults per result type. No measurements live here.
export function chromeForType(type: ResultType): Chrome {
  switch (type) {
    case ResultType.Irrigation:
      return { accent: AppColors.statusAmber, label: "Irrigation Recommendation", ctaLabel: "View Farm Action Windows" };
    case ResultType.RainForecast:
      return { accent: AppColors.researcherBlue, label: "Rain Forecast", ctaLabel: "View Detailed Forecast" };
    case ResultType.CropStatus:
      return { accent: AppColors.farmerGreen, label: "Crop Status", ctaLabel: "View Farm Action Windows" };
    case ResultType.General:
      return { accent: AppColors.researcherBlue, label: "WeatherGPT", ctaLabel: "Ask about weather" };
    case ResultType.ResearchQuery:
      return { accent: AppColors.researcherBlue, label: "Research Query", ctaLabel: "Ask about weather" };
  }
}

export function toneColor(tone: CardTone): string {
  switch (tone) {
    case CardTone.Good:
      return AppColors.statusGreenText;
    case CardTone.Caution:
      return AppColors.statusAmber;
    case CardTone.Avoid:
      return AppColors.statusRed;
    default:
      return AppColors.researcherBlue;
  }
}

/// Icon name per condition, mapped by the UI to an icon family.
export function iconForCondition(condition: string | null): string {
  const c = (condition ?? "").toLowerCase();
  if (c.includes("thunder")) return "thunderstorm";
  if (c.includes("snow")) return "ac-unit";
  if (c.includes("rain") || c.includes("drizzle")) return "water-drop";
  if (c.includes("fog") || c.includes("mist") || c.includes("haze")) return "foggy";
  if (c.includes("cloud") || c.includes("overcast")) return "cloud";
  if (c.includes("clear") || c.includes("sun")) return "wb-sunny";
  return "help-outline";
}

function iconKeyFor(icon: string): string {
  // Maps Dart IconData semantics to MaterialCommunityIcons names used in RN.
  switch (icon) {
    case "thunderstorm":
      return "weather-lightning";
    case "ac-unit":
      return "snowflake";
    case "water-drop":
      return "water";
    case "foggy":
      return "weather-fog";
    case "cloud":
      return "cloud-outline";
    case "wb-sunny":
      return "weather-sunny";
    default:
      return "help-circle-outline";
  }
}

export function forecastIconForCondition(condition: string | null): string {
  return iconKeyFor(iconForCondition(condition));
}

/// Maps a backend answer onto the result card.
export function mapBackendAnswer(
  query: string,
  response: string,
  raw?: Record<string, unknown> | null,
): VoiceResponse {
  const normalized = query.toLowerCase().trim();
  const bodyRaw = response.trim();
  const lowerBody = bodyRaw.toLowerCase();
  const isMeta = looksLikeGreetingOrIntro(normalized, lowerBody);

  const type = typeForQuery(normalized, isMeta);
  const chrome = chromeForType(type);
  const card: VoiceCard | null = isMeta
    ? null
    : voiceCardFromJson(raw?.["card"] ?? raw?.["result"]);

  // The prose answer is authoritative; a card explanation only fills a gap.
  const body = bodyRaw !== "" ? bodyRaw : card?.explanation ?? "";
  const plain = MarkdownUtils.forSpeech(body);
  const firstLine =
    plain
      .split(/[.!?;\n]/)
      .map((s) => s.trim())
      .find((s) => s !== "") ?? "";
  const verdictSource = card?.verdict ?? firstLine;
  const verdict = verdictSource.length > 90 ? `${verdictSource.slice(0, 90)}…` : verdictSource;

  return {
    transcript: query,
    type,
    accent: chrome.accent,
    label: isMeta ? "Assistant" : card?.label ?? chrome.label,
    // Empty verdict means "the backend gave us nothing to headline" — the UI
    // renders a neutral title rather than inventing a sunny one.
    verdict,
    explanation: body,
    stats: (card?.stats ?? []).map((stat) => ({ label: stat.label, value: stat.value, color: toneColor(stat.tone) })),
    forecast: (card?.forecast ?? []).map((day: VoiceCardDay) => ({
      day: day.label,
      icon: forecastIconForCondition(day.condition),
      temperature: day.temperature,
      rainfall: day.rainfall ?? "—",
    })),
    ctaLabel: isMeta ? "Ask about weather" : card?.ctaLabel ?? chrome.ctaLabel,
  };
}
