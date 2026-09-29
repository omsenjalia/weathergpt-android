import React, { useEffect, useMemo, useState } from "react";
import { StyleSheet, View } from "react-native";
import { router } from "expo-router";

import { AppText, Button, Card, CardHeader, Colors, Divider, Screen, SegmentedControl, Skeleton, Space, StateView } from "../../src/ui";
import { DeviationBars, LineChart } from "../../src/ui/charts/LineChart";
import { useTranslation } from "../../src/i18n/useTranslation";
import { useLocationStore } from "../../src/features/location/locationStore";
import { useSavedLocationsStore } from "../../src/features/explore/exploreStores";
import {
  anomalyPercent,
  ArchiveStatus,
  AsyncComparison,
  AsyncSeries,
  comparedTotal,
  comparedValueFor,
  comparisonLastTwoYears,
  fetchComparison,
  fetchHistoricalSeries,
  HistoricalMetric,
  historicalRangeLabel,
  longTermAverage,
  metricLabel,
  metricUnit,
} from "../../src/features/research/researchStores";

export default function LabScreen(): React.ReactElement {
  const t = useTranslation();
  return (
    <Screen inTabs title={t("nav.lab")}>
      <HistoricalCard />
      <ComparisonCard />
    </Screen>
  );
}

function HistoricalCard(): React.ReactElement {
  const t = useTranslation();
  const location = useLocationStore((s) => s.location);
  const [metric, setMetric] = useState<HistoricalMetric>(HistoricalMetric.Rainfall);
  const [series, setSeries] = useState<AsyncSeries>({ kind: "loading" });
  const [attempt, setAttempt] = useState(0);

  useEffect(() => {
    // Only the latest selection may write state.
    let active = true;
    setSeries({ kind: "loading" });
    fetchHistoricalSeries({ metric, monthly: false }, location)
      .then((s) => active && setSeries({ kind: "data", series: s }))
      .catch((e: unknown) => active && setSeries({ kind: "error", message: e instanceof Error ? e.message : String(e) }));
    return () => {
      active = false;
    };
  }, [metric, location, attempt]);

  const unit = metricUnit(metric);
  const points = series.kind === "data" && series.series.status === ArchiveStatus.Available ? series.series.points : [];
  const mean = longTermAverage(points);
  const deviation = anomalyPercent(points);
  const deviations = useMemo(() => (mean === 0 ? [] : points.map((p) => ({ x: p.x, value: ((p.value - mean) / mean) * 100 }))), [points, mean]);

  return (
    <>
      <Card style={styles.gap}>
        <CardHeader icon="chart-line" title={`${t("researcher.historical_weather")} · ${location.name.split(",")[0]}`} />
        <SegmentedControl
          value={metric}
          onChange={setMetric}
          segments={[HistoricalMetric.Rainfall, HistoricalMetric.Temperature, HistoricalMetric.Humidity].map((m) => ({ value: m, label: metricLabel(m) }))}
        />
        {series.kind === "loading" && <Skeleton height={200} radius={12} />}
        {series.kind === "error" && <StateView compact tone="error" icon="database-alert-outline" title={t("voice.error")} body={series.message} actionLabel={t("chat.retry")} onAction={() => setAttempt((n) => n + 1)} />}
        {series.kind === "data" && series.series.status !== ArchiveStatus.Available && (
          <StateView compact icon="database-off-outline" title={t("home.unavailable")} body={series.series.detail ?? t("home.unavailable_generic_short")} />
        )}
        {points.length > 0 && series.kind === "data" && (
          <>
            <LineChart series={[{ points, color: Colors.researcher }]} unit={unit === "°C" ? "°" : ""} accessibilityLabel={`${metricLabel(metric)} ${historicalRangeLabel(series.series) ?? ""}`} />
            <View style={styles.stats}>
              <Stat label={t("lab.mean")} value={`${mean.toFixed(1)} ${unit}`} />
              <Stat label={t("lab.latest_vs_mean")} value={`${deviation >= 0 ? "+" : ""}${deviation.toFixed(1)}%`} color={deviation >= 0 ? Colors.tempWarm : Colors.tempCool} />
              <Stat label={t("lab.coverage")} value={compactRange(historicalRangeLabel(series.series))} />
            </View>
            <AppText variant="caption" tone="tertiary">
              {series.series.source ?? t("home.source_not_reported")}
            </AppText>
          </>
        )}
      </Card>

      {deviations.length > 1 && (
        <Card style={styles.gap}>
          <CardHeader icon="chart-bar" title={t("researcher.anomaly_trends")} />
          <DeviationBars points={deviations} accessibilityLabel={t("researcher.anomaly_trends")} />
          <AppText variant="footnote" tone="tertiary">
            {t("lab.deviation_note")}
          </AppText>
        </Card>
      )}
    </>
  );
}

