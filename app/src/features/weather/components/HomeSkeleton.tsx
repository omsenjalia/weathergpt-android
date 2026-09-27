import React from "react";
import { StyleSheet, View } from "react-native";

import { Card, Skeleton, Space } from "../../../ui";

/// Placeholder shaped like the Home layout so nothing jumps when data lands.
export function HomeSkeleton(): React.ReactElement {
  return (
    <View style={styles.root} accessibilityLabel="Loading weather" accessibilityRole="progressbar">
      <View style={styles.hero}>
        <Skeleton width={140} height={18} />
        <Skeleton width={150} height={88} radius={20} style={styles.gapLg} />
        <Skeleton width={120} height={22} />
        <Skeleton width={180} height={14} />
      </View>
      <Card style={styles.card}>
        <Skeleton width={110} height={12} />
        <View style={styles.row}>
          {Array.from({ length: 6 }, (_, i) => (
            <View key={i} style={styles.hour}>
              <Skeleton width={28} height={10} />
              <Skeleton width={26} height={26} radius={13} />
              <Skeleton width={30} height={14} />
            </View>
          ))}
        </View>
      </Card>
      <Card style={styles.card}>
        <Skeleton width={110} height={12} />
        {Array.from({ length: 5 }, (_, i) => (
          <Skeleton key={i} height={16} style={styles.gapSm} />
        ))}
      </Card>
    </View>
  );
}

const styles = StyleSheet.create({
  root: {
    gap: Space.md,
  },
  hero: {
    alignItems: "center",
    gap: Space.md,
    paddingVertical: Space.xxl,
  },
  gapLg: {
    marginVertical: Space.sm,
  },
  gapSm: {
    marginTop: Space.md,
  },
  card: {
    gap: Space.md,
  },
  row: {
    flexDirection: "row",
    justifyContent: "space-between",
  },
  hour: {
    alignItems: "center",
    gap: Space.sm,
  },
});
