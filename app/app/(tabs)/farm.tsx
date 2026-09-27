import React, { useEffect, useMemo } from "react";
import { RefreshControl, StyleSheet, View } from "react-native";
import { router } from "expo-router";

import { AppText, Button, Card, CardHeader, Colors, Divider, IconButton, Radius, Screen, SegmentedControl, Skeleton, Space, StateView } from "../../src/ui";
import { useTranslation } from "../../src/i18n/useTranslation";
import { LANGUAGE_META } from "../../src/i18n";
import { useSettingsStore } from "../../src/features/settings/settingsStore";
import { AdvisoryStatus, actionWindowsHasData, useActionWindowsStore, useFarmProfileStore } from "../../src/features/farm/farmStores";
import { ActionWindowTab, AdvisorySource } from "../../src/features/farm/models/advisoryModels";
import { useLocationStore } from "../../src/features/location/locationStore";
import { SuitabilityLegend, SuitabilityTrack } from "../../src/features/farm/components/SuitabilityTrack";
import { weekdayShort } from "../../src/features/weather/format";

const HOUR_TICKS = ["00", "06", "12", "18", "24"];

export default function FarmScreen(): React.ReactElement {
  const t = useTranslation();
  const persona = useSettingsStore((s) => s.userPersona);
  const profile = useFarmProfileStore((s) => s.profile);
  const completed = useFarmProfileStore((s) => s.completed);
  const location = useLocationStore((s) => s.location);
  const advisory = useActionWindowsStore((s) => s.state);

  useEffect(() => {
    const store = useActionWindowsStore.getState();
    if (!completed) {
      store.invalidate();
      return;
    }
    store.setContext({ location, profile, mode: persona });
    store.selectTab(store.state.selectedTab);
  }, [completed, location, profile, persona]);

  const dayTicks = useMemo(() => {
    const locale = LANGUAGE_META[t.language].ttsLocale;
    return Array.from({ length: 7 }, (_, i) => weekdayShort(new Date(Date.now() + i * 86_400_000).toISOString(), locale));
  }, [t.language]);

  const loading = advisory.status === AdvisoryStatus.Loading;
  const weekly = advisory.selectedTab === ActionWindowTab.SevenDay;
  const refresh = () => void useActionWindowsStore.getState().refresh();

  return (
    <Screen
      inTabs
      title={t("nav.farm")}
      subtitle={completed ? profile.location || location.name : undefined}
      trailing={completed ? <IconButton icon="pencil-outline" variant="filled" accessibilityLabel={t("farmer.edit_farm_profile")} onPress={() => router.push("/farm-profile")} /> : undefined}
      refreshControl={completed ? <RefreshControl refreshing={false} onRefresh={refresh} tintColor={Colors.text} colors={[Colors.accent]} /> : undefined}
    >
      {!completed ? (
        <Card>
          <StateView
            icon="sprout"
            title={t("farmer.complete_profile")}
            body={t("farmer.profile_complete_hint")}
          />
          <Button label={t("farmer.complete_profile")} size="lg" fullWidth onPress={() => router.push("/farm-profile")} />
        </Card>
      ) : (
        <>
          <ProfileSummary />

          <SegmentedControl
            accessibilityLabel={t("home.action_windows")}
            value={advisory.selectedTab}
            onChange={(tab) => useActionWindowsStore.getState().selectTab(tab)}
            segments={[
              { value: ActionWindowTab.Today, label: t("common.today") },
              { value: ActionWindowTab.Tomorrow, label: t("common.tomorrow") },
              { value: ActionWindowTab.SevenDay, label: t("common.days_7") },
            ]}
          />

          {loading ? (
            <Card style={styles.gap}>
              <Skeleton width="60%" height={22} />
              {[0, 1, 2].map((i) => (
                <View key={i} style={styles.gapSm}>
                  <Skeleton width={120} height={14} />
                  <Skeleton height={12} />
                </View>
              ))}
            </Card>
          ) : advisory.status === AdvisoryStatus.Unavailable || !actionWindowsHasData(advisory) ? (
            <Card>
              <StateView
                icon="cloud-off-outline"
                tone="caution"
                title={t("farmer.advisory_unavailable")}
                body={t("farmer.advisory_unavailable_body")}
                actionLabel={t("chat.retry")}
                onAction={refresh}
              />
            </Card>
          ) : (
            <Card style={styles.gap}>
              <View style={styles.verdictRow}>
                <AppText variant="title" style={styles.flex}>
                  {advisory.summaryVerdict}
                </AppText>
              </View>
              {advisory.source === AdvisorySource.SystemOne && advisory.aiConfidence !== null && (
                <View style={styles.confidence}>
                  <AppText variant="caption" color={Colors.farmer}>
                    System One · {Math.round(advisory.aiConfidence * 100)}%
                  </AppText>
                </View>
              )}
              {advisory.summaryExplanation !== "" && (
                <AppText variant="subhead" tone="secondary">
                  {advisory.summaryExplanation}
                </AppText>
              )}
              <Divider />
              {weekly ? (
                <SuitabilityTrack title={t("home.action_windows")} icon="calendar-week" cells={advisory.fieldWorkWindows} ticks={dayTicks} />
              ) : (
                <>
                  <SuitabilityTrack title={t("farmer.irrigation")} icon="water-outline" cells={advisory.irrigationWindows} ticks={HOUR_TICKS} />
                  <SuitabilityTrack title={t("farmer.spraying")} icon="spray" cells={advisory.sprayingWindows} ticks={HOUR_TICKS} />
                  <SuitabilityTrack title={t("farmer.field_work")} icon="tractor-variant" cells={advisory.fieldWorkWindows} ticks={HOUR_TICKS} />
                </>
              )}
              <SuitabilityLegend />
              {advisory.fieldWorkStatus !== "" && !weekly && (
                <View style={styles.best}>
                  <AppText variant="footnote" tone="accent">
                    {advisory.fieldWorkStatus}
                  </AppText>
                </View>
              )}
              {advisory.asOfUtc !== null && (
                <AppText variant="caption" tone="tertiary">
                  {t("farmer.last_verified", { time: advisory.asOfUtc.toLocaleTimeString([], { hour: "numeric", minute: "2-digit" }) })}
                </AppText>
              )}
            </Card>
          )}
        </>
      )}
    </Screen>
  );
}

