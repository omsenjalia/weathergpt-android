/// Helpers for cleaning model output for UI and TTS — port of
/// `lib/core/utils/markdown_utils.dart`.

export class MarkdownUtils {
  /// Strip markdown / widget blocks / emojis so TTS does not read syntax
  /// aloud. Tables are flattened into spoken sentences and LaTeX delimiters
  /// are removed so equations are not read as backslashes.
  static forSpeech(input: string): string {
    let text = input;
    // Remove fenced code / widget blocks
    text = text.replace(/```[\s\S]*?```/g, " ");
    text = text.replace(/`[^`]+`/g, " ");
    text = text.replace(/widget:\w+\s*/g, " ");
    // Headings (including emoji titles like "## 🌤️ WeatherGPT Live Status")
    text = text.replace(/^#{1,6}\s*.*$/gm, " ");
    // Table separator rows vanish; data rows become prose with every cell
    // divider spoken as a plain pause.
    text = text.replace(/^\s*\|[\s:\-|]+\|\s*$/gm, " ");
    text = text.replaceAll("|", " ");
    // LaTeX: keep the payload, drop the delimiters and layout commands the
    // speech engine cannot pronounce.
    text = text.replace(/\\[[\]()]/g, " ");
    text = text.replace(/\\(frac|dfrac|sqrt|text|mathbf|cdot|times|pm|approx)\b/g, " ");
    text = text.replace(/[{}^_]/g, " ");
    // Bold / italic / links / list markers
    text = text.replace(/\*\*|__/g, "");
    text = text.replace(/\*|_/g, "");
    text = text.replace(/\[([^\]]+)\]\([^)]+\)/g, "$1");
    text = text.replace(/^\s*[-*•]\s+/gm, "");
    // Drop common status titles if they leaked as plain text
    text = text.replace(/WeatherGPT\s+Live\s+Status/gi, " ");
    // Strip emoji & pictographs (TTS often reads them as "sun behind cloud")
    // eslint-disable-next-line no-misleading-character-class
    text = text.replace(/[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE0F}\u{200D}]/gu, " ");
    text = text.replace(/\s+/g, " ").trim();
    return text;
  }

  /// Speak the body only (not the short title/verdict).
  static spokenSummary(verdict: string, explanation: string): string {
    let body = explanation.trim() === "" ? verdict : explanation;
    // Prefer content after the first blank line / heading block
    const lines = body.split("\n");
    const kept: string[] = [];
    for (const line of lines) {
      const t = line.trim();
      if (t === "") {
        if (kept.length > 0) kept.push("");
        continue;
      }
      if (t.startsWith("#")) continue;
      if (/^WeatherGPT\s+Live/i.test(t)) continue;
      kept.push(t);
    }
    body = this.forSpeech(kept.join(" "));
    if (body === "") body = this.forSpeech(explanation);
    if (body.length <= 320) return body;
    const cut = body.slice(0, 320);
    const lastStop = Math.max(cut.lastIndexOf("."), cut.lastIndexOf("!"), cut.lastIndexOf("?"));
    return lastStop > 40 ? cut.slice(0, lastStop + 1) : `${cut}…`;
  }
}
