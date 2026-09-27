/// Two-column grid of metric tiles. Each tile: eyebrow, primary value, a
/// small visual (scale, compass, arc) and a one-line interpretation. Tiles
/// with no data say so explicitly instead of showing a zero.

import React from "react";
import { StyleSheet, View } from "react-native";
import { LinearGradient } from "expo-linear-gradient";
import Svg, { Circle, Path } from "react-native-svg";

import { AppText, Card, CardHeader, Colors, Icon, IconName, Radius, Space, Touchable } from "../../../ui";
import { useTranslation } from "../../../i18n/useTranslation";
import { WeatherSnapshot } from "../models/weather";
import { precipIntervalIsComplete } from "../../../core/models/fieldSources";
import type { MetricKind } from "./DetailSheets";
import {
  EM_DASH,
  aqiBandKey,
  compassLabel,
  formatDegrees,
  formatLocalClock,
  formatNumber,
  formatPercent,
  humidityBandKey,
  localMinutesOfDay,
  nowMinutesAtLocation,
  scaleRatio,
  uvBandKey,
} from "../format";

interface MetricTilesProps {
  snapshot: WeatherSnapshot;
  units: "celsius" | "fahrenheit";
  onSelect?: (metric: MetricKind) => void;
}

export function MetricTiles({ snapshot, units, onSelect }: MetricTilesProps): React.ReactElement {
  const t = useTranslation();
  const uvKey = uvBandKey(snapshot.uvIndex);
  const aqiKey = aqiBandKey(snapshot.aqi);
  const humidityKey = humidityBandKey(snapshot.humidity);
  const precip24 = snapshot.precipNext24h ?? null;

  return (
    <View style={styles.grid}>
      <Tile onPress={onSelect ? () => onSelect("uv") : undefined} icon="white-balance-sunny" title={t("home.uv_index")} value={formatNumber(snapshot.uvIndex)} caption={uvKey ? t(uvKey) : t("home.unavailable_generic_short")}>
        <GradientScale ratio={scaleRatio(snapshot.uvIndex, 0, 11)} colors={["#4ADE80", "#FACC15", "#FB923C", "#F87171", "#C084FC"]} />
      </Tile>

      <Tile onPress={onSelect ? () => onSelect("aqi") : undefined} icon="blur" title={t("home.aqi")} value={formatNumber(snapshot.aqi)} caption={aqiKey ? t(aqiKey) : t("home.unavailable_generic_short")}>
        <GradientScale ratio={scaleRatio(snapshot.aqi, 0, 100)} colors={["#4ADE80", "#A3E635", "#FACC15", "#FB923C", "#F87171", "#A855F7"]} />
      </Tile>

      <Tile
        onPress={onSelect ? () => onSelect("wind") : undefined}
        icon="weather-windy"
        title={t("home.wind")}
        value={formatNumber(snapshot.windKmh)}
        unit={snapshot.windKmh != null ? "km/h" : undefined}
        caption={snapshot.windDirection != null ? `${compassLabel(snapshot.windDirection)} · ${Math.round(snapshot.windDirection)}°` : t("home.unavailable_generic_short")}
        visual={<Compass degrees={snapshot.windDirection ?? null} />}
      />

      <Tile
        onPress={onSelect ? () => onSelect("humidity") : undefined}
        icon="water-percent"
        title={t("home.humidity")}
        value={formatPercent(snapshot.humidity)}
        caption={humidityKey ? t(humidityKey) : t("home.unavailable_generic_short")}
      >
        <Meter ratio={scaleRatio(snapshot.humidity, 0, 100)} color={Colors.rain} />
      </Tile>

      <SunTile snapshot={snapshot} onPress={onSelect ? () => onSelect("sun") : undefined} />

      <Tile
        onPress={onSelect ? () => onSelect("precip") : undefined}
        icon="umbrella-outline"
        title={t("home.precipitation")}
        value={precip24 !== null ? formatNumber(precip24.totalMm, "", 1) : formatPercent(snapshot.rainProbability)}
        unit={precip24 !== null ? "mm" : undefined}
        caption={precip24 !== null ? (precipIntervalIsComplete(precip24) ? t("home.next_24h_rain") : t("home.next_24h_rain_partial")) : t("home.rain_chance")}
      />

      <Tile
        onPress={onSelect ? () => onSelect("feels") : undefined}
        icon="thermometer"
        title={t("home.feels_like")}
        value={formatDegrees(snapshot.feelsLikeC, units)}
        caption={feelsCaption(snapshot, t)}
      />

      <Tile
        onPress={onSelect ? () => onSelect("pressure") : undefined}
        icon="gauge"
        title={t("home.pressure")}
        value={formatNumber(snapshot.pressureHpa)}
        unit={snapshot.pressureHpa != null ? "hPa" : undefined}
        caption={t("home.pressure_type")}
      />
    </View>
  );
}

