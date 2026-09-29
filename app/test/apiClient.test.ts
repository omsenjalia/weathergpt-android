import { afterEach, expect, it, vi } from "vitest";
import { ApiClient, BACKEND_SECRET_MISMATCH } from "../src/core/services/apiClient";

afterEach(() => { vi.unstubAllGlobals(); vi.unstubAllEnvs(); vi.useRealTimers(); });

it.each(["<html>proxy failure</html>", "null", "[]", "", "42"])("rejects malformed success body %s", async (body) => {
  vi.stubGlobal("fetch", vi.fn(async () => new Response(body)));
  await expect(ApiClient.get("/weather")).rejects.toThrow("invalid response");
});
it("keeps the timeout active while reading the body", async () => {
  vi.useFakeTimers();
  vi.stubGlobal("fetch", vi.fn(async (_url, init: RequestInit) => ({
    status: 200,
    text: () => new Promise((_resolve, reject) => {
      init.signal?.addEventListener("abort", () => reject(new DOMException("Aborted", "AbortError")));
    }),
  })));
  const request = expect(ApiClient.get("/weather")).rejects.toThrow("taking longer");
  await vi.advanceTimersByTimeAsync(60_000);
  await request;
  expect(vi.getTimerCount()).toBe(0);
});
it("encodes query values without serializing absent metrics", async () => {
  const fetch = vi.fn(async () => new Response('{"status":"ok"}'));
  vi.stubGlobal("fetch", fetch);
  await ApiClient.get("/weather", { city: "New Delhi", missing: null });
  const url = new URL((fetch.mock.calls as unknown as [string][])[0][0]);
  expect(url.searchParams.get("city")).toBe("New Delhi");
  expect(url.searchParams.has("missing")).toBe(false);
});
it("sends the backend secret only when one is configured", async () => {
  const fetch = vi.fn(async () => new Response('{"status":"ok"}'));
  vi.stubGlobal("fetch", fetch);
  vi.stubEnv("EXPO_PUBLIC_BACKEND_SECRET", "");
  await ApiClient.get("/weather");
  vi.stubEnv("EXPO_PUBLIC_BACKEND_SECRET", " shared-s3cret ");
  await ApiClient.post("/chat", { message: "hi" });
  const headers = (fetch.mock.calls as unknown as [string, RequestInit][]).map(([, init]) => init.headers as Record<string, string>);
  expect(headers[0]).not.toHaveProperty("X-Backend-Secret");
  expect(headers[1]?.["X-Backend-Secret"]).toBe("shared-s3cret");
});
it("explains a backend secret mismatch instead of a generic failure", async () => {
  vi.stubGlobal("fetch", vi.fn(async () => new Response(
    '{"detail":{"code":"backend_secret_mismatch","message":"This client is not authorised for this backend"}}',
    { status: 401 },
  )));
  await expect(ApiClient.get("/v2/weather")).rejects.toThrow(BACKEND_SECRET_MISMATCH);
});
