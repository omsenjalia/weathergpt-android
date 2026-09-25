# Background video research

The home screen uses bundled portrait MP4s so the app remains usable when a CDN is
unavailable. The current files are documented in `assets/videos/ATTRIBUTION.txt` and
are described there as 1080x1920 H.264 loops from Wikimedia Commons.

## Vetted 1080x1920 replacement candidates

These clips were checked against their source pages on 17 September 2026. They fit the
9:16 phone viewport and are licensed through the Pexels license. Download the MP4 from
the source page, transcode to the app's H.264/mobile profile, and update
`assets/videos/ATTRIBUTION.txt` before replacing any bundled file.

| Scenario | Candidate | Source details |
| --- | --- | --- |
| Clear / morning / midday | [A Vertical Video of Clouds in a Blue Sky](https://www.pexels.com/video/a-vertical-video-of-clouds-in-a-blue-sky-4055514/) | Cristian Angel · 1080x1920 · 58s · 59.94fps |
| Clear / partly cloudy | [Time Lapse of Moving Clouds in Sky](https://www.pexels.com/video/time-lapse-of-moving-clouds-in-sky-13516810/) | Dmitry Marchenkov · 1080x1920 · 33s · 30fps |
| Clear / soft cloud fallback | [Dreamy Blue Sky with Soft White Clouds](https://www.pexels.com/video/dreamy-blue-sky-with-soft-white-clouds-37465257/) | OMARY AMIRI · 1080x1920 · 11s · 30fps |
| Rain / drizzle | [Rain session back 2024](https://www.pexels.com/video/rain-session-back-2024-26524813/) | Anil Donoji · 1080x1920 · 24s · 25fps |
| Heavy rain / wet-weather detail | [Raindrops Falling on Outdoor Pavement](https://www.pexels.com/video/raindrops-falling-on-outdoor-pavement-34528535/) | Sergei Starostin · 1080x1920 · 49s · 29.97fps |
| Cloudy / overcast calm | [Clouds Moving in Sky over Lake](https://www.pexels.com/video/clouds-moving-in-sky-over-lake-13315051/) | Dmitry Marchenkov · 1080x1920 · 33s · 30fps |

Pexels states that its photos and videos are free for personal and commercial use
without attribution, but depicted brands, people, or property can have separate
rights. Review the current Pexels license before shipping refreshed media.

## Sources not selected for bundling

- [Pixabay storm/sunset/rain](https://pixabay.com/videos/storm-sunset-rain-night-clouds-218530/) is
  high resolution but listed as 3840x2160 (16:9), so it would need a heavy crop in a
  9:16 UI. Pixabay also uses its own content license rather than a blanket CC0 grant.
- [Mixkit weather library](https://mixkit.co/free-stock-video/weather/) has useful HD
  material, but the free resolution/license can vary by clip; one inspected clip listed
  720p personal-use download while 1080p was premium.
- YouTube search results were treated as discovery only. A YouTube upload is not
  automatically licensed for redistribution in a mobile app; use it only when the
  creator provides a clear downloadable license.

The code changes in this pass deliberately keep the offline Wikimedia bundle as the
runtime source while improving contrast and transition behavior. This avoids replacing
working assets with hotlinked URLs or binaries whose download/license provenance has
not been captured in the repository.
