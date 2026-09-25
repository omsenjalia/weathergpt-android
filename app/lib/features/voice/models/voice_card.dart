/// Structured card the backend may attach to a `/chat` or `/voice` answer.
///
/// The card is **optional and additive**: when the backend sends text only,
/// there are no stats and no forecast rows, and the UI must say so rather than
/// substitute plausible-looking numbers. Nothing here is derived client-side
/// from the prose.
///
/// Pure Dart (no Flutter imports) so card parsing is unit-testable.
library;

import '../../../core/models/json_values.dart';

/// Visual intent of one stat, as named by the backend. Colour stays a UI
/// concern — the app maps the tone, it does not accept colour values.
enum CardTone { neutral, good, caution, avoid }

CardTone cardToneFromName(Object? value) {
  switch (jsonString(value)?.toLowerCase()) {
    case 'good':
    case 'safe':
    case 'favourable':
      return CardTone.good;
    case 'caution':
    case 'watch':
      return CardTone.caution;
    case 'avoid':
    case 'poor':
    case 'risk':
      return CardTone.avoid;
    default:
      return CardTone.neutral;
  }
}

class VoiceCardStat {
  const VoiceCardStat(
      {required this.label, required this.value, this.tone = CardTone.neutral});
  final String label;
  final String value;
  final CardTone tone;
}

class VoiceCardDay {
  const VoiceCardDay({
    required this.label,
    required this.temperature,
    this.rainfall,
    this.condition,
  });
  final String label;
  final String temperature;

  /// Rendered as sent. A missing value stays `null` and shows an em dash; it
  /// is never rendered as `0 mm`.
  final String? rainfall;
  final String? condition;
}

class VoiceCard {
  const VoiceCard({
    this.label,
    this.verdict,
    this.explanation,
    this.ctaLabel,
    this.stats = const [],
    this.forecast = const [],
    this.source,
    this.confidence,
  });

  final String? label;
  final String? verdict;
  final String? explanation;
  final String? ctaLabel;
  final List<VoiceCardStat> stats;
  final List<VoiceCardDay> forecast;

  /// Data source / run the card is attributed to, when the backend says.
  final String? source;

  /// Decision confidence, kept distinct from any weather-event probability.
  final double? confidence;

  /// Parses an optional card. Returns `null` when the backend sent none, so
  /// callers can distinguish "no card" from "empty card".
  static VoiceCard? fromJson(Object? raw) {
    final data = jsonMap(raw);
    if (data == null) return null;

    final stats = <VoiceCardStat>[];
    for (final item in jsonList(data['stats'])) {
      final row = jsonMap(item);
      if (row == null) continue;
      final label = jsonString(row['label']);
      final value = jsonString(row['value']);
      if (label == null || value == null) continue;
      stats.add(VoiceCardStat(
          label: label, value: value, tone: cardToneFromName(row['tone'])));
    }

    final forecast = <VoiceCardDay>[];
    for (final item in jsonList(data['forecast'])) {
      final row = jsonMap(item);
      if (row == null) continue;
      final label = jsonString(row['day'] ?? row['label'] ?? row['date']);
      if (label == null) continue;
      forecast.add(VoiceCardDay(
        label: label,
        temperature: jsonString(row['temperature'] ?? row['temp']) ?? '—',
        rainfall: jsonString(row['rainfall'] ?? row['rainfall_mm'] ?? row['precip_mm']),
        condition: jsonString(row['condition'] ?? row['icon']),
      ));
    }

    return VoiceCard(
      label: jsonString(data['label']),
      verdict: jsonString(data['verdict']),
      explanation: jsonString(data['explanation']),
      ctaLabel: jsonString(data['cta_label'] ?? data['cta']),
      stats: stats,
      forecast: forecast,
      source: jsonString(data['source'] ?? data['provider']),
      confidence: jsonDouble(data['confidence']),
    );
  }
}
