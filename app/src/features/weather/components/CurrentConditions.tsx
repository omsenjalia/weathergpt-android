import React from "react";
import { StyleSheet, View } from "react-native";

import { AppText, Colors, Icon, Space, Touchable, textStyles } from "../../../ui";
import { useTranslation } from "../../../i18n/useTranslation";
import { WeatherSnapshot } from "../models/weather";
import { useWeatherStore } from "../weatherStore";
import { formatDegrees } from "../format";

interface CurrentConditionsProps {
  snapshot: WeatherSnapshot;
  locationName: string;
  units: "celsius" | "fahrenheit";
  onPressLocation: () => void;
}

/// Hero block — sits directly on the sky, no card. Location, temperature,
/// condition and the day's range, in that reading order.
export function CurrentConditions({ snapshot, locationName, units, onPressLocation }: CurrentConditionsProps): React.ReactElement {
  const t = useTranslation();
  const [place, region] = splitName(locationName);
  const condition = snapshot.condition === "—" || snapshot.condition.trim() === "" ? t("home.condition_unknown") : snapshot.condition;
  const updated = useWeatherStore((s) => s.updatedAt);

  return (
    <View style={styles.root}>
      <Touchable
        onPress={onPressLocation}
        haptics="selection"
        accessibilityLabel={`${t("home.choose_location")}: ${locationName}`}
        style={styles.location}
      >
        <Icon name="map-marker" size={16} color={Colors.text} />
        <AppText variant="headline" style={[styles.place, textStyles.shadow]} numberOfLines={1}>
          {place}
        </AppText>
        <Icon name="chevron-down" size={18} color={Colors.textSecondary} />
      </Touchable>
      {region !== null && (
        <AppText variant="footnote" tone="secondary" style={textStyles.shadow} numberOfLines={1}>
          {region}
        </AppText>
      )}

      <AppText
        variant="display"
        style={[styles.temp, textStyles.shadow]}
        accessibilityLabel={`${formatDegrees(snapshot.temperatureC, units)} ${condition}`}
      >
        {formatDegrees(snapshot.temperatureC, units)}
      </AppText>
      <AppText variant="title" style={textStyles.shadow} align="center">
        {condition}
      </AppText>
      <View style={styles.rangeRow}>
        <AppText variant="callout" tone="secondary" style={textStyles.shadow}>
          H {formatDegrees(snapshot.highC, units)}
        </AppText>
        <View style={styles.dot} />
        <AppText variant="callout" tone="secondary" style={textStyles.shadow}>
          L {formatDegrees(snapshot.lowC, units)}
        </AppText>
        {snapshot.feelsLikeC !== null && snapshot.feelsLikeC !== undefined && (
          <>
            <View style={styles.dot} />
            <AppText variant="callout" tone="secondary" style={textStyles.shadow}>
              {t("home.feels_like")} {formatDegrees(snapshot.feelsLikeC, units)}
            </AppText>
          </>
        )}
      </View>
      {updated !== null && (
        <AppText variant="caption" tone="tertiary" style={styles.updated}>
          {t("home.updated", { time: updated.toLocaleTimeString([], { hour: "numeric", minute: "2-digit" }) })}
        </AppText>
      )}
    </View>
  );
}

function splitName(name: string): [string, string | null] {
  const [head, ...rest] = name.split(",");
  const region = rest.join(",").trim();
  return [head!.trim(), region === "" ? null : region];
}

const styles = StyleSheet.create({
  root: {
    alignItems: "center",
    paddingTop: Space.lg,
    paddingBottom: Space.xl,
  },
  location: {
    flexDirection: "row",
    alignItems: "center",
    gap: 4,
    minHeight: 36,
    paddingHorizontal: Space.md,
    maxWidth: "100%",
  },
  place: {
    flexShrink: 1,
  },
  temp: {
    marginTop: Space.sm,
    // Optical centring: the degree glyph adds visual weight on the right.
    paddingLeft: 18,
  },
  rangeRow: {
    flexDirection: "row",
    alignItems: "center",
    flexWrap: "wrap",
    justifyContent: "center",
    gap: Space.sm,
    marginTop: Space.xs,
  },
  dot: {
    width: 3,
    height: 3,
    borderRadius: 2,
    backgroundColor: Colors.textTertiary,
  },
  updated: {
    marginTop: Space.sm,
  },
});