function feelsCaption(snapshot: WeatherSnapshot, t: ReturnType<typeof useTranslation>): string {
  if (snapshot.feelsLikeC == null) return t("home.unavailable_generic_short");
  if (snapshot.temperatureC == null) return t("home.feels_like");
  const diff = Math.round(snapshot.feelsLikeC - snapshot.temperatureC);
  if (diff === 0) return t("home.trend_steady");
  return diff > 0 ? t("home.trend_warming", { d: diff }) : t("home.trend_cooling", { d: Math.abs(diff) });
}

// ---------------------------------------------------------------------------

interface TileProps {
  icon: IconName;
  title: string;
  value: string;
  unit?: string;
  caption: string;
  visual?: React.ReactNode;
  children?: React.ReactNode;
  onPress?: () => void;
}

function Tile({ icon, title, value, unit, caption, visual, children, onPress }: TileProps): React.ReactElement {
  return (
    <Touchable onPress={onPress} style={styles.tileWrap} accessibilityLabel={`${title}: ${value}${unit ? ` ${unit}` : ""}. ${caption}`}>
      <Card style={styles.tile}>
        <CardHeader icon={icon} title={title} />
        <View style={styles.valueRow}>
          <View style={styles.flex}>
            <View style={styles.valueLine}>
              <AppText variant="metric" tone={value === EM_DASH ? "tertiary" : "primary"}>
                {value}
              </AppText>
              {unit !== undefined && (
                <AppText variant="footnote" tone="secondary" style={styles.unit}>
                  {unit}
                </AppText>
              )}
            </View>
          </View>
          {visual}
        </View>
        <View style={styles.tileFooter}>
          {children}
          <AppText variant="footnote" tone="secondary" numberOfLines={2}>
            {caption}
          </AppText>
        </View>
      </Card>
    </Touchable>
  );
}

function GradientScale({ ratio, colors }: { ratio: number | null; colors: readonly string[] }): React.ReactElement {
  return (
    <View style={styles.scale}>
      <LinearGradient colors={colors as [string, string, ...string[]]} start={{ x: 0, y: 0 }} end={{ x: 1, y: 0 }} style={[StyleSheet.absoluteFill, styles.scaleFill, ratio === null && styles.muted]} />
      {ratio !== null && <View style={[styles.marker, { left: `${ratio * 100}%` }]} />}
    </View>
  );
}

function Meter({ ratio, color }: { ratio: number | null; color: string }): React.ReactElement {
  return (
    <View style={styles.scale}>
      <View style={[StyleSheet.absoluteFill, styles.scaleFill, { backgroundColor: Colors.surfaceInset }]} />
      {ratio !== null && <View style={[styles.meterFill, { width: `${ratio * 100}%`, backgroundColor: color }]} />}
    </View>
  );
}

function Compass({ degrees }: { degrees: number | null }): React.ReactElement {
  return (
    <View style={styles.compass}>
      <AppText variant="caption" tone="tertiary" style={styles.north}>
        N
      </AppText>
      {degrees !== null ? (
        // Arrow points where the wind blows *to* (meteorological direction + 180°).
        <View style={{ transform: [{ rotate: `${(degrees + 180) % 360}deg` }] }}>
          <Icon name="navigation" size={20} color={Colors.accentText} />
        </View>
      ) : (
        <Icon name="minus" size={18} color={Colors.textTertiary} />
      )}
    </View>
  );
}

