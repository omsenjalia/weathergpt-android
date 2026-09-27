/// On-device parsing for the farmer voice onboarding flow — port of
/// `lib/features/farmer/models/farm_voice_parser.dart`.
///
/// Speech answers are matched against the wire-value catalogs plus
/// English/Hindi/Gujarati alias maps, so "wheat", "गेहूं", "ઘઉં" and even
/// romanized "gehu" all resolve to `Wheat`. Farm size accepts ASCII digits,
/// Devanagari/Gujarati digits and number words ("चार" → 4). Everything
/// returns `null` when nothing matches — the voice flow re-asks rather than
/// guessing.

import { FARM_CROPS, GROWTH_STAGES, IRRIGATION_TYPES, SOIL_TYPES } from "./farmOptions";

/// Lowercase, de-punctuate and collapse whitespace. Indic scripts pass
/// through untouched — only ASCII punctuation is stripped.
export function normalizeVoiceInput(input: string): string {
  return input
    .toLowerCase()
    .replace(/[.,!?;:()"\-—–]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

/// Converts Devanagari (०-९) and Gujarati (૦-૯) digits to ASCII.
export function indicDigitsToAscii(input: string): string {
  let out = "";
  for (const char of input) {
    const code = char.codePointAt(0)!;
    if (code >= 0x0966 && code <= 0x096f) {
      out += String.fromCodePoint(0x30 + (code - 0x0966));
    } else if (code >= 0x0ae6 && code <= 0x0aef) {
      out += String.fromCodePoint(0x30 + (code - 0x0ae6));
    } else {
      out += char;
    }
  }
  return out;
}

/// Matches free speech to one of `options` (wire values), consulting
/// `aliases` (spoken form → wire value) as well.
///
/// Order: exact match first, then longest-phrase containment ("black cotton
/// soil" beats "black"). Keys of 4 or fewer characters only match whole words
/// ("rain" must not fire inside "drain"). Returns the wire value or `null`.
export function matchVoiceOption(
  input: string,
  options: readonly string[],
  aliases: Record<string, string> = {},
): string | null {
  const norm = normalizeVoiceInput(input);
  if (norm === "") return null;

  for (const option of options) {
    if (normalizeVoiceInput(option) === norm) return option;
  }
  for (const [spoken, wire] of Object.entries(aliases)) {
    if (normalizeVoiceInput(spoken) === norm) return wire;
  }

  const words = new Set(norm.split(" "));
  const candidates: Array<[string, string]> = [
    ...options.map((option): [string, string] => [option, option]),
    ...Object.entries(aliases),
  ].sort((a, b) => b[0].length - a[0].length);

  for (const [key, value] of candidates) {
    const normalized = normalizeVoiceInput(key);
    if (normalized === "") continue;
    if (normalized.length <= 4) {
      if (words.has(normalized)) return value;
    } else if (norm.includes(normalized)) {
      return value;
    }
  }
  return null;
}

/// Spoken crop name → wire value. Includes Hindi/Gujarati names plus common
/// romanized forms.
export const CROP_VOICE_ALIASES: Record<string, string> = {
  paddy: "Rice", corn: "Maize", gram: "Pulses", lentil: "Pulses", lentils: "Pulses",
  chickpea: "Pulses", dal: "Pulses", chana: "Pulses", narma: "Cotton", kapas: "Cotton",
  gehu: "Wheat", dhan: "Rice", makka: "Maize", ganna: "Sugarcane", aloo: "Potato",
  pyaz: "Onion", pyaaz: "Onion", tamatar: "Tomato", sarson: "Mustard", sarso: "Mustard",
  mungfali: "Groundnut", moongfali: "Groundnut",
  "गेहूं": "Wheat", "गेहूँ": "Wheat", "धान": "Rice", "चावल": "Rice", "कपास": "Cotton",
  "नरमा": "Cotton", "मक्का": "Maize", "मक्की": "Maize", "गन्ना": "Sugarcane", "ईख": "Sugarcane",
  "सोयाबीन": "Soybean", "मूंगफली": "Groundnut", "सरसों": "Mustard", "सरसो": "Mustard",
  "आलू": "Potato", "प्याज": "Onion", "प्याज़": "Onion", "टमाटर": "Tomato", "दाल": "Pulses",
  "दलहन": "Pulses", "चना": "Pulses", "अरहर": "Pulses", "मसूर": "Pulses", "मूंग": "Pulses",
  "उड़द": "Pulses",
  "ઘઉં": "Wheat", "ડાંગર": "Rice", "ચોખા": "Rice", "કપાસ": "Cotton", "મકાઈ": "Maize",
  "શેરડી": "Sugarcane", "સોયાબીન": "Soybean", "મગફળી": "Groundnut", "સરસવ": "Mustard",
  "બટાકા": "Potato", "બટાટા": "Potato", "ડુંગળી": "Onion", "ટામેટા": "Tomato",
  "ટામેટાં": "Tomato", "કઠોળ": "Pulses", "ચણા": "Pulses", "તુવેર": "Pulses", "મગ": "Pulses",
  "અડદ": "Pulses",
};

export const GROWTH_STAGE_VOICE_ALIASES: Record<string, string> = {
  planting: "Sowing", planted: "Sowing", sprouting: "Germination", sprout: "Germination",
  growing: "Vegetative", growth: "Vegetative", blooming: "Flowering", bloom: "Flowering",
  flower: "Flowering", fruit: "Fruiting", "grain filling": "Fruiting", maturing: "Maturity",
  mature: "Maturity", ripe: "Maturity", ripening: "Maturity", harvesting: "Harvest",
  "ready to harvest": "Harvest", cutting: "Harvest",
  "बुवाई": "Sowing", "बोआई": "Sowing", "अंकुरण": "Germination", "वानस्पतिक": "Vegetative",
  "फूल": "Flowering", "फल": "Fruiting", "दाना": "Fruiting", "परिपक्व": "Maturity",
  "कटाई": "Harvest",
  "વાવણી": "Sowing", "વાવેતર": "Sowing", "અંકુરણ": "Germination", "વાનસ્પતિક": "Vegetative",
  "ફૂલ": "Flowering", "ફળ": "Fruiting", "દાણા": "Fruiting", "પરિપક્વ": "Maturity",
  "કાપણી": "Harvest", "લણણી": "Harvest",
};

export const IRRIGATION_VOICE_ALIASES: Record<string, string> = {
  bore: "Borewell", "bore well": "Borewell", tubewell: "Borewell", "tube well": "Borewell",
  "drip irrigation": "Drip", rain: "Rainfed", "rain only": "Rainfed", "only rain": "Rainfed",
  "no irrigation": "Rainfed", "depends on rain": "Rainfed", monsoon: "Rainfed",
  "बोरवेल": "Borewell", "ट्यूबवेल": "Borewell", "नहर": "Canal", "ड्रिप": "Drip",
  "टपक": "Drip", "स्प्रिंकलर": "Sprinkler", "फव्वारा": "Sprinkler", "बारिश": "Rainfed",
  "वर्षा": "Rainfed", "बारानी": "Rainfed",
  "બોરવેલ": "Borewell", "ટ્યુબવેલ": "Borewell", "નહેર": "Canal", "ડ્રિપ": "Drip",
  "ટપક": "Drip", "સ્પ્રિંકલર": "Sprinkler", "ફુવારા": "Sprinkler", "વરસાદ": "Rainfed",
  "વરસાદી": "Rainfed",
};

export const SOIL_VOICE_ALIASES: Record<string, string> = {
  loam: "Loamy", clayey: "Clay", sand: "Sandy", silt: "Silty", black: "Black",
  "black soil": "Black", "black cotton soil": "Black", "red soil": "Red",
  alluvium: "Alluvial",
  "दोमट": "Loamy", "चिकनी": "Clay", "रेतीली": "Sandy", "बलुई": "Sandy", "सिल्ट": "Silty",
  "काली": "Black", "लाल": "Red", "जलोढ़": "Alluvial",
  "ગોરાડુ": "Loamy", "ચીકણી": "Clay", "રેતાળ": "Sandy", "કાંપ": "Silty", "કાળી": "Black",
  "લાલ": "Red",
};

export function parseVoiceCrop(input: string): string | null {
  return matchVoiceOption(input, FARM_CROPS, CROP_VOICE_ALIASES);
}

export function parseVoiceGrowthStage(input: string): string | null {
  return matchVoiceOption(input, GROWTH_STAGES, GROWTH_STAGE_VOICE_ALIASES);
}

export function parseVoiceIrrigation(input: string): string | null {
  return matchVoiceOption(input, IRRIGATION_TYPES, IRRIGATION_VOICE_ALIASES);
}

export function parseVoiceSoil(input: string): string | null {
  return matchVoiceOption(input, SOIL_TYPES, SOIL_VOICE_ALIASES);
}

/// Spoken number → acres.
export const NUMBER_WORD_ACRES: Record<string, number> = {
  one: 1, two: 2, three: 3, four: 4, five: 5, six: 6, seven: 7, eight: 8, nine: 9, ten: 10,
  "एक": 1, "दो": 2, "तीन": 3, "चार": 4, "पाँच": 5, "पांच": 5, "छह": 6, "छः": 6, "सात": 7,
  "आठ": 8, "नौ": 9, "दस": 10, "पंद्रह": 15, "बीस": 20,
  "એક": 1, "બે": 2, "ત્રણ": 3, "ચાર": 4, "પાંચ": 5, "છ": 6, "સાત": 7, "આઠ": 8, "નવ": 9,
  "દસ": 10, "પંદર": 15, "વીસ": 20,
};

/// Words meaning "acre" — when one is present but no number was heard
/// ("an acre"), assume a single acre rather than re-asking.
const ACRE_WORDS = new Set(["acre", "acres", "एकड़", "ऐकड़", "એકર"]);

/// Parses a spoken farm size in acres. Accepts ASCII digits ("4.5"),
/// Devanagari/Gujarati digits ("४") and number words ("चार", "two").
/// Returns `null` for anything non-positive or unparseable.
export function parseVoiceFarmSize(input: string): number | null {
  // Digits are read before punctuation stripping so "4.5" survives.
  const ascii = indicDigitsToAscii(input);
  const digits = /\d+([.,]\d+)?/.exec(ascii);
  if (digits !== null) {
    const raw = digits[0];
    // "1,000" is a thousands separator, "4,5" a decimal comma.
    const canonical = raw.includes(",") && /,\d{3}$/.test(raw) ? raw.replaceAll(",", "") : raw.replaceAll(",", ".");
    const value = Number(canonical);
    if (Number.isFinite(value) && value > 0 && value <= 100000) return value;
  }

  const norm = normalizeVoiceInput(ascii);
  if (norm === "") return null;

  // Number words match whole tokens only ("one" must not fire in "someone").
  const words = new Set(norm.split(" "));
  for (const [word, acres] of Object.entries(NUMBER_WORD_ACRES)) {
    if (words.has(normalizeVoiceInput(word))) return acres;
  }

  for (const word of words) {
    if (ACRE_WORDS.has(word)) return 1;
  }
  return null;
}

/// Display/round-trip format for a parsed size: `4` not `4.0`.
export function formatVoiceFarmSize(acres: number): string {
  return acres % 1 === 0 ? acres.toFixed(0) : acres.toFixed(1);
}
