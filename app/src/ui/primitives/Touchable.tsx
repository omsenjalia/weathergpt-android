import React from "react";
import { Platform, Pressable, PressableProps, StyleProp, ViewStyle } from "react-native";
import * as Haptics from "expo-haptics";

import { Motion } from "../theme/tokens";

export type HapticKind = "none" | "selection" | "light" | "success";

export function haptic(kind: HapticKind): void {
  if (kind === "none" || Platform.OS === "web") return;
  try {
    if (kind === "selection") void Haptics.selectionAsync();
    else if (kind === "success") void Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    else void Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
  } catch {
    // Haptics are a nicety; never let them break an interaction.
  }
}

export interface TouchableProps extends Omit<PressableProps, "style"> {
  style?: StyleProp<ViewStyle>;
  /// Scale down slightly while pressed. Off for full-width rows.
  scale?: boolean;
  haptics?: HapticKind;
  children?: React.ReactNode;
}

/// Pressable with press feedback (scale + dim) and optional haptics. Every
/// tappable surface in the app goes through this. The style lands on the
/// Pressable itself, so layout props (flex, flexBasis) behave exactly as on a
/// plain View. (An Animated wrapper around Pressable swallows presses on
/// react-native-web, so feedback uses the pressed-state style instead.)
export function Touchable({ style, scale = true, haptics = "none", onPress, disabled, children, ...rest }: TouchableProps): React.ReactElement {
  return (
    <Pressable
      {...rest}
      disabled={disabled}
      accessibilityRole={rest.accessibilityRole ?? "button"}
      accessibilityState={{ disabled: disabled ?? false, ...rest.accessibilityState }}
      onPress={(e) => {
        haptic(haptics);
        onPress?.(e);
      }}
      style={({ pressed }) => [
        style,
        disabled ? { opacity: 0.45 } : pressed ? { opacity: 0.82, transform: scale ? [{ scale: Motion.pressScale }] : undefined } : null,
      ]}
    >
      {children}
    </Pressable>
  );
}
