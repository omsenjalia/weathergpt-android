/// Structured answer card shared by chat replies and voice results. Only
/// renders what the backend actually sent — no stats means no stats row.

import React from "react";
import { StyleSheet, View } from "react-native";

import { AppText, Colors, Icon, IconName, Radius, Space } from "../../../ui";
import { toneColor } from "../../voice/mappers/voiceResponseMapper";
import { forecastIconForCondition } from "../../voice/mappers/voiceResponseMapper";
import { VoiceCard } from "../../voice/models/voiceCard";

export interface Insight {
  label: string | null;
  verdict: string | null;
  accent: string;
  stats: Array<{ label: string; value: string; color: string }>;
  forecast: Array<{ day: string; icon: string; temperature: string; rainfall: string }>;
  confidence: number | null;
  source: string | null;
}

export function insightFromCard(card: VoiceCard): Insight {
  return {
    label: card.label,
    verdict: card.verdict,
    accent: Colors.accent,
    stats: card.stats.map((s) => ({ label: s.label, value: s.value, color: toneColor(s.tone) })),
    forecast: card.forecast.map((d) => ({ day: d.label, icon: forecastIconForCondition(d.condition), temperature: d.temperature, rainfall: d.rainfall ?? "—" })),
    confidence: card.confidence,
    source: card.source,
  };
}

export function insightHasContent(insight: Insight): boolean {
  return (insight.verdict !== null && insight.verdict !== "") || insight.stats.length > 0 || insight.forecast.length > 0;
}

export function InsightCard({ insight }: { insight: Insight }): React.ReactElement {
  return (
    <View style={[styles.card, { borderLeftColor: insight.accent }]}>
      {insight.label !== null && insight.label !== "" && (
        <AppText variant="caption" tone="tertiary">
          {insight.label}
        </AppText>
      )}
      {insight.verdict !== null && insight.verdict !== "" && <AppText variant="headline">{insight.verdict}</AppText>}

      {insight.stats.length > 0 && (
        <View style={styles.stats}>
          {insight.stats.map((stat) => (
            <View key={stat.label} style={styles.stat}>
              <AppText variant="caption" tone="tertiary" numberOfLines={1}>
                {stat.label}
              </AppText>
              <AppText variant="bodyStrong" color={stat.color} numberOfLines={1}>
                {stat.value}
              </AppText>
            </View>
          ))}
        </View>
      )}

      {insight.forecast.length > 0 && (
        <View style={styles.forecast}>
          {insight.forecast.map((day) => (
            <View key={day.day} style={styles.day}>
              <AppText variant="caption" tone="secondary">
                {day.day}
              </AppText>
              <Icon name={day.icon as IconName} size={22} color={Colors.text} />
              <AppText variant="numeric">{day.temperature}</AppText>
              <AppText variant="caption" color={Colors.rain}>
                {day.rainfall}
              </AppText>
            </View>
          ))}
        </View>
      )}

      {(insight.confidence !== null || insight.source !== null) && (
        <AppText variant="caption" tone="tertiary">
          {[insight.source, insight.confidence !== null ? `${Math.round(insight.confidence * 100)}% confident` : null].filter(Boolean).join(" · ")}
        </AppText>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    gap: Space.sm,
    padding: Space.md,
    borderRadius: Radius.md,
    borderLeftWidth: 3,
    backgroundColor: Colors.surfaceInset,
  },
  stats: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: Space.sm,
  },
  stat: {
    flexGrow: 1,
    flexBasis: "30%",
    padding: Space.sm,
    borderRadius: Radius.sm,
    backgroundColor: Colors.surface,
  },
  forecast: {
    flexDirection: "row",
    justifyContent: "space-between",
    gap: Space.sm,
  },
  day: {
    flex: 1,
    alignItems: "center",
    gap: 2,
  },
});
