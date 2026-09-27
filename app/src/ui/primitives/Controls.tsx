/// Selection controls: segmented control, selectable chips, switch row.

import React from "react";
import { ScrollView, StyleSheet, Switch, View } from "react-native";

import { AppText } from "./AppText";
import { Icon, IconName } from "./Icon";
import { Touchable } from "./Touchable";
import { Colors, Layout, Radius, Space } from "../theme/tokens";

// ---------------------------------------------------------------------------
// Segmented control

export interface Segment<T extends string> {
  value: T;
  label: string;
}

interface SegmentedControlProps<T extends string> {
  segments: readonly Segment<T>[];
  value: T;
  onChange: (value: T) => void;
  accessibilityLabel?: string;
}

export function SegmentedControl<T extends string>({ segments, value, onChange, accessibilityLabel }: SegmentedControlProps<T>): React.ReactElement {
  return (
    <View style={styles.segmented} accessibilityRole="tablist" accessibilityLabel={accessibilityLabel}>
      {segments.map((segment) => {
        const selected = segment.value === value;
        return (
          <Touchable
            key={segment.value}
            scale={false}
            haptics={selected ? "none" : "selection"}
            onPress={() => onChange(segment.value)}
            accessibilityRole="tab"
            accessibilityState={{ selected }}
            accessibilityLabel={segment.label}
            style={[styles.segment, selected && styles.segmentSelected]}
          >
            <AppText variant="footnote" tone={selected ? "inverse" : "secondary"} numberOfLines={1}>
              {segment.label}
            </AppText>
          </Touchable>
        );
      })}
    </View>
  );
}

// ---------------------------------------------------------------------------
// Chips

interface ChipProps {
  label: string;
  selected?: boolean;
  onPress?: () => void;
  icon?: IconName;
  accent?: string;
}

export function Chip({ label, selected = false, onPress, icon, accent = Colors.accent }: ChipProps): React.ReactElement {
  return (
    <Touchable
      onPress={onPress}
      haptics="selection"
      accessibilityRole={onPress !== undefined ? "button" : "text"}
      accessibilityState={{ selected }}
      accessibilityLabel={label}
      style={[styles.chip, selected && { backgroundColor: accent, borderColor: accent }]}
    >
      {icon !== undefined && <Icon name={icon} size={15} color={selected ? Colors.onAccent : Colors.textSecondary} />}
      <AppText variant="footnote" color={selected ? Colors.onAccent : Colors.text} numberOfLines={1}>
        {label}
      </AppText>
    </Touchable>
  );
}

interface ChipGroupProps<T extends string> {
  options: readonly T[];
  value: T | null;
  onChange: (value: T) => void;
  labelFor?: (value: T) => string;
  /// Wrap onto multiple lines (forms) or scroll horizontally (toolbars).
  layout?: "wrap" | "scroll";
  accent?: string;
}

export function ChipGroup<T extends string>({ options, value, onChange, labelFor, layout = "wrap", accent }: ChipGroupProps<T>): React.ReactElement {
  const chips = options.map((option) => (
    <Chip key={option} label={labelFor ? labelFor(option) : option} selected={option === value} onPress={() => onChange(option)} accent={accent} />
  ));
  if (layout === "scroll") {
    return (
      <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.chipScroll}>
        {chips}
      </ScrollView>
    );
  }
  return <View style={styles.chipWrap}>{chips}</View>;
}

// ---------------------------------------------------------------------------
// Switch row

interface SwitchRowProps {
  label: string;
  description?: string;
  value: boolean;
  onValueChange: (value: boolean) => void;
  icon?: IconName;
}

export function SwitchRow({ label, description, value, onValueChange, icon }: SwitchRowProps): React.ReactElement {
  return (
    <View style={styles.switchRow}>
      {icon !== undefined && <RowIcon name={icon} />}
      <View style={styles.flex}>
        <AppText variant="callout">{label}</AppText>
        {description !== undefined && (
          <AppText variant="footnote" tone="tertiary">
            {description}
          </AppText>
        )}
      </View>
      <Switch
        value={value}
        onValueChange={onValueChange}
        accessibilityLabel={label}
        trackColor={{ true: Colors.accent, false: Colors.hairlineStrong }}
        thumbColor={Colors.text}
        ios_backgroundColor={Colors.hairlineStrong}
      />
    </View>
  );
}

// ---------------------------------------------------------------------------
// List row

interface ListRowProps {
  label: string;
  value?: string;
  description?: string;
  icon?: IconName;
  iconColor?: string;
  onPress?: () => void;
  destructive?: boolean;
  trailing?: React.ReactNode;
}

export function ListRow({ label, value, description, icon, iconColor, onPress, destructive, trailing }: ListRowProps): React.ReactElement {
  const body = (
    <>
      {icon !== undefined && <RowIcon name={icon} color={iconColor} />}
      <View style={styles.flex}>
        <AppText variant="callout" tone={destructive ? "danger" : "primary"} numberOfLines={1}>
          {label}
        </AppText>
        {description !== undefined && (
          <AppText variant="footnote" tone="tertiary" numberOfLines={2}>
            {description}
          </AppText>
        )}
      </View>
      {value !== undefined && (
        <AppText variant="subhead" tone="secondary" numberOfLines={1} style={styles.rowValue}>
          {value}
        </AppText>
      )}
      {trailing}
      {onPress !== undefined && <Icon name="chevron-right" size={20} color={Colors.textTertiary} />}
    </>
  );
  if (onPress === undefined) return <View style={styles.listRow}>{body}</View>;
  return (
    <Touchable scale={false} onPress={onPress} accessibilityLabel={value ? `${label}, ${value}` : label} style={styles.listRow}>
      {body}
    </Touchable>
  );
}

function RowIcon({ name, color = Colors.accentText }: { name: IconName; color?: string }): React.ReactElement {
  return (
    <View style={styles.rowIcon}>
      <Icon name={name} size={18} color={color} />
    </View>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1 },
  segmented: {
    flexDirection: "row",
    padding: 3,
    borderRadius: Radius.pill,
    backgroundColor: Colors.surface,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: Colors.hairline,
  },
  segment: {
    flex: 1,
    minHeight: 36,
    borderRadius: Radius.pill,
    alignItems: "center",
    justifyContent: "center",
    paddingHorizontal: Space.sm,
  },
  segmentSelected: {
    backgroundColor: Colors.text,
  },
  chip: {
    flexDirection: "row",
    alignItems: "center",
    gap: 6,
    minHeight: 36,
    paddingHorizontal: 14,
    borderRadius: Radius.pill,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: Colors.hairlineStrong,
    backgroundColor: Colors.surfaceInset,
  },
  chipWrap: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: Space.sm,
  },
  chipScroll: {
    gap: Space.sm,
    paddingRight: Space.lg,
  },
  switchRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: Space.md,
    minHeight: Layout.minTouch + 8,
    paddingVertical: Space.sm,
  },
  listRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: Space.md,
    minHeight: Layout.minTouch + 8,
    paddingVertical: Space.sm,
  },
  rowValue: {
    maxWidth: "45%",
  },
  rowIcon: {
    width: 32,
    height: 32,
    borderRadius: Radius.sm,
    backgroundColor: Colors.surfaceInset,
    alignItems: "center",
    justifyContent: "center",
  },
});
