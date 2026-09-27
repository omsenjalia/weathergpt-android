/// Detail sheets for Home: one hour, one day, or one metric tile. Port of the
/// Flutter `weather_detail_sheets.dart`. Every missing value renders as an
/// em dash with an honest note; provider names appear only in developer mode.

import React from "react";
import { ScrollView, StyleSheet, View } from "react-native";

import { AppText, Colors, Divider, Icon, IconName, Radius, Sheet, Space, Touchable } from "../../../ui";
import { useTranslation } from "../../../i18n/useTranslation";
import { LANGUAGE_META } from "../../../i18n";
import { fieldSourcesContributors, fieldSourcesProviderFor } from "../../../core/models/fieldSources";
import { DayForecast, HourlyPoint, WeatherSnapshot, dayHasEnvelope } from "../models/weather";
import {
  EM_DASH,
  aqiBandKey,
  compassLabel,
  formatDegrees,
  formatLocalClock,
  formatNumber,
  formatPercent,
  humidityBandKey,
  iconForWeather,
  isNightAt,
  isUnknownWeather,
  localMinutesOfDay,
  minutesFromHourLabel,
  uvBandKey,
  weekdayShort,
} from "../format";

export type MetricKind = "uv" | "aqi" | "wind" | "humidity" | "sun" | "precip" | "feels" | "pressure";

export type WeatherDetail = { kind: "hour"; index: number; hours?: HourlyPoint[] } | { kind: "day"; index: number } | { kind: "metric"; metric: MetricKind };

interface DetailSheetProps {
  detail: WeatherDetail | null;
  snapshot: WeatherSnapshot;
  units: "celsius" | "fahrenheit";
  developer: boolean;
  onClose: () => void;
  onNavigate: (detail: WeatherDetail) => void;
}

export function WeatherDetailSheet({ detail, snapshot, units, developer, onClose, onNavigate }: DetailSheetProps): React.ReactElement {
  return (
    <Sheet visible={detail !== null} onClose={onClose}>
      {detail?.kind === "hour" && <HourDetail snapshot={snapshot} hours={detail.hours ?? snapshot.hourly} index={detail.index} units={units} developer={developer} />}
      {detail?.kind === "day" && <DayDetail snapshot={snapshot} index={detail.index} units={units} developer={developer} onNavigate={onNavigate} />}
      {detail?.kind === "metric" && <MetricDetail snapshot={snapshot} metric={detail.metric} units={units} developer={developer} />}
    </Sheet>
  );
}

// ---------------------------------------------------------------------------
// Building blocks

interface Row {
  label: string;
  value: string;
  icon: IconName;
  note?: string | null;
}

function Header({ title, subtitle, icon, trailing }: { title: string; subtitle: string; icon: IconName; trailing?: React.ReactNode }): React.ReactElement {
  return (
    <View style={styles.header}>
      <View style={styles.headerIcon}>
        <Icon name={icon} size={24} color={Colors.accentText} />
      </View>
      <View style={styles.flex}>
        <AppText variant="title" accessibilityRole="header">
          {title}
        </AppText>
        <AppText variant="subhead" tone="secondary">
          {subtitle}
        </AppText>
      </View>
      {trailing}
    </View>
  );
}

function Rows({ rows }: { rows: Row[] }): React.ReactElement {
  return (
    <View style={styles.rows}>
      {rows.map((row, i) => (
        <View key={`${row.label}-${i}`}>
          {i > 0 && <Divider />}
          <View style={styles.row} accessible accessibilityLabel={`${row.label}: ${row.value}${row.note ? `. ${row.note}` : ""}`}>
            <Icon name={row.icon} size={18} color={Colors.textTertiary} />
            <View style={styles.flex}>
              <AppText variant="callout" tone="secondary">
                {row.label}
              </AppText>
              {row.note != null && row.note !== "" && (
                <AppText variant="caption" tone="tertiary">
                  {row.note}
                </AppText>
              )}
            </View>
            <AppText variant="numeric" tone={row.value === EM_DASH ? "tertiary" : "primary"} style={styles.rowValue}>
              {row.value}
            </AppText>
          </View>
        </View>
      ))}
    </View>
  );
}

function Note({ icon, text }: { icon: IconName; text: string }): React.ReactElement {
  return (
    <View style={styles.note}>
      <Icon name={icon} size={16} color={Colors.caution} />
      <AppText variant="footnote" tone="secondary" style={styles.flex}>
        {text}
      </AppText>
    </View>
  );
}

