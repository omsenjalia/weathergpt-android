import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/location.dart';
import '../../home/providers/location_provider.dart';
import '../../home/widgets/location_search_section.dart';
import '../../settings/providers/settings_provider.dart';
import '../providers/map_provider.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  WebViewController? _controller;
  var _loading = true;
  String? _lastUrl;

  static const _layerMeta = <MapLayer, (IconData, Color, String)>{
    MapLayer.wind: (Icons.air, Color(0xFF38BDF8), 'map.layer_wind'),
    MapLayer.rain: (Icons.water_drop_outlined, Color(0xFF60A5FA), 'map.layer_rain'),
    MapLayer.temp: (Icons.thermostat, Color(0xFFF59E0B), 'map.layer_temp'),
    MapLayer.clouds: (Icons.cloud_outlined, Color(0xFF94A3B8), 'map.layer_clouds'),
    MapLayer.radar: (Icons.radar, Color(0xFF10B981), 'map.layer_radar'),
    MapLayer.waves: (Icons.waves, Color(0xFF06B6D4), 'map.layer_waves'),
    MapLayer.pressure: (Icons.speed, Color(0xFFEC4899), 'map.layer_pressure'),
    MapLayer.thunder: (Icons.thunderstorm_outlined, Color(0xFFA78BFA), 'map.layer_thunder'),
    MapLayer.snow: (Icons.ac_unit, Color(0xFFE0F2FE), 'map.layer_snow'),
    MapLayer.humidity: (Icons.opacity, Color(0xFF34D399), 'map.layer_humidity'),
    MapLayer.cape: (Icons.bolt, Color(0xFFF97316), 'map.layer_cape'),
  };

  static const _productLabels = <MapProduct, String>{
    MapProduct.ecmwf: 'ECMWF',
    MapProduct.gfs: 'GFS',
    MapProduct.icon: 'ICON',
    MapProduct.nems: 'NEMS',
  };

  Color get _accent {
    final persona = ref.watch(settingsProvider).userPersona;
    return switch (persona) {
      'farmer' => AppColors.farmerGreen,
      'researcher' => AppColors.researcherBlue,
      _ => AppColors.accent,
    };
  }


  bool _isGoogleAuthUrl(String url) {
    final u = url.toLowerCase();
    return u.contains('accounts.google.com') ||
        u.contains('google.com/account') ||
        u.contains('oauth') && u.contains('google');
  }

  /// Prefer Chrome Custom Tabs (Android) / SFSafariViewController (iOS).
  /// Those share the system browser cookie jar, so Google sign-in persists
  /// much better than an isolated WebView.
  Future<bool> _openInCustomTabs(String url) async {
    final uri = Uri.parse(url);
    // 1) Custom Tabs / SFSafariViewController (in-app browser chrome)
    try {
      if (await canLaunchUrl(uri)) {
        final ok = await launchUrl(
          uri,
          mode: LaunchMode.inAppBrowserView,
          browserConfiguration: const BrowserConfiguration(showTitle: true),
          webOnlyWindowName: '_blank',
        );
        if (ok) return true;
      }
    } catch (_) {
      // Fall through to external browser.
    }
    // 2) Full external browser (Chrome / Safari)
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (ok) return true;
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open Weather Lab. Check that a browser is installed.'),
        ),
      );
    }
    return false;
  }

  Future<void> _openExternal(String url) async {
    await _openInCustomTabs(url);
  }

  /// Friendly prompt when Weather Lab needs Google sign-in.
  Future<void> _promptGoogleSignIn(String authOrLabUrl) async {
    if (!mounted) return;
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Google sign-in required',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'DeepMind Weather Lab needs a Google account. '
                  'We open it in Chrome Custom Tabs / Safari so your '
                  'Google session can persist (much better than WebView).',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(ctx, 'browser'),
                  icon: const Icon(Icons.open_in_browser),
                  label: const Text('Continue with Google (Custom Tabs)'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.black87,
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, 'app'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.borderSubtle),
                    minimumSize: const Size.fromHeight(44),
                  ),
                  child: const Text('Continue in app (may fail)'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, 'cancel'),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted) return;
    if (choice == 'browser') {
      await _openExternal(authOrLabUrl);
    } else if (choice == 'app' && _controller != null) {
      // Stay in WebView — user chose to try embedded login
    } else if (choice == 'cancel') {
      ref.read(mapProvider.notifier).setSource(MapSource.windy);
    }
  }

  Future<void> _onSelectWeatherLab() async {
    ref.read(mapProvider.notifier).setSource(MapSource.weatherLab);
    if (!mounted) return;
    final url = _embedUrl(ref.read(mapProvider));
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Open Weather Lab',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Weather Lab is Google DeepMind\'s AI forecast map. '
                  'A Google account is often required. Opening in your '
                  'browser gives the smoothest login experience.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(ctx, 'browser'),
                  icon: const Icon(Icons.open_in_browser),
                  label: const Text('Open in Custom Tabs (recommended)'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.black87,
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, 'app'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.borderSubtle),
                    minimumSize: const Size.fromHeight(44),
                  ),
                  child: const Text('Try WebView (login may not stick)'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, 'cancel'),
                  child: const Text('Stay on Windy'),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted) return;
    if (choice == 'browser') {
      final opened = await _openInCustomTabs(url);
      // In-app map stays on Windy; Lab runs in Custom Tabs with better sessions.
      ref.read(mapProvider.notifier).setSource(MapSource.windy);
      if (opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Weather Lab opened in Custom Tabs. Google sign-in can persist here.',
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } else if (choice == 'cancel') {
      ref.read(mapProvider.notifier).setSource(MapSource.windy);
    }
    // 'app' → isolated WebView (weaker session persistence)
  }

  String _embedUrl(MapState map) {
    if (map.source == MapSource.weatherLab) {
      // DeepMind Weather Lab — interactive AI forecast map (no scraping).
      // center is lon,lat; zoom ~5–8 works well for regional view.
      final zoom = (map.zoom.clamp(3, 12) * 0.85).toStringAsFixed(2);
      return 'https://deepmind.google.com/science/weatherlab'
          '?cyclones_enabled=false'
          '&weather_enabled=true'
          '&weather_model=weathernext3'
          '&weather_layers=total_precipitation_1hr_mean'
          '&zoom=$zoom'
          '&center=${map.lat},${map.lon}';
    }
    final overlay = map.activeLayer.name;
    final product = map.product.name;
    final menu = map.showMenu ? 'true' : '';
    final marker = map.showMarker ? 'true' : '';
    return 'https://embed.windy.com/embed2.html'
        '?lat=${map.lat}&lon=${map.lon}'
        '&detailLat=${map.lat}&detailLon=${map.lon}'
        '&width=100%25&height=100%25'
        '&zoom=${map.zoom}'
        '&level=surface'
        '&overlay=$overlay'
        '&product=$product'
        '&menu=$menu'
        '&message=true'
        '&marker=$marker'
        '&calendar=now'
        '&pressure='
        '&type=map'
        '&location=coordinates'
        '&detail=true'
        '&metricWind=default'
        '&metricTemp=default'
        '&radarRange=-1';
  }

  void _ensureController(MapState map) {
    final url = _embedUrl(map);
    if (_controller == null) {
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0xFF0B1220))
        ..setNavigationDelegate(
          NavigationDelegate(
            onNavigationRequest: (request) {
              final url = request.url;
              if (_isGoogleAuthUrl(url)) {
                // Don't show bare Google login inside the WebView.
                _promptGoogleSignIn(url);
                return NavigationDecision.prevent;
              }
              return NavigationDecision.navigate;
            },
            onPageStarted: (url) {
              if (mounted) setState(() => _loading = true);
              if (_isGoogleAuthUrl(url)) {
                _promptGoogleSignIn(url);
              }
            },
            onPageFinished: (_) {
              if (mounted) setState(() => _loading = false);
            },
            onWebResourceError: (_) {
              if (mounted) setState(() => _loading = false);
            },
          ),
        )
        ..loadRequest(Uri.parse(url));
      _controller = controller;
      _lastUrl = url;
      return;
    }
    if (_lastUrl != url) {
      _lastUrl = url;
      _controller!.loadRequest(Uri.parse(url));
    }
  }

  Future<void> _applyLocation(AppLocation loc, {int zoom = 8}) async {
    await ref.read(locationProvider.notifier).select(loc);
    ref.read(mapProvider.notifier).setCenter(loc.lat, loc.lon, zoom: zoom);
    if (!mounted) return;
    // Force WebView reload with new center (Weather Lab URL embeds lat/lon).
    final map = ref.read(mapProvider);
    final url = _embedUrl(map);
    _lastUrl = url;
    await _controller?.loadRequest(Uri.parse(url));
  }

  Future<void> _showLocationPicker() async {
    final selected = await showModalBottomSheet<AppLocation>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.viewInsetsOf(ctx).bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Jump to location',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text(
                'Weather Lab follows this center. Search a city or pick a preset.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 340,
                child: LocationSearchSection(
                  autofocus: true,
                  onSelected: (loc) => Navigator.pop(ctx, loc),
                  idleChild: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      for (final loc in kPresetLocations)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading:
                              const Icon(Icons.place_outlined, size: 20),
                          title: Text(loc.name),
                          onTap: () => Navigator.pop(ctx, loc),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (selected != null) await _applyLocation(selected);
  }

  Future<void> _locate() async {
    final location =
        await ref.read(mapProvider.notifier).detectCurrentLocation();
    if (!mounted) return;
    if (location == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('map.location_denied'.tr())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final map = ref.watch(mapProvider);
    final homeLoc = ref.watch(locationProvider);
    final persona = ref.watch(settingsProvider).userPersona;
    final isResearcher = persona == 'researcher';

    // Keep Windy centered on home location; Weather Lab uses explicit picker.
    if (map.source == MapSource.windy &&
        ((map.lat - homeLoc.lat).abs() > 0.01 ||
            (map.lon - homeLoc.lon).abs() > 0.01)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(mapProvider.notifier)
            .setCenter(homeLoc.lat, homeLoc.lon, zoom: map.zoom < 7 ? 8 : map.zoom);
      });
    }
    _ensureController(map);

    final layers = isResearcher
        ? _layerMeta.keys.toList()
        : [
            MapLayer.wind,
            MapLayer.rain,
            MapLayer.temp,
            MapLayer.clouds,
            MapLayer.radar,
            MapLayer.pressure,
          ];

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              child: Row(
                children: [
                  Text(
                    'map.title'.tr(),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  if (isResearcher)
                    Text(
                      'map.researcher_mode'.tr(),
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.researcherBlue),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: SegmentedButton<MapSource>(
                segments: const [
                  ButtonSegment(
                    value: MapSource.windy,
                    label: Text('Windy'),
                    icon: Icon(Icons.air, size: 16),
                  ),
                  ButtonSegment(
                    value: MapSource.weatherLab,
                    label: Text('Weather Lab'),
                    icon: Icon(Icons.auto_awesome, size: 16),
                  ),
                ],
                selected: {map.source},
                onSelectionChanged: (s) {
                  if (s.isEmpty) return;
                  final next = s.first;
                  if (next == MapSource.weatherLab) {
                    _onSelectWeatherLab();
                  } else {
                    ref.read(mapProvider.notifier).setSource(MapSource.windy);
                  }
                },
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),

            // Location control for Weather Lab (cannot set place inside Google UI easily)
            if (map.source == MapSource.weatherLab)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Material(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _showLocationPicker,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          Icon(Icons.place_rounded, color: _accent, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Forecast location',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textTertiary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  homeLoc.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              final loc = await ref
                                  .read(locationProvider.notifier)
                                  .selectFromGps();
                              if (loc != null) await _applyLocation(loc, zoom: 9);
                            },
                            child: const Text('GPS'),
                          ),
                          IconButton(
                            tooltip: 'Search',
                            onPressed: _showLocationPicker,
                            icon: const Icon(Icons.search_rounded),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            // Layer chips (Windy only)
            if (map.source == MapSource.windy)
            SizedBox(
              height: 44,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                scrollDirection: Axis.horizontal,
                itemCount: layers.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final layer = layers[i];
                  final meta = _layerMeta[layer]!;
                  final selected = map.activeLayer == layer;
                  return FilterChip(
                    selected: selected,
                    showCheckmark: false,
                    avatar: Icon(meta.$1,
                        size: 16,
                        color: selected ? Colors.white : meta.$2),
                    label: Text(meta.$3.tr()),
                    selectedColor: _accent.withValues(alpha: 0.35),
                    backgroundColor: AppColors.surfaceCard,
                    side: BorderSide(
                      color: selected
                          ? _accent.withValues(alpha: 0.7)
                          : AppColors.borderSubtle,
                    ),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                    onSelected: (_) =>
                        ref.read(mapProvider.notifier).setLayer(layer),
                  );
                },
              ),
            ),
            if (isResearcher && map.source == MapSource.windy) ...[
              const SizedBox(height: 6),
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    for (final p in MapProduct.values) ...[
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(_productLabels[p]!),
                          selected: map.product == p,
                          onSelected: (_) =>
                              ref.read(mapProvider.notifier).setProduct(p),
                          selectedColor:
                              AppColors.researcherBlue.withValues(alpha: 0.3),
                          labelStyle: const TextStyle(fontSize: 11),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 6),
            Expanded(
              child: Stack(
                children: [
                  if (_controller != null)
                    WebViewWidget(controller: _controller!),
                  if (_loading)
                    const ColoredBox(
                      color: Color(0xFF0B1220),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (map.source == MapSource.windy)
                  Positioned(
                    right: 12,
                    bottom: 20,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _MapFab(
                          icon: Icons.add,
                          color: _accent,
                          onTap: () =>
                              ref.read(mapProvider.notifier).zoomIn(),
                        ),
                        const SizedBox(height: 8),
                        _MapFab(
                          icon: Icons.remove,
                          color: _accent,
                          onTap: () =>
                              ref.read(mapProvider.notifier).zoomOut(),
                        ),
                        const SizedBox(height: 8),
                        _MapFab(
                          icon: map.isLoadingLocation
                              ? null
                              : Icons.my_location,
                          loading: map.isLoadingLocation,
                          color: _accent,
                          onTap: _locate,
                        ),
                        if (isResearcher) ...[
                          const SizedBox(height: 8),
                          _MapFab(
                            icon: map.showMenu
                                ? Icons.menu_open
                                : Icons.menu,
                            color: _accent,
                            onTap: () =>
                                ref.read(mapProvider.notifier).toggleMenu(),
                          ),
                          const SizedBox(height: 8),
                          _MapFab(
                            icon: map.showMarker
                                ? Icons.location_on
                                : Icons.location_off_outlined,
                            color: _accent,
                            onTap: () => ref
                                .read(mapProvider.notifier)
                                .toggleMarker(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (map.source == MapSource.windy)
                  Positioned(
                    left: 12,
                    bottom: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceCard.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Text(
                        map.source == MapSource.weatherLab
                            ? 'Weather Lab · WeatherNext 3 · z${map.zoom}'
                            : 'Windy · ${_productLabels[map.product]} · z${map.zoom}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapFab extends StatelessWidget {
  const _MapFab({
    required this.color,
    required this.onTap,
    this.icon,
    this.loading = false,
  });

  final IconData? icon;
  final bool loading;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceCard,
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: loading ? null : onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: loading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: color),
                  )
                : Icon(icon, color: color, size: 20),
          ),
        ),
      ),
    );
  }
}
