import React, { useCallback, useEffect, useRef, useState } from "react";
import { AppState, RefreshControl, StyleSheet, View } from "react-native";
import { router } from "expo-router";

import { AppText, Button, Card, Colors, Icon, InlineBanner, Screen, Space, StateView, Touchable } from "../../src/ui";
import { useTranslation } from "../../src/i18n/useTranslation";
import { useSettingsStore, selectMode } from "../../src/features/settings/settingsStore";
import { useLocationStore } from "../../src/features/location/locationStore";
import { useDeveloperOptionsStore } from "../../src/features/settings/developerOptionsStore";
import { useWeatherStore } from "../../src/features/weather/weatherStore";
import { CurrentConditions } from "../../src/features/weather/components/CurrentConditions";
import { HourlyForecast } from "../../src/features/weather/components/HourlyForecast";
import { DailyForecast } from "../../src/features/weather/components/DailyForecast";
import { MetricTiles } from "../../src/features/weather/components/MetricTiles";
import { HomeSkeleton } from "../../src/features/weather/components/HomeSkeleton";
import { AskCard } from "../../src/features/weather/components/AskCard";
import { WeatherDetail, WeatherDetailSheet } from "../../src/features/weather/components/DetailSheets";
import { LocationPromptBar } from "../../src/features/location/components/LocationPromptBar";

/// Refetch when the app returns to the foreground with data older than this.
const STALE_AFTER_MS = 10 * 60_000;

export default function HomeScreen(): React.ReactElement {
  const t = useTranslation();
  const mode = useSettingsStore(selectMode);
  const units = useSettingsStore((s) => s.units);
  const location = useLocationStore((s) => s.location);
  const snapshot = useWeatherStore((s) => s.snapshot);
  const loading = useWeatherStore((s) => s.loading);
  const error = useWeatherStore((s) => s.error);
  const lastRequest = useWeatherStore((s) => s.lastRequest);
  const devEnabled = useDeveloperOptionsStore((s) => s.enabled);
  const showProvenance = useDeveloperOptionsStore((s) => s.showProvenanceOnHome);
  // Only options that change the request trigger a refetch.
  const devRequestKey = useDeveloperOptionsStore((s) =>
    s.enabled ? [s.sourcePin, s.hourlyHours, s.forecastDays, s.supplementSecondaryFields, s.disableV2Fallback].join("|") : "off",
  );

  const load = useCallback(() => {
    void useWeatherStore.getState().fetchWeather(location, mode, useDeveloperOptionsStore.getState());
  }, [location, mode, devRequestKey]); // eslint-disable-line react-hooks/exhaustive-deps

  useEffect(load, [load]);

  const lastLoad = useRef(Date.now());
  useEffect(() => {
    lastLoad.current = Date.now();
  }, [snapshot]);
  useEffect(() => {
    const sub = AppState.addEventListener("change", (state) => {
      if (state === "active" && Date.now() - lastLoad.current > STALE_AFTER_MS) load();
    });
    return () => sub.remove();
  }, [load]);

  const openLocations = () => router.push("/locations");
  const [detail, setDetail] = useState<WeatherDetail | null>(null);

  if (snapshot === null && error !== null && !loading) {
    return (
      <Screen inTabs>
        <View style={styles.errorWrap}>
          <StateView icon="cloud-off-outline" tone="error" title={t("home.load_failed")} body={error} actionLabel={t("voice.try_again")} onAction={load} />
          <Button label={location.name} icon="map-marker-outline" variant="ghost" onPress={openLocations} />
        </View>
      </Screen>
    );
  }

  return (
    <Screen
      inTabs
      refreshControl={<RefreshControl refreshing={loading && snapshot !== null} onRefresh={load} tintColor={Colors.text} colors={[Colors.accent]} />}
    >
      {snapshot === null ? (
        <HomeSkeleton />
      ) : (
        <>
          <CurrentConditions snapshot={snapshot} locationName={location.name} units={units} onPressLocation={openLocations} />
          <LocationPromptBar />
          {error !== null && <InlineBanner tone="caution" icon="cloud-alert" message={t("home.refresh_failed")} actionLabel={t("chat.retry")} onAction={load} />}
          <AskCard mode={mode} />
          {mode === "farmer" && <FarmShortcut />}
          <HourlyForecast snapshot={snapshot} units={units} onSelectHour={(index) => setDetail({ kind: "hour", index })} />
          <DailyForecast snapshot={snapshot} units={units} onSelectDay={(index) => setDetail({ kind: "day", index })} />
          <MetricTiles snapshot={snapshot} units={units} onSelect={(metric) => setDetail({ kind: "metric", metric })} />
          <Attribution
            source={snapshot.provenance.selectedSource ?? snapshot.provenance.source ?? null}
            detail={devEnabled && (showProvenance || lastRequest?.usedLegacyFallback) ? `${lastRequest?.endpoint ?? ""}${lastRequest?.usedLegacyFallback ? " · legacy fallback" : ""}${snapshot.provenance.runId ? ` · run ${snapshot.provenance.runId}` : ""}` : null}
          />
          <WeatherDetailSheet
            detail={detail}
            snapshot={snapshot}
            units={units}
            developer={devEnabled}
            onClose={() => setDetail(null)}
            onNavigate={setDetail}
          />
        </>
      )}
    </Screen>
  );
}

function FarmShortcut(): React.ReactElement {
  const t = useTranslation();
  return (
    <Touchable onPress={() => router.navigate("/farm")} haptics="light" accessibilityLabel={t("home.action_windows")}>
      <Card style={styles.farm}>
        <View style={styles.farmIcon}>
          <Icon name="sprout" size={22} color={Colors.farmer} />
        </View>
        <View style={styles.flex}>
          <AppText variant="headline">{t("home.action_windows")}</AppText>
          <AppText variant="footnote" tone="secondary">
            {`${t("farmer.irrigation")} · ${t("farmer.spraying")} · ${t("farmer.field_work")}`}
          </AppText>
        </View>
        <Icon name="chevron-right" size={22} color={Colors.textTertiary} />
      </Card>
    </Touchable>
  );
}

function Attribution({ source, detail }: { source: string | null; detail: string | null }): React.ReactElement {
  const t = useTranslation();
  return (
    <View style={styles.attribution}>
      <AppText variant="caption" tone="tertiary" align="center">
        {source !== null ? t("home.via", { source }) : t("home.source_not_reported")}
      </AppText>
      {detail !== null && (
        <AppText variant="caption" tone="tertiary" align="center">
          {detail}
        </AppText>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  flex: {
    flex: 1,
  },
  errorWrap: {
    flex: 1,
    minHeight: 480,
    justifyContent: "center",
    alignItems: "center",
  },
  farm: {
    flexDirection: "row",
    alignItems: "center",
    gap: Space.md,
  },
  farmIcon: {
    width: 44,
    height: 44,
    borderRadius: 14,
    backgroundColor: "rgba(74, 222, 128, 0.14)",
    alignItems: "center",
    justifyContent: "center",
  },
  attribution: {
    gap: 2,
    paddingTop: Space.sm,
  },
});