function SourceFooter({ snapshot, developer }: { snapshot: WeatherSnapshot; developer: boolean }): React.ReactElement | null {
  const t = useTranslation();
  const primary = snapshot.provenance.selectedSource ?? snapshot.provenance.source ?? null;
  if (!developer && snapshot.currentIsEnsembleMean !== true) return null;
  const others = fieldSourcesContributors(snapshot.fieldSources).filter((c) => c !== primary);
  return (
    <View style={styles.footer}>
      {developer && (
        <AppText variant="caption" tone="tertiary">
          {`${t("home.source")}: ${primary ?? t("home.source_not_reported")}${snapshot.provenance.runId ? ` · ${snapshot.provenance.runId}` : ""}`}
        </AppText>
      )}
      {developer && others.length > 0 && (
        <AppText variant="caption" tone="tertiary">
          {t("home.secondary_fields_via", { sources: others.join(", ") })}
        </AppText>
      )}
      {snapshot.currentIsEnsembleMean === true && (
        <AppText variant="caption" tone="tertiary">
          {t("home.ensemble_note")}
        </AppText>
      )}
    </View>
  );
}

function locale(language: keyof typeof LANGUAGE_META): string {
  return LANGUAGE_META[language].ttsLocale;
}

function localDate(snapshot: WeatherSnapshot, utc: Date): string {
  const offset = snapshot.utcOffsetSeconds ?? -utc.getTimezoneOffset() * 60;
  return new Date(utc.getTime() + offset * 1000).toISOString().slice(0, 10);
}

// ---------------------------------------------------------------------------
// Hour

function HourDetail({ snapshot, hours, index, units, developer }: { snapshot: WeatherSnapshot; hours: HourlyPoint[]; index: number; units: "celsius" | "fahrenheit"; developer: boolean }): React.ReactElement | null {
  const t = useTranslation();
  const hour = hours[index];
  if (hour === undefined) return null;
  const prev = index > 0 ? hours[index - 1] : undefined;
  const next = hours[index + 1];
  let trend = "";
  if (prev !== undefined) {
    const d = hour.tempC - prev.tempC;
    trend = Math.abs(d) < 0.3 ? t("home.trend_steady") : d > 0 ? t("home.trend_warming", { d: Math.abs(d).toFixed(1) }) : t("home.trend_cooling", { d: Math.abs(d).toFixed(1) });
  } else if (next !== undefined) {
    const d = next.tempC - hour.tempC;
    trend = Math.abs(d) < 0.3 ? t("home.trend_steady") : d > 0 ? t("home.trend_then_warmer") : t("home.trend_then_cooler");
  }
  const day = hour.timeUtc ? weekdayShort(localDate(snapshot, hour.timeUtc), locale(t.language)) : null;
  const minutes = minutesFromHourLabel(hour.label);
  const night = minutes !== null && isNightAt(minutes, localMinutesOfDay(snapshot.sunrise, snapshot.utcOffsetSeconds), localMinutesOfDay(snapshot.sunset, snapshot.utcOffsetSeconds));
  const uvKey = uvBandKey(hour.uvIndex);

  const rows: Row[] = [
    { label: t("home.temperature"), value: formatDegrees(hour.tempC, units), icon: "thermometer", note: trend },
    ...(hour.feelsLikeC != null ? [{ label: t("home.feels_like"), value: formatDegrees(hour.feelsLikeC, units), icon: "human" as IconName }] : []),
    { label: t("home.rain_chance"), value: formatPercent(hour.rainProbability), icon: "umbrella-outline", note: snapshot.currentIsEnsembleMean === true && hour.rainProbability != null ? t("home.rain_lower_bound") : null },
    { label: t("home.precipitation"), value: hour.precipMm == null ? EM_DASH : `${hour.precipMm.toFixed(hour.precipMm < 1 ? 2 : 1)} mm`, icon: "water-outline" },
    { label: t("home.wind"), value: hour.windKmh == null ? EM_DASH : `${Math.round(hour.windKmh)} km/h${hour.windDirection != null ? ` ${compassLabel(hour.windDirection)}` : ""}`, icon: "weather-windy" },
    { label: t("home.humidity"), value: formatPercent(hour.humidity), icon: "water-percent" },
    ...(hour.cloudCover != null ? [{ label: t("home.cloud_cover"), value: formatPercent(hour.cloudCover), icon: "cloud-outline" as IconName }] : []),
    ...(hour.pressureHpa != null ? [{ label: t("home.pressure"), value: `${Math.round(hour.pressureHpa)} hPa`, icon: "gauge" as IconName }] : []),
    ...(hour.uvIndex != null ? [{ label: t("home.uv_index"), value: `${formatNumber(hour.uvIndex, "", hour.uvIndex % 1 === 0 ? 0 : 1)}${uvKey ? ` · ${t(uvKey)}` : ""}`, icon: "white-balance-sunny" as IconName }] : []),
    ...(developer && hour.weatherCode != null ? [{ label: t("home.wmo_code"), value: String(hour.weatherCode), icon: "pound" as IconName }] : []),
    ...(developer && hour.timeUtc ? [{ label: "UTC", value: hour.timeUtc.toISOString().slice(0, 16).replace("T", " "), icon: "earth" as IconName }] : []),
  ];

  return (
    <>
      <Header
        title={day ? `${day} · ${hour.label}` : hour.label}
        subtitle={hour.condition ?? t("home.condition_unknown")}
        icon={iconForWeather(hour, night)}
        trailing={<AppText variant="metric">{formatDegrees(hour.tempC, units)}</AppText>}
      />
      {hour.condition == null && hour.missingReason != null && <Note icon="information-outline" text={t("home.missing_reason", { reason: hour.missingReason })} />}
      <Rows rows={rows} />
      <SourceFooter snapshot={snapshot} developer={developer} />
    </>
  );
}

