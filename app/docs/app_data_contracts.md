# App data contracts (Flutter ⇄ backend)

Durable reference for what the Flutter app sends and renders. Migrated out of the
temporary `feature/app/` planning folder so it survives the plan's removal.
Endpoint inventory lives in [`web_app_api_contract.md`](web_app_api_contract.md).

The app **renders and requests**; the backend owns provider selection
(IMD → WeatherNext → AccuWeather → Open-Meteo), authentication, normalization,
scientific calculation, Jev/TypeSafe evaluation and authorization.

## Configuration boundary

- The app's `.env` is bundled as an asset by `pubspec.yaml`. It is **not** a
  secret store. Only `BACKEND_URL` belongs there
  (template: `feature/app/app.env.example`).
- Google/OAuth, IMD, AccuWeather, Groq and `TYPESAFE_API_KEY` credentials are
  server-side only. Never add them to the Flutter `.env`.
- A user selecting Researcher mode is a UI preference, not an entitlement. It
  grants no Google/IAM access and no redistribution right.

## Mode propagation

`mode` is sent on forecast, chat and voice requests. Wire values:
`everyone | farmer | researcher`.

| Field | Meaning |
|---|---|
| `mode` | Authoritative product mode. |
| `farmer_mode` | Legacy boolean, kept for backward compatibility and **derived from** `mode` so the two can never disagree. |

Resolution rules (implemented in `lib/core/models/app_mode.dart`):

1. An explicit `mode` wins.
2. An explicit but unknown value is **rejected**, never escalated. In strict
   mode the caller gets `AppModeException`; non-strict callers de-escalate to
   `everyone`, the least privileged mode.
3. With no `mode`, legacy `farmer_mode == true` maps to `farmer`, otherwise
   `everyone`.

The app persists the persona as its canonical wire name and refuses to store an
unrecognised value (`SettingsNotifier.updatePersona`).

### Farm context

Chat and voice read the user's saved profile from `farmProfileProvider` — the
same source `/advisory` uses. `crop`, `growth_stage`, `soil` and `irrigation`
are attached **only** in farmer mode, and only when non-blank. Private farm
context is never sent on Everyone or Researcher requests. Chat and voice build
their payload through one shared builder
(`lib/core/models/request_context.dart`) so the two surfaces cannot drift.

> Historical bug fixed here: both surfaces hardcoded `crop: "Wheat"` regardless
> of the user's actual profile.

## Null semantics

Absent, wrong-typed, blank, `NaN` and infinite values parse to `null`
(`lib/core/models/json_values.dart`). Nothing coerces a missing measurement to
`0`, because `0 °C`, `0 mm` and `0%` are claims the backend did not make.

Two specific traps:

- A missing `weather_code` stays `null`. WMO code `0` means *clear sky*, so
  defaulting produced a sunny sky for an unknown condition. `SkyCondition.unknown`
  now renders a neutral sky.
- Hour buckets with no temperature are dropped, not drawn at zero.

Timestamps: strings with an explicit `Z` or `±hh:mm` offset are honoured
exactly; a naive string is read as UTC and the assumption is reportable via
`naiveTimestampAssumedUtc`.

## Provenance and freshness

`WeatherProvenance` (`lib/core/models/data_provenance.dart`) records what the
backend reported and claims nothing otherwise. Tolerated keys, at the top level
or inside `meta`:

| Concern | Keys |
|---|---|
| Source | `source`, `provider`, `data_source`, `primary_source` |
| Product | `product`, `dataset` |
| Run | `run_id`, `run`, `model_run` |
| Produced at | `issued_at`, `run_time`, `analysis_time`, `valid_time` |
| Retrieved at | `retrieved_at`, `fetched_at`, `updated_at` |
| Timezone | `timezone`, `timezone_id` |
| Contract | `schema_version`, `contract_version` |
| Degraded | `fallback`, `degraded`, `is_fallback` |
| Unavailable fields | `missing_fields`, `missing`, `unavailable`, `null_reasons` |
| Horizon | `horizon_hours`, `horizon` |

A payload with no metadata reports **no source** — the UI says "Source not
reported" rather than naming a provider. An unknown age is never labelled
stale; staleness needs a timestamp and defaults to a 6-hour threshold.

### What counts as "degraded"

`fallback_reasons` lists every provider the backend skipped. A provider that
was *never configured* (`missing_credentials`, `credentials_*`, `disabled`,
`not_configured`, …) is **not** a degradation — WeatherNext answering after
IMD was skipped for lack of a key is the normal path. `WeatherProvenance`
therefore:

- prefers the backend's explicit `degraded` boolean;
- otherwise sets `fallback` only when a reason is a *real failure*
  (`FallbackReason.isRealFailure`) or the run is `is_stale`;
- exposes `realFailures` / `skippedUnconfigured` separately for the Debug
  screen, and `weatherNextFailed` is true only when WeatherNext was configured,
  tried, and lost.

