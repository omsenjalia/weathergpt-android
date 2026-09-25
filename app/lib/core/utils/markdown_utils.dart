/// Helpers for cleaning model output for UI and TTS.
class MarkdownUtils {
  MarkdownUtils._();

  /// Strip markdown / widget blocks / emojis so TTS does not read syntax aloud.
  ///
  /// Tables are flattened into spoken sentences ("Temp: 31. Rain: low") and
  /// LaTeX delimiters are removed so equations are not read as backslashes.
  static String forSpeech(String input) {
    var text = input;
    // Remove fenced code / widget blocks
    text = text.replaceAll(RegExp(r'```[\s\S]*?```'), ' ');
    text = text.replaceAll(RegExp(r'`[^`]+`'), ' ');
    text = text.replaceAll(RegExp(r'widget:\w+\s*'), ' ');
    // Headings (including emoji titles like "## 🌤️ WeatherGPT Live Status")
    text = text.replaceAll(RegExp(r'^#{1,6}\s*.*$', multiLine: true), ' ');
    // Table separator rows (|---|---|) vanish; data rows become prose with
    // every cell divider spoken as a plain pause.
    text = text.replaceAll(
      RegExp(r'^\s*\|[\s:\-|]+\|\s*$', multiLine: true),
      ' ',
    );
    text = text.replaceAll('|', ' ');
    // LaTeX: keep the payload, drop the delimiters and layout commands the
    // speech engine cannot pronounce.
    text = text.replaceAll(RegExp(r'\\[\[\]()]'), ' ');
    text = text.replaceAll(
      RegExp(r'\\(frac|dfrac|sqrt|text|mathbf|cdot|times|pm|approx)\b'),
      ' ',
    );
    text = text.replaceAll(RegExp(r'[{}^_]'), ' ');
    // Bold / italic / links / list markers
    text = text.replaceAll(RegExp(r'\*\*|__'), '');
    text = text.replaceAll(RegExp(r'\*|_'), '');
    text = text.replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1');
    text = text.replaceAll(RegExp(r'^\s*[-*•]\s+', multiLine: true), '');
    // Drop common status titles if they leaked as plain text
    text = text.replaceAll(
      RegExp(
        r'WeatherGPT\s+Live\s+Status',
        caseSensitive: false,
      ),
      ' ',
    );
    // Strip emoji & pictographs (TTS often reads them as "sun behind cloud")
    text = text.replaceAll(
      RegExp(
        r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE0F}\u{200D}]',
        unicode: true,
      ),
      ' ',
    );
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text;
  }

  /// Speak the body only (not the short title/verdict).
  static String spokenSummary(String verdict, String explanation) {
    var body = explanation.trim().isEmpty ? verdict : explanation;
    // Prefer content after the first blank line / heading block
    final lines = body.split('\n');
    final kept = <String>[];
    for (final line in lines) {
      final t = line.trim();
      if (t.isEmpty) {
        if (kept.isNotEmpty) kept.add('');
        continue;
      }
      if (t.startsWith('#')) continue;
      if (RegExp(r'^WeatherGPT\s+Live', caseSensitive: false).hasMatch(t)) {
        continue;
      }
      kept.add(t);
    }
    body = forSpeech(kept.join(' '));
    if (body.isEmpty) body = forSpeech(explanation);
    if (body.length <= 320) return body;
    final cut = body.substring(0, 320);
    final lastStop = cut.lastIndexOf(RegExp(r'[.!?]'));
    return lastStop > 40 ? cut.substring(0, lastStop + 1) : '$cut…';
  }
}
