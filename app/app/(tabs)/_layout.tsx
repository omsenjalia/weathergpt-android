import React, { useMemo } from "react";
import { Tabs } from "expo-router";

import { FloatingTabBar, TabSpec } from "../../src/ui/shell/TabBar";
import { useSettingsStore, selectMode } from "../../src/features/settings/settingsStore";
import { useTranslation } from "../../src/i18n/useTranslation";
import { AppMode } from "../../src/core/models/appMode";

/// Persona-aware tab order: Farmer gains Farm and Plan, Researcher gains Lab
/// and Models (three tabs either side of the voice orb).
function visibleTabs(mode: AppMode): string[] {
  const tabs = ["home", "chat", "explore", "profile"];
  if (mode === "farmer") tabs.splice(2, 0, "farm", "plan");
  if (mode === "researcher") tabs.splice(2, 0, "lab", "models");
  return tabs;
}

export default function TabsLayout(): React.ReactElement {
  const mode = useSettingsStore(selectMode);
  const t = useTranslation();

  const specs = useMemo<Record<string, TabSpec>>(
    () => ({
      home: { label: t("common.today"), icon: "weather-partly-cloudy", activeIcon: "weather-partly-cloudy" },
      chat: { label: t("nav.chat"), icon: "chat-outline", activeIcon: "chat" },
      farm: { label: t("nav.farm"), icon: "sprout-outline", activeIcon: "sprout" },
      plan: { label: t("nav.plan"), icon: "calendar-month-outline", activeIcon: "calendar-month" },
      lab: { label: t("nav.lab"), icon: "flask-outline", activeIcon: "flask" },
      models: { label: t("nav.models"), icon: "chart-bell-curve", activeIcon: "chart-bell-curve-cumulative" },
      explore: { label: t("nav.map"), icon: "map-outline", activeIcon: "map" },
      profile: { label: t("common.settings"), icon: "cog-outline", activeIcon: "cog" },
    }),
    [t],
  );
  const visible = useMemo(() => visibleTabs(mode), [mode]);

  return (
    <Tabs
      screenOptions={{ headerShown: false, sceneStyle: { backgroundColor: "transparent" }, animation: "shift" }}
      tabBar={(props) => <FloatingTabBar {...props} specs={specs} visible={visible} voiceLabel={t("chat.voice")} />}
    >
      <Tabs.Screen name="home" />
      <Tabs.Screen name="chat" />
      <Tabs.Screen name="farm" />
      <Tabs.Screen name="plan" />
      <Tabs.Screen name="lab" />
      <Tabs.Screen name="models" />
      <Tabs.Screen name="explore" />
      <Tabs.Screen name="profile" />
    </Tabs>
  );
}