// ---------------------------------------------------------------------------
// Day

function DayDetail({ snapshot, index, units, developer, onNavigate }: { snapshot: WeatherSnapshot; index: number; units: "celsius" | "fahrenheit"; developer: boolean; onNavigate: (d: WeatherDetail) => void }): React.ReactElement | null {
  const t = useTranslation();
  const day: DayForecast | undefined = snapshot.forecast[index];
  if (day === undefined) return null;
  const partial = day.coversFullDay === false;
  const hours = snapshot.hourly.filter((h) => h.timeUtc != null && localDate(snapshot, h.timeUtc) === day.date);
  const uvKey = uvBandKey(day.uvIndexMax);
  const title = index === 0 ? t("common.today") : index === 1 ? t("common.tomorrow") : weekdayShort(day.date, locale(t.language));
  const via = (field: string) => (developer && day.fieldSources[field] ? t("home.via", { source: day.fieldSources[field]! }) : null);

  const rows: Row[] = [
    { label: t("home.high_low"), value: `${formatDegrees(day.highC, units)} / ${formatDegrees(day.lowC, units)}`, icon: "thermometer", note: day.statistic === "ensemble_mean" ? t("home.ensemble_mean") : null },
    ...(dayHasEnvelope(day) ? [{ label: t("home.temp_spread"), value: `${formatDegrees(day.lowP10C, units)} – ${formatDegrees(day.highP90C, units)}`, icon: "unfold-more-horizontal" as IconName, note: t("home.envelope_note") }] : []),
    { label: t("home.rain_chance"), value: formatPercent(day.rainProbability), icon: "umbrella-outline", note: day.statistic === "ensemble_mean" && day.rainProbability != null ? t("home.rain_lower_bound") : null },
    {
      label: t("home.precipitation"),
      value: day.precipMm == null ? EM_DASH : `${day.precipMm.toFixed(day.precipMm < 10 ? 1 : 0)} mm`,
      icon: "water-outline",
      note: partial ? t("home.covers_only", { interval: day.precipIntervalLabel ?? `${day.hoursCovered ?? "?"}h` }) : day.precipIntervalLabel,
    },
    { label: t("home.max_wind"), value: day.windKmhMax == null ? EM_DASH : `${Math.round(day.windKmhMax)} km/h`, icon: "weather-windy" },
    { label: t("home.sunrise"), value: formatLocalClock(day.sunrise, snapshot.utcOffsetSeconds), icon: "weather-sunset-up", note: via("sunrise") },
    { label: t("home.sunset"), value: formatLocalClock(day.sunset, snapshot.utcOffsetSeconds), icon: "weather-sunset-down", note: via("sunset") },
    ...(day.uvIndexMax != null ? [{ label: t("home.uv_max"), value: `${formatNumber(day.uvIndexMax, "", day.uvIndexMax % 1 === 0 ? 0 : 1)}${uvKey ? ` · ${t(uvKey)}` : ""}`, icon: "white-balance-sunny" as IconName, note: via("uv_index_max") }] : []),
    ...(developer && day.weatherCode != null ? [{ label: t("home.wmo_code"), value: String(day.weatherCode), icon: "pound" as IconName }] : []),
    ...(day.hoursCovered != null ? [{ label: t("home.hours_in_day"), value: `${day.hoursCovered} / 24`, icon: "clock-outline" as IconName }] : []),
  ];

  return (
    <>
      <Header
        title={title}
        subtitle={day.condition === "—" ? t("home.condition_unknown") : day.condition}
        icon={iconForWeather({ weatherCode: day.weatherCode, condition: day.condition, windKmh: day.windKmhMax })}
        trailing={
          <View style={styles.dayTemps}>
            <AppText variant="metric">{formatDegrees(day.highC, units)}</AppText>
            <AppText variant="headline" tone="tertiary">
              {formatDegrees(day.lowC, units)}
            </AppText>
          </View>
        }
      />
      {partial && <Note icon="timer-sand" text={t("home.partial_day_detail", { n: day.hoursCovered ?? "?" })} />}
      {hours.length > 0 && (
        <View style={styles.gapSm}>
          <AppText variant="eyebrow" tone="tertiary">
            {t("home.hour_by_hour")}
          </AppText>
          <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.hourStrip}>
            {hours.map((h, i) => (
              <Touchable key={`${h.label}-${i}`} onPress={() => onNavigate({ kind: "hour", index: i, hours })} accessibilityLabel={`${h.label}, ${formatDegrees(h.tempC, units)}`} style={styles.hourCell}>
                <AppText variant="caption" tone="secondary">
                  {h.label}
                </AppText>
                <Icon name={iconForWeather(h)} size={20} color={isUnknownWeather(h) ? Colors.textTertiary : Colors.text} />
                <AppText variant="numeric">{formatDegrees(h.tempC, units)}</AppText>
                <AppText variant="caption" color={Colors.rain}>
                  {h.rainProbability == null ? EM_DASH : `${Math.round(h.rainProbability)}%`}
                </AppText>
              </Touchable>
            ))}
          </ScrollView>
        </View>
      )}
      <Rows rows={rows} />
      <SourceFooter snapshot={snapshot} developer={developer} />
    </>
  );
}

