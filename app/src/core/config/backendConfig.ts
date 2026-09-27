/// Backend URL resolution — port of `lib/core/constants/backend_config.dart`.
/// Supports EXPO_PUBLIC_BACKEND_URL and an emulator-only development fallback;
/// release builds must configure the deployed backend explicitly.

export const EMULATOR_BACKEND_URL = "http://10.0.2.2:8888";

function pick(raw: string | null | undefined): string | null {
  if (raw === null || raw === undefined) return null;
  let v = raw.trim();
  if (v === "") return null;
  if ((v.startsWith('"') && v.endsWith('"')) || (v.startsWith("'") && v.endsWith("'"))) {
    v = v.slice(1, -1).trim();
  }
  v = v.replace(/\/+$/, "");
  return v === "" ? null : v;
}

/// `defineUrl` mirrors the Dart `--dart-define` slot: EXPO_PUBLIC_BACKEND_URL
/// in this port. `dotenvUrl` is the bundled .env value.
export function resolveBackendUrl(opts?: { defineUrl?: string | null; dotenvUrl?: string | null }): string {
  const defineUrl = opts?.defineUrl ?? null;
  const dotenvUrl = opts?.dotenvUrl ?? null;
  return pick(defineUrl) ?? pick(dotenvUrl) ?? EMULATOR_BACKEND_URL;
}
