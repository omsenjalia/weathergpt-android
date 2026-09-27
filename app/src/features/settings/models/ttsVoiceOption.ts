/// Device text-to-speech voice helpers — port of
/// `lib/features/settings/models/tts_voice_option.dart`.

/// One engine voice: `name` is the engine id passed back to the TTS engine
/// (e.g. `en-gb-x-rjs#female_2-local`), `locale` its BCP-47-ish tag.
export interface TtsVoiceOption {
  name: string;
  locale: string;
}

/// Human label for picker rows: `en-gb-x-rjs#female_2-local` → `Female 2`,
/// `en-US-SMTf00` → `SMTf00`, `Karen` → `Karen`. Falls back to `name`.
export function ttsVoiceFriendlyName(option: TtsVoiceOption): string {
  let label = option.name;
  const hash = label.indexOf("#");
  if (hash >= 0 && hash + 1 < label.length) {
    label = label.slice(hash + 1);
  } else {
    // Strip a leading locale prefix: "en-US-SMTf00" -> "SMTf00".
    label = label.replace(/^[a-z]{2,3}([-_][a-zA-Z]{2,4})?[-_]/, "");
  }
  label = label.replace(/-(local|network)$/i, "");
  label = label.replace(/[_-]+/g, " ").trim();
  if (label === "") return option.name;
  return label
    .split(" ")
    .filter((w) => w !== "")
    .map((w) => w[0].toUpperCase() + w.slice(1))
    .join(" ");
}

/// Persisted voice choice for one app language.
///
/// `source` is the seam for the server-models follow-up: device voices use
/// `'device'` today, while a future `'server'` source can carry a model id.
export interface TtsVoiceSelection {
  source: string;
  name: string;
  locale: string;
}

export function ttsSelectionIsDevice(selection: TtsVoiceSelection): boolean {
  return selection.source === "device";
}

export function ttsSelectionIsValid(selection: TtsVoiceSelection): boolean {
  return selection.name !== "" && selection.locale !== "";
}

export function ttsSelectionToMap(selection: TtsVoiceSelection): Record<string, string> {
  return { source: selection.source, name: selection.name, locale: selection.locale };
}

export function ttsSelectionFromMap(map: Record<string, unknown>): TtsVoiceSelection {
  return {
    source: typeof map["source"] === "string" ? map["source"] : "device",
    name: typeof map["name"] === "string" ? map["name"] : "",
    locale: typeof map["locale"] === "string" ? map["locale"] : "",
  };
}

/// Defensively parses TTS engine `getVoices` output (an array of
/// `{name, locale}` objects). Anything malformed is skipped, never throws.
export function parseTtsVoices(raw: unknown): TtsVoiceOption[] {
  if (!Array.isArray(raw)) return [];
  const options: TtsVoiceOption[] = [];
  for (const entry of raw) {
    if (entry === null || typeof entry !== "object") continue;
    const row = entry as Record<string, unknown>;
    const name = row["name"];
    const locale = row["locale"];
    if (typeof name !== "string" || typeof locale !== "string") continue;
    if (name === "" || locale === "") continue;
    options.push({ name, locale });
  }
  return options;
}

function norm(locale: string): string {
  return locale.replaceAll("_", "-").toLowerCase();
}

/// Voices whose locale starts with `langCode` (`en` matches `en-US` and
/// `en_US`), sorted by locale then name for a stable picker list.
export function filterVoicesForLanguage(voices: TtsVoiceOption[], langCode: string): TtsVoiceOption[] {
  const prefix = langCode.trim().toLowerCase();
  const matches = voices.filter((v) => norm(v.locale).startsWith(prefix));
  matches.sort((a, b) => {
    const byLocale = norm(a.locale).localeCompare(norm(b.locale));
    return byLocale !== 0 ? byLocale : a.name.localeCompare(b.name);
  });
  return matches;
}

/// Returns `savedName` when it still exists among `voices` (OS updates can
/// remove voices), else null so the caller falls back to the locale default.
export function resolveVoiceName(voices: TtsVoiceOption[], savedName: string | null): string | null {
  if (savedName === null || savedName === "") return null;
  return voices.some((v) => v.name === savedName) ? savedName : null;
}
