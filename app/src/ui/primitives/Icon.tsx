import React from "react";
import { MaterialCommunityIcons } from "@expo/vector-icons";

import { Colors } from "../theme/tokens";

export type IconName = keyof typeof MaterialCommunityIcons.glyphMap;

interface IconProps {
  name: IconName;
  size?: number;
  color?: string;
  accessibilityLabel?: string;
}

/// One icon family app-wide (Material Community) keeps stroke weight and
/// metaphors consistent.
export function Icon({ name, size = 20, color = Colors.text, accessibilityLabel }: IconProps): React.ReactElement {
  return (
    <MaterialCommunityIcons
      name={name}
      size={size}
      color={color}
      accessibilityLabel={accessibilityLabel}
      accessibilityElementsHidden={accessibilityLabel === undefined}
      importantForAccessibility={accessibilityLabel === undefined ? "no-hide-descendants" : "auto"}
    />
  );
}
