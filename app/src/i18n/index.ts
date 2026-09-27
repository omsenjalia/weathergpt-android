/// Internationalization engine — port of the `easy_localization` layer.
/// Flat dot-key JSON files for 9 live Indian languages, loaded eagerly so the
/// app can switch language with no async gap. Missing keys fall back to
/// English, then to the key itself.

import bn from "./locales/bn.json";
import en from "./locales/en.json";
import gu from "./locales/gu.json";
import hi from "./locales/hi.json";
import kn from "./locales/kn.json";
import ml from "./locales/ml.json";
import mr from "./locales/mr.json";
import ta from "./locales/ta.json";
import te from "./locales/te.json";

type RawBundle = Record<string, unknown>;

export const SUPPORTED_LANGUAGES = ["en", "hi", "gu", "mr", "ta", "te", "kn", "ml", "bn"] as const;
export type LanguageCode = (typeof SUPPORTED_LANGUAGES)[number];

export interface LanguageMeta {
  code: LanguageCode;
  native: string;
  english: string;
  ttsLocale: string;
  sttLocale: string;
}

/// Language → TTS/STT locale mapping, ported from
/// `onboarding_provider.dart` (`kOnboardingTtsLocales`) and
/// `voice_provider.dart` (`_sttLocale`).
export const LANGUAGE_META: Record<LanguageCode, LanguageMeta> = {
  en: { code: "en", native: "English", english: "English", ttsLocale: "en-US", sttLocale: "en_US" },
  hi: { code: "hi", native: "हिंदी", english: "Hindi", ttsLocale: "hi-IN", sttLocale: "hi_IN" },
  gu: { code: "gu", native: "ગુજરાતી", english: "Gujarati", ttsLocale: "gu-IN", sttLocale: "gu_IN" },
  mr: { code: "mr", native: "मराठी", english: "Marathi", ttsLocale: "mr-IN", sttLocale: "mr_IN" },
  ta: { code: "ta", native: "தமிழ்", english: "Tamil", ttsLocale: "ta-IN", sttLocale: "ta_IN" },
  te: { code: "te", native: "తెలుగు", english: "Telugu", ttsLocale: "te-IN", sttLocale: "te_IN" },
  kn: { code: "kn", native: "ಕನ್ನಡ", english: "Kannada", ttsLocale: "kn-IN", sttLocale: "kn_IN" },
  ml: { code: "ml", native: "മലയാളം", english: "Malayalam", ttsLocale: "ml-IN", sttLocale: "ml_IN" },
  bn: { code: "bn", native: "বাংলা", english: "Bengali", ttsLocale: "bn-IN", sttLocale: "bn_IN" },
};

const stripDefault = (bundle: Record<string, unknown>): Record<string, string> => {
  // Some bundlers wrap JSON with a `default` export key; drop it so keyset
  // arithmetic and lookups never see a phantom "default" translation.
  const clone: Record<string, string> = {};
  for (const [key, value] of Object.entries(bundle)) {
    if (key !== "default" && typeof value === "string") clone[key] = value;
  }
  return clone;
};

const BUNDLES: Record<LanguageCode, Record<string, string>> = {
  en: stripDefault(en),
  hi: stripDefault(hi as Record<string, unknown>),
  gu: stripDefault(gu as Record<string, unknown>),
  mr: stripDefault(mr as Record<string, unknown>),
  ta: stripDefault(ta as Record<string, unknown>),
  te: stripDefault(te as Record<string, unknown>),
  kn: stripDefault(kn as Record<string, unknown>),
  ml: stripDefault(ml as Record<string, unknown>),
  bn: stripDefault(bn as Record<string, unknown>),
};

export function isSupportedLanguage(value: unknown): value is LanguageCode {
  return typeof value === "string" && (SUPPORTED_LANGUAGES as readonly string[]).includes(value);
}

const PLACEHOLDER = /\{(\w+)\}/g;

function interpolate(template: string, args?: Record<string, string | number>): string {
  if (!args) return template;
  return template.replace(PLACEHOLDER, (match, name) =>
    name in args ? String(args[name]) : match,
  );
}

export interface Translator {
  (key: string, args?: Record<string, string | number>): string;
  language: LanguageCode;
}

/// Creates a translator bound to a language. English keys exist for all 287
/// strings; other locales fall back to English for any missing key.
export function createTranslator(language: LanguageCode): Translator {
  const fn = ((key: string, args?: Record<string, string | number>) => {
    const bundle = BUNDLES[language] ?? BUNDLES.en;
    const value = bundle[key] ?? BUNDLES.en[key] ?? key;
    return interpolate(value, args);
  }) as Translator;
  fn.language = language;
  return fn;
}

export function translationKeyCount(language: LanguageCode): number {
  return Object.keys(BUNDLES[language]).length;
}
