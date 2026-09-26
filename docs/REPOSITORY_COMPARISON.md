# Android deep-dive: comparison, repairs and verification

**Audit date:** 2026-09-26. **Verdict:** this is an Android-only, reduced-backend
fork/reorganization of the Flutter app, not a feature-equivalent clone. The initial
checkout had real runtime breakages. Backend and configuration regressions are
now covered by passing offline tests. Native/device/live-provider validation is
still outstanding; see [Verification](#verification).

## Comparison basis

Compared files, not just repository descriptions:

- This checkout before changes: [`a0613eb`](https://github.com/omsenjalia/weathergpt-android/tree/a0613ebca448a4ed35c5c41a2dc6c2481ac69f28).
- Reference app `main` when inspected: [`9ad3c51`](https://github.com/omsenjalia/weathergpt-app/tree/9ad3c5178c52e53006d528748ea7359bd558f393).
- Reference architecture: [`ARCHITECTURE.md`](https://github.com/omsenjalia/weathergpt-app/blob/9ad3c5178c52e53006d528748ea7359bd558f393/ARCHITECTURE.md).
- Reference workflows: [`.github/workflows`](https://github.com/omsenjalia/weathergpt-app/tree/9ad3c5178c52e53006d528748ea7359bd558f393/.github/workflows).
- Reference app's **pinned backend submodule**, not today's unrelated backend HEAD:
  [`omsenjalia/weathergpt@fc78632`](https://github.com/omsenjalia/weathergpt/tree/fc786322abfe87c13c4ef60c6f199a7997d09a8a/backend).
- The reference also contains `backend-integration/` patch/staging files. These
  are distinct from its pinned backend and were not mistaken for this repo's
  actual deployed code.

### How much was originally different?

After mapping this repo's `app/*` to the reference's root:

- **157 of 161 app files were byte-identical.** The four differing files were
  `.env.example`, `pubspec.yaml`, `atmosphere_video_background.dart` and
  `weather_video_background.dart`.
- Relative to the reference's pinned `backend/` source, this repo's original 39
  backend files comprised **22 identical**, **14 changed**, and **3 local-only**
  files. Local-only files were `forecast_supplement.py`, its test file and
  `test_backend.py`. The pinned reference contained **22 other files absent here**,
  primarily WeatherNext, TypeSafe/decision services and their tests.

These are **baseline** counts, before the repairs below. They do not imply all
inherited files were correct or that the reference deployment was verified live.

## Main differences

| Area | Reference `weathergpt-app` | This Android repository |
|---|---|---|
| Layout | Flutter app at root; separate backend Git submodule | `app/` and `backend/` are ordinary tracked directories in one repo |
| Platform runners | Android **and 40 iOS files** | Android only; no iOS runner/build path |
| Core Flutter features | Personas, chat, voice, farm/research screens, translations | Largely the same inherited app; not a native Kotlin rewrite |
| Weather visuals | video_player plus 30 MP4 sky/weather assets and attribution | No video dependency/assets; painted atmospheric animation and gradients |
| Forecast policy | IMD → WeatherNext → AccuWeather → Open-Meteo integration | IMD scaffold → AccuWeather → Open-Meteo; actual default without keys is Open-Meteo |
| WeatherNext | Google auth, BigQuery/GCS/Earth Engine, normalization/catalog/tools/provider | These modules and Google/scientific Python dependencies are absent |
| Jev / System One | TypeSafe service and decision modules/routes | No external TypeSafe integration; keyword routing and threshold advisories |
| IMD | Reference architecture advertises substantial capabilities | Local adapter explicitly says endpoint integration and official warnings are pending |
| Research | Research UI plus richer WeatherNext backend products | Archive/trends/comparison UI remains; no ensemble/profile/run/inference services |
| v2 contract | Rich WeatherNext products and ancillary routes | Flat current + hourly/forecast lists, provider provenance, configuration health |
| Default URL | Shared hosted backend and reference CI placeholder fallback | Local emulator by default; hosted URL must be configured explicitly for release |
| Push process | `push-all.sh` handles another Git repo/submodule | One ordinary Git workflow; helper is now informational, not auto-committing |
| CI at audit start | Three app workflows | None |
| CI after this work | Reference behavior was independent build/test workflows | Monorepo-aware backend + app gates, reusable APK build, signed nightly prereleases |
| Architecture claims | SIH pitch, live-production labels and future-roadmap claims | Source-grounded implementation description; unsupported/live-unverified features called out |

### Features retained, not removed

Everyone/Farmer/Researcher UI, nine localization catalogs, STT/TTS, farmer
Talk-vs-Type onboarding, persisted profiles/settings/places, Windy WebView,
Markdown/widget rendering, charts and developer inspection remain. Compatibility
parsers and some pure model/advisory utilities still understand richer sibling
payloads; no one should infer from those types that the corresponding server
integration exists.

### Important limits of the reduced backend

- **IMD is a stub**, not a working provider activated by supplying a key.
- AccuWeather's adapter supplies current/daily data but does not fetch hourly
  forecasts. Supplementation is ancillary-field filling, not full provider parity.
- Farm profile fields are accepted and reach LLM context, but the rules-only
  advisory engine is not a crop/soil/stage-specific agronomic model.
- Yearly archive APIs exist; monthly climatology, complete archive coverage
  verification, official climate normals and WeatherNext research products do not.
- Some fallback/server copy remains English despite nine UI catalogs. Device
  speech-language coverage must be tested on installed Android engines.
- No auth/rate-limit layer protects diagnostic or billable routes. CORS is broad.
  This is not a production-security certification.

## What was changed

### Architecture and documentation

Added root [`ARCHITECTURE.md`](../ARCHITECTURE.md), adapted to the actual monorepo,
with topology, stack, entrypoints, client state, API contracts, provider selection,
voice/chat, CI/signing and operational limits. Removed reference-only production,
SIH-compliance, WeatherNext/Jev, video, iOS, submodule and speculative roadmap
claims from the current architecture.

Rewrote the root README and the inherited client/API contract documents to agree
with the code. Historical WeatherNext/video research is explicitly marked as
historical, not current instructions. Replaced stale QA notes claiming research
charts still used mock tables with a real remaining device/deployment checklist.

### Runtime and wiring repairs

| Finding in initial checkout | Repair / regression coverage |
|---|---|
| Backend import failed: `services.chat` imported missing `ClientKind` | Restored the shared type; app imports and real Uvicorn startup verified |
| Direct `/v2/weather` → `/weather` Python call left `requested_source` as a `Query` object | Explicit delegation of every argument; both route shapes tested |
| Weather and tool serializers read nonexistent `SelectionResult.requested_source` | Weather uses the actual requested source; selection exposes provenance-backed property for tools |
| v2 request knobs ignored; hourly output hardcoded to 24 | Threaded daily/hourly/supplement settings through service; default 48-hour and bounded output tests |
| UI health call had no backend route; unused catalog/series paths advertised | Implemented configuration-only `/v2/weather/health`; removed nonexistent client paths; endpoint inventory test |
| Researcher automatically pinned removed WeatherNext; settings exposed its model controls | All personas default to auto; removed unsupported controls; stale persisted pins safely fall back |
| Unknown source silently selected Open-Meteo; failed pins could fall through legacy providers | Reject unknown sources, enforce pins and explicit unavailable errors in weather/advisory/chat paths |
| Missing probability/code became dry/clear data | Preserve nulls in mobile weather and Open-Meteo adapter; insufficient advisory input gets neutral/unavailable |
| Open-Meteo local timestamps were marked UTC without conversion | Zone-aware conversion, timezone metadata and local advisory grouping; India timezone regression |
| Daily UV and wind omitted from normalized Open-Meteo rows | Request/map fields needed by home and farm consumers |
| Successful LLM path called undefined `_sanitize` and fell back | Return sanitized `ChatResult`; mocked agent-success regression |
| Off-topic requests could fall into telemetry when TypeSafe routing was disabled | Added an early deterministic domain boundary and route test |
| Agent timeout used executor context manager that waited anyway | Non-waiting shutdown; timeout regression; running work still cannot be force-killed |
| Farm context silently dropped by Pydantic; explicit persona disagreed with legacy flag | Accept farm fields, pass context, honor explicit mode, derive farmer flag |
| Greeting/prompt advertised removed tools | Honest capability wording; no unused WeatherNext tool import |
| Provider-priority and model env examples didn't match config/selection code | Parse/validate ordered priority; use `GROQ_MODEL` consistently |
| Comparison split city/region labels at every comma and discarded valid locations | Split final two coordinate fields, preserving geocoded labels |
| Vercel entrypoint existed without path rewriting | Route rewrites and same-app entrypoint test |
| Startup fallback silently targeted the sibling deployment | Emulator-only default; release build configuration must provide URL |
| Copied Android toolchain versions drifted beyond the pinned Flutter template | Aligned AGP/Kotlin/Gradle to Flutter 3.44.0 template versions; signing fails closed |
| Android speech/TTS package visibility queries missing | Added recognition/TTS intent queries; runtime device test still required |
| Copied push helper assumed `app/backend` submodule and staged everything | Safe informational monorepo helper; no automatic commit/push |
| No root credential/tooling ignores | Ignore local env, keystores, virtualenvs, reports and APK/AAB outputs |

The Android toolchain alignment was checked against Flutter's own
[`3.44.0` version constants](https://github.com/flutter/flutter/blob/3.44.0/packages/flutter_tools/lib/src/android/gradle_utils.dart)
and [Kotlin app template](https://github.com/flutter/flutter/blob/3.44.0/packages/flutter_tools/templates/app/android-kotlin.tmpl/app/build.gradle.kts.tmpl),
not guessed from older Flutter versions. The template applies Kotlin through
Flutter compatibility logic; it does not need an extra explicit app Kotlin plugin.
This source check is not a substitute for building the APK.

### Workflow adaptation and hardening

The original three filenames are preserved, plus a shared `build-apk.yml` to
avoid signing/path drift between CI and nightly.

| Concern | Adaptation |
|---|---|
| Working directory | All Flutter commands run in `app/`, Python in `backend/` |
| Validation | Backend compile/undefined-name checks, network-isolated tests, Flutter analysis/tests, actionlint, config-script tests |
| Build gates | Both APK paths depend on successful checks; no pretend arrow between independent workflows |
| Logs | Analyzer/test artifacts retained; explicit Bash pipefail prevents `tee` masking errors |
| Fork PRs | Read-only test token, no PR-comment write permission, no signing credentials in PR builds |
| Backend URL | No unrelated hosted/placeholder default; CI fallback explicitly emulator-only, nightly requires HTTPS |
| Keystore | All-or-none credentials; absolute path; fail closed for release signing; cleanup even after failure |
| Artifacts | Name distinguishes release-signed vs debug-signed and local-backend fallback |
| Nightly | Default branch only; activity gate; tests first; stable keystore required; prerelease, not production release |
| Versioning | Shared seconds-since-2020 versionCode across CI/nightly, instead of unrelated workflow run counters |
| Tag correctness | Release targets the tested SHA; an existing date tag/release is never overwritten |
| Backend deployment | Intentionally separate; not falsely represented as handled by APK workflows |

CI without secrets remains useful for development. Nightly publication deliberately
**does not inherit the reference's debug-key fallback**: that fallback undermines
upgrade compatibility and mislabels distributable packages. Configure repository
`BACKEND_URL` and the four signing secrets listed in the README to enable nightlies.

## Verification

### Passed locally

| Check | Result |
|---|---|
| Backend dependency installation | `requirements-dev.txt` installed on Python 3.11 |
| `python -m pytest backend/tests -q` | **84 passed**, with external sockets blocked; no provider/LLM credentials |
| `ruff check backend --select E9,F821,F822,F823` | Passed (syntax/undefined-name checks, not a full style/security lint) |
| `python -m compileall -q backend scripts` | Passed |
| `python -m unittest discover -s scripts/tests -v` | **5 passed** (URL validation, signing completeness, path/permissions, versioning defaults) |
| Dart grammar parse | All **115** Dart source/test files parse without syntax errors using tree-sitter; not Dart semantic analysis |
| Workflow YAML parse | All four workflow documents parse; not equivalent to actionlint/GitHub execution |
| `git diff --check` | Passed |
| Actual Uvicorn HTTP smoke | `/`, `/health`, `/v2/weather/health`, `/dev`, `/docs`, `/openapi.json`: **200** |
| Chat smoke without keys | Greeting and domain-boundary paths: **200** |
| Provider failure smoke | Missing IMD pin: **502 unavailable**; removed WeatherNext: **422** |

The backend suite exercises real routes, provider selection and Open-Meteo
normalization against fake provider HTTP data. Coverage includes home responses,
nulls, horizons, source pins, supplementary-field switch, advisory shape, local
hours, archive/comparison parsing, farm context, agent success/timeout and the
Vercel entrypoint. Python compares the checked-in weather fixture's fields; Dart
parser tests consume it in CI. The missing WeatherNext/BigQuery integration test
was replaced with coverage of installed-provider routes, not marked as passing.

The suite currently emits **505 dependency deprecation warnings** from the older
FastAPI/LangChain/Pydantic combination. Those are not hidden CI failures, but they
are dependency-upgrade work; passing tests are not a dependency security audit.

### Not verified here / remaining gates

1. **Flutter semantic analysis, Flutter unit/widget execution, dependency solve
   and APK compilation.** No Flutter/Dart/Java/Android SDK was installed in this
   sandbox. Flutter storage and pub.dev downloads failed TLS/connectivity checks.
   Grammar parsing does not replace those tools.
2. **Dependency-lock refresh.** The original app lock lists speech_to_text 6.6.2
   while `pubspec.yaml` requires ^7.4.0. It was not hand-edited without a resolver.
   CI runs `flutter pub get`; review and commit its resolved lock on a Flutter host.
3. **actionlint execution and hosted Actions runs.** YAML parsed locally, but
   actionlint's binary download was blocked too. CI runs the pinned actionlint
   container. No changes were pushed, no workflow dispatched, and no release
   published during this audit. Repository Actions administrative settings could
   not be inspected with the integration's current permissions.
4. **Signing key validity, keystore password/alias, and upgrade installation.**
   Configuration logic is tested, but no real signing secrets were requested or
   used. Keystore format/password validity is checked by the actual Gradle build.
5. **Real devices and live services.** GPS/mic permission flows, STT/TTS engines,
   Indic rendering, Windy WebView, animation performance, live Groq/model access,
   provider quotas, Vercel deployment and phone-to-backend HTTPS remain manual/
   deployment checks. Tests intentionally do not spend API quota or certify
   third-party availability.
6. **Public deployment hardening.** Restrict diagnostic/billable routes, add rate
   limits/resource bounds, review data retention/logging and dependencies, and
   restrict cleartext Android networking for production. Official IMD and removed
   research/decision capabilities need real implementations, not just keys.

### Recommended next run on an SDK-equipped host

```bash
# At repository root, after activating a Python 3.11 venv:
pip install -r backend/requirements-dev.txt
python -m pytest backend/tests -q
python -m unittest discover -s scripts/tests -v
cd app
cp .env.example .env    # fresh checkout only
flutter pub get
flutter analyze
flutter test --timeout 60s
flutter build apk --release
```

Then review the lockfile, configure the deployed backend URL and stable signing
secrets, run the gated CI build, and follow [device QA](../app/docs/qa_notes.md).
Only after those checks should the result be described as an end-to-end verified
Android release.
