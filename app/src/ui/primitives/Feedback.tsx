/// Loading, empty and error states. Skeletons mirror the shape of the content
/// they stand in for so layouts never jump when data arrives.

import React, { useEffect, useRef } from "react";
import { Animated, DimensionValue, Platform, StyleProp, StyleSheet, View, ViewStyle } from "react-native";

import { AppText } from "./AppText";
import { Button } from "./Button";
import { Icon, IconName } from "./Icon";
import { Colors, Radius, Space } from "../theme/tokens";

interface SkeletonProps {
  width?: DimensionValue;
  height?: number;
  radius?: number;
  style?: StyleProp<ViewStyle>;
}

export function Skeleton({ width = "100%", height = 14, radius = Radius.xs, style }: SkeletonProps): React.ReactElement {
  const pulse = useRef(new Animated.Value(0.45)).current;
  useEffect(() => {
    const loop = Animated.loop(
      Animated.sequence([
        Animated.timing(pulse, { toValue: 0.9, duration: 800, useNativeDriver: Platform.OS !== "web" }),
        Animated.timing(pulse, { toValue: 0.45, duration: 800, useNativeDriver: Platform.OS !== "web" }),
      ]),
    );
    loop.start();
    return () => loop.stop();
  }, [pulse]);
  return (
    <Animated.View
      accessibilityElementsHidden
      importantForAccessibility="no-hide-descendants"
      style={[{ width, height, borderRadius: radius, backgroundColor: Colors.surfaceInset, opacity: pulse }, style]}
    />
  );
}

interface StateViewProps {
  icon: IconName;
  title: string;
  body?: string;
  actionLabel?: string;
  onAction?: () => void;
  tone?: "neutral" | "error" | "caution";
  compact?: boolean;
}

/// Composed empty / error / unavailable state. Always says what happened and,
/// when possible, offers the one action that fixes it.
export function StateView({ icon, title, body, actionLabel, onAction, tone = "neutral", compact = false }: StateViewProps): React.ReactElement {
  const iconColor = tone === "error" ? Colors.danger : tone === "caution" ? Colors.caution : Colors.accentText;
  return (
    <View style={[styles.state, compact && styles.compact]} accessibilityRole={tone === "error" ? "alert" : undefined}>
      <View style={[styles.stateIcon, { backgroundColor: tone === "neutral" ? Colors.accentSoft : Colors.surfaceInset }]}>
        <Icon name={icon} size={26} color={iconColor} />
      </View>
      <AppText variant="headline" align="center">
        {title}
      </AppText>
      {body !== undefined && (
        <AppText variant="subhead" tone="secondary" align="center" style={styles.body}>
          {body}
        </AppText>
      )}
      {actionLabel !== undefined && onAction !== undefined && (
        <Button label={actionLabel} onPress={onAction} variant="secondary" icon="refresh" style={styles.action} />
      )}
    </View>
  );
}

interface InlineBannerProps {
  icon?: IconName;
  message: string;
  tone?: "info" | "error" | "caution";
  actionLabel?: string;
  onAction?: () => void;
}

export function InlineBanner({ icon, message, tone = "info", actionLabel, onAction }: InlineBannerProps): React.ReactElement {
  const color = tone === "error" ? Colors.danger : tone === "caution" ? Colors.caution : Colors.info;
  return (
    <View style={[styles.banner, { borderColor: color }]} accessibilityRole={tone === "error" ? "alert" : undefined}>
      <Icon name={icon ?? (tone === "error" ? "alert-circle-outline" : "information-outline")} size={18} color={color} />
      <AppText variant="footnote" style={styles.bannerText}>
        {message}
      </AppText>
      {actionLabel !== undefined && onAction !== undefined && (
        <Button label={actionLabel} onPress={onAction} variant="ghost" style={styles.bannerAction} />
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  state: {
    alignItems: "center",
    justifyContent: "center",
    paddingVertical: Space.huge,
    paddingHorizontal: Space.xxl,
    gap: Space.sm,
  },
  compact: {
    paddingVertical: Space.xxl,
  },
  stateIcon: {
    width: 56,
    height: 56,
    borderRadius: 28,
    alignItems: "center",
    justifyContent: "center",
    marginBottom: Space.sm,
  },
  body: {
    maxWidth: 340,
  },
  action: {
    marginTop: Space.md,
  },
  banner: {
    flexDirection: "row",
    alignItems: "center",
    gap: Space.sm,
    paddingLeft: Space.md,
    paddingRight: Space.xs,
    paddingVertical: Space.xs,
    minHeight: 44,
    borderRadius: Radius.md,
    borderWidth: 1,
    backgroundColor: Colors.surfaceStrong,
  },
  bannerText: {
    flex: 1,
    paddingVertical: Space.xs,
  },
  bannerAction: {
    paddingHorizontal: Space.md,
  },
});
