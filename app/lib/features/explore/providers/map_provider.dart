import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// Windy embed overlay ids (must match embed.windy.com `overlay=` values).
enum MapLayer {
  wind,
  rain,
  temp,
  clouds,
  radar,
  waves,
  pressure,
  thunder,
  snow,
  humidity,
  cape,
}

enum MapProduct { ecmwf, gfs, icon, nems }

/// Which map engine to show in Explore.
enum MapSource { windy, weatherLab }


class MapState {
  const MapState({
    this.activeLayer = MapLayer.wind,
    this.product = MapProduct.ecmwf,
    this.source = MapSource.windy,
    this.lat = 23.0225,
    this.lon = 72.5714,
    this.zoom = 6,
    this.showMenu = false,
    this.showMarker = true,
    this.currentLocation,
    this.isLoadingLocation = false,
  });

  final MapLayer activeLayer;
  final MapProduct product;
  final MapSource source;
  final double lat;
  final double lon;
  final int zoom;
  final bool showMenu;
  final bool showMarker;
  final ({double lat, double lon})? currentLocation;
  final bool isLoadingLocation;

  MapState copyWith({
    MapLayer? activeLayer,
    MapProduct? product,
    MapSource? source,
    double? lat,
    double? lon,
    int? zoom,
    bool? showMenu,
    bool? showMarker,
    ({double lat, double lon})? currentLocation,
    bool? isLoadingLocation,
    bool clearLocation = false,
  }) =>
      MapState(
        activeLayer: activeLayer ?? this.activeLayer,
        product: product ?? this.product,
        source: source ?? this.source,
        lat: lat ?? this.lat,
        lon: lon ?? this.lon,
        zoom: zoom ?? this.zoom,
        showMenu: showMenu ?? this.showMenu,
        showMarker: showMarker ?? this.showMarker,
        currentLocation:
            clearLocation ? null : (currentLocation ?? this.currentLocation),
        isLoadingLocation: isLoadingLocation ?? this.isLoadingLocation,
      );
}

class MapNotifier extends StateNotifier<MapState> {
  MapNotifier() : super(const MapState());

  void setLayer(MapLayer layer) => state = state.copyWith(activeLayer: layer);

  void setProduct(MapProduct product) =>
      state = state.copyWith(product: product);

  void setSource(MapSource source) => state = state.copyWith(source: source);

  void setZoom(int zoom) =>
      state = state.copyWith(zoom: zoom.clamp(3, 12));

  void zoomIn() => setZoom(state.zoom + 1);

  void zoomOut() => setZoom(state.zoom - 1);

  void toggleMenu() => state = state.copyWith(showMenu: !state.showMenu);

  void toggleMarker() =>
      state = state.copyWith(showMarker: !state.showMarker);

  void setCenter(double lat, double lon, {int? zoom}) => state = state.copyWith(
        lat: lat,
        lon: lon,
        zoom: zoom ?? state.zoom,
      );

  Future<({double lat, double lon})?> detectCurrentLocation() async {
    state = state.copyWith(isLoadingLocation: true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      final position = await Geolocator.getCurrentPosition();
      final location = (lat: position.latitude, lon: position.longitude);
      state = state.copyWith(
        currentLocation: location,
        lat: location.lat,
        lon: location.lon,
        zoom: 11,
      );
      return location;
    } finally {
      state = state.copyWith(isLoadingLocation: false);
    }
  }
}

final mapProvider = StateNotifierProvider<MapNotifier, MapState>(
  (ref) => MapNotifier(),
);
