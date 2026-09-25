/// Device text-to-speech voices enumerated via `FlutterTts.getVoices`, plus
/// the pure helpers the voice picker, the voice surface and tests share.
library;

/// One engine voice: [name] is the engine id passed back to `setVoice`
/// (e.g. `en-gb-x-rjs#female_2-local`), [locale] its BCP-47-ish tag
/// (`en-GB`, or `en_GB` on some engines).
class TtsVoiceOption {
  const TtsVoiceOption({required this.name, required this.locale});

  final String name;
  final String locale;

  /// Human label for picker rows: `en-gb-x-rjs#female_2-local` → `Female 2`,
  /// `en-US-SMTf00` → `SMTf00`, `Karen` → `Karen`. Falls back to [name].
  String get friendlyName {
    var label = name;
    final hash = label.indexOf('#');
    if (hash >= 0 && hash + 1 < label.length) {
      label = label.substring(hash + 1);
    } else {
      // Strip a leading locale prefix: "en-US-SMTf00" -> "SMTf00".
      label = label.replaceFirst(RegExp(r'^[a-z]{2,3}([-_][a-zA-Z]{2,4})?[-_]'), '');
    }
    label = label.replaceFirst(RegExp(r'-(local|network)$', caseSensitive: false), '');
    label = label.replaceAll(RegExp(r'[_-]+'), ' ').trim();
    if (label.isEmpty) return name;
    return label
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  /// Payload shape `FlutterTts.setVoice` expects.
  Map<String, String> toVoiceMap() => {'name': name, 'locale': locale};
}

/// Persisted voice choice for one app language.
///
/// [source] is the seam for the server-models follow-up: device voices use
/// `'device'` today, while a future `'server'` source can carry a model id
/// in [name]. The voice surface only applies device selections.
class TtsVoiceSelection {
  const TtsVoiceSelection({
    this.source = 'device',
    required this.name,
    required this.locale,
  });

  final String source;
  final String name;
  final String locale;

  bool get isDevice => source == 'device';
  bool get isValid => name.isNotEmpty && locale.isNotEmpty;

  Map<String, String> toMap() =>
      {'source': source, 'name': name, 'locale': locale};

  factory TtsVoiceSelection.fromMap(Map<dynamic, dynamic> map) =>
      TtsVoiceSelection(
        source: map['source'] as String? ?? 'device',
        name: map['name'] as String? ?? '',
        locale: map['locale'] as String? ?? '',
      );
}

/// Defensively parses `getVoices` output (a `List` of `{name, locale}`
/// maps). Anything malformed is skipped, never throws.
List<TtsVoiceOption> parseTtsVoices(Object? raw) {
  if (raw is! List) return const [];
  final options = <TtsVoiceOption>[];
  for (final entry in raw) {
    if (entry is! Map) continue;
    final name = entry['name'];
    final locale = entry['locale'];
    if (name is! String || locale is! String) continue;
    if (name.isEmpty || locale.isEmpty) continue;
    options.add(TtsVoiceOption(name: name, locale: locale));
  }
  return options;
}

/// Voices whose locale starts with [langCode] (`en` matches `en-US` and
/// `en_US`), sorted by locale then name for a stable picker list.
List<TtsVoiceOption> filterVoicesForLanguage(
    List<TtsVoiceOption> voices, String langCode) {
  final prefix = langCode.trim().toLowerCase();
  final matches =
      voices.where((v) => _norm(v.locale).startsWith(prefix)).toList();
  matches.sort((a, b) {
    final byLocale = _norm(a.locale).compareTo(_norm(b.locale));
    return byLocale != 0 ? byLocale : a.name.compareTo(b.name);
  });
  return matches;
}

String _norm(String locale) => locale.replaceAll('_', '-').toLowerCase();

/// Returns [savedName] when it still exists among [voices] (OS updates can
/// remove voices), else null so the caller falls back to the locale default.
String? resolveVoiceName(List<TtsVoiceOption> voices, String? savedName) {
  if (savedName == null || savedName.isEmpty) return null;
  return voices.any((v) => v.name == savedName) ? savedName : null;
}
