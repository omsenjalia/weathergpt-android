import React from "react";
import { StyleProp, StyleSheet, View, ViewProps, ViewStyle } from "react-native";

import { AppText } from "./AppText";
import { Icon, IconName } from "./Icon";
import { Colors, Radius, Space } from "../theme/tokens";

interface CardProps extends ViewProps {
  children?: React.ReactNode;
  /// Denser fill for text-heavy content on bright skies.
  strong?: boolean;
  padded?: boolean;
  style?: StyleProp<ViewStyle>;
}

/// Translucent surface over the live sky. Elevation is communicated by fill
/// density and a single hairline — no drop shadows fighting the gradient.
export function Card({ children, strong = false, padded = true, style, ...rest }: CardProps): React.ReactElement {
  return (
    <View {...rest} style={[styles.card, strong && styles.strong, padded && styles.padded, style]}>
      {children}
    </View>
  );
}

interface CardHeaderProps {
  icon?: IconName;
  title: string;
  trailing?: React.ReactNode;
}

/// Small eyebrow row at the top of a card: icon + sentence-case label.
export function CardHeader({ icon, title, trailing }: CardHeaderProps): React.ReactElement {
  return (
    <View style={styles.header} accessibilityRole="header">
      {icon !== undefined && <Icon name={icon} size={15} color={Colors.textTertiary} />}
      <AppText variant="eyebrow" tone="tertiary" style={styles.headerTitle} numberOfLines={1}>
        {title}
      </AppText>
      {trailing}
    </View>
  );
}

export function Divider({ inset = 0 }: { inset?: number }): React.ReactElement {
  return <View style={[styles.divider, { marginLeft: inset }]} />;
}

const styles = StyleSheet.create({
  card: {
    backgroundColor: Colors.surface,
    borderRadius: Radius.lg,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: Colors.hairline,
    overflow: "hidden",
  },
  strong: {
    backgroundColor: Colors.surfaceStrong,
  },
  padded: {
    padding: Space.lg,
  },
  header: {
    flexDirection: "row",
    alignItems: "center",
    gap: 6,
    marginBottom: Space.md,
  },
  headerTitle: {
    flex: 1,
  },
  divider: {
    height: StyleSheet.hairlineWidth,
    backgroundColor: Colors.hairline,
  },
});