function ProfileSummary(): React.ReactElement {
  const t = useTranslation();
  const profile = useFarmProfileStore((s) => s.profile);
  const facts: Array<[string, string]> = [
    [t("farmer.crop"), profile.crop],
    [t("farmer.growth_stage"), profile.growthStage],
    [t("farmer.soil_type"), profile.soilType],
    [t("farmer.irrigation_type"), profile.irrigationType],
    [t("farmer.farm_size"), `${profile.farmSizeAcres} ${t("farmer.acres")}`],
  ];
  return (
    <Card>
      <CardHeader icon="sprout-outline" title={t("farmer.farm_profile")} />
      <View style={styles.facts}>
        {facts.map(([label, value]) => (
          <View key={label} style={styles.fact}>
            <AppText variant="caption" tone="tertiary" numberOfLines={1}>
              {label}
            </AppText>
            <AppText variant="callout" numberOfLines={1}>
              {value}
            </AppText>
          </View>
        ))}
      </View>
    </Card>
  );
}

const styles = StyleSheet.create({
  flex: {
    flex: 1,
  },
  gap: {
    gap: Space.lg,
  },
  gapSm: {
    gap: Space.sm,
  },
  verdictRow: {
    flexDirection: "row",
    alignItems: "center",
  },
  confidence: {
    alignSelf: "flex-start",
    paddingHorizontal: Space.sm,
    paddingVertical: 4,
    borderRadius: Radius.pill,
    backgroundColor: "rgba(74, 222, 128, 0.14)",
  },
  best: {
    padding: Space.md,
    borderRadius: Radius.sm,
    backgroundColor: Colors.accentSoft,
  },
  facts: {
    flexDirection: "row",
    flexWrap: "wrap",
    rowGap: Space.md,
  },
  fact: {
    width: "33.33%",
    paddingRight: Space.sm,
    gap: 2,
  },
});
