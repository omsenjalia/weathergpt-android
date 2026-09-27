/// The sole HTTP entry point — port of `lib/core/services/api_client.dart`
/// (Dio → fetch). Keep API keys on the server, never in this app. Every call
/// is timed, summarised and pushed into the request ring buffer.

import Constants from "expo-constants";

import { resolveBackendUrl } from "../config/backendConfig";
import { NetworkError, ServerError, ValidationError } from "../errors/appErrors";
import { decodeJsonObject } from "../models/jsonValues";
import { recordRequest } from "./requestLog";

let language = "en";

export function setApiLanguage(value: string): void {
  language = value;
}

function envBackendUrl(): string | null {
  // Expo public env vars survive `expo export`; Constants mirrors them too.
  const fromProcess = typeof process !== "undefined" ? process.env.EXPO_PUBLIC_BACKEND_URL : undefined;
  const fromConstants = (Constants.expoConfig?.extra as Record<string, unknown> | undefined)?.BACKEND_URL;
  return (typeof fromProcess === "string" ? fromProcess : null) ?? (typeof fromConstants === "string" ? fromConstants : null);
}

export function apiBaseUrl(): string {
  return resolveBackendUrl({
    defineUrl: envBackendUrl(),
    dotenvUrl: null,
  });
}

function summarizeBody(body: Record<string, unknown> | null): string | null {
  if (!body) return null;
  const parts: string[] = [];
  const prov = body.provenance;
  const provMap = prov !== null && typeof prov === "object" ? (prov as Record<string, unknown>) : null;
  const source = body.selected_source ?? provMap?.selected_source ?? body.source;
  if (source !== null && source !== undefined) parts.push(`source=${source}`);
  const run = provMap?.run_id ?? body.run_id;
  if (run !== null && run !== undefined) parts.push(`run=${run}`);
  if (body.status !== null && body.status !== undefined) parts.push(`status=${body.status}`);
  if (Array.isArray(body.hourly)) parts.push(`hourly=${body.hourly.length}`);
  if (Array.isArray(body.daily)) parts.push(`daily=${body.daily.length}`);
  if (Array.isArray(body.forecast)) parts.push(`forecast=${body.forecast.length}`);
  if (body.degraded === true) parts.push("DEGRADED");
  return parts.length === 0 ? null : parts.join(" · ");
}

function mapFetchError(error: unknown, status: number, bodyText: string | null): Error {
  if (error instanceof NetworkError || error instanceof ServerError || error instanceof ValidationError) {
    return error;
  }
  const detail = (() => {
    if (!bodyText) return null;
    const data = decodeJsonObject(bodyText);
    if (data["detail"] !== null && data["detail"] !== undefined) return String(data["detail"]);
    if (data["message"] !== null && data["message"] !== undefined) return String(data["message"]);
    return null;
  })();

  if (error instanceof Error && error.name === "AbortError") {
    return new NetworkError("WeatherGPT is taking longer than usual. Please try again in a moment.");
  }
  if (error instanceof TypeError) {
    return new NetworkError("Could not reach WeatherGPT. Check your connection and try again.");
  }
  if (status === 400 || status === 422) {
    return new ValidationError(detail ?? "Please check the requested weather data.");
  }
  return new ServerError(detail ?? "WeatherGPT is temporarily unavailable. Please try again.");
}

async function request(
  method: "GET" | "POST",
  path: string,
  opts?: { query?: Record<string, unknown>; data?: unknown },
): Promise<Record<string, unknown>> {
  const startedAt = new Date();
  const startedMs = Date.now();
  const query = method === "GET" ? opts?.query ?? {} : {};
  let status = 0;
  let bodyText: string | null = null;

  const url = new URL(apiBaseUrl() + path);
  for (const [key, value] of Object.entries(query)) {
    if (value !== null && value !== undefined) url.searchParams.set(key, String(value));
  }

  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 60_000);
    let response: Response;
    try {
      response = await fetch(url.toString(), {
        method,
        headers: {
          Accept: "application/json",
          "Accept-Language": language,
          ...(method === "POST" ? { "Content-Type": "application/json" } : {}),
        },
        body: method === "POST" ? JSON.stringify(opts?.data ?? {}) : undefined,
        signal: controller.signal,
      });
      status = response.status;
      bodyText = await response.text();
    } finally {
      clearTimeout(timeout);
    }
    if (status >= 500) {
      throw new ServerError("WeatherGPT is temporarily unavailable. Please try again.");
    }
    if (status >= 400) {
      throw mapFetchError(new Error(`HTTP ${status}`), status, bodyText);
    }
    let body: Record<string, unknown>;
    try {
      const parsed: unknown = JSON.parse(bodyText);
      if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed)) throw new Error();
      body = parsed as Record<string, unknown>;
    } catch {
      throw new ServerError("WeatherGPT returned an invalid response. Please try again.");
    }
    recordRequest({
      startedAt,
      method,
      path,
      query,
      statusCode: status,
      durationMs: Date.now() - startedMs,
      summary: summarizeBody(body),
    });
    return body;
  } catch (error) {
    const mapped = mapFetchError(error, status, bodyText);
    recordRequest({
      startedAt,
      method,
      path,
      query,
      statusCode: status,
      durationMs: Date.now() - startedMs,
      error: mapped.message,
    });
    throw mapped;
  }
}

export const ApiClient = {
  get: (path: string, query?: Record<string, unknown>) => request("GET", path, { query }),
  post: (path: string, data?: unknown) => request("POST", path, { data }),
  baseUrl: apiBaseUrl,
};