function SunTile({ snapshot, onPress }: { snapshot: WeatherSnapshot; onPress?: () => void }): React.ReactElement {
  const t = useTranslation();
  const sunrise = localMinutesOfDay(snapshot.sunrise, snapshot.utcOffsetSeconds);
  const sunset = localMinutesOfDay(snapshot.sunset, snapshot.utcOffsetSeconds);
  const now = nowMinutesAtLocation(snapshot.utcOffsetSeconds);
  const beforeSunset = sunset !== null && now < sunset && (sunrise === null || now >= sunrise);
  const progress = sunrise !== null && sunset !== null && sunset > sunrise ? Math.min(1, Math.max(0, (now - sunrise) / (sunset - sunrise))) : null;

  const title = beforeSunset ? t("home.sunset") : t("home.sunrise");
  const value = formatLocalClock(beforeSunset ? snapshot.sunset : snapshot.sunrise, snapshot.utcOffsetSeconds);
  const other = beforeSunset
    ? `${t("home.sunrise")} ${formatLocalClock(snapshot.sunrise, snapshot.utcOffsetSeconds)}`
    : `${t("home.sunset")} ${formatLocalClock(snapshot.sunset, snapshot.utcOffsetSeconds)}`;

  return (
    <Tile onPress={onPress} icon={beforeSunset ? "weather-sunset-down" : "weather-sunset-up"} title={title} value={value} caption={other}>
      <SunArc progress={progress} />
    </Tile>
  );
}

function SunArc({ progress }: { progress: number | null }): React.ReactElement {
  const w = 120;
  const h = 34;
  const r = 52;
  const cx = w / 2;
  const cy = h + r - 30;
  const arc = `M ${cx - r} ${cy} A ${r} ${r} 0 0 1 ${cx + r} ${cy}`;
  const angle = progress === null ? null : Math.PI - progress * Math.PI;
  return (
    <Svg width="100%" height={h} viewBox={`0 0 ${w} ${h}`} preserveAspectRatio="xMidYMax meet">
      <Path d={arc} stroke={Colors.hairlineStrong} strokeWidth={1.5} strokeDasharray="3 4" fill="none" />
      {angle !== null && <Circle cx={cx + r * Math.cos(angle)} cy={cy - r * Math.sin(angle)} r={5} fill="#FCD34D" />}
    </Svg>
  );
}

const styles = StyleSheet.create({
  grid: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: Space.md,
  },
  tileWrap: {
    flexBasis: "46%",
    flexGrow: 1,
  },
  tile: {
    flex: 1,
    minHeight: 164,
    justifyContent: "space-between",
  },
  flex: {
    flex: 1,
  },
  valueRow: {
    flexDirection: "row",
    alignItems: "center",
  },
  valueLine: {
    flexDirection: "row",
    alignItems: "baseline",
    gap: 4,
  },
  unit: {
    marginBottom: 2,
  },
  tileFooter: {
    gap: Space.sm,
    marginTop: Space.md,
  },
  scale: {
    height: 6,
    justifyContent: "center",
  },
  scaleFill: {
    borderRadius: Radius.pill,
  },
  muted: {
    opacity: 0.25,
  },
  marker: {
    position: "absolute",
    width: 10,
    height: 10,
    marginLeft: -5,
    borderRadius: 5,
    backgroundColor: Colors.text,
    borderWidth: 2,
    borderColor: Colors.canvas,
  },
  meterFill: {
    height: 6,
    borderRadius: Radius.pill,
  },
  compass: {
    width: 44,
    height: 44,
    borderRadius: 22,
    borderWidth: 1,
    borderColor: Colors.hairlineStrong,
    alignItems: "center",
    justifyContent: "center",
  },
  north: {
    position: "absolute",
    top: 1,
    fontSize: 8,
    lineHeight: 10,
  },
});
