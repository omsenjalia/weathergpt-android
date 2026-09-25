import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/models/app_mode.dart';
import '../../../core/services/api_client.dart';
import '../models/tts_voice_option.dart';

export '../../../core/models/app_mode.dart';

enum TemperatureUnit { celsius, fahrenheit }

class SettingsState {
  const SettingsState({
    this.displayName,
    this.email,
    this.language = 'en',
    this.userPersona = 'everyone',
    this.units = TemperatureUnit.celsius,
    this.ttsVoiceLocale = 'en-US',
    this.ttsSpeed = 0.85,
    this.ttsVoices = const {},
    this.notificationsEnabled = const {
      'weather_alerts': true,
      'imd_warnings': true,
      'daily_summary': false,
    },
  });

  final String? displayName;
  final String? email;
  final String language;
  final String userPersona;
  final TemperatureUnit units;
  final String ttsVoiceLocale;
  final double ttsSpeed;
  /// Persisted voice choice per app language code ('en' -> selection).
  /// Absent means the system default voice for that language.
  final Map<String, TtsVoiceSelection> ttsVoices;
  final Map<String, bool> notificationsEnabled;

  /// Validated product mode derived from the persisted persona string.
  ///
  /// A persona value this build does not recognise de-escalates to
  /// [AppMode.everyone]; it never escalates. A user-selected Researcher mode
  /// grants no server permission of its own — authorization stays server-side.
  AppMode get mode => appModeFromName(userPersona) ?? AppMode.everyone;

  /// True when the persisted persona string is a recognised mode.
  bool get hasRecognisedPersona => appModeFromName(userPersona) != null;

  SettingsState copyWith(
          {String? displayName,
          String? email,
          String? language,
          String? userPersona,
          TemperatureUnit? units,
          String? ttsVoiceLocale,
          double? ttsSpeed,
          Map<String, TtsVoiceSelection>? ttsVoices,
          Map<String, bool>? notificationsEnabled}) =>
      SettingsState(
          displayName: displayName ?? this.displayName,
          email: email ?? this.email,
          language: language ?? this.language,
          userPersona: userPersona ?? this.userPersona,
          units: units ?? this.units,
          ttsVoiceLocale: ttsVoiceLocale ?? this.ttsVoiceLocale,
          ttsSpeed: ttsSpeed ?? this.ttsSpeed,
          ttsVoices: ttsVoices ?? this.ttsVoices,
          notificationsEnabled:
              notificationsEnabled ?? this.notificationsEnabled);
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(_load());

  static SettingsState _load() {
    if (!Hive.isBoxOpen('settings')) return const SettingsState();
    final box = Hive.box('settings');
    final rawNotifications = box.get('notifications_enabled');
    final notifications = rawNotifications is Map
        ? rawNotifications.map((key, value) => MapEntry('$key', value == true))
        : const <String, bool>{
            'weather_alerts': true,
            'imd_warnings': true,
            'daily_summary': false
          };
    return SettingsState(
      displayName: box.get('display_name') as String?,
      email: box.get('email') as String?,
      language: box.get('language', defaultValue: 'en') as String,
      userPersona: box.get('user_persona', defaultValue: 'everyone') as String,
      units:
          box.get('temperature_unit', defaultValue: 'celsius') == 'fahrenheit'
              ? TemperatureUnit.fahrenheit
              : TemperatureUnit.celsius,
      ttsVoiceLocale:
          box.get('tts_voice_locale', defaultValue: 'en-US') as String,
      ttsSpeed: (box.get('tts_speed', defaultValue: 0.85) as num).toDouble(),
      ttsVoices: _loadVoices(box.get('tts_voices')),
      notificationsEnabled: notifications,
    );
  }

  static Map<String, TtsVoiceSelection> _loadVoices(Object? raw) {
    if (raw is! Map) return const {};
    final voices = <String, TtsVoiceSelection>{};
    raw.forEach((key, value) {
      if (key is! String || value is! Map) return;
      final selection = TtsVoiceSelection.fromMap(value);
      if (selection.isValid) voices[key] = selection;
    });
    return voices;
  }

  /// Single persistence path for every setting.
  Future<void> _put(String key, Object? value) async {
    final box = await Hive.openBox<dynamic>('settings');
    await box.put(key, value);
  }

  Future<void> updateProfile(String name, String email) async {
    state = state.copyWith(displayName: name, email: email);
    await _put('display_name', name);
    await _put('email', email);
  }

  Future<void> updateLanguage(String code) async {
    state = state.copyWith(language: code);
    ApiClient.instance.setLanguage(code);
    await _put('language', code);
  }

  /// Stores the persona as its canonical wire name.
  ///
  /// Unknown values are rejected rather than persisted, so a future build can
  /// never read a typo as a privileged mode.
  Future<void> updatePersona(String persona) async {
    final mode = appModeFromName(persona);
    if (mode == null) throw AppModeException(persona);
    state = state.copyWith(userPersona: mode.wire);
    await _put('user_persona', mode.wire);
  }

  Future<void> updateUnits(TemperatureUnit units) async {
    state = state.copyWith(units: units);
    await _put(
      'temperature_unit',
      units == TemperatureUnit.fahrenheit ? 'fahrenheit' : 'celsius',
    );
  }

  Future<void> updateTtsSpeed(double speed) async {
    state = state.copyWith(ttsSpeed: speed);
    await _put('tts_speed', speed);
  }

  Future<void> updateTtsVoiceLocale(String locale) async {
    state = state.copyWith(ttsVoiceLocale: locale);
    await _put('tts_voice_locale', locale);
  }

  /// Remembers [selection] as the voice for [langCode].
  Future<void> updateTtsVoice(
      String langCode, TtsVoiceSelection selection) async {
    final voices = {...state.ttsVoices, langCode: selection};
    state = state.copyWith(ttsVoices: voices);
    await _put(
        'tts_voices', voices.map((k, v) => MapEntry(k, v.toMap())));
  }

  /// Forgets the voice for [langCode] (system default applies again).
  Future<void> clearTtsVoice(String langCode) async {
    if (!state.ttsVoices.containsKey(langCode)) return;
    final voices = {...state.ttsVoices}..remove(langCode);
    state = state.copyWith(ttsVoices: voices);
    await _put(
        'tts_voices', voices.map((k, v) => MapEntry(k, v.toMap())));
  }

  Future<void> updateVoiceSettings(String locale, double speed) async {
    state = state.copyWith(ttsVoiceLocale: locale, ttsSpeed: speed);
    await _put('tts_voice_locale', locale);
    await _put('tts_speed', speed);
  }

  Future<void> updateNotificationPref(String key, bool enabled) async {
    final prefs = {...state.notificationsEnabled, key: enabled};
    state = state.copyWith(notificationsEnabled: prefs);
    await _put('notifications_enabled', prefs);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
    (ref) => SettingsNotifier());
