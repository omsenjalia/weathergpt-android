# WeatherGPT Android

Flutter Android weather/chat/voice application with an in-repository FastAPI
backend. **This is one monorepo, not a Flutter repo with a backend submodule.**

- [Architecture](ARCHITECTURE.md) — implemented features, data flow and limits
- [Repository comparison and verification](docs/REPOSITORY_COMPARISON.md) — differences from `weathergpt-app`, repairs and remaining checks
- [Client/backend contracts](app/docs/app_data_contracts.md)
- [Device QA checklist](app/docs/qa_notes.md)

```text
app/                 Flutter source, Android runner, translations and tests
backend/             FastAPI routes, provider adapters, agent and tests
.github/workflows/   Test gates, APK artifacts and signed nightly releases
scripts/             CI signing/configuration validation
```

## Local backend

Use Python **3.11**. From the repository root:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r backend/requirements-dev.txt
cp backend/.env.example backend/.env
cd backend
uvicorn main:app --host 0.0.0.0 --port 8888 --reload
```

Open `http://localhost:8888/docs`. Open-Meteo weather requires internet but no key.
Leave `GROQ_API_KEY` blank for deterministic telemetry chat; configure it only for
LLM reasoning. AccuWeather is optional. IMD is an unimplemented adapter scaffold;
WeatherNext and TypeSafe/Jev are **not installed**. Provider keys stay server-side.
For deployment, install `backend/requirements.txt` (without test tools).

## Android app

Install Flutter **3.44.0**, Java **17** and the Android SDK; run `flutter doctor`.
From the repository root:

```bash
cd app
cp .env.example .env
flutter pub get
flutter run
```

`BACKEND_URL=http://10.0.2.2:8888` reaches the host from an Android emulator.
For a real phone, use a reachable LAN URL or a deployed HTTPS backend in `.env`,
or override it with `--dart-define=BACKEND_URL=https://your-backend.example`.
There is no implicit fallback to the sibling repository's hosted service.
**The app `.env` is bundled in the APK; it is not a secret store.**

Release-mode development APK:

```bash
cd app  # from repository root
flutter build apk --release
```

Output: `app/build/app/outputs/flutter-apk/app-release.apk`. Without signing
configuration this uses **debug keys**; it is not a production-signed release.
The inherited lockfile needs a Flutter dependency refresh (STT's declared ^7.4.0
constraint differs from its old locked 6.6.2). Review/commit the resolved lock
when running `flutter pub get` on an SDK-equipped machine.

## Tests

From the repository root, with the Python environment activated:

```bash
python -m pytest backend/tests -q
ruff check backend --select E9,F821,F822,F823
python -m unittest discover -s scripts/tests -v
cd app
cp .env.example .env  # only for a fresh test checkout; do not overwrite local config
flutter pub get
flutter analyze
flutter test --timeout 60s
```

Backend tests block external sockets and use fixture readings: successful tests
do not imply live provider access. See the audit report for checks actually run
in this environment; Flutter analysis/tests, APK compilation and device testing
remain required, not claimed passes.

## CI and signed nightly setup

- `ci-test.yml`: Python contracts, Flutter analysis/tests, workflow/build-script
  checks. Also reusable by both build paths.
- `ci-build-signed.yml`: PR/push/manual test gate → reusable APK build. PR builds
  never receive release keystore credentials. Missing config produces a clearly
  labeled debug-signed, local-backend development artifact.
- `nightly-release.yml`: 18:30 UTC (00:00 India), only when the default branch has
  recent commits; manual dispatch bypasses the activity check but not test/signing
  gates. Publishes a **prerelease**, direct-download `release.apk`.

For deployable APKs, set repository **variable** `BACKEND_URL` to the HTTPS URL
of your deployed **Android backend** (`BACKEND_URL` secret is also accepted).
Add these four Actions secrets through GitHub's settings:

| Secret | Value |
|---|---|
| `KEYSTORE_BASE64` | Base64-encoded release keystore |
| `KEYSTORE_PASSWORD` | Keystore password |
| `KEY_ALIAS` | Signing key alias |
| `KEY_PASSWORD` | Key password |

Never paste credentials into source or the app `.env`. Nightly builds fail rather
than silently publishing with debug keys or a placeholder URL. Gradle likewise
fails if `SIGNING_MODE=signed` lacks valid credentials. Local signing uses the
same variables and an **absolute** `KEYSTORE_PATH` pointing at your keystore.

Nightly tags are immutable per UTC date and target the tested commit. CI and
nightly share the same version-code scheme. Debug-signed APKs from separate CI
runners may require uninstalling the prior app; release upgrades need the same
stable signing key. Actions artifact downloads are ZIP-wrapped; Releases expose
the APK directly.

## Deployment and contribution

For Vercel, choose project root **`backend/`**; `api/index.py` exports the FastAPI
app and `vercel.json` rewrites API paths to it. Uvicorn is also supported. Backend
deployment is separate from APK publication; these workflows do not deploy it.
Protect unauthenticated developer/billable endpoints and apply rate/resource
limits before public production use.

Use normal Git commands at the root for both `app/` and `backend/`. There are no
submodules to initialize or push. The legacy `app/scripts/push-all.sh` prints this
guidance rather than automatically committing/pushing files.
