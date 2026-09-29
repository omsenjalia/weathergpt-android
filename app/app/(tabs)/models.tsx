import React, { useEffect, useState } from "react";
import { StyleSheet, View } from "react-native";

import { AppText, Card, CardHeader, Colors, Divider, Radius, Screen, SegmentedControl, Skeleton, Space, StateView } from "../../src/ui";
import { LineChart } from "../../src/ui/charts/LineChart";
import { useTranslation } from "../../src/i18n/useTranslation";
import { LANGUAGE_META } from "../../src/i18n";
import { useLocationStore } from "../../src/features/location/locationStore";
import {
  CatalogProvider,
  displayUnit,
  fetchCatalog,
  fetchForecastSeries,
  ForecastSeries,
  SeriesVariable,
  sourceLabel,
  tickUnit,
} from "../../src/features/research/modelData";

type Async<T> = { kind: "loading" } | { kind: "error"; message: string } | { kind: "data"; value: T };

function formatValue(value: number, units: string): string {
  const rounded = Math.abs(value) >= 100 ? Math.round(value) : Math.round(value * 10) / 10;
  return units === "C" ? `${rounded}°` : `${rounded} ${units}`;
}

const errorMessage = (e: unknown) => (e instanceof Error ? e.message : String(e));

export default function ModelsScreen(): React.ReactElement {
  const t = useTranslation();
  return (
    <Screen inTabs title={t("nav.models")}>
      <SeriesCard />
      <ProvidersCard />
    </Screen>
  );
}

function SeriesCard(): React.ReactElement {
  const t = useTranslation();
  const location = useLocationStore((s) => s.location);
  const [variable, setVariable] = useState<SeriesVariable>(SeriesVariable.Temperature);
  const [series, setSeries] = useState<Async<ForecastSeries>>({ kind: "loading" });
  const [attempt, setAttempt] = useState(0);

  useEffect(() => {
    // Only the latest selection may write state.
    let active = true;
    setSeries({ kind: "loading" });
    fetchForecastSeries(variable, location)
      .then((value) => active && setSeries({ kind: "data", value }))
      .catch((e: unknown) => active && setSeries({ kind: "error", message: errorMessage(e) }));
    return () => {
      active = false;
    };
  }, [variable, location, attempt]);

  const locale = LANGUAGE_META[t.language].ttsLocale;
  const data = series.kind === "data" ? series.value : null;
  const dayLabel = (startMs: number) => (x: number) => new Date(startMs + x * 3_600_000).toLocaleDateString(locale, { weekday: "short", day: "numeric" });

  return (
    <Card style={styles.gap}>
      <CardHeader icon="chart-bell-curve-cumulative" title={`${t("models.forecast_series")} · ${location.name.split(",")[0]}`} />
      <SegmentedControl
        value={variable}
        onChange={setVariable}
        segments={[
          { value: SeriesVariable.Temperature, label: t("researcher.temperature") },
          { value: SeriesVariable.Rainfall, label: t("researcher.rainfall") },
          { value: SeriesVariable.Wind, label: t("home.wind") },
        ]}
      />
      {series.kind === "loading" && <Skeleton height={200} radius={12} />}
      {series.kind === "error" && <StateView compact tone="error" icon="database-alert-outline" title={t("voice.error")} body={series.message} actionLabel={t("chat.retry")} onAction={() => setAttempt((n) => n + 1)} />}
      {data !== null && (data.status !== "ok" || data.mean.length === 0) && (
        <StateView compact icon="database-off-outline" title={t("home.unavailable")} body={data.detail ?? t("home.unavailable_generic_short")} />
      )}
      {data !== null && data.status === "ok" && data.mean.length > 0 && (
        <>
          <LineChart
            series={[{ points: data.mean, color: Colors.researcher }]}
            unit={tickUnit(data.units)}
            formatX={dayLabel(data.startMs)}
            accessibilityLabel={`${t("models.forecast_series")} ${displayUnit(data.units)}`}
          />
          <View style={styles.legend}>
            <LegendItem label={`${t("lab.mean")} (${displayUnit(data.units)})`} />
          </View>
          <View style={styles.stats}>
            <Stat label={t("home.uv_high")} value={formatValue(Math.max(...data.mean.map((p) => p.value)), data.units)} />
            <Stat label={t("home.uv_low")} value={formatValue(Math.min(...data.mean.map((p) => p.value)), data.units)} />
          </View>
          <AppText variant="caption" tone="tertiary">
            {`${t("models.source")}: ${sourceLabel(data)}`}
          </AppText>
        </>
      )}
    </Card>
  );
}

