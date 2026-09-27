import React from "react";
import { ActivityIndicator, StyleProp, StyleSheet, View, ViewStyle } from "react-native";

import { AppText } from "./AppText";
import { Icon, IconName } from "./Icon";
import { Touchable } from "./Touchable";
import { Colors, Layout, Radius, Space } from "../theme/tokens";

type Variant = "primary" | "secondary" | "ghost" | "danger";
type Size = "md" | "lg";

interface ButtonProps {
  label: string;
  onPress?: () => void;
  variant?: Variant;
  size?: Size;
  icon?: IconName;
  loading?: boolean;
  disabled?: boolean;
  fullWidth?: boolean;
  style?: StyleProp<ViewStyle>;
  accessibilityHint?: string;
}

const FILL: Record<Variant, string> = {
  primary: Colors.accent,
  secondary: Colors.surfaceInset,
  ghost: "transparent",
  danger: "rgba(248, 113, 113, 0.14)",
};

const INK: Record<Variant, string> = {
  primary: Colors.onAccent,
  secondary: Colors.text,
  ghost: Colors.accentText,
  danger: Colors.danger,
};

export function Button({
  label,
  onPress,
  variant = "primary",
  size = "md",
  icon,
  loading = false,
  disabled = false,
  fullWidth = false,
  style,
  accessibilityHint,
}: ButtonProps): React.ReactElement {
  const ink = INK[variant];
  return (
    <Touchable
      onPress={onPress}
      disabled={disabled || loading}
      haptics={variant === "primary" ? "light" : "none"}
      accessibilityLabel={label}
      accessibilityHint={accessibilityHint}
      accessibilityState={{ busy: loading }}
      style={[
        styles.base,
        size === "lg" ? styles.lg : styles.md,
        { backgroundColor: FILL[variant] },
        variant === "secondary" && styles.secondaryBorder,
        fullWidth && styles.fullWidth,
        style,
      ]}
    >
      <View style={styles.row}>
        {loading ? (
          <ActivityIndicator size="small" color={ink} />
        ) : (
          icon !== undefined && <Icon name={icon} size={size === "lg" ? 20 : 18} color={ink} />
        )}
        <AppText variant={size === "lg" ? "bodyStrong" : "callout"} color={ink} style={styles.label} numberOfLines={1}>
          {label}
        </AppText>
      </View>
    </Touchable>
  );
}

interface IconButtonProps {
  icon: IconName;
  onPress?: () => void;
  accessibilityLabel: string;
  variant?: "plain" | "filled" | "accent";
  size?: number;
  disabled?: boolean;
  color?: string;
}

/// Circular icon-only button with a 44pt minimum hit target.
export function IconButton({ icon, onPress, accessibilityLabel, variant = "plain", size = 40, disabled, color }: IconButtonProps): React.ReactElement {
  const bg = variant === "accent" ? Colors.accent : variant === "filled" ? Colors.surfaceInset : "transparent";
  const ink = color ?? (variant === "accent" ? Colors.onAccent : Colors.text);
  return (
    <Touchable
      onPress={onPress}
      disabled={disabled}
      accessibilityLabel={accessibilityLabel}
      hitSlop={Math.max(0, (Layout.minTouch - size) / 2)}
      style={[styles.iconButton, { width: size, height: size, borderRadius: size / 2, backgroundColor: bg }, variant === "filled" && styles.secondaryBorder]}
    >
      <Icon name={icon} size={Math.round(size * 0.5)} color={ink} />
    </Touchable>
  );
}

const styles = StyleSheet.create({
  base: {
    borderRadius: Radius.pill,
    alignItems: "center",
    justifyContent: "center",
  },
  md: {
    minHeight: Layout.minTouch,
    paddingHorizontal: Space.xl,
  },
  lg: {
    minHeight: 54,
    paddingHorizontal: Space.xxl,
  },
  fullWidth: {
    alignSelf: "stretch",
  },
  secondaryBorder: {
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: Colors.hairlineStrong,
  },
  row: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    gap: Space.sm,
  },
  label: {
    flexShrink: 1,
  },
  iconButton: {
    alignItems: "center",
    justifyContent: "center",
  },
});