// ---------------------------------------------------------------------------
// Metric

const METRIC_FIELD: Record<MetricKind, string | null> = {
  uv: "uv_index",
  aqi: "air_quality",
  wind: "wind_speed_kmh",
  humidity: "humidity_percent",
  sun: "sunrise",
  precip: "precipitation",
  feels: "feels_like_c",
  pressure: "pressure_hpa",
};

function MetricDetail({ snapshot, metric, units, developer }: { snapshot: WeatherSnapshot; metric: MetricKind; units: "celsius" | "fahrenheit"; developer: boolean }): React.ReactElement {
  const t = useTranslation();
  const s = snapshot;
  const band = (key: string | null) => (key === null ? null : t(key));
  let title = "";
  let value = EM_DASH;
  let caption: string | null = null;
  let icon: IconName = "information-outline";
  let explanation = "";
  const extra: Row[] = [];

  switch (metric) {
    case "uv":
      title = t("home.uv_index");
      value = formatNumber(s.uvIndex, "", s.uvIndex != null && s.uvIndex % 1 !== 0 ? 1 : 0);
      caption = band(uvBandKey(s.uvIndex));
      icon = "white-balance-sunny";
      explanation = t("home.explain_uv");
      break;
    case "aqi":
      title = t("home.aqi");
      value = formatNumber(s.aqi);
      caption = band(aqiBandKey(s.aqi));
      icon = "blur";
      explanation = t("home.explain_aqi");
      if (s.pm25 != null) extra.push({ label: "PM2.5", value: `${Math.round(s.pm25)} µg/m³`, icon: "blur-radial" });
      if (s.aqi != null) extra.push({ label: t("home.scale"), value: "European AQI (0–100+)", icon: "ruler" });
      break;
    case "wind":
      title = t("home.wind");
      value = s.windKmh == null ? EM_DASH : `${Math.round(s.windKmh)} km/h`;
      caption = s.windDirection != null ? `${compassLabel(s.windDirection)} · ${Math.round(s.windDirection)}°` : null;
      icon = "weather-windy";
      break;
    case "humidity":
      title = t("home.humidity");
      value = formatPercent(s.humidity);
      caption = band(humidityBandKey(s.humidity));
      icon = "water-percent";
      explanation = t("home.explain_humidity");
      break;
    case "sun":
      title = `${t("home.sunrise")} · ${t("home.sunset")}`;
      value = formatLocalClock(s.sunrise, s.utcOffsetSeconds);
      caption = `${t("home.sunset")} ${formatLocalClock(s.sunset, s.utcOffsetSeconds)}`;
      icon = "weather-sunset";
      explanation = t("home.explain_sun");
      if (s.timezoneId) extra.push({ label: t("home.timezone"), value: s.timezoneId, icon: "clock-outline" });
      break;
    case "precip":
      title = t("home.precipitation");
      value = s.precipNext24h ? `${s.precipNext24h.totalMm.toFixed(1)} mm` : formatPercent(s.rainProbability);
      caption = s.precipNext24h ? t("home.next_24h_rain") : t("home.rain_chance");
      icon = "umbrella-outline";
      if (s.precipNext24h?.label) extra.push({ label: t("home.covers_only", { interval: s.precipNext24h.label }), value: "", icon: "timer-sand" });
      break;
    case "feels":
      title = t("home.feels_like");
      value = formatDegrees(s.feelsLikeC, units);
      caption = s.temperatureC != null ? `${t("home.temperature")} ${formatDegrees(s.temperatureC, units)}` : null;
      icon = "thermometer";
      if (s.temperatureSpread) extra.push({ label: t("home.temp_spread"), value: `${formatDegrees(s.temperatureSpread.p10C, units)} – ${formatDegrees(s.temperatureSpread.p90C, units)}`, icon: "unfold-more-horizontal", note: t("home.envelope_note") });
      break;
    case "pressure":
      title = t("home.pressure");
      value = s.pressureHpa == null ? EM_DASH : `${Math.round(s.pressureHpa)} hPa`;
      caption = t("home.pressure_type");
      icon = "gauge";
      explanation = t("home.explain_pressure");
      break;
  }

  const unavailable = value === EM_DASH;
  const field = METRIC_FIELD[metric];
  const primary = s.provenance.selectedSource ?? s.provenance.source ?? null;
  const provider = field === null ? null : fieldSourcesProviderFor(s.fieldSources, field);
  const explicitNull = field !== null && field in s.fieldSources.sources && provider === null;
  const rows: Row[] = [
    { label: t("home.value"), value, icon },
    ...(!unavailable && caption ? [{ label: t("home.meaning"), value: caption, icon: "lightbulb-outline" as IconName }] : []),
    ...extra,
    ...(developer
      ? [{
          label: t("home.source"),
          value: unavailable ? (explicitNull ? t("home.no_provider_for") : t("home.source_not_reported")) : provider ?? primary ?? t("home.source_not_reported"),
          icon: "source-branch" as IconName,
          note: !unavailable && provider !== null && primary !== null && provider !== primary ? t("home.supplemented_note", { primary }) : null,
        }]
      : []),
  ];

  return (
    <>
      <Header title={title} subtitle={unavailable ? t("home.unavailable") : caption ?? ""} icon={icon} trailing={<AppText variant="metric" tone={unavailable ? "tertiary" : "primary"}>{value}</AppText>} />
      {explanation !== "" && (
        <AppText variant="subhead" tone="secondary">
          {explanation}
        </AppText>
      )}
      {unavailable && (
        <Note
          icon="information-outline"
          text={developer ? (explicitNull ? t("home.unavailable_explicit") : t("home.unavailable_generic", { primary: primary ?? "—" })) : t("home.unavailable_generic_short")}
        />
      )}
      <Rows rows={rows.filter((r) => r.value !== "" || r.note)} />
      <SourceFooter snapshot={snapshot} developer={developer} />
    </>
  );
}

