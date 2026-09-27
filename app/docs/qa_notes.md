# Android device QA checklist

_Updated 2026-09-26. These are remaining manual checks, not claimed passes._

Before distributing a signed APK:

- Run `bun install --frozen-lockfile`, `bun run typecheck`, `bun run test`, then
  `bunx expo prebuild -p android` and a release APK build.
- Install on a real Android phone; verify cold start, upgrade with the same key,
  onboarding, persona changes and saved state. Settings stored by earlier builds
  are not migrated to AsyncStorage; users repeat onboarding once.
- Exercise GPS/mic permission grants **and denials**, unavailable speech engines,
  installed TTS voices, nine language catalogs and Talk↔Type onboarding.
- Test home/loading/error/retry, source pins, hourly/day horizons and offline behavior.
- Verify farm windows with missing upstream fields; do not show invented confidence
  or claim TypeSafe decisions. Test profile-edit and location-change invalidation.
- Historical/comparison screens are wired to the API, not placeholder tables.
  Verify saved place names with commas, empty series and unsupported monthly view.
- Check Windy WebView, external links, Indic text wrapping, safe areas and animation
  performance; this build uses gradient skies with animated particles, not MP4 videos.
- Point the APK at a deployed instance of **this** backend. Check HTTPS, provider
  quotas and Groq model access without exposing secrets in the app or logs.
- Protect `/dev*` and other billable API surfaces before public deployment.

Local backend regression results and environment limitations are described in
[the architecture](../../ARCHITECTURE.md#11-verification-and-operational-limits).