function ComparisonCard(): React.ReactElement {
  const t = useTranslation();
  const saved = useSavedLocationsStore((s) => s.locations);
  const savedKey = saved.map((s) => s.name).join("|");
  const [comparison, setComparison] = useState<AsyncComparison>({ kind: "loading" });
  const [attempt, setAttempt] = useState(0);

  useEffect(() => {
    let active = true;
    setComparison({ kind: "loading" });
    fetchComparison(useSavedLocationsStore.getState().locations)
      .then((r) => active && setComparison({ kind: "data", result: r }))
      .catch((e: unknown) => active && setComparison({ kind: "error", message: e instanceof Error ? e.message : String(e) }));
    return () => {
      active = false;
    };
  }, [savedKey, attempt]);

  return (
    <Card style={styles.gap}>
      <CardHeader icon="compare-horizontal" title={`${t("researcher.compare_locations")} · ${t("researcher.rainfall")}`} />
      {comparison.kind === "loading" && <Skeleton height={200} radius={12} />}
      {comparison.kind === "error" && <StateView compact tone="error" icon="database-alert-outline" title={t("voice.error")} body={comparison.message} actionLabel={t("chat.retry")} onAction={() => setAttempt((n) => n + 1)} />}
      {comparison.kind === "data" && comparison.result.detail !== null && (
        <>
          <StateView compact icon="map-marker-multiple-outline" title={t("researcher.compare_locations")} body={comparison.result.detail} />
          <Button label={t("settings.saved_locations")} icon="star-outline" variant="secondary" onPress={() => router.push("/locations")} />
        </>
      )}
      {comparison.kind === "data" && comparison.result.detail === null && (
        <>
          <LineChart series={comparison.result.locations.map((l) => ({ points: l.points, color: l.colorValue, label: l.name }))} accessibilityLabel={t("researcher.compare_locations")} />
          <View style={styles.legend}>
            {comparison.result.locations.map((loc) => (
              <View key={loc.name} style={styles.legendItem}>
                <View style={[styles.swatch, { backgroundColor: loc.colorValue }]} />
                <AppText variant="footnote" numberOfLines={1}>
                  {loc.name.split(",")[0]}
                </AppText>
              </View>
            ))}
          </View>
          <Divider />
          <View>
            <View style={styles.tableRow}>
              <AppText variant="caption" tone="tertiary" style={styles.tableHead}>
                mm
              </AppText>
              {comparisonLastTwoYears(comparison.result).map((year) => (
                <AppText key={year} variant="caption" tone="tertiary" style={styles.tableCell} align="right">
                  {year}
                </AppText>
              ))}
              <AppText variant="caption" tone="tertiary" style={styles.tableCell} align="right">
                Σ
              </AppText>
            </View>
            {comparison.result.locations.map((loc) => (
              <View key={loc.name} style={styles.tableRow}>
                <AppText variant="footnote" style={styles.tableHead} numberOfLines={1} color={loc.colorValue}>
                  {loc.name.split(",")[0]}
                </AppText>
                {comparisonLastTwoYears(comparison.result).map((year) => {
                  const v = comparedValueFor(loc, year);
                  return (
                    <AppText key={year} variant="numeric" style={styles.tableCell} align="right" tone={v === null ? "tertiary" : "primary"}>
                      {v === null ? "—" : Math.round(v)}
                    </AppText>
                  );
                })}
                <AppText variant="numeric" style={styles.tableCell} align="right">
                  {comparedTotal(loc) === null ? "—" : Math.round(comparedTotal(loc)!)}
                </AppText>
              </View>
            ))}
          </View>
        </>
      )}
    </Card>
  );
}

/// "2001 – 2025" → "2001–25" so the range fits a third-width tile.
function compactRange(label: string | null): string {
  if (label === null) return "—";
  const [first, last] = label.split(" – ");
  if (first === undefined || last === undefined) return label;
  return first.slice(0, 2) === last.slice(0, 2) ? `${first}–${last.slice(2)}` : `${first}–${last}`;
}

function Stat({ label, value, color }: { label: string; value: string; color?: string }): React.ReactElement {
  return (
    <View style={styles.stat}>
      <AppText variant="caption" tone="tertiary" numberOfLines={2}>
        {label}
      </AppText>
      <AppText variant="numeric" color={color} numberOfLines={1} adjustsFontSizeToFit minimumFontScale={0.7}>
        {value}
      </AppText>
    </View>
  );
}

const styles = StyleSheet.create({
  gap: {
    gap: Space.md,
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
    width: 10,
    height: 10,
    borderRadius: 3,
  },
  tableRow: {
    flexDirection: "row",
    alignItems: "center",
    minHeight: 32,
  },
  tableHead: {
    flex: 1,
  },
  tableCell: {
    width: 64,
  },
});
