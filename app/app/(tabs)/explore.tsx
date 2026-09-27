import React, { useEffect, useState } from "react";
import { ActivityIndicator, Platform, ScrollView, StyleSheet, View } from "react-native";
import { WebView } from "react-native-webview";
import { router } from "expo-router";
import * as WebBrowser from "expo-web-browser";
import { useSafeAreaInsets } from "react-native-safe-area-context";

import { AppText, Colors, Icon, IconName, Layout, Radius, Space, StateView, Touchable } from "../../src/ui";
import { useTranslation } from "../../src/i18n/useTranslation";
import {
  MAP_ALL_LAYERS,
  MAP_BASIC_LAYERS,
  MAP_PRODUCTS,
  MapLayer,
  MapProduct,
  useMapStore,
  weatherLabUrl,
  windyEmbedUrl,
} from "../../src/features/explore/exploreStores";
import { useLocationStore } from "../../src/features/location/locationStore";
import { useSettingsStore, selectMode } from "../../src/features/settings/settingsStore";

const LAYER_META: Record<MapLayer, { key: string; icon: IconName; color: string }> = {
  [MapLayer.Wind]: { key: "map.layer_wind", icon: "weather-windy", color: "#38BDF8" },
  [MapLayer.Rain]: { key: "map.layer_rain", icon: "water-outline", color: "#60A5FA" },
  [MapLayer.Temp]: { key: "map.layer_temp", icon: "thermometer", color: "#F59E0B" },
  [MapLayer.Clouds]: { key: "map.layer_clouds", icon: "cloud-outline", color: "#94A3B8" },
  [MapLayer.Radar]: { key: "map.layer_radar", icon: "radar", color: "#10B981" },
  [MapLayer.Waves]: { key: "map.layer_waves", icon: "waves", color: "#06B6D4" },
  [MapLayer.Pressure]: { key: "map.layer_pressure", icon: "gauge", color: "#EC4899" },
  [MapLayer.Thunder]: { key: "map.layer_thunder", icon: "weather-lightning", color: "#A78BFA" },
  [MapLayer.Snow]: { key: "map.layer_snow", icon: "snowflake", color: "#E0F2FE" },
  [MapLayer.Humidity]: { key: "map.layer_humidity", icon: "water-percent", color: "#34D399" },
  [MapLayer.Cape]: { key: "map.layer_cape", icon: "flash-outline", color: "#F97316" },
};

const PRODUCT_LABEL: Record<MapProduct, string> = {
  [MapProduct.Ecmwf]: "ECMWF",
  [MapProduct.Gfs]: "GFS",
  [MapProduct.Icon]: "ICON",
  [MapProduct.Nems]: "NEMS",
};

