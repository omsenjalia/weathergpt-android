/// Floating tab bar for the (tabs) navigator. Persona-aware: the Farm and
/// Lab tabs appear only for the matching mode.

import React from "react";
import { StyleSheet, View } from "react-native";
import { router, Tabs } from "expo-router";
import { useSafeAreaInsets } from "react-native-safe-area-context";

import { AppText } from "../primitives/AppText";
import { Icon, IconName } from "../primitives/Icon";
import { Touchable } from "../primitives/Touchable";
import { VoiceOrb } from "../primitives/VoiceOrb";
import { Colors, Layout, Radius, Space } from "../theme/tokens";
import { useKeyboardVisible } from "./useKeyboardVisible";

type TabBarProps = Parameters<NonNullable<React.ComponentProps<typeof Tabs>["tabBar"]>>[0];

export interface TabSpec {
  label: string;
  icon: IconName;
  activeIcon: IconName;
}

interface FloatingTabBarProps extends TabBarProps {
  specs: Record<string, TabSpec>;
  /// Route names to show, in order. The voice button sits in the middle.
  visible: readonly string[];
  voiceLabel: string;
}

export function FloatingTabBar({ state, navigation, specs, visible, voiceLabel }: FloatingTabBarProps): React.ReactElement | null {
  const insets = useSafeAreaInsets();
  const keyboard = useKeyboardVisible();
  if (keyboard) return null;

  const activeName = state.routes[state.index]?.name;
  const middle = Math.ceil(visible.length / 2);

  return (
    <View pointerEvents="box-none" style={[styles.wrap, { paddingBottom: Math.max(insets.bottom, Space.md) }]}>
      <View style={styles.bar} accessibilityRole="tablist">
        {visible.map((name, index) => {
          const route = state.routes.find((r) => r.name === name);
          const spec = specs[name];
          if (route === undefined || spec === undefined) return null;
          const focused = name === activeName;
          const tab = (
            <Touchable
              key={route.key}
              scale={false}
              haptics={focused ? "none" : "selection"}
              accessibilityRole="tab"
              accessibilityState={{ selected: focused }}
              accessibilityLabel={spec.label}
              onPress={() => {
                const event = navigation.emit({ type: "tabPress", target: route.key, canPreventDefault: true });
                if (!focused && !event.defaultPrevented) navigation.navigate(route.name, route.params);
              }}
              onLongPress={() => navigation.emit({ type: "tabLongPress", target: route.key })}
              style={styles.item}
            >
              <View style={[styles.iconPill, focused && styles.iconPillActive]}>
                <Icon name={focused ? spec.activeIcon : spec.icon} size={22} color={focused ? Colors.onAccent : Colors.textSecondary} />
              </View>
              <AppText variant="caption" tone={focused ? "primary" : "tertiary"} numberOfLines={1}>
                {spec.label}
              </AppText>
            </Touchable>
          );
          if (index !== middle) return tab;
          // Voice-first: the assistant is one tap away from every tab.
          return (
            <React.Fragment key={route.key}>
              <View style={styles.voiceSlot}>
                <View style={styles.voiceLift}>
                  <VoiceOrb size={58} ambient={false} accessibilityLabel={voiceLabel} onPress={() => router.push("/voice")} />
                </View>
              </View>
              {tab}
            </React.Fragment>
          );
        })}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: {
    position: "absolute",
    left: 0,
    right: 0,
    bottom: 0,
    alignItems: "center",
    paddingHorizontal: Space.lg,
  },
  bar: {
    flexDirection: "row",
    width: "100%",
    maxWidth: 480,
    minHeight: Layout.tabBarHeight + 8,
    paddingHorizontal: Space.xs,
    paddingVertical: Space.sm,
    borderRadius: Radius.xl,
    backgroundColor: "rgba(8, 13, 26, 0.86)",
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: Colors.hairlineStrong,
    shadowColor: "#000",
    shadowOpacity: 0.3,
    shadowRadius: 24,
    shadowOffset: { width: 0, height: 10 },
    elevation: 12,
  },
  item: {
    flex: 1,
    alignItems: "center",
    justifyContent: "center",
    gap: 3,
    minHeight: Layout.minTouch,
  },
  voiceSlot: {
    width: 66,
    alignItems: "center",
  },
  voiceLift: {
    marginTop: -30,
    borderRadius: 34,
    borderWidth: 4,
    borderColor: "rgba(8, 13, 26, 0.9)",
  },
  iconPill: {
    width: 52,
    height: 30,
    borderRadius: Radius.pill,
    alignItems: "center",
    justifyContent: "center",
  },
  iconPillActive: {
    backgroundColor: Colors.accent,
  },
});
