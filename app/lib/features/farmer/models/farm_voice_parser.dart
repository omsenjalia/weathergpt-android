/// On-device parsing for the farmer voice onboarding flow.
///
/// Speech answers are matched against the [farm_options.dart] wire-value
/// catalogs plus English/Hindi/Gujarati alias maps, so "wheat", "गेहूं",
/// "ઘઉં" and even romanized "gehu" all resolve to `Wheat`. Farm size accepts
/// ASCII digits, Devanagari/Gujarati digits and number words ("चार" → 4).
///
/// Pure Dart (no Flutter imports) so the matching rules are unit-testable in
/// isolation. Everything returns `null` when nothing matches — the voice flow
/// re-asks rather than guessing.
library;

import 'farm_options.dart';

/// Lowercase, de-punctuate and collapse whitespace. Indic scripts pass
/// through untouched — only ASCII punctuation is stripped.
String normalizeVoiceInput(String input) => input
    .toLowerCase()
    .replaceAll(RegExp(r'[.,!?;:()"\-—–]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Converts Devanagari (०-९) and Gujarati (૦-૯) digits to ASCII.
String indicDigitsToAscii(String input) {
  final out = StringBuffer();
  for (final rune in input.runes) {
    if (rune >= 0x0966 && rune <= 0x096F) {
      out.writeCharCode(0x30 + (rune - 0x0966));
    } else if (rune >= 0x0AE6 && rune <= 0x0AEF) {
      out.writeCharCode(0x30 + (rune - 0x0AE6));
    } else {
      out.writeCharCode(rune);
    }
  }
  return out.toString();
}

/// Matches free speech to one of [options] (wire values), consulting
/// [aliases] (spoken form → wire value) as well.
///
/// Order: exact match first, then longest-phrase containment ("black cotton
/// soil" beats "black"). Keys of 4 or fewer characters only match whole words
/// ("rain" must not fire inside "drain"). Returns the wire value or `null`.
String? matchVoiceOption(
  String input,
  List<String> options, [
  Map<String, String> aliases = const {},
]) {
  final norm = normalizeVoiceInput(input);
  if (norm.isEmpty) return null;

  for (final option in options) {
    if (normalizeVoiceInput(option) == norm) return option;
  }
  for (final entry in aliases.entries) {
    if (normalizeVoiceInput(entry.key) == norm) return entry.value;
  }

  final words = norm.split(' ').toSet();
  final candidates = <MapEntry<String, String>>[
    for (final option in options) MapEntry(option, option),
    ...aliases.entries,
  ]..sort((a, b) => b.key.length.compareTo(a.key.length));
  for (final candidate in candidates) {
    final key = normalizeVoiceInput(candidate.key);
    if (key.isEmpty) continue;
    if (key.length <= 4) {
      if (words.contains(key)) return candidate.value;
    } else if (norm.contains(key)) {
      return candidate.value;
    }
  }
  return null;
}

/// Spoken crop name → wire value. Includes Hindi/Gujarati names plus common
/// romanized forms (for when the STT locale transcribes Indic words in Latin
/// script).
const kCropVoiceAliases = <String, String>{
  'paddy': 'Rice',
  'corn': 'Maize',
  'gram': 'Pulses',
  'lentil': 'Pulses',
  'lentils': 'Pulses',
  'chickpea': 'Pulses',
  'dal': 'Pulses',
  'chana': 'Pulses',
  'narma': 'Cotton',
  'kapas': 'Cotton',
  'gehu': 'Wheat',
  'dhan': 'Rice',
  'makka': 'Maize',
  'ganna': 'Sugarcane',
  'aloo': 'Potato',
  'pyaz': 'Onion',
  'pyaaz': 'Onion',
  'tamatar': 'Tomato',
  'sarson': 'Mustard',
  'sarso': 'Mustard',
  'mungfali': 'Groundnut',
  'moongfali': 'Groundnut',
  'गेहूं': 'Wheat',
  'गेहूँ': 'Wheat',
  'धान': 'Rice',
  'चावल': 'Rice',
  'कपास': 'Cotton',
  'नरमा': 'Cotton',
  'मक्का': 'Maize',
  'मक्की': 'Maize',
  'गन्ना': 'Sugarcane',
  'ईख': 'Sugarcane',
  'सोयाबीन': 'Soybean',
  'मूंगफली': 'Groundnut',
  'सरसों': 'Mustard',
  'सरसो': 'Mustard',
  'आलू': 'Potato',
  'प्याज': 'Onion',
  'प्याज़': 'Onion',
  'टमाटर': 'Tomato',
  'दाल': 'Pulses',
  'दलहन': 'Pulses',
  'चना': 'Pulses',
  'अरहर': 'Pulses',
  'मसूर': 'Pulses',
  'मूंग': 'Pulses',
  'उड़द': 'Pulses',
  'ઘઉં': 'Wheat',
  'ડાંગર': 'Rice',
  'ચોખા': 'Rice',
  'કપાસ': 'Cotton',
  'મકાઈ': 'Maize',
  'શેરડી': 'Sugarcane',
  'સોયાબીન': 'Soybean',
  'મગફળી': 'Groundnut',
  'સરસવ': 'Mustard',
  'બટાકા': 'Potato',
  'બટાટા': 'Potato',
  'ડુંગળી': 'Onion',
  'ટામેટા': 'Tomato',
  'ટામેટાં': 'Tomato',
  'કઠોળ': 'Pulses',
  'ચણા': 'Pulses',
  'તુવેર': 'Pulses',
  'મગ': 'Pulses',
  'અડદ': 'Pulses',
};

/// Spoken growth stage → wire value.
const kGrowthStageVoiceAliases = <String, String>{
  'planting': 'Sowing',
  'planted': 'Sowing',
  'sprouting': 'Germination',
  'sprout': 'Germination',
  'growing': 'Vegetative',
  'growth': 'Vegetative',
  'blooming': 'Flowering',
  'bloom': 'Flowering',
  'flower': 'Flowering',
  'fruit': 'Fruiting',
  'grain filling': 'Fruiting',
  'maturing': 'Maturity',
  'mature': 'Maturity',
  'ripe': 'Maturity',
  'ripening': 'Maturity',
  'harvesting': 'Harvest',
  'ready to harvest': 'Harvest',
  'cutting': 'Harvest',
  'बुवाई': 'Sowing',
  'बोआई': 'Sowing',
  'अंकुरण': 'Germination',
  'वानस्पतिक': 'Vegetative',
  'फूल': 'Flowering',
  'फल': 'Fruiting',
  'दाना': 'Fruiting',
  'परिपक्व': 'Maturity',
  'कटाई': 'Harvest',
  'વાવણી': 'Sowing',
  'વાવેતર': 'Sowing',
  'અંકુરણ': 'Germination',
  'વાનસ્પતિક': 'Vegetative',
  'ફૂલ': 'Flowering',
  'ફળ': 'Fruiting',
  'દાણા': 'Fruiting',
  'પરિપક્વ': 'Maturity',
  'કાપણી': 'Harvest',
  'લણણી': 'Harvest',
};

/// Spoken irrigation method → wire value.
const kIrrigationVoiceAliases = <String, String>{
  'bore': 'Borewell',
  'bore well': 'Borewell',
  'tubewell': 'Borewell',
  'tube well': 'Borewell',
  'drip irrigation': 'Drip',
  'rain': 'Rainfed',
  'rain only': 'Rainfed',
  'only rain': 'Rainfed',
  'no irrigation': 'Rainfed',
  'depends on rain': 'Rainfed',
  'monsoon': 'Rainfed',
  'बोरवेल': 'Borewell',
  'ट्यूबवेल': 'Borewell',
  'नहर': 'Canal',
  'ड्रिप': 'Drip',
  'टपक': 'Drip',
  'स्प्रिंकलर': 'Sprinkler',
  'फव्वारा': 'Sprinkler',
  'बारिश': 'Rainfed',
  'वर्षा': 'Rainfed',
  'बारानी': 'Rainfed',
  'બોરવેલ': 'Borewell',
  'ટ્યુબવેલ': 'Borewell',
  'નહેર': 'Canal',
  'ડ્રિપ': 'Drip',
  'ટપક': 'Drip',
  'સ્પ્રિંકલર': 'Sprinkler',
  'ફુવારા': 'Sprinkler',
  'વરસાદ': 'Rainfed',
  'વરસાદી': 'Rainfed',
};

/// Spoken soil type → wire value.
const kSoilVoiceAliases = <String, String>{
  'loam': 'Loamy',
  'clayey': 'Clay',
  'sand': 'Sandy',
  'silt': 'Silty',
  'black': 'Black',
  'black soil': 'Black',
  'black cotton soil': 'Black',
  'red soil': 'Red',
  'alluvium': 'Alluvial',
  'दोमट': 'Loamy',
  'चिकनी': 'Clay',
  'रेतीली': 'Sandy',
  'बलुई': 'Sandy',
  'सिल्ट': 'Silty',
  'काली': 'Black',
  'लाल': 'Red',
  'जलोढ़': 'Alluvial',
  'ગોરાડુ': 'Loamy',
  'ચીકણી': 'Clay',
  'રેતાળ': 'Sandy',
  'કાંપ': 'Silty',
  'કાળી': 'Black',
  'લાલ': 'Red',
};

String? parseVoiceCrop(String input) =>
    matchVoiceOption(input, kFarmCrops, kCropVoiceAliases);

String? parseVoiceGrowthStage(String input) =>
    matchVoiceOption(input, kGrowthStages, kGrowthStageVoiceAliases);

String? parseVoiceIrrigation(String input) =>
    matchVoiceOption(input, kIrrigationTypes, kIrrigationVoiceAliases);

String? parseVoiceSoil(String input) =>
    matchVoiceOption(input, kSoilTypes, kSoilVoiceAliases);

/// Spoken number → acres.
const kNumberWordAcres = <String, double>{
  'one': 1,
  'two': 2,
  'three': 3,
  'four': 4,
  'five': 5,
  'six': 6,
  'seven': 7,
  'eight': 8,
  'nine': 9,
  'ten': 10,
  'एक': 1,
  'दो': 2,
  'तीन': 3,
  'चार': 4,
  'पाँच': 5,
  'पांच': 5,
  'छह': 6,
  'छः': 6,
  'सात': 7,
  'आठ': 8,
  'नौ': 9,
  'दस': 10,
  'पंद्रह': 15,
  'बीस': 20,
  'એક': 1,
  'બે': 2,
  'ત્રણ': 3,
  'ચાર': 4,
  'પાંચ': 5,
  'છ': 6,
  'સાત': 7,
  'આઠ': 8,
  'નવ': 9,
  'દસ': 10,
  'પંદર': 15,
  'વીસ': 20,
};

/// Words meaning "acre" — when one is present but no number was heard
/// ("an acre"), assume a single acre rather than re-asking.
const kAcreWords = <String>{'acre', 'acres', 'एकड़', 'ऐकड़', 'એકર'};

/// Parses a spoken farm size in acres. Accepts ASCII digits ("4.5"),
/// Devanagari/Gujarati digits ("४") and number words ("चार", "two").
/// Returns `null` for anything non-positive or unparseable.
double? parseVoiceFarmSize(String input) {
  // Digits are read before punctuation stripping so "4.5" survives.
  final ascii = indicDigitsToAscii(input);
  final digits = RegExp(r'\d+([.,]\d+)?').firstMatch(ascii);
  if (digits != null) {
    final raw = digits.group(0)!;
    // "1,000" is a thousands separator, "4,5" a decimal comma.
    final canonical = raw.contains(',') && RegExp(r',\d{3}$').hasMatch(raw)
        ? raw.replaceAll(',', '')
        : raw.replaceAll(',', '.');
    final value = double.tryParse(canonical);
    if (value != null && value > 0 && value <= 100000) return value;
  }

  final norm = normalizeVoiceInput(ascii);
  if (norm.isEmpty) return null;

  // Number words match whole tokens only ("one" must not fire in "someone").
  final words = norm.split(' ').toSet();
  for (final entry in kNumberWordAcres.entries) {
    if (words.contains(normalizeVoiceInput(entry.key))) return entry.value;
  }

  if (words.intersection(kAcreWords).isNotEmpty) return 1;
  return null;
}

/// Display/round-trip format for a parsed size: `4` not `4.0`.
String formatVoiceFarmSize(double acres) =>
    acres.toStringAsFixed(acres % 1 == 0 ? 0 : 1);
