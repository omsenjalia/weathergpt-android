import React, { useEffect, useState } from "react";
import { StyleSheet, View } from "react-native";
import { router } from "expo-router";
import Svg, { Line, Rect, Text as SvgText } from "react-native-svg";

import { AppText, Button, Card, CardHeader, Colors, Divider, FontFamily, Radius, Screen, Skeleton, Space, StateView } from "../../src/ui";
import { useTranslation } from "../../src/i18n/useTranslation";
import { LANGUAGE_META } from "../../src/i18n";
import { useLocationStore } from "../../src/features/location/locationStore";
import { useFarmProfileStore } from "../../src/features/farm/farmStores";
import { GROWTH_STAGES } from "../../src/features/farm/models/farmOptions";
import { sourceLabel } from "../../src/features/research/modelData";
import {
  CROP_DURATION_DAYS,
  cropNoteKey,
  fetchRainOutlook,
  nextRainyDay,
  RainDay,
  RainOutlook,
  RAINY_DAY_MM,
  stageIndex,
  stageTaskKey,
  totalRain,
} from "../../src/features/farm/planData";

type Async<T> = { kind: "loading" } | { kind: "error"; message: string } | { kind: "data"; value: T };

const errorMessage = (e: unknown) => (e instanceof Error ? e.message : String(e));

/// Loads `load` whenever `deps` change; only the latest request may write state.
function useAsync<T>(load: () => Promise<T>, deps: React.DependencyList): [Async<T>, () => void] {
  const [state, setState] = useState<Async<T>>({ kind: "loading" });
  const [attempt, setAttempt] = useState(0);
  useEffect(() => {
    let active = true;
    setState({ kind: "loading" });
    load()
      .then((value) => active && setState({ kind: "data", value }))
      .catch((e: unknown) => active && setState({ kind: "error", message: errorMessage(e) }));
    return () => {
      active = false;
    };
  }, [...deps, attempt]);
  return [state, () => setAttempt((n) => n + 1)];
}

export default function PlanScreen(): React.ReactElement {
  const t = useTranslation();
  return (
    <Screen inTabs title={t("nav.plan")}>
      <RainCard />
      <CalendarCard />
    </Screen>
  );
}

function RainCard(): React.ReactElement {
  const t = useTranslation();
  const location = useLocationStore((s) => s.location);
  const [outlook, retry] = useAsync<RainOutlook>(() => fetchRainOutlook(location), [location]);
  const locale = LANGUAGE_META[t.language].ttsLocale;
  const dayLabel = (date: string, withDay = true) =>
    new Date(`${date}T12:00:00`).toLocaleDateString(locale, withDay ? { weekday: "short", day: "numeric" } : { weekday: "short" });

  const data = outlook.kind === "data" ? outlook.value : null;
  const days = data?.days ?? [];
  const next = nextRainyDay(days);

  return (
    <Card style={styles.gap}>
      <CardHeader icon="weather-pouring" title={`${t("plan.rain_outlook")} · ${location.name.split(",")[0]}`} />
      {outlook.kind === "loading" && <Skeleton height={160} radius={12} />}
      {outlook.kind === "error" && <StateView compact tone="error" icon="database-alert-outline" title={t("voice.error")} body={outlook.message} actionLabel={t("chat.retry")} onAction={retry} />}
      {data !== null && days.length === 0 && (
        <StateView compact icon="database-off-outline" title={t("home.unavailable")} body={data.series.detail ?? t("home.unavailable_generic_short")} />
      )}
      {data !== null && days.length > 0 && (
        <>
          <RainBars days={days} firstLabel={dayLabel(days[0]!.date)} lastLabel={dayLabel(days[days.length - 1]!.date)} accessibilityLabel={t("plan.rain_outlook")} />
          <View style={styles.legend}>
            <LegendSwatch color={Colors.rain} label={t("plan.expected")} />
            <LegendSwatch color={Colors.caution} line label={t("plan.rainy_line")} />
          </View>
          <View style={styles.stats}>
            <Stat label={t("plan.next_rain")} value={next === null ? t("plan.none") : dayLabel(days[next]!.date, false)} />
            <Stat label={t("plan.dry_days")} value={t("plan.days", { n: next === null ? `${days.length}+` : next })} />
            <Stat label={t("plan.total")} value={`${formatMm(totalRain(days))} mm`} />
          </View>
          <AppText variant="caption" tone="tertiary">
            {`${t("plan.rain_note")} ${t("models.source")}: ${sourceLabel(data.series)}.`}
          </AppText>
        </>
      )}
    </Card>
  );
}