const styles = StyleSheet.create({
  flex: {
    flex: 1,
  },
  gapSm: {
    gap: Space.sm,
  },
  header: {
    flexDirection: "row",
    alignItems: "center",
    gap: Space.md,
  },
  headerIcon: {
    width: 48,
    height: 48,
    borderRadius: 15,
    backgroundColor: Colors.accentSoft,
    alignItems: "center",
    justifyContent: "center",
  },
  dayTemps: {
    alignItems: "flex-end",
  },
  rows: {
    borderRadius: Radius.md,
    backgroundColor: Colors.surfaceInset,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: Colors.hairline,
    paddingHorizontal: Space.md,
  },
  row: {
    flexDirection: "row",
    alignItems: "center",
    gap: Space.md,
    minHeight: 48,
    paddingVertical: Space.sm,
  },
  rowValue: {
    maxWidth: "55%",
    textAlign: "right",
  },
  note: {
    flexDirection: "row",
    gap: Space.sm,
    padding: Space.md,
    borderRadius: Radius.sm,
    backgroundColor: "rgba(251, 191, 36, 0.10)",
    borderWidth: 1,
    borderColor: "rgba(251, 191, 36, 0.35)",
  },
  footer: {
    gap: 2,
  },
  hourStrip: {
    gap: Space.sm,
  },
  hourCell: {
    width: 62,
    alignItems: "center",
    gap: 4,
    paddingVertical: Space.sm,
    borderRadius: Radius.sm,
    backgroundColor: Colors.surfaceInset,
  },
});
