import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/api_error_view.dart';
import '../../../models/location.dart';
import '../../../models/weather.dart';
import '../../explore/providers/saved_locations_provider.dart';
import '../../settings/providers/developer_options_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../providers/atmosphere_provider.dart';
import '../providers/location_provider.dart';
import '../providers/weather_provider.dart';
import '../theme/atmosphere_theme.dart';
import '../widgets/atmosphere_video_background.dart';
import '../widgets/location_search_section.dart';
import '../widgets/voice_orb.dart';
import '../widgets/weather_detail_panels.dart';
import '../widgets/weather_hero_card.dart';
import '../widgets/weather_metric_strip.dart';
import '../widgets/weather_provenance_bar.dart';
import '../widgets/weather_segment_tabs.dart';

class WeatherHomeScreen extends ConsumerStatefulWidget {
  const WeatherHomeScreen({super.key});

  @override
  ConsumerState<WeatherHomeScreen> createState() => _WeatherHomeScreenState();
}

class _WeatherHomeScreenState extends ConsumerState<WeatherHomeScreen> {
  int _tab = 0;
  bool _bannerDismissed = false;

  @override
  void initState() {
    super.initState();
    // First launch: ask for location permission once so the app opens on the
    // user's real city instead of the Ahmedabad default. Silent no-op when
    // the user already chose a location or denied. If the OS can no longer
    // show its dialog (permanently denied earlier), the prompt bar below is
    // the visible fallback.
    _bannerDismissed = Hive.box('settings')
        .get('location_banner_dismissed', defaultValue: false) as bool;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(locationProvider.notifier).maybeAutoLocate();
    });
  }

  Future<void> _enableLocation() async {
    final notifier = ref.read(locationProvider.notifier);
    final loc = await notifier.selectFromGps();
    if (loc != null || !mounted) return;
    // Something blocked the ask: explain instead of failing silently.
    final permanentlyDenied = await notifier.isPermanentlyDenied;
    if (!mounted) return;
    if (permanentlyDenied) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surfaceCardAlt,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text('location.settings_title'.tr()),
          content: Text('location.settings_body'.tr()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('location.cancel'.tr()),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                notifier.openSystemSettings();
              },
              child: Text('location.open_settings'.tr()),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('location.not_available'.tr())),
      );
    }
  }

  Future<void> _pickLocation() async {
    final selected = await showModalBottomSheet<AppLocation>(
      context: context,
      backgroundColor: AppColors.surfaceCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const _LocationSheet(),
    );
    if (selected != null) {
      // weatherProvider re-fetches automatically on location change,
      // so no manual invalidate is needed.
      await ref.read(locationProvider.notifier).select(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Minute cadence: recompute the sky period while the user sits on Home.
    ref.watch(clockTickerProvider);
    final location = ref.watch(locationProvider);
    final weatherAsync = ref.watch(weatherProvider);
    // The two compact enrichments are an Everyone-mode contract; Farmer and
    // Researcher get their own scope instead of the same card recoloured.
    final mode = ref.watch(settingsProvider.select((s) => s.mode));
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final bottomInset = bottomPad + 100; // space for nav + mic

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: weatherAsync.when(
        loading: () => const _HomeSkeleton(),
        error: (e, _) => ApiErrorView(
          error: e,
          onRetry: () => ref.invalidate(weatherProvider),
        ),
        data: (w) {
          final sunrise = parseWeatherTime(w.sunrise);
          final sunset = parseWeatherTime(w.sunset);
          final dev = ref.watch(developerOptionsProvider);
          final period = (dev.enabled && dev.forcePeriod != null)
              ? dev.forcePeriod!
              : periodFromLocalTime(DateTime.now(), sunrise, sunset);
          final sky = (dev.enabled && dev.forceSky != null)
              ? dev.forceSky!
              : conditionFromWeather(w);
          final palette = paletteFor(period, sky);

          return Stack(
            children: [
              Positioned.fill(
                child: (dev.enabled && dev.disableVideoSky)
                    ? DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [palette.top, palette.mid, palette.bottom],
                          ),
                        ),
                      )
                    : AtmosphereVideoBackground(
                        palette: palette,
                        sky: sky,
                        period: period,
                      ),
              ),
              // readability veil over lower content
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: MediaQuery.sizeOf(context).height * 0.55,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        palette.bottom.withValues(alpha: 0.55),
                        const Color(0xFF0B1220).withValues(alpha: 0.92),
                      ],
                    ),
                  ),
                ),
              ),
              SafeArea(
                bottom: false,
                child: RefreshIndicator(
                  color: palette.accent,
                  backgroundColor: AppColors.bgElevated,
                  onRefresh: () async {
                    HapticFeedback.lightImpact();
                    ref.invalidate(weatherProvider);
                  },
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.24),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: _pickLocation,
                                  child: Row(
                                    children: [
                                      Icon(Icons.near_me_rounded,
                                          size: 18, color: palette.accent),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          location.name.split(',').first,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: palette.text,
                                            shadows: const [
                                              Shadow(
                                                color: Colors.black54,
                                                blurRadius: 8,
                                              ),
                                            ],
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Icon(Icons.keyboard_arrow_down_rounded,
                                          color: palette.textMuted),
                                    ],
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => context.go('/profile'),
                                icon: Icon(Icons.settings_outlined,
                                    color: palette.text),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: WeatherHeroCard(weather: w, palette: palette),
                      ),
                    ),
                    // First-run helper: when we are still on the default
                    // city and the OS permission is not granted, offer a
                    // visible one-tap enable (the OS dialog alone can be
                    // permanently suppressed by an earlier denial).
                    if (location.name == kDefaultLocation.name &&
                        !_bannerDismissed)
                      SliverToBoxAdapter(
                        child: _LocationPromptBar(
                          onEnable: _enableLocation,
                          onDismiss: () {
                            setState(() => _bannerDismissed = true);
                            Hive.box('settings').put(
                                'location_banner_dismissed', true);
                          },
                        ),
                      ),
                    // Source / run / freshness chips live on the developer
                    // Debug screen; they only return to the home screen when a
                    // developer explicitly asks for them. The compact status
                    // line is developer-only too — regular users see no
                    // provenance or freshness UI on Home at all.
                    if (dev.enabled && dev.showProvenanceOnHome)
                      SliverToBoxAdapter(
                        child: WeatherProvenanceBar(
                          weather: w,
                          palette: palette,
                          showEnrichments: mode == AppMode.everyone,
                        ),
                      )
                    else if (dev.enabled)
                      SliverToBoxAdapter(
                        child: _CompactStatusLine(weather: w, palette: palette),
                      ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: WeatherMetricStrip(weather: w, palette: palette),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 18)),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: WeatherSegmentTabs(
                          index: _tab,
                          onChanged: (i) => setState(() => _tab = i),
                          palette: palette,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                        child: _tab == 0
                            ? WeatherOverviewGrid(
                                weather: w,
                                palette: palette,
                                showSourceBadges: dev.enabled &&
                                    dev.showFieldSourceBadges,
                                showProvenance: dev.enabled,
                              )
                            : _tab == 1
                                ? WeatherHourlyPanel(
                                    weather: w,
                                    palette: palette,
                                    maxHours: dev.enabled ? dev.hourlyHours : 48,
                                    showProvenance: dev.enabled,
                                  )
                                : WeatherDailyPanel(
                                    weather: w,
                                    palette: palette,
                                    maxDays: dev.enabled ? dev.forecastDays : 7,
                                    showProvenance: dev.enabled,
                                  ),
                      ),
                    ),
                    SliverToBoxAdapter(child: SizedBox(height: bottomInset + 24)),
                  ],
                ),
                ),
              ),
              // Mic FAB — above floating nav bar (classic position)
              Positioned(
                left: 0,
                right: 0,
                bottom: bottomPad + 78,
                child: Center(
                  child: VoiceOrb(
                    palette: palette,
                    onTap: () => context.push('/voice/listening', extra: {
                      'accent': palette.accent,
                    }),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Developer-only one-liner under the hero: full "source · run · stale"
/// attribution, a stale/degraded warning when — and only when — the backend
/// says so, and a shortcut to the Debug screen.
///
/// Regular users see no status line at all — provenance and freshness live
/// on the Debug screen.
class _CompactStatusLine extends StatelessWidget {
  const _CompactStatusLine({required this.weather, required this.palette});
  final WeatherSnapshot weather;
  final AtmospherePalette palette;

  @override
  Widget build(BuildContext context) {
    final p = weather.provenance;
    final name = !p.hasSource
        ? 'home.source_not_reported'.tr()
        : switch (p.provider) {
            WeatherProvider.imd => 'IMD',
            WeatherProvider.weathernext => 'WeatherNext',
            WeatherProvider.accuweather => 'AccuWeather',
            WeatherProvider.openMeteo => 'Open-Meteo',
            WeatherProvider.unknown => p.selectedSource ?? p.source!,
          };
    final stale = p.isStaleAt(DateTime.now().toUtc(), maxAge: const Duration(hours: 24));
    final warn = (weather.degraded ?? p.fallback) || stale;
    final stamp = p.issuedAtUtc;
    final when = stamp == null ? null : DateFormat('HH:mm').format(weather.toLocationLocal(stamp));
    final parts = <String>[
      name,
      if (when != null) 'home.run_at'.tr(namedArgs: {'time': when}),
      if (stale) 'home.stale'.tr(),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
      child: GestureDetector(
        onTap: () => context.push('/debug'),
        child: Row(
          children: [
            Icon(
              warn ? Icons.report_gmailerrorred_outlined : (p.isWeatherNext ? Icons.auto_awesome : Icons.public),
              size: 13,
              color: warn ? const Color(0xFFFBBF24) : palette.textMuted,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                parts.join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: warn ? const Color(0xFFFBBF24) : palette.textMuted,
                  shadows: const [Shadow(color: Colors.black45, blurRadius: 6)],
                ),
              ),
            ),
            Icon(Icons.bug_report_outlined, size: 14, color: palette.textMuted),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet listing preset + saved locations and the GPS option.
class _LocationSheet extends ConsumerWidget {
  const _LocationSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(locationProvider);
    final saved = ref.watch(savedLocationsProvider);
    final options = <AppLocation>[
      ...kPresetLocations,
      ...saved.map((s) => AppLocation(name: s.name, lat: s.lat, lon: s.lon)),
    ];
    final seen = <String>{};
    final unique = <AppLocation>[];
    for (final o in options) {
      if (seen.add(o.name)) unique.add(o);
    }
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'home.choose_location'.tr(),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.my_location, color: AppColors.accent),
              title: Text('home.use_my_location'.tr()),
              onTap: () async {
                final loc =
                    await ref.read(locationProvider.notifier).selectFromGps();
                if (context.mounted) Navigator.pop(context, loc);
              },
            ),
            const Divider(height: 1, color: AppColors.borderSubtle),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: LocationSearchSection(
                  onSelected: (loc) => Navigator.pop(context, loc),
                  idleChild: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: unique.length,
                itemBuilder: (_, i) {
                  final loc = unique[i];
                  final sel = loc.name == current.name;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.place_outlined,
                      color: sel ? AppColors.accent : AppColors.textSecondary,
                    ),
                    title: Text(loc.name),
                    trailing: sel
                        ? const Icon(Icons.check_circle,
                            color: AppColors.accent, size: 20)
                        : null,
                    onTap: () => Navigator.pop(context, loc),
                  );
                },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Layout-stable shimmer skeleton shown while the first snapshot loads.
class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Shimmer.fromColors(
          baseColor: const Color(0xFF1A2740),
          highlightColor: const Color(0xFF243149),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 132,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  height: 226,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    for (var i = 0; i < 3; i++) ...[
                      if (i > 0) const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          height: 104,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One-tap "turn on location" bar shown while the app is still on the
/// default city. Glass pill with an accent action — dismissible.
class _LocationPromptBar extends StatelessWidget {
  const _LocationPromptBar({required this.onEnable, required this.onDismiss});

  final VoidCallback onEnable;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        decoration: BoxDecoration(
          color: AppColors.glassFillStrong,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.statusAmber.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.location_on_outlined,
              size: 20,
              color: AppColors.statusAmber,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'location.banner'.tr(),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: onEnable,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.ctaTextDark,
                backgroundColor: AppColors.accent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: const StadiumBorder(),
              ),
              child: Text(
                'location.enable'.tr(),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: onDismiss,
              icon: const Icon(Icons.close_rounded,
                  size: 18, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