/// Full-screen Windy map with floating controls (port of the Flutter
/// explore screen). The map follows the Home location.
export default function ExploreScreen(): React.ReactElement {
  const t = useTranslation();
  const insets = useSafeAreaInsets();
  const map = useMapStore();
  const location = useLocationStore((s) => s.location);
  const researcher = useSettingsStore(selectMode) === "researcher";
  const [loading, setLoading] = useState(true);
  const [failed, setFailed] = useState(false);
  const [locating, setLocating] = useState(false);
  const [locateError, setLocateError] = useState(false);

  useEffect(() => {
    useMapStore.getState().setCenter(location.lat, location.lon, Math.max(useMapStore.getState().zoom, 7));
  }, [location.lat, location.lon]);

  const url = windyEmbedUrl(map);
  useEffect(() => setLoading(true), [url]);

  const locate = async () => {
    setLocating(true);
    setLocateError(false);
    const place = await useLocationStore.getState().selectFromGps();
    setLocating(false);
    if (place === null) setLocateError(true);
  };

  const openWeatherLab = () => void WebBrowser.openBrowserAsync(weatherLabUrl(map)).catch(() => undefined);
  const layers = researcher ? MAP_ALL_LAYERS : MAP_BASIC_LAYERS;
  const bottom = Layout.tabBarHeight + 8 + Math.max(insets.bottom, Space.md) + Space.xl;

  return (
    <View style={styles.root}>
      <View style={StyleSheet.absoluteFill}>
        {failed ? (
          <View style={styles.center}>
            <StateView icon="map-marker-off-outline" tone="error" title={t("map.unavailable")} actionLabel={t("chat.retry")} onAction={() => setFailed(false)} />
          </View>
        ) : Platform.OS === "web" ? (
          <iframe key={url} src={url} title={t("map.title")} onLoad={() => setLoading(false)} style={{ width: "100%", height: "100%", border: "none" }} />
        ) : (
          <WebView
            source={{ uri: url }}
            style={styles.web}
            originWhitelist={["https://*"]}
            mixedContentMode="never"
            onLoadEnd={() => setLoading(false)}
            onError={() => setFailed(true)}
            onHttpError={() => setFailed(true)}
          />
        )}
        {loading && !failed && (
          <View style={styles.loading} pointerEvents="none">
            <ActivityIndicator color={Colors.text} />
          </View>
        )}
      </View>

      {/* Top bar */}
      <View pointerEvents="box-none" style={[styles.top, { paddingTop: insets.top + Space.sm }]}>
        <View style={styles.topBar}>
          <Touchable onPress={() => router.push("/locations")} scale={false} accessibilityLabel={`${t("home.choose_location")}: ${location.name}`} style={styles.place}>
            <Icon name="map-marker" size={18} color={Colors.accentText} />
            <View style={styles.flex}>
              <AppText variant="caption" tone="tertiary">
                {t("map.title")}
              </AppText>
              <AppText variant="callout" numberOfLines={1}>
                {location.name.split(",")[0]}
              </AppText>
            </View>
          </Touchable>
          <View style={styles.sources}>
            <View style={[styles.source, styles.sourceActive]}>
              <Icon name="weather-windy" size={15} color={Colors.onAccent} />
              <AppText variant="footnote" color={Colors.onAccent}>
                Windy
              </AppText>
            </View>
            <Touchable onPress={openWeatherLab} accessibilityLabel="Weather Lab" accessibilityHint="Opens Google DeepMind Weather Lab in the browser" style={styles.source}>
              <Icon name="creation" size={15} color={Colors.textSecondary} />
              <AppText variant="footnote" tone="secondary">
                Weather Lab
              </AppText>
              <Icon name="open-in-new" size={12} color={Colors.textTertiary} />
            </Touchable>
          </View>
        </View>
        {locateError && (
          <View style={styles.toast}>
            <AppText variant="footnote">{t("map.location_denied")}</AppText>
          </View>
        )}
      </View>

      {/* Map controls */}
      <View pointerEvents="box-none" style={[styles.fabs, { bottom: bottom + (researcher ? 108 : 64) }]}>
        <Fab icon="plus" label={t("map.zoom_in")} onPress={() => useMapStore.getState().zoomIn()} />
        <Fab icon="minus" label={t("map.zoom_out")} onPress={() => useMapStore.getState().zoomOut()} />
        <Fab icon="crosshairs-gps" label={t("home.use_my_location")} busy={locating} onPress={() => void locate()} />
        {researcher && (
          <>
            <Fab icon={map.showMenu ? "menu-open" : "menu"} label="Windy menu" active={map.showMenu === true} onPress={() => useMapStore.getState().toggleMenu()} />
            <Fab icon={map.showMarker === false ? "map-marker-off-outline" : "map-marker"} label="Marker" active={map.showMarker !== false} onPress={() => useMapStore.getState().toggleMarker()} />
          </>
        )}
      </View>

      {/* Layers */}
      <View pointerEvents="box-none" style={[styles.bottomBar, { bottom }]}>
        {researcher && (
          <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.chips}>
            <AppText variant="caption" tone="secondary" style={styles.researcherTag}>
              {t("map.researcher_mode")}
            </AppText>
            {MAP_PRODUCTS.map((product) => (
              <MapChip key={product} label={PRODUCT_LABEL[product]} selected={map.product === product} color={Colors.researcher} onPress={() => useMapStore.getState().setProduct(product)} />
            ))}
          </ScrollView>
        )}
        <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.chips}>
          {layers.map((layer) => (
            <MapChip
              key={layer}
              icon={LAYER_META[layer].icon}
              label={t(LAYER_META[layer].key)}
              color={LAYER_META[layer].color}
              selected={map.activeLayer === layer}
              onPress={() => useMapStore.getState().setLayer(layer)}
            />
          ))}
        </ScrollView>
      </View>
    </View>
  );
}

