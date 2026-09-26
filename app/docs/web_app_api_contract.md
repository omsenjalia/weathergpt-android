# Local Android backend endpoint inventory

_The filename is retained for existing links. This repository has no web frontend._

Backend root: `backend/main.py`; Vercel root directory: `backend/`.
Client base URL: `app/.env` or `--dart-define=BACKEND_URL`.
See [data contracts](app_data_contracts.md) for response semantics.

| Method | Path | Required input | Notes |
|---|---|---|---|
| GET | `/` | — | Advertises `weathergpt-android` mobile client and provider policy |
| GET | `/health` | — | Liveness, clients, uptime |
| GET | `/weather` | lat, lon | Legacy-compatible flat weather/provenance response |
| GET | `/v2/weather` | lat, lon | Same service; source, forecast_days, hourly_hours, supplement supported |
| GET | `/v2/weather/health` | — | Configuration-only check, optional sample lat/lon |
| POST | `/chat` | message or messages | Location/language/mode/farm context; `{response, meta}` |
| GET | `/advisory` | lat, lon | Thresholds, days 1–7; no TypeSafe calls |
| GET | `/historical` | lat, lon | Yearly rainfall/temperature/humidity; default 2000–2024 |
| GET | `/comparison` | locations | `name,lat,lon;name2,lat2,lon2`; default 2015–2024 |
| GET | `/fusion` | lat, lon | Legacy weighted providers, separate from ordered forecast selection |
| GET | `/dev` | — | System/configuration/tool/route/log diagnostics |
| GET | `/dev/forecast` | — | Sample live selection plus legacy cache diagnostics |
| POST | `/dev/sandbox` | prompt | Runs agent; may incur Groq usage |
| GET | `/docs`, `/openapi.json` | — | FastAPI schema/browser docs |

Coordinates on weather/advisory/history routes are validated in the geographic
range. `/comparison` skips malformed locations and rejects an empty valid set.
Unknown sources yield 422; unavailable providers yield 502 rather than synthetic
weather. Validation errors use FastAPI `detail`; unhandled failures return 500 with
a request ID. Weather upstream requests run in the thread pool, not the event loop.

Not present: `/voice`, `/dev/intent`, `/v2/weather/catalog`, `/v2/weather/series`,
WeatherNext tools/routes, decision-platform routes, official-alert ingestion.
Do not copy the sibling backend's OpenAPI expectations into this app unchanged.

`backend/tests/test_mobile_contract.py` checks that every path declared by the
Flutter `ApiEndpoints` class exists in this backend's OpenAPI schema.
