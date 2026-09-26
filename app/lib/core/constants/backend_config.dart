/// Backend URL resolution — supports .env, --dart-define, and an emulator-only development fallback.
library;

const String kEmulatorBackendUrl = 'http://10.0.2.2:8888';

String resolveBackendUrl({String? dartDefineUrl, String? dotenvUrl}) {
  String? pick(String? raw) {
    if (raw == null) return null;
    var v = raw.trim();
    if (v.isEmpty) return null;
    if ((v.startsWith('"') && v.endsWith('"')) || (v.startsWith("'") && v.endsWith("'"))) {
      v = v.substring(1, v.length - 1).trim();
    }
    v = v.replaceAll(RegExp(r'/+$'), '');
    return v.isEmpty ? null : v;
  }
  return pick(dartDefineUrl) ?? pick(dotenvUrl) ?? kEmulatorBackendUrl;
}
