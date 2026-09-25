/// Maps a backend chat/voice answer onto the result card.
///
/// Split out of `voice_provider.dart` so the mapping runs in tests without
/// instantiating speech_to_text / flutter_tts platform channels.
///
/// The card's numbers come **only** from a structured [VoiceCard] the backend
/// chose to send. When the backend answers with prose alone, the card carries no
/// stats and no forecast rows — substituting a plausible-looking rain
/// percentage, soil-moisture reading, growth stage or fixed weekday forecast is
/// precisely the behaviour the implementation plan prohibits.
library;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/markdown_utils.dart';
import '../models/voice_card.dart';

enum ResultType { irrigation, rainForecast, general, cropStatus, researchQuery }

class ResultStat {
  const ResultStat(this.label, this.value, {this.color});
  final String label;
  final String value;
  final Color? color;
}

class ForecastDay {
  const ForecastDay(this.day, this.icon, this.temperature, this.rainfall);
  final String day;
  final IconData icon;
  final String temperature;
  final String rainfall;
}

class VoiceResponse {
  const VoiceResponse(
      {required this.transcript,
      required this.type,
      required this.accent,
      required this.label,
      required this.verdict,
      required this.explanation,
      required this.stats,
      required this.forecast,
      required this.ctaLabel});
  final String transcript;
  final ResultType type;
  final Color accent;
  final String label;
  final String verdict;
  final String explanation;
  final List<ResultStat> stats;
  final List<ForecastDay> forecast;
  final String ctaLabel;
}

/// Greetings / intro replies should not show irrigation/rain mock cards.
bool looksLikeGreetingOrIntro(String query, String lowerBody) {
  const greetings = {
    'hi',
    'hello',
    'hey',
    'yo',
    'sup',
    'help',
    'thanks',
    'thank you',
    'namaste',
    'namaskar',
    'hola',
    'હેલો',
    'હાય',
    'નમસ્તે',
    'नमस्ते',
    'हैलो',
    'हाय',
  };
  final q = query.trim().toLowerCase();
  if (greetings.contains(q)) return true;
  if (q.startsWith('what do you') || q.startsWith('who are you')) {
    return true;
  }
  if (lowerBody.contains("i'm **weathergpt**") ||
      lowerBody.contains('i am weathergpt') ||
      lowerBody.contains("couldn't fetch live weather") ||
      lowerBody.contains('try asking:') ||
      lowerBody.contains('weathergpt છું') ||
      lowerBody.contains('weathergpt हूं') ||
      lowerBody.contains('weathergpt हूँ')) {
    return true;
  }
  final hasNumbers =
      RegExp(r'\d+\s*°|\d+\s*mm|\d+%').hasMatch(lowerBody);
  if (!hasNumbers &&
      lowerBody.contains('weathergpt') &&
      (lowerBody.contains('help') ||
          lowerBody.contains('ask') ||
          lowerBody.contains('સલાહ') ||
          lowerBody.contains('જણાવો') ||
          lowerBody.contains('advisor') ||
          lowerBody.contains('હવામાન'))) {
    return true;
  }
  return false;
}

/// Classifies the ask so the card can pick its chrome (accent, label, CTA).
///
/// Classification only chooses presentation. It never produces values: the
/// numbers on a card come from the backend or not at all.
ResultType typeForQuery(String normalizedQuery, bool isMeta) {
  if (isMeta) return ResultType.general;
  if (normalizedQuery.contains('irrigat')) return ResultType.irrigation;
  if (normalizedQuery.contains('rain') ||
      normalizedQuery.contains('forecast')) {
    return ResultType.rainForecast;
  }
  if (normalizedQuery.contains('crop') || normalizedQuery.contains('wheat')) {
    return ResultType.cropStatus;
  }
  return ResultType.general;
}

