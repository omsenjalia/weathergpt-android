import React, { useMemo } from "react";
import { StyleSheet, View } from "react-native";
import { LinearGradient } from "expo-linear-gradient";

import { AppText, Card, CardHeader, Colors, Divider, Icon, Radius, Space, StateView, Touchable } from "../../../ui";
import { useTranslation } from "../../../i18n/useTranslation";
import { LANGUAGE_META } from "../../../i18n";
import { DayForecast, WeatherSnapshot } from "../models/weather";
import { formatDegrees, iconForWeather, isUnknownWeather, weekdayShort } from "../format";

interface DailyForecastProps {
  snapshot: WeatherSnapshot;
  units: "celsius" | "fahrenheit";
  onSelectDay?: (index: number) => void;
}

/// Daily list with range bars on a shared week-wide scale, so days can be
/// compared at a glance. Missing highs/lows render as an empty track.
export function DailyForecast({ snapshot, units, onSelectDay }: DailyForecastProps): React.ReactElement {
  const t = useTranslation();
  const locale = LANGUAGE_META[t.language].ttsLocale;
  const days = snapshot.forecast;

  const [weekMin, weekMax] = useMemo(() => {
    const values = days.flatMap((d) => [d.lowC, d.highC]).filter((v): v is number => v !== null && v !== undefined);
    if (values.length === 0) return [0, 1];
    return [Math.min(...values), Math.max(...values)];
  }, [days]);

  if (days.length === 0) {
    return (
      <Card>
        <CardHeader icon="calendar-month-outline" title={t("home.day_forecast", { n: 7 })} />
        <StateView compact icon="calendar-remove-outline" title={t("home.unavailable")} body={t("home.forecast_unavailable")} />
      </Card>
    );
  }

  return (
    <Card>
      <CardHeader icon="calendar-month-outline" title={t("home.day_forecast", { n: days.length })} />
      {days.map((day, index) => (
        <View key={`${day.date}-${index}`}>
          {index > 0 && <Divider />}
          <DayRow
            day={day}
            label={index === 0 ? t("common.today") : weekdayShort(day.date, locale)}
            units={units}
            weekMin={weekMin}
            weekMax={weekMax}
            current={index === 0 ? snapshot.temperatureC ?? null : null}
            onPress={onSelectDay ? () => onSelectDay(index) : undefined}
          />
        </View>
      ))}
    </Card>
  );
}

interface DayRowProps {
  day: DayForecast;
  label: string;
  units: "celsius" | "fahrenheit";
  weekMin: number;
  weekMax: number;
  current: number | null;
  onPress?: () => void;
}

function DayRow({ day, label, units, weekMin, weekMax, current, onPress }: DayRowProps): React.ReactElement {
  const t = useTranslation();
  const rain = day.rainProbability;
  const span = Math.max(weekMax - weekMin, 1);
  const hasRange = day.lowC != null && day.highC != null;
  const left = hasRange ? ((day.lowC! - weekMin) / span) * 100 : 0;
  const width = hasRange ? Math.max(((day.highC! - day.lowC!) / span) * 100, 4) : 0;
  const dot = current !== null && hasRange ? ((Math.min(Math.max(current, weekMin), weekMax) - weekMin) / span) * 100 : null;

  return (
    <Touchable
      style={styles.row}
      scale={false}
      onPress={onPress}
      accessibilityLabel={`${label}: ${day.condition}, ${t("home.high_low")} ${formatDegrees(day.highC, units)} / ${formatDegrees(day.lowC, units)}${rain != null ? `, ${t("home.rain_chance")} ${Math.round(rain)}%` : ""}`}
      accessibilityHint={t("home.tap_for_details")}
    >
      <AppText variant="callout" style={styles.day} numberOfLines={1}>
        {label}
      </AppText>
      <View style={styles.iconCol}>
        <Icon
          name={iconForWeather({ weatherCode: day.weatherCode, condition: day.condition, windKmh: day.windKmhMax })}
          size={22}
          color={isUnknownWeather({ weatherCode: day.weatherCode, condition: day.condition }) ? Colors.textTertiary : Colors.text}
        />
        {rain != null && rain >= 10 && (
          <AppText variant="caption" color={Colors.rain}>
            {Math.round(rain)}%
          </AppText>
        )}
      </View>
      <AppText variant="numeric" tone="tertiary" style={styles.temp} align="right">
        {formatDegrees(day.lowC, units)}
      </AppText>
      <View style={styles.track}>
        {hasRange && (
          <LinearGradient
            colors={[Colors.tempCool, Colors.tempWarm]}
            start={{ x: 0, y: 0 }}
            end={{ x: 1, y: 0 }}
            style={[styles.fill, { left: `${left}%`, width: `${Math.min(width, 100 - left)}%` }]}
          />
        )}
        {dot !== null && <View style={[styles.now, { left: `${dot}%` }]} />}
      </View>
      <AppText variant="numeric" style={styles.temp} align="right">
        {formatDegrees(day.highC, units)}
      </AppText>
    </Touchable>
  );
}

const styles = StyleSheet.create({
  row: {
    flexDirection: "row",
    alignItems: "center",
    gap: Space.md,
    minHeight: 52,
  },
  day: {
    width: 52,
  },
  iconCol: {
    width: 36,
    alignItems: "center",
  },
  temp: {
    width: 38,
  },
  track: {
    flex: 1,
    height: 5,
    borderRadius: Radius.pill,
    backgroundColor: Colors.surfaceInset,
    justifyContent: "center",
  },
  fill: {
    position: "absolute",
    top: 0,
    bottom: 0,
    borderRadius: Radius.pill,
  },
  now: {
    position: "absolute",
    width: 9,
    height: 9,
    marginLeft: -4.5,
    borderRadius: 5,
    backgroundColor: Colors.text,
    borderWidth: 2,
    borderColor: Colors.canvas,
  },
});
