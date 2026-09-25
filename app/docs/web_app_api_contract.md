# API contract (audited 2026-09-10)

Audited source: `../Web App/backend/main.py` and `../Web App/frontend/src/api.js`.
No `WeatherGPT_Architecture.md` file was present. The web client configures its base URL as `VITE_API_URL`, falling back to `http://localhost:8888`; it sends no authentication header. The mobile app uses `BACKEND_URL` in `.env`.

## Backend endpoints

| Method | Path | Request | Response |
|---|---|---|---|
| POST | `/chat` | `{ message: string = "", messages: [{ role: string, content: string }] = [], location: string = "", language: string = "English", mode?: "everyone"\|"farmer"\|"researcher", farmer_mode: bool = false, crop: string = "", growth_stage?: string, soil?: string, irrigation?: string }` | `{ response: string, meta: { path, client, language, location, intent, intent_engine: "system-one"\|"keywords", intent_confidence? } }` |
| POST | `/voice` | multipart: `audio?`, `transcript`, `language`, `lat`, `lon`, `crop` | `{ response: string }` |
| GET | `/weather` | `lat`, `lon`, `language?`, `mode?` | current conditions, current-day highs/lows and a 3-day forecast |
| GET | `/advisory` | `lat`, `lon`, `crop?`, `days?` (1–7), `mode?`, `growth_stage?`, `soil?`, `irrigation?` (farm context refines System One scoring) | `{ summary, windows: [{ date, suitability ("good"\|"caution"\|"poor"), summary, best_window, rain_probability, rain_mm, wind_kmh_max, high_c, hourly?: { irrigation \| spraying \| field_work: [{ hour, suitability }] } (first 2 windows), ai?: { spray \| irrigation \| fieldwork: { score, confidence, band }, overall: { choice, confidence } } }], advisory_engine: "system-one+thresholds"\|"thresholds", ai: { enabled, applied, model, evaluated_days, mean_confidence?, overall_verdict?, overall_confidence? } }` — `hourly`/`ai`/`advisory_engine` are additive TypeSafe-era fields; older clients ignore them |
| GET | `/historical` | `lat`, `lon`, `metric`, `start_year?`, `end_year?` | `{ metric, points: [{ year, value }] }` |
| GET | `/comparison` | `locations=name,lat,lon;…`, `metric?`, years | `{ metric, locations: [{ name, points }] }` |
| POST | `/dev/sandbox` and `/dev/sandbox/` | `{ prompt: string, location: string = "New Delhi", language: string = "English" }` | Success: `{ status: "success", duration_ms: number, prompt: string, location: string, language: string, response: string, model_used: string, timestamp: string }`; failure: `{ status: "error", duration_ms: number, error: string, timestamp: string }` (HTTP 500). |
| GET | `/dev/intent` and `/dev/intent/` | `text` (sample message, 1–500 chars) | `{ text, engine: "system-one"\|"keywords", intent, confidence?, keyword_intent, system_one?: { route, probabilities, confidence, live_data, smalltalk, abuse }, would_fast_path, duration_ms, timestamp }` — routing decision inspector; `system_one` is null without a `TYPESAFE_API_KEY` |
| GET | `/health` and `/health/` | None | `{ status: "ok" }` |
| GET | `/dev` and `/dev/` | None | Diagnostics including `status`, `timestamp`, `server_start_time`, `uptime_seconds`, `system`, `llm_config`, `provider_keys_status`, `registered_endpoints`, `registered_ai_tools`, and `recent_logs`. |

## Additive fields the mobile app sends and accepts

Audited 2026-09-19 against this repository's Flutter client. Everything below is
**additive**: a backend that ignores it keeps working, and the app treats every
listed response field as optional. Semantics, null handling and the reasons for
each field are in [`app_data_contracts.md`](app_data_contracts.md).

**Requests**

- `mode` (`everyone | farmer | researcher`) on `/weather`, `/chat` and
  `/advisory`. Authoritative when present; `farmer_mode` is kept for
  compatibility and derived from it.
- `growth_stage`, `soil`, `irrigation` on `/chat` — the farmer's saved profile,
  sent only in farmer mode and only when non-blank.
- `locations` on `/comparison` is built from the user's saved locations as
  `name,lat,lon;…`.

**Responses (all optional)**

- `/chat`, `/voice`: `card` — structured stats/forecast rows, source and
  decision confidence. Without it the app renders prose only and invents nothing.
- `/weather`: `source`/`provider`, `product`, `run_id`, `issued_at`,
  `retrieved_at`, `timezone`, `schema_version`, `fallback`, `missing_fields`,
  `horizon_hours` (also accepted inside `meta`), plus the two Everyone-mode
  enrichments `temperature_spread` (`p10_c`, `p90_c`, coverage) and
  `precip_next_24h` (`total_mm`, `start`, `end`, `complete`).
- `/advisory`: `windows[i].ai.overall = { choice, confidence }` — the
  per-day decision the app renders. `ai.overall_verdict` and
  `ai.mean_confidence` are aggregates used only for the 7-day overview.

Unknown additive fields are ignored by the parser. The proposed `/v2/...`
WeatherNext contracts are **not** called by this app yet.

## Client-only external calls

The backend now proxies Open-Meteo for its mobile weather and research endpoints; the existing web app still makes its direct calls:

- `https://air-quality-api.open-meteo.com/v1/air-quality` with `latitude`, `longitude`, `current`, and `timezone=auto`.
- `https://geocoding-api.open-meteo.com/v1/search` with `name`, `count=1`, and `language=en`.

Its weather forecast is assembled client-side by `getEnsembleWeather`, not a FastAPI route. The backend `.env.example` defines `GROQ_API_KEY`, optional `GROQ_MODEL`, provider keys (`WEATHERAPI_KEY`, `TOMORROW_KEY`, `OPENWEATHER_KEY`, `ACCUWEATHER_KEY`), `IMD_API_KEY` and `IMD_JWT_TOKEN` for future official IMD integration, plus the optional `TYPESAFE_*` variables (System One decision model — chat intent routing and farm advisory scoring). The TypeSafe key is server-side only; see `backend-integration/README.md` in this repo.