function MapChip({ label, icon, color, selected, onPress }: { label: string; icon?: IconName; color: string; selected: boolean; onPress: () => void }): React.ReactElement {
  return (
    <Touchable
      onPress={onPress}
      haptics="selection"
      accessibilityRole="button"
      accessibilityState={{ selected }}
      accessibilityLabel={label}
      style={[styles.chip, selected && { borderColor: color, backgroundColor: "rgba(8, 13, 26, 0.95)" }]}
    >
      {icon !== undefined && <Icon name={icon} size={16} color={selected ? color : Colors.textSecondary} />}
      <AppText variant="footnote" tone={selected ? "primary" : "secondary"}>
        {label}
      </AppText>
    </Touchable>
  );
}

function Fab({ icon, label, onPress, busy = false, active = false }: { icon: IconName; label: string; onPress: () => void; busy?: boolean; active?: boolean }): React.ReactElement {
  return (
    <Touchable onPress={onPress} accessibilityLabel={label} style={[styles.fab, active && styles.fabActive]}>
      {busy ? <ActivityIndicator size="small" color={Colors.text} /> : <Icon name={icon} size={22} color={active ? Colors.accentText : Colors.text} />}
    </Touchable>
  );
}

const GLASS = "rgba(8, 13, 26, 0.82)";

const styles = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: Colors.canvasDeep,
  },
  flex: {
    flex: 1,
  },
  web: {
    flex: 1,
    backgroundColor: Colors.canvasDeep,
  },
  center: {
    flex: 1,
    justifyContent: "center",
  },
  loading: {
    ...StyleSheet.absoluteFillObject,
    alignItems: "center",
    justifyContent: "center",
  },
  top: {
    position: "absolute",
    left: 0,
    right: 0,
    top: 0,
    paddingHorizontal: Space.md,
    gap: Space.sm,
  },
  topBar: {
    flexDirection: "row",
    alignItems: "center",
    gap: Space.sm,
    padding: 6,
    borderRadius: Radius.lg,
    backgroundColor: GLASS,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: Colors.hairlineStrong,
  },
  place: {
    flex: 1,
    flexDirection: "row",
    alignItems: "center",
    gap: Space.sm,
    paddingHorizontal: Space.sm,
    minHeight: 44,
  },
  sources: {
    flexDirection: "row",
    padding: 3,
    borderRadius: Radius.pill,
    backgroundColor: Colors.surfaceInset,
  },
  source: {
    flexDirection: "row",
    alignItems: "center",
    gap: 4,
    minHeight: 34,
    paddingHorizontal: Space.md,
    borderRadius: Radius.pill,
  },
  sourceActive: {
    backgroundColor: Colors.accent,
  },
  toast: {
    alignSelf: "center",
    paddingHorizontal: Space.lg,
    paddingVertical: Space.sm,
    borderRadius: Radius.pill,
    backgroundColor: GLASS,
  },
  fabs: {
    position: "absolute",
    right: Space.md,
    gap: Space.sm,
  },
  fab: {
    width: 46,
    height: 46,
    borderRadius: 23,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: GLASS,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: Colors.hairlineStrong,
  },
  fabActive: {
    borderColor: Colors.accent,
  },
  bottomBar: {
    position: "absolute",
    left: 0,
    right: 0,
    gap: Space.sm,
  },
  chips: {
    gap: Space.sm,
    paddingHorizontal: Space.md,
    alignItems: "center",
  },
  researcherTag: {
    paddingHorizontal: Space.xs,
  },
  chip: {
    flexDirection: "row",
    alignItems: "center",
    gap: 6,
    minHeight: 40,
    paddingHorizontal: 14,
    borderRadius: Radius.pill,
    borderWidth: 1.5,
    borderColor: Colors.hairlineStrong,
    backgroundColor: GLASS,
  },
});
