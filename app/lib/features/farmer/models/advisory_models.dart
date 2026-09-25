/// Pure models and mapping for the backend `/advisory` payload.
///
/// Kept free of Flutter imports so the mapping rules are unit-testable in
/// isolation. The backend returns:
///
/// ```json
/// {
///   "summary": "Advisory for Wheat: 1/2 day(s) look favourable ...",
///   "advisory_engine": "system-one+thresholds" | "thresholds",
///   "ai": {"enabled": true, "applied": true, "mean_confidence": 0.885,
///          "overall_verdict": "good" | "caution" | "avoid", ...},
///   "windows": [
///     {"date": "2026-09-18", "suitability": "good" | "caution" | "poor",
///      "summary": "...", "best_window": "Best: 6–10 AM",
///      "hourly": {"irrigation":  [{"hour": "00:00", "suitability": "avoid"}, ...],
///                 "spraying":    [...], "field_work": [...]},
///      "ai": {"spray": {"score": 3.6, "confidence": 0.88, "band": "good"}, ...}}
///   ]
/// }
/// ```
library;

/// Which slice of the forecast the action-window screen is showing.
enum ActionWindowTab { today, tomorrow, sevenDay }

/// Visual band for one activity in one time bucket.
enum Suitability { good, caution, avoid, neutral }

/// Where the currently displayed advisory came from.
enum AdvisorySource { systemOne, thresholds, offline }

class HourlySuitability {
  const HourlySuitability(this.suitability, {this.hours = 1});
  final Suitability suitability;
  final int hours;
}

/// Maps a backend band name onto the visual enum. Unknown/missing -> neutral.
Suitability suitabilityFromName(String? name) {
  switch (name) {
    case 'good':
      return Suitability.good;
    case 'caution':
      return Suitability.caution;
    case 'poor':
    case 'avoid':
      return Suitability.avoid;
    default:
      return Suitability.neutral;
  }
}

int _severity(Suitability value) => switch (value) {
      Suitability.avoid => 3,
      Suitability.caution => 2,
      Suitability.good => 1,
      Suitability.neutral => 0,
    };

Suitability _worstOf(Suitability a, Suitability b) =>
    _severity(a) >= _severity(b) ? a : b;

Map<String, dynamic>? _cellMap(Object? cell) =>
    cell is Map ? Map<String, dynamic>.from(cell) : null;

/// Collapses the backend's 24 hourly cells into `bucketCount` visual cells
/// (default 12 two-hour buckets for the action-window bars), taking the worst
/// band within each bucket so caution is never hidden by averaging.
List<HourlySuitability> collapseHourlyCells(List<dynamic> cells,
    {int bucketCount = 12}) {
  if (cells.isEmpty) return const [];
  if (bucketCount < 1) bucketCount = 1;
  final size =
      (cells.length / bucketCount).ceil().clamp(1, cells.length).toInt();
  final result = <HourlySuitability>[];
  for (var start = 0; start < cells.length; start += size) {
    var worst = Suitability.neutral;
    var count = 0;
    for (var i = start; i < start + size && i < cells.length; i++) {
      worst = _worstOf(worst, suitabilityFromName(_cellMap(cells[i])?['suitability'] as String?));
      count++;
    }
    result.add(HourlySuitability(worst, hours: count));
  }
  return result;
}

/// One visual cell per forecast day (for the 7-day tab).
List<HourlySuitability> dailySuitabilityCells(List<dynamic> windows,
    {int maxDays = 7}) {
  final cells = <HourlySuitability>[];
  for (final window in windows.take(maxDays)) {
    cells.add(HourlySuitability(
        suitabilityFromName(_cellMap(window)?['suitability'] as String?)));
  }
  return cells;
}

/// True when the backend actually applied System One answers (not just enabled).
bool aiApplied(Map<String, dynamic>? ai) =>
    ai != null && ai['enabled'] == true && ai['applied'] == true;

/// Top-level verdict choice reported by System One, if any.
///
/// This is a *whole-request* verdict (the backend's highest-confidence overall
/// answer). It must not be rendered as one specific day's decision — use
/// [dayDecisionFrom] for that.
String? aiOverallVerdict(Map<String, dynamic>? ai) {
  final value = ai?['overall_verdict'];
  return value is String ? value : null;
}

/// The decision the backend attached to one specific forecast day.
///
/// `/advisory` returns `windows[i].ai.overall = {choice, confidence}`. Reading
/// the day's own decision is what stops a global, highest-confidence verdict
/// from being shown as "today's" answer when it was actually computed for
/// another day.
class DayDecision {
  const DayDecision({this.choice, this.confidence});

  /// Absent decision — the day has no verdict to show.
  static const DayDecision none = DayDecision();

  final String? choice;
  final double? confidence;

  bool get isPresent => choice != null && choice!.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      other is DayDecision &&
      other.choice == choice &&
      other.confidence == confidence;

  @override
  int get hashCode => Object.hash(choice, confidence);

  @override
  String toString() => 'DayDecision($choice, $confidence)';
}

Map<String, dynamic>? _castMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : null;

/// Extracts the per-day decision from one `/advisory` window entry.
DayDecision dayDecisionFrom(Map<String, dynamic>? window) {
  final overall = _castMap(_castMap(window?['ai'])?['overall']);
  if (overall == null) return DayDecision.none;
  final choice = overall['choice'];
  final confidence = overall['confidence'];
  return DayDecision(
    choice: choice is String ? choice : null,
    confidence: confidence is num ? confidence.toDouble() : null,
  );
}

/// Farmer-facing verdict line derived from a daily band name.
String verdictTextForBand(String? band) {
  switch (band) {
    case 'good':
      return 'Good day for field work';
    case 'caution':
      return 'A workable day with caution';
    case 'poor':
    case 'avoid':
      return 'Avoid heavy farm work today';
    default:
      return 'Advisory ready';
  }
}

/// Mean confidence across the System One answers the backend acted on.
double? aiMeanConfidence(Map<String, dynamic>? ai) {
  final value = ai?['mean_confidence'];
  return value is num ? value.toDouble() : null;
}
