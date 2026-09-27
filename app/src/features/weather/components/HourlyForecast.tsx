import React, { useMemo } from "react";
import { ScrollView, StyleSheet, View } from "react-native";

import { AppText, Card, CardHeader, Colors, Icon, Space, StateView, Touchable } from "../../../ui";
import { useTranslation } from "../../../i18n/useTranslation";
import { WeatherSnapshot } from "../models/weather";
import { formatDegrees, iconForWeather, isNightAt, isUnknownWeather, localMinutesOfDay, minutesFromHourLabel } from "../format";

interface HourlyForecastProps {
  snapshot: WeatherSnapshot;
  units: "celsius" | "fahrenheit";
  /// Cap the strip; the full horizon lives in the detail view.
  limit?: number;
  onSelectHour?: (index: number) => void;
}

export function HourlyForecast({ snapshot, units, limit = 24, onSelectHour }: HourlyForecastProps): React.ReactElement {
  const t = useTranslation();
  const hours = useMemo(() => snapshot.hourly.slice(0, limit), [snapshot.hourly, limit]);
  const sunrise = localMinutesOfDay(snapshot.sunrise, snapshot.utcOffsetSeconds);
  const sunset = localMinutesOfDay(snapshot.sunset, snapshot.utcOffsetSeconds);

  if (hours.length === 0) {
    return (
      <Card>
        <CardHeader icon="clock-outline" title={t("home.hour_by_hour")} />
        <StateView compact icon="clock-alert-outline" title={t("home.unavailable")} body={t("home.hourly_unavailable")} />
      </Card>
    );
  }

  return (
    <Card padded={false}>
      <View style={styles.header}>
        <CardHeader icon="clock-outline" title={t("home.next_hours", { n: hours.length })} />
      </View>
      <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.strip}>
        {hours.map((hour, index) => {
          const minutes = minutesFromHourLabel(hour.label);
          const night = minutes !== null && isNightAt(minutes, sunrise, sunset);
          const rain = hour.rainProbability;
          const label = index === 0 ? t("home.now") : hour.label;
          return (
            <Touchable
              key={`${hour.label}-${index}`}
              style={styles.cell}
              onPress={onSelectHour ? () => onSelectHour(index) : undefined}
              accessibilityHint={t("home.tap_for_details")}
              accessibilityLabel={`${label}, ${formatDegrees(hour.tempC, units)}${rain != null ? `, ${Math.round(rain)}% ${t("weather.rain")}` : ""}`}
            >
              <AppText variant="footnote" tone={index === 0 ? "primary" : "secondary"}>
                {label}
              </AppText>
              <View style={styles.iconSlot}>
                <Icon name={iconForWeather(hour, night)} size={26} color={isUnknownWeather(hour) ? Colors.textTertiary : Colors.text} />
                <AppText variant="caption" color={Colors.rain} style={styles.rain}>
                  {rain != null && rain >= 10 ? `${Math.round(rain)}%` : " "}
                </AppText>
              </View>
              <AppText variant="numeric">{formatDegrees(hour.tempC, units)}</AppText>
            </Touchable>
          );
        })}
      </ScrollView>
    </Card>
  );
}

const styles = StyleSheet.create({
  header: {
    paddingHorizontal: Space.lg,
    paddingTop: Space.lg,
  },
  strip: {
    paddingHorizontal: Space.sm,
    paddingBottom: Space.lg,
  },
  cell: {
    width: 58,
    alignItems: "center",
    gap: Space.xs,
    paddingVertical: Space.xs,
    borderRadius: 14,
  },
  iconSlot: {
    height: 46,
    alignItems: "center",
    justifyContent: "center",
  },
  rain: {
    marginTop: 1,
  },
});
