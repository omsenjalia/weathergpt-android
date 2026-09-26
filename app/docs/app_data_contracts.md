# Android app data contracts

_Audited 2026-09-26. Applies to `app/` ↔ `backend/` in this monorepo._

The authoritative topology is [../../ARCHITECTURE.md](../../ARCHITECTURE.md).
[Endpoint inventory](web_app_api_contract.md) describes the local API. The sibling
WeatherNext/TypeSafe contract is **not** the contract deployed from this checkout.

## Configuration and persona context

- The only bundled `.env` setting is the public `BACKEND_URL`.
- Resolution: Dart define → `.env` → `http://10.0.2.2:8888` (Android emulator).
- Modes: `everyone`, `farmer`, `researcher`. Explicit mode is authoritative;
  otherwise the legacy `farmer_mode` boolean may select Farmer.
- Chat and voice use `AgentRequestContext` to attach `crop`, `growth_stage`,
  `soil`, `irrigation` only in Farmer mode. The backend accepts these fields;
  enabled LLM reasoning receives them as user-supplied context.
- No persona implicitly pins WeatherNext. Developer pins are
  `auto|imd|accuweather|open_meteo`. Old persisted WeatherNext pins revert to auto.

## Weather requests and responses

Home calls `GET /v2/weather` with `lat`, `lon`, `mode`, `requested_source`,
`forecast_days` (default 7), `hourly_hours` (default 48), optional `supplement=false`.
`Accept-Language` accompanies backend requests. The weather API accepts an
explicit `language` query but provider condition labels are not automatically
translated by the header.

The local v2 facade intentionally returns the same **flat current + list** shape
as `/weather`. Example (abbreviated):

```json
{
  "status": "ok",
  "temperature_c": 25,
  "weather_code": 0,
  "humidity": 65,
  "wind_kmh": 8,
  "uv_index": 6,
  "aqi": 30,
  "hourly": [{"time": "2026-09-26T06:00:00+00:00", "temperature_c": 25}],
  "forecast": [{"date": "2026-09-26", "high_c": 30, "low_c": 20}],
  "location": {"timezone": "Asia/Kolkata", "utc_offset_seconds": 19800},
  "selected_source": "open_meteo",
  "requested_source": "auto",
  "provenance": {"selected_source": "open_meteo"},
  "field_sources": {"temperature_c": "open_meteo"}
}
```

The real offline response fixture is
[`test/fixtures/weather_android.json`](../test/fixtures/weather_android.json).
Python tests compare its wire fields; a Dart parser test consumes the same file.
It is test data, not a live forecast.

`parseWeatherSnapshotV2` accepts this flat shape and the richer sibling shape for
backward compatibility. It does not imply that nested WeatherNext products exist
here. `hourly` covers upcoming available rows, `forecast` local calendar days.
A smaller provider horizon is not padded with invented data.

- Missing current weather code/rain probability remain null; code `0` is clear.
- Missing/wrong/nonfinite numeric values parse as null on the client.
- Missing hourly temperatures are skipped instead of graphed at zero.
- Open-Meteo's naive local hours are converted to UTC on the backend; the location
  timezone/offset is included for labels. Older payloads without timezone metadata
  may use client fallbacks.
- `field_sources` identifies primary or supplemented values. Only selected
  missing ancillary fields are supplemented; absent primary hourly data remains
  absent. `supplement=false` disables enrichment in the weather response path.
- `fallback_reasons` records skipped providers. Unconfigured providers are not
  inherently a degraded forecast; actual failures/staleness are distinct.
- Auto-source v2 failures may retry legacy `/weather` with the same horizons.
  Explicit source pins **never** substitute an automatic legacy request.
- Unsupported source names return 422. A supported but unavailable pin, or total
  upstream failure, returns 502 with structured `detail`.

## Chat and voice

`POST /chat` accepts either `message` or `messages` (role/content history), plus
location label, optional coordinates, language, persona and farm fields. It
returns `response` (Markdown) and `meta` (path/client/language/intent/intent_engine/
requested_source; optional provenance fields).

The keyword router may return a greeting, domain boundary, deterministic
telemetry or a Groq agent answer. Agent failures/timeouts fall back to telemetry.
Pinned source requests use constrained telemetry. No System One API is called.
Widget fences are sanitized server-side and parsed by `RichMarkdown`; unknown or
richer compatibility payloads must not be interpreted as evidence of installed
WeatherNext/decision tools.

Voice recognition is on-device/plugin-provided. It posts recognized text to
`/chat` and uses `flutter_tts` to read speech-cleaned output. There is no backend
`/voice` endpoint. Farmer voice onboarding is a separate scripted, local flow.

## Farm action windows

`GET /advisory` accepts lat/lon, crop, days (1–7), growth stage, soil, irrigation,
source and mode. Response: `summary`, `windows`, `advisory_engine`, `ai`, source
and provenance. Windows include date, suitability, explanation and available
activity bands (`irrigation`, `spraying`, `field_work`) for the first two days.

The local engine is **thresholds**; `ai.enabled` and `ai.applied` are false.
Crop/profile inputs do not make the rule thresholds crop-specific. Missing
critical daily inputs yield a neutral/insufficient-data window. The client
collapses hourly cells into two-hour visual bands, caches by request context/day,
and exposes request failures rather than a bundled "safe" forecast.

Client System One badge parsers are compatibility support only; this backend
must not fabricate confidence values. Weather-based guidance is not official
agronomic certification or an emergency alert service.

## Research

- `/historical`: `{metric, points: [{year, value}], source}`. Rainfall sums returned
  records; temperature/humidity average them. Year range at most 40 years apart.
- `/comparison`: `{metric, locations: [{name, lat, lon, points}], source}`. Wire
  locations use `name,lat,lon;name2,lat2,lon2`; names may contain commas (the final
  two components are coordinates). Semicolons separate locations.
- No records means an empty series, not zero-valued observations. Client chart
  labels reflect returned coverage. Monthly climatology is explicitly unsupported.
- Returned-window deviation is not a 30-year climate-normal anomaly. No ensemble,
  profile, run catalog or model inference endpoint exists here.

## Diagnostics

`/v2/weather/health` reports installed provider configuration/eligibility; `status`
`ok` means the endpoint answered, **not** that upstream weather is reachable.
The request ring buffer stores recent statuses/timings and summaries. Developer
options control source/horizons/supplementation/fallback plus visual/voice overrides.
Provider attribution remains primarily a debug surface. Server developer routes
are not authenticated; protect them independently of the UI before public use.