/// Presentation-only defaults per result type. No measurements live here.
({Color accent, String label, String ctaLabel}) chromeForType(ResultType type) =>
    switch (type) {
      ResultType.irrigation => (
          accent: AppColors.statusAmber,
          label: 'Irrigation Recommendation',
          ctaLabel: 'View Farm Action Windows'
        ),
      ResultType.rainForecast => (
          accent: AppColors.researcherBlue,
          label: 'Rain Forecast',
          ctaLabel: 'View Detailed Forecast'
        ),
      ResultType.cropStatus => (
          accent: AppColors.farmerGreen,
          label: 'Crop Status',
          ctaLabel: 'View Farm Action Windows'
        ),
      ResultType.general => (
          accent: AppColors.researcherBlue,
          label: 'WeatherGPT',
          ctaLabel: 'Ask about weather'
        ),
      ResultType.researchQuery => (
          accent: AppColors.researcherBlue,
          label: 'Research Query',
          ctaLabel: 'Ask about weather'
        ),
    };

Color toneColor(CardTone tone) => switch (tone) {
      CardTone.good => AppColors.statusGreenText,
      CardTone.caution => AppColors.statusAmber,
      CardTone.avoid => AppColors.statusRed,
      CardTone.neutral => AppColors.researcherBlue,
    };

IconData iconForCondition(String? condition) {
  final c = (condition ?? '').toLowerCase();
  if (c.contains('thunder')) return Icons.thunderstorm_outlined;
  if (c.contains('snow')) return Icons.ac_unit;
  if (c.contains('rain') || c.contains('drizzle')) {
    return Icons.water_drop_outlined;
  }
  if (c.contains('fog') || c.contains('mist') || c.contains('haze')) {
    return Icons.foggy;
  }
  if (c.contains('cloud') || c.contains('overcast')) {
    return Icons.cloud_outlined;
  }
  if (c.contains('clear') || c.contains('sun')) return Icons.wb_sunny_outlined;
  return Icons.help_outline;
}

/// Maps a backend answer onto the result card.
///
/// Stats and forecast rows come **only** from a structured card the backend
/// chose to send ([VoiceCard]). When it sends prose alone the card shows the
/// prose with empty stats — fabricating a rain percentage, a soil-moisture
/// reading, a growth stage or a fixed weekday forecast here is exactly the
/// behaviour the implementation plan prohibits.
VoiceResponse mapBackendAnswer(String query, String response,
    {Map<String, dynamic>? raw}) {
  final normalized = query.toLowerCase().trim();
  final bodyRaw = response.trim();
  final lowerBody = bodyRaw.toLowerCase();
  final isMeta = looksLikeGreetingOrIntro(normalized, lowerBody);

  final type = typeForQuery(normalized, isMeta);
  final chrome = chromeForType(type);
  final card =
      isMeta ? null : VoiceCard.fromJson(raw?['card'] ?? raw?['result']);

  // The prose answer is authoritative; a card explanation only fills a gap.
  final body = bodyRaw.isNotEmpty
      ? bodyRaw
      : (card?.explanation ?? '');
  final plain = MarkdownUtils.forSpeech(body);
  final firstLine = plain
      .split(RegExp(r'[.!?;\n]'))
      .map((s) => s.trim())
      .firstWhere((s) => s.isNotEmpty, orElse: () => '');
  final verdictSource = card?.verdict ?? firstLine;
  final verdict = verdictSource.length > 90
      ? '${verdictSource.substring(0, 90)}…'
      : verdictSource;

  return VoiceResponse(
    transcript: query,
    type: type,
    accent: chrome.accent,
    label: isMeta ? 'Assistant' : (card?.label ?? chrome.label),
    // Empty verdict means "the backend gave us nothing to headline" — the UI
    // renders a neutral title rather than inventing a sunny one.
    verdict: verdict,
    explanation: body,
    stats: [
      for (final stat in card?.stats ?? const <VoiceCardStat>[])
        ResultStat(stat.label, stat.value, color: toneColor(stat.tone)),
    ],
    forecast: [
      for (final day in card?.forecast ?? const <VoiceCardDay>[])
        ForecastDay(
          day.label,
          iconForCondition(day.condition),
          day.temperature,
          day.rainfall ?? '—',
        ),
    ],
    ctaLabel: isMeta ? 'Ask about weather' : (card?.ctaLabel ?? chrome.ctaLabel),
  );
}
