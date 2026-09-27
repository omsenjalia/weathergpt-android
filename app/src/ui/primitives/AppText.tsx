import React from "react";
import { Text, TextProps, StyleSheet } from "react-native";

import { Colors, Type, TypeVariant } from "../theme/tokens";

type Tone = "primary" | "secondary" | "tertiary" | "accent" | "danger" | "inverse";

const TONE_COLOR: Record<Tone, string> = {
  primary: Colors.text,
  secondary: Colors.textSecondary,
  tertiary: Colors.textTertiary,
  accent: Colors.accentText,
  danger: Colors.danger,
  inverse: Colors.textInverse,
};

export interface AppTextProps extends TextProps {
  variant?: TypeVariant;
  tone?: Tone;
  color?: string;
  align?: "left" | "center" | "right";
}

/// The only text component screens should use. Variants map to the type
/// scale in `tokens.ts`; colour comes from a semantic tone.
export function AppText({ variant = "body", tone = "primary", color, align, style, ...rest }: AppTextProps): React.ReactElement {
  return (
    <Text
      {...rest}
      maxFontSizeMultiplier={rest.maxFontSizeMultiplier ?? 1.6}
      style={[Type[variant], { color: color ?? TONE_COLOR[tone] }, align !== undefined && { textAlign: align }, style]}
    />
  );
}

export const textStyles = StyleSheet.create({
  shadow: {
    textShadowColor: "rgba(0, 0, 0, 0.28)",
    textShadowOffset: { width: 0, height: 1 },
    textShadowRadius: 12,
  },
});