function CalendarCard(): React.ReactElement {
  const t = useTranslation();
  const profile = useFarmProfileStore((s) => s.profile);
  const completed = useFarmProfileStore((s) => s.completed);

  if (!completed) {
    return (
      <Card style={styles.gap}>
        <CardHeader icon="calendar-month-outline" title={t("plan.crop_calendar")} />
        <StateView compact icon="sprout" title={t("farmer.complete_profile")} body={t("farmer.profile_complete_hint")} />
        <Button label={t("farmer.complete_profile")} fullWidth onPress={() => router.push("/farm-profile")} />
      </Card>
    );
  }

  const current = stageIndex(profile.growthStage);
  const duration = CROP_DURATION_DAYS[profile.crop];
  const noteKey = cropNoteKey(profile.crop);

  return (
    <Card style={styles.gap}>
      <CardHeader icon="calendar-month-outline" title={`${t("plan.crop_calendar")} · ${profile.crop}`} />
      {duration !== undefined && (
        <AppText variant="subhead" tone="secondary">
          {t("plan.duration", { min: duration[0], max: duration[1] })}
        </AppText>
      )}
      {noteKey !== null && (
        <View style={styles.note}>
          <AppText variant="footnote" color={Colors.farmer}>
            {t(noteKey)}
          </AppText>
        </View>
      )}
      <Divider />
      <View>
        {GROWTH_STAGES.map((stage, i) => {
          const state = current === -1 ? "future" : i < current ? "past" : i === current ? "current" : "future";
          // Tasks for the current stage and the one after it; the rest stay compact.
          const showTask = current === -1 || i === current || i === current + 1;
          return (
            <View key={stage} style={styles.stageRow}>
              <View style={styles.rail}>
                <View style={[styles.dot, state === "past" && styles.dotPast, state === "current" && styles.dotCurrent]} />
                {i < GROWTH_STAGES.length - 1 && <View style={styles.railLine} />}
              </View>
              <View style={[styles.stageBody, state === "current" && styles.stageCurrent]}>
                <View style={styles.stageTitle}>
                  <AppText variant="callout" tone={state === "past" ? "tertiary" : "primary"}>
                    {stage}
                  </AppText>
                  {state === "current" && (
                    <View style={styles.nowBadge}>
                      <AppText variant="caption" color={Colors.onAccent}>
                        {t("plan.now")}
                      </AppText>
                    </View>
                  )}
                </View>
                {showTask && (
                  <AppText variant="footnote" tone="secondary">
                    {t(stageTaskKey(stage))}
                  </AppText>
                )}
              </View>
            </View>
          );
        })}
      </View>
      <AppText variant="caption" tone="tertiary">
        {t("plan.guidance_note")}
      </AppText>
    </Card>
  );
}

const BAR_PAD = { left: 34, right: 4, top: 8, bottom: 20 };