function ProvidersCard(): React.ReactElement {
  const t = useTranslation();
  const [catalog, setCatalog] = useState<Async<CatalogProvider[]>>({ kind: "loading" });
  const [attempt, setAttempt] = useState(0);

  useEffect(() => {
    let active = true;
    setCatalog({ kind: "loading" });
    fetchCatalog()
      .then((value) => active && setCatalog({ kind: "data", value }))
      .catch((e: unknown) => active && setCatalog({ kind: "error", message: errorMessage(e) }));
    return () => {
      active = false;
    };
  }, [attempt]);

  return (
    <Card style={styles.gap}>
      <CardHeader icon="database-outline" title={t("models.providers")} />
      {catalog.kind === "loading" && <Skeleton height={160} radius={12} />}
      {catalog.kind === "error" && <StateView compact tone="error" icon="database-alert-outline" title={t("voice.error")} body={catalog.message} actionLabel={t("chat.retry")} onAction={() => setAttempt((n) => n + 1)} />}
      {catalog.kind === "data" &&
        catalog.value.map((provider, i) => (
          <React.Fragment key={provider.id}>
            {i > 0 && <Divider />}
            <View style={styles.provider}>
              <AppText variant="callout">{provider.name}</AppText>
              <View style={styles.badges}>
                {provider.coverage !== "" && <Badge label={provider.coverage} />}
                {provider.hourly && <Badge label={t("models.hourly")} />}
              </View>
              <AppText variant="footnote" tone="tertiary">
                {provider.products.join(" · ")}
              </AppText>
            </View>
          </React.Fragment>
        ))}
    </Card>
  );
}

function LegendItem({ label, muted = false }: { label: string; muted?: boolean }): React.ReactElement {
  return (
    <View style={styles.legendItem}>
      <View style={[styles.swatch, muted && styles.swatchMuted]} />
      <AppText variant="footnote" tone="secondary">
        {label}
      </AppText>
    </View>
  );
}

function Badge({ label, accent = false }: { label: string; accent?: boolean }): React.ReactElement {
  return (
    <View style={[styles.badge, accent && styles.badgeAccent]}>
      <AppText variant="caption" color={accent ? Colors.researcher : undefined} tone="secondary">
        {label}
      </AppText>
    </View>
  );
}

function Stat({ label, value }: { label: string; value: string }): React.ReactElement {
  return (
    <View style={styles.stat}>
      <AppText variant="caption" tone="tertiary" numberOfLines={2}>
        {label}
      </AppText>
      <AppText variant="numeric" numberOfLines={1} adjustsFontSizeToFit minimumFontScale={0.7}>
        {value}
      </AppText>
    </View>
  );
}

const styles = StyleSheet.create({
  gap: {
    gap: Space.md,
  },
  legend: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: Space.md,
  },
  legendItem: {
    flexDirection: "row",
    alignItems: "center",
    gap: 6,
  },
  swatch: {
    width: 14,
    height: 3,
    borderRadius: 2,
    backgroundColor: Colors.researcher,
  },
  swatchMuted: {
    height: 1.5,
    opacity: 0.55,
  },
  stats: {
    flexDirection: "row",
    gap: Space.sm,
  },
  stat: {
    flex: 1,
    padding: Space.sm,
    borderRadius: 10,
    backgroundColor: Colors.surfaceInset,
    gap: 2,
  },
  provider: {
    gap: Space.xs,
  },
  badges: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: Space.xs,
  },
  badge: {
    paddingHorizontal: Space.sm,
    paddingVertical: 2,
    borderRadius: Radius.pill,
    backgroundColor: Colors.surfaceInset,
  },
  badgeAccent: {
    backgroundColor: "rgba(96, 165, 250, 0.14)",
  },
});
