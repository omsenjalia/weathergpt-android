import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

/// Shared renderer for every AI-authored surface in the app (chat answers,
/// voice results, advisory notes).
///
/// Built on `gpt_markdown` so LLM output renders the way modern assistants
/// present it:
/// - GFM tables with a real grid, header tint, zebra striping and horizontal
///   scrolling when columns exceed the bubble width
/// - fenced code blocks with a language label and a working copy button
/// - inline LaTeX (`\(E = mc^2\)`) and display math (`\[ … \]`) that scrolls
///   horizontally instead of overflowing
/// - styled blockquotes, task lists, horizontal rules and tappable links
///
/// The renderer is also defensive about WeatherGPT's own `widget:` fence
/// protocol: those blocks are native-UI instructions, not content, and are
/// stripped before parsing so they can never leak into the conversation.
class RichMarkdown extends StatelessWidget {
  const RichMarkdown(
    this.data, {
    super.key,
    this.baseStyle,
    this.textColor,
    this.accentColor,
    this.mutedColor,
    this.selectable = true,
  });

  final String data;

  /// Base text style for body copy. Size/height/font family come from here;
  /// colors fall back to [textColor] and then the ambient theme.
  final TextStyle? baseStyle;

  /// Explicit body color for surfaces that do not inherit a sensible theme
  /// (chat bubbles, voice result cards). Headings, lists and tables derive
  /// from it.
  final Color? textColor;

  /// Accent used for links, inline code chips and blockquote bars.
  final Color? accentColor;

  /// Muted color for horizontal rules and secondary chrome.
  final Color? mutedColor;

  /// Wrap in a [SelectionArea] so users can long-press-copy answers.
  final bool selectable;

  /// Removes native widget fences and json payloads the UI renders itself.
  static String sanitize(String input) {
    var text = input
        .replaceAll(RegExp(r'```widget:[\s\S]*?```'), '')
        .replaceAll(RegExp(r'```json[\s\S]*?```'), '');
    // A stray fence the model forgot to close must not swallow the answer.
    if ('```'.allMatches(text).length.isOdd) text = '$text\n```';
    return text.trim();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final onSurface = textColor ??
        (brightness == Brightness.dark
            ? const Color(0xFFF1F5F9)
            : const Color(0xFF0F172A));
    final accent = accentColor ?? Theme.of(context).colorScheme.primary;
    final muted = mutedColor ?? onSurface.withValues(alpha: 0.45);
    final base = (baseStyle ?? const TextStyle())
        .copyWith(color: onSurface, height: 1.5);

    final styleSheet = GptMarkdownStyleSheet(
      heading: HeadingStyle(
        textStyle: TextStyle(
          color: onSurface,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          height: 1.25,
        ),
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        showDivider: false,
      ),
      link: LinkStyle(
        color: accent,
        fontWeight: FontWeight.w600,
        decoration: TextDecoration.underline,
        decorationThickness: 1.5,
      ),
      inlineCode: InlineCodeStyle(
        color: onSurface,
        backgroundColor: onSurface.withValues(alpha: 0.08),
        borderColor: onSurface.withValues(alpha: 0.10),
        borderWidth: 1,
        borderRadius: const Radius.circular(6),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      ),
      list: ListStyle(
        bulletColor: onSurface.withValues(alpha: 0.65),
        markerTextStyle: TextStyle(
          color: onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      blockQuote: BlockQuoteStyle(
        barWidth: 3,
        barColor: accent,
        barRadius: const Radius.circular(2),
        backgroundColor: accent.withValues(alpha: 0.06),
        padding: const EdgeInsetsDirectional.only(
          start: 12,
          top: 8,
          bottom: 8,
        ),
        margin: const EdgeInsets.symmetric(vertical: 8),
        textStyle: TextStyle(color: onSurface.withValues(alpha: 0.92)),
      ),
      codeBlock: CodeBlockStyle(
        backgroundColor: brightness == Brightness.dark
            ? const Color(0xFF0A0F1C)
            : const Color(0xFF0F172A),
        borderColor: onSurface.withValues(alpha: 0.08),
        borderWidth: 1,
        borderRadius: const Radius.circular(12),
        textColor: const Color(0xFFE2E8F0),
        showLanguageLabel: true,
        languageStyle: const TextStyle(
          color: Color(0xFF94A3B8),
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
        showCopyButton: true,
      ),
      table: TableStyle(
        borderColor: onSurface.withValues(alpha: 0.12),
        borderWidth: 1,
        borderRadius: const Radius.circular(12),
        cellPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        headerBackground: accent.withValues(alpha: 0.10),
        headerTextStyle: TextStyle(
          color: onSurface,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
        rowStripeColor: onSurface.withValues(alpha: 0.035),
      ),
      latex: LatexStyle(
        textStyle: TextStyle(color: onSurface),
        scrollBlockHorizontally: true,
        padding: const EdgeInsets.symmetric(vertical: 6),
      ),
      hr: HrStyle(
        thickness: 1,
        color: muted.withValues(alpha: 0.5),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );

    final markdown = GptMarkdown(
      sanitize(data),
      style: base,
      styleSheet: styleSheet,
      onLinkTap: _openLink,
    );

    if (!selectable) return markdown;
    return SelectionArea(child: markdown);
  }

  Future<void> _openLink(String url, String? title) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Nothing sensible to do for an unlaunchable link; never crash chat.
    }
  }
}