/// Daily rain bars: solid expected total and a
/// dashed rainy-day line. The scale never drops below 5 mm, so a dry week
/// looks dry instead of blowing trace amounts up to full height.
function RainBars({ days, firstLabel, lastLabel, accessibilityLabel, height = 150 }: { days: RainDay[]; firstLabel: string; lastLabel: string; accessibilityLabel: string; height?: number }): React.ReactElement {
  const [width, setWidth] = useState(0);
  const max = Math.max(5, ...days.map((d) => d.expectedMm));
  const plotH = height - BAR_PAD.top - BAR_PAD.bottom;
  const toY = (mm: number) => BAR_PAD.top + plotH * (1 - mm / max);
  const slot = days.length > 0 ? (width - BAR_PAD.left - BAR_PAD.right) / days.length : 0;
  const barW = Math.max(Math.min(slot * 0.62, 16), 2);

  return (
    <View style={{ height }} onLayout={(e) => setWidth(Math.round(e.nativeEvent.layout.width))} accessible accessibilityRole="image" accessibilityLabel={accessibilityLabel}>
      {width > 0 && (
        <Svg width={width} height={height}>
          {[0, max].map((tick) => (
            <React.Fragment key={tick}>
              <Line x1={BAR_PAD.left} x2={width - BAR_PAD.right} y1={toY(tick)} y2={toY(tick)} stroke={Colors.hairline} strokeWidth={1} />
              <SvgText x={BAR_PAD.left - 6} y={toY(tick) + 3} fontSize={10} fill={Colors.textTertiary} textAnchor="end" fontFamily={FontFamily.medium}>
                {`${formatMm(tick)}`}
              </SvgText>
            </React.Fragment>
          ))}
          <Line x1={BAR_PAD.left} x2={width - BAR_PAD.right} y1={toY(RAINY_DAY_MM)} y2={toY(RAINY_DAY_MM)} stroke={Colors.caution} strokeWidth={1} strokeDasharray="4 4" />
          {days.map((d, i) => {
            const x = BAR_PAD.left + i * slot + (slot - barW) / 2;
            const bar = (mm: number, opacity: number) => {
              const top = toY(mm);
              return <Rect x={x} y={top} width={barW} height={Math.max(toY(0) - top, 0)} rx={Math.min(3, barW / 2)} fill={Colors.rain} fillOpacity={opacity} />;
            };
            return (
              <React.Fragment key={d.date}>
                {bar(d.expectedMm, 1)}
              </React.Fragment>
            );
          })}
          <SvgText x={BAR_PAD.left} y={height - 5} fontSize={10} fill={Colors.textTertiary} fontFamily={FontFamily.medium}>
            {firstLabel}
          </SvgText>
          <SvgText x={width - BAR_PAD.right} y={height - 5} fontSize={10} fill={Colors.textTertiary} textAnchor="end" fontFamily={FontFamily.medium}>
            {lastLabel}
          </SvgText>
        </Svg>
      )}
    </View>
  );
}

function formatMm(mm: number): string {
  return mm >= 10 ? String(Math.round(mm)) : String(Math.round(mm * 10) / 10);
}

function LegendSwatch({ color, label, faint = false, line = false }: { color: string; label: string; faint?: boolean; line?: boolean }): React.ReactElement {
  return (
    <View style={styles.legendItem}>
      <View style={[line ? styles.swatchLine : styles.swatch, { backgroundColor: color }, faint && styles.swatchFaint]} />
      <AppText variant="footnote" tone="secondary">
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
    width: 10,
    height: 10,
    borderRadius: 3,
  },
  swatchFaint: {
    opacity: 0.3,
  },
  swatchLine: {
    width: 14,
    height: 2,
    borderRadius: 1,
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
  note: {
    padding: Space.md,
    borderRadius: Radius.sm,
    backgroundColor: "rgba(74, 222, 128, 0.10)",
  },
  stageRow: {
    flexDirection: "row",
    gap: Space.sm,
  },
  rail: {
    width: 14,
    alignItems: "center",
  },
  dot: {
    width: 10,
    height: 10,
    marginTop: 12,
    borderRadius: 5,
    borderWidth: 1.5,
    borderColor: Colors.hairlineStrong,
  },
  dotPast: {
    backgroundColor: Colors.textTertiary,
    borderColor: Colors.textTertiary,
  },
  dotCurrent: {
    width: 12,
    height: 12,
    borderRadius: 6,
    backgroundColor: Colors.accent,
    borderColor: Colors.accent,
  },
  railLine: {
    flex: 1,
    width: 1.5,
    marginTop: 2,
    backgroundColor: Colors.hairline,
  },
  stageBody: {
    flex: 1,
    gap: 2,
    paddingVertical: Space.sm,
    paddingHorizontal: Space.sm,
    borderRadius: Radius.sm,
  },
  stageCurrent: {
    backgroundColor: Colors.accentSoft,
  },
  stageTitle: {
    flexDirection: "row",
    alignItems: "center",
    gap: Space.sm,
  },
  nowBadge: {
    paddingHorizontal: Space.sm,
    paddingVertical: 1,
    borderRadius: Radius.pill,
    backgroundColor: Colors.accent,
  },
});