The full provider-chain metadata (`tried_providers`, `selection_policy_version`,
`query_diagnostics`, `methods`, `sampled_coordinates`, `expected_member_count`,
`validity_*`, …) is parsed verbatim for developers but never rendered on the
Home screen.

### Per-field attribution (`field_sources`)

Both `/v2/weather` and `/weather` may return

```json
"field_sources": {
  "temperature_c": "weathernext",
  "humidity_percent": "open_meteo",
  "uv_index": null,
  "_supplement": {"provider": "open_meteo", "enabled": true, "attempted": true,
                   "filled": ["humidity_percent"], "errors": [], "cache_hit": false}
}
```

`FieldSources` keeps that map exactly: a field mapped to a provider is shown
with a "via <provider>" badge when that provider differs from the selected
source; a field mapped to `null` renders "—" with the explanation *no provider
supplied this value*; a field that is absent from the map is attributed to the
selected source only when the map is entirely missing (older backend). Daily
rows carry their own `field_sources` for sunrise/sunset/UV max. The app never
promotes a supplemented value to the headline provider's name.

### Request shape the app sends to `/v2/weather`

`lat`, `lon`, `mode`, `requested_source` (developer pin, else `weathernext` in
Researcher mode, else `auto`), `forecast_days` (7, or the developer slider),
`hourly_hours` (48, or the developer slider), `supplement=false` only when the
developer switched the Open-Meteo supplement off, `model` only when a
non-default WeatherNext model is pinned. `lastWeatherRequestProvider` exposes
the exact query, whether the legacy `/weather` fallback was used, and the v2
error, for the Debug screen.

## Everyone-mode enrichments

Exactly two, both optional and additive. Cards are hidden when absent.

**`temperature_spread`** → `{ p10_c, p90_c, source, run_id, valid_from, valid_to,
members }`. A one-sided or inverted spread is rejected outright. This is a
*range*: no rain or temperature probability may be inferred from percentiles.

**`precip_next_24h`** → `{ total_mm, start, end, complete, source, run_id }`.
When `complete` is `false` the interval is labelled partial, and a partial total
is never presented as a whole-period total.

## Advisory decisions (`/advisory`)

Each forecast day carries its **own** decision at
`windows[i].ai.overall = { choice, confidence }`. The app renders that day's
decision and confidence. The request-level `ai.overall_verdict` and
`ai.mean_confidence` are aggregates and are used **only** for the 7-day overview,
never as a specific day's verdict.

When a day has no decision, no "System One · NN% confident" badge is shown — a
global verdict did not shape that day.

There is **no bundled offline advisory**. When the backend is unreachable the
farmer sees an explicit unavailable state; empty window bars are never rendered,
because they would read as "everything is neutral". Cached windows are keyed on
location + crop + growth stage + soil + irrigation + UTC date, so a result cannot
survive a move, a profile edit or midnight, and an in-flight response for a
superseded context is discarded.

## Voice and chat cards

`/chat` (and `/voice`) answers are prose plus optional metadata. A structured
card is **optional and additive**:

```json
{ "response": "…",
  "card": {
    "label": "Rain Forecast", "verdict": "…", "explanation": "…",
    "cta_label": "…", "source": "imd", "confidence": 0.82,
    "stats":    [{ "label": "Chance of rain", "value": "70%", "tone": "caution" }],
    "forecast": [{ "day": "Sat", "temperature": "31°", "rainfall": "9 mm",
                   "condition": "rain" }] } }
```

`tone` is `good | caution | avoid` (aliases `safe`, `favourable`, `watch`,
`risk`, `poor` accepted); colour stays a UI concern. With no card the result
screen shows the prose with **no stats and no forecast rows**. Decision
confidence and weather-event probability are distinct fields and must stay
visually distinct.

> Historical bug fixed here: canned `78%` / `12 mm` stats, a fixed Tue/Wed/Thu
> forecast and `Soil Moisture: Adequate` were rendered for every answer.

## Researcher archive views

`/historical` (`lat`, `lon`, `metric`, `start_year?`, `end_year?` →
`{ metric, points: [{ year, value }] }`) and `/comparison` (`locations` as
`name,lat,lon;…`) are real endpoints; the historical, anomaly and comparison
screens read them. Comparison locations come from the user's saved locations,
not a bundled city list.

- Rows missing a year or a finite value are dropped, not plotted at zero.
- Axis bounds and year labels are derived from what came back.
- Month-of-year climatology is **not** served by `/historical`; the UI states
  that instead of charting a bundled table.
- `anomalyPercent` is a deviation from the mean of the *returned* window. It is
  not a climate-normal calculation and is labelled accordingly.

## What is deliberately not implemented

Proposed `/v2/...` WeatherNext contracts, capability/catalog/series/profile/
ensemble/job endpoints, structured farmer window decisions from the backend, and
licensed exports remain **unwired**: they are design targets in
`feature/backend/weathernext_3_integration_plan.md`, not existing services. New
screens must not be wired to them until the backend implements and versions
them. The withdrawn Weather Lab auto-login/custom-map proposal stays withdrawn.
