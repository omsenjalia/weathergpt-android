/// Defensive coercion helpers for decoded JSON.
///
/// Every accessor returns `null` for absent, wrong-typed, blank, `NaN` or
/// infinite values. Nothing ever defaults a missing measurement to `0`, because
/// a `0` temperature, `0 mm` of rain or a `0` rain probability is a *claim* the
/// backend did not make (feature/app/implementation_plan.md §4.1).
///
/// Pure Dart (no Flutter imports) so parsing is unit-testable in isolation.
library;

import 'dart:convert';

/// Nullable [num]; `null` for missing, non-numeric, NaN or infinite input.
num? jsonNum(Object? value) {
  if (value is num) return value.isFinite ? value : null;
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final parsed = num.tryParse(trimmed);
    return parsed != null && parsed.isFinite ? parsed : null;
  }
  return null;
}

/// Nullable [double] built on [jsonNum].
double? jsonDouble(Object? value) => jsonNum(value)?.toDouble();

/// Nullable [int] built on [jsonNum]; fractional values are accepted only when
/// they are integral, otherwise `null`.
int? jsonInt(Object? value) {
  final parsed = jsonNum(value);
  if (parsed == null) return null;
  if (parsed is int) return parsed;
  final rounded = parsed.roundToDouble();
  return (parsed - rounded).abs() < 1e-9 ? rounded.toInt() : null;
}

/// Nullable [String]; `null` for missing, empty or the literal text
/// `null`/`none`/`nan` that some serializers emit for absent values.
String? jsonString(Object? value) {
  if (value == null) return null;
  final text = value is String ? value : '$value';
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  final lowered = trimmed.toLowerCase();
  if (lowered == 'null' || lowered == 'none' || lowered == 'nan') return null;
  return trimmed;
}

/// Nullable [bool]; only real booleans and `true`/`false` strings qualify.
bool? jsonBool(Object? value) {
  if (value is bool) return value;
  if (value is String) {
    switch (value.trim().toLowerCase()) {
      case 'true':
        return true;
      case 'false':
        return false;
    }
  }
  return null;
}

/// Nullable nested object; `null` for missing or non-map values.
Map<String, dynamic>? jsonMap(Object? value) {
  if (value is Map) {
    return value.map((key, entry) => MapEntry('$key', entry));
  }
  return null;
}

/// Always a list; missing or non-list values collapse to `const []`.
List<dynamic> jsonList(Object? value) => value is List ? value : const [];

/// Parses an ISO-8601 timestamp into a UTC [DateTime], preserving the instant.
///
/// The backend contract documents UTC instants. A string carrying an explicit
/// `Z` or `±hh:mm` offset is honoured exactly; a naive string is read as UTC
/// and that assumption is reportable through [naiveTimestampAssumedUtc] so a
/// future contract can state its own timezone instead of the app guessing.
DateTime? jsonUtc(Object? value) {
  final raw = jsonString(value);
  if (raw == null) return null;
  try {
    if (_hasExplicitOffset(raw)) {
      final parsed = DateTime.parse(raw);
      return parsed.isUtc ? parsed : parsed.toUtc();
    }
    return DateTime.parse('${raw}Z').toUtc();
  } on FormatException {
    return null;
  }
}

bool _hasExplicitOffset(String raw) {
  final upper = raw.toUpperCase();
  if (upper.endsWith('Z')) return true;
  final timeIndex = upper.indexOf('T');
  if (timeIndex < 0) return false;
  final timePart = upper.substring(timeIndex + 1);
  return timePart.contains('+') || timePart.contains('-');
}

/// True when [raw] carries no timezone designator, meaning [jsonUtc] had to
/// assume UTC. Exposed for tests and for any UI that needs to caveat a time.
bool naiveTimestampAssumedUtc(Object? raw) {
  final text = jsonString(raw);
  return text != null && !_hasExplicitOffset(text);
}

/// Decodes a JSON object, returning `const {}` for empty or malformed input so
/// callers never crash on a truncated response.
Map<String, dynamic> decodeJsonObject(String? body) {
  if (body == null || body.trim().isEmpty) return const {};
  try {
    final decoded = jsonDecode(body);
    return decoded is Map ? jsonMap(decoded) ?? const {} : const {};
  } on FormatException {
    return const {};
  }
}
