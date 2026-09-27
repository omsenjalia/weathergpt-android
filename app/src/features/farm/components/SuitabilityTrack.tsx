/// Suitability track for one farm activity: coloured segments over a day
/// (two-hour buckets) or a week (one cell per day).

import React from "react";
import { StyleSheet, View } from "react-native";

import { AppText, Colors, Icon, IconName, Radius, Space } from "../../../ui";
import { useTranslation } from "../../../i18n/useTranslation";
import { HourlySuitability, Suitability } from "../models/advisoryModels";

export const SUITABILITY_COLOR: Record<Suitability, string> = {
  [Suitability.Good]: Colors.good,
  [Suitability.Caution]: Colors.caution,
  [Suitability.Avoid]: Colors.danger,
  [Suitability.Neutral]: Colors.neutral,
};

export function useSuitabilityLabel(): (s: Suitability) => string {
  const t = useTranslation();
  return (s) =>
    s === Suitability.Good ? t("weather.good") : s === Suitability.Caution ? t("farmer.band_caution") : s === Suitability.Avoid ? t("farmer.band_avoid") : "—";
}

interface SuitabilityTrackProps {
  title: string;
  icon: IconName;
  cells: HourlySuitability[];
  /// Tick labels under the track, spread evenly.
  ticks: string[];
}

export function SuitabilityTrack({ title, icon, cells, ticks }: SuitabilityTrackProps): React.ReactElement {
  const label = useSuitabilityLabel();
  const total = cells.reduce((sum, c) => sum + c.hours, 0) || 1;
  const goodShare = cells.filter((c) => c.suitability === Suitability.Good).reduce((s, c) => s + c.hours, 0) / total;
  const worst = cells.some((c) => c.suitability === Suitability.Avoid)
    ? Suitability.Avoid
    : cells.some((c) => c.suitability === Suitability.Caution)
      ? Suitability.Caution
      : cells.some((c) => c.suitability === Suitability.Good)
        ? Suitability.Good
        : Suitability.Neutral;

  return (
    <View style={styles.wrap} accessible accessibilityLabel={`${title}: ${Math.round(goodShare * 100)}% ${label(Suitability.Good)}${worst !== Suitability.Good ? `, ${label(worst)}` : ""}`}>
      <View style={styles.header}>
        <Icon name={icon} size={16} color={Colors.textSecondary} />
        <AppText variant="callout" style={styles.title}>
          {title}
        </AppText>
        <View style={[styles.badge, { backgroundColor: `${SUITABILITY_COLOR[worst]}22` }]}>
          <View style={[styles.badgeDot, { backgroundColor: SUITABILITY_COLOR[worst] }]} />
          <AppText variant="caption" color={SUITABILITY_COLOR[worst] === Colors.neutral ? Colors.textSecondary : SUITABILITY_COLOR[worst]}>
            {label(worst)}
          </AppText>
        </View>
      </View>
      <View style={styles.track}>
        {cells.length === 0 ? (
          <View style={[styles.segment, { flex: 1, backgroundColor: Colors.surfaceInset }]} />
        ) : (
          cells.map((cell, i) => <View key={i} style={[styles.segment, { flex: cell.hours / total, backgroundColor: SUITABILITY_COLOR[cell.suitability] }]} />)
        )}
      </View>
      <View style={styles.ticks}>
        {ticks.map((tick, i) => (
          <AppText key={`${tick}-${i}`} variant="caption" tone="tertiary">
            {tick}
          </AppText>
        ))}
      </View>
    </View>
  );
}

export function SuitabilityLegend(): React.ReactElement {
  const label = useSuitabilityLabel();
  return (
    <View style={styles.legend}>
      {[Suitability.Good, Suitability.Caution, Suitability.Avoid].map((s) => (
        <View key={s} style={styles.legendItem}>
          <View style={[styles.badgeDot, { backgroundColor: SUITABILITY_COLOR[s] }]} />
          <AppText variant="caption" tone="secondary">
            {label(s)}
          </AppText>
        </View>
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: {
    gap: Space.sm,
  },
  header: {
    flexDirection: "row",
    alignItems: "center",
    gap: Space.sm,
  },
  title: {
    flex: 1,
  },
  badge: {
    flexDirection: "row",
    alignItems: "center",
    gap: 5,
    paddingHorizontal: Space.sm,
    paddingVertical: 3,
    borderRadius: Radius.pill,
  },
  badgeDot: {
    width: 7,
    height: 7,
    borderRadius: 4,
  },
  track: {
    flexDirection: "row",
    gap: 2,
    height: 12,
  },
  segment: {
    borderRadius: 3,
  },
  ticks: {
    flexDirection: "row",
    justifyContent: "space-between",
  },
  legend: {
    flexDirection: "row",
    gap: Space.lg,
  },
  legendItem: {
    flexDirection: "row",
    alignItems: "center",
    gap: 6,
  },
});
