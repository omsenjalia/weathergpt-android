import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/services/geocoding_service.dart';
import '../../../models/location.dart';

class LocationNotifier extends StateNotifier<AppLocation> {
  LocationNotifier() : super(_load());

  static AppLocation _load() {
    if (!Hive.isBoxOpen('settings')) return kDefaultLocation;
    final box = Hive.box('settings');
    final raw = box.get('selected_location');
    if (raw is Map) return AppLocation.fromMap(raw);
    return kDefaultLocation;
  }

  Future<void> select(AppLocation location) async {
    state = location;
    if (!Hive.isBoxOpen('settings')) return;
    await Hive.box('settings').put('selected_location', location.toMap());
  }

  /// On first launch after onboarding: ask the OS for location permission
  /// once and, when granted, resolve the real position (with a human place
  /// name) as the active home location.
  ///
  /// Behaviour contract:
  /// - Runs at most once per install (`location_prompted` flag), so a user
  ///   who denied is never nagged again.
  /// - Never overrides an explicit choice (`selected_location` already set).
  /// - Every failure path (service off, denied, denied-forever, timeout)
  ///   silently keeps the default location; the home-screen prompt bar is
  ///   the visible fallback (it can deep-link to app settings).
  Future<void> maybeAutoLocate() async {
    if (!Hive.isBoxOpen('settings')) return;
    final box = Hive.box('settings');
    if (box.get('selected_location') != null) return;
    if ((box.get('location_prompted', defaultValue: false) as bool)) return;
    await box.put('location_prompted', true);
    await selectFromGps();
  }

  /// Whether the OS will show a permission dialog when we ask right now:
  /// yes only when permission has not been decided or denied-forever yet.
  Future<bool> get canAskOs async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.denied ||
        permission == LocationPermission.unableToDetermine;
  }

  /// True when permission was permanently refused and only the system
  /// settings page can change it.
  Future<bool> get isPermanentlyDenied async =>
      await Geolocator.checkPermission() == LocationPermission.deniedForever;

  /// Opens the app's system settings page (the only path left when the OS
  /// permission was permanently refused).
  Future<void> openSystemSettings() => Geolocator.openAppSettings();


  /// Resolve GPS, reverse-geocode a place name, and persist as the active
  /// home location. Returns null when the user denied or the fix failed.
  Future<AppLocation?> selectFromGps() async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    final Position pos;
    try {
      pos = await Geolocator.getCurrentPosition();
    } catch (_) {
      return null;
    }
    final name = await GeocodingService.reverseName(pos.latitude, pos.longitude);
    final loc = AppLocation(name: name, lat: pos.latitude, lon: pos.longitude);
    await select(loc);
    return loc;
  }
}

final locationProvider =
    StateNotifierProvider<LocationNotifier, AppLocation>(
  (ref) => LocationNotifier(),
);
