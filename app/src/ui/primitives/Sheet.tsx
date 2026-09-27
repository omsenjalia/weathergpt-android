/// Bottom sheet: slides up over a dimmed backdrop, scrolls its content,
/// closes on backdrop tap, hardware back, or a downward swipe on the handle.

import React, { useEffect, useRef, useState } from "react";
import { Animated, Modal, PanResponder, Platform, Pressable, ScrollView, StyleSheet, useWindowDimensions, View } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";

import { Colors, Layout, Radius, Space } from "../theme/tokens";

interface SheetProps {
  visible: boolean;
  onClose: () => void;
  children: React.ReactNode;
  accessibilityLabel?: string;
}

const nativeDriver = Platform.OS !== "web";

export function Sheet({ visible, onClose, children, accessibilityLabel }: SheetProps): React.ReactElement | null {
  const { height } = useWindowDimensions();
  const insets = useSafeAreaInsets();
  const [mounted, setMounted] = useState(visible);
  const progress = useRef(new Animated.Value(0)).current;
  const drag = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    if (visible) {
      setMounted(true);
      drag.setValue(0);
      Animated.spring(progress, { toValue: 1, useNativeDriver: nativeDriver, damping: 22, stiffness: 220, mass: 0.9 }).start();
    } else if (mounted) {
      Animated.timing(progress, { toValue: 0, duration: 200, useNativeDriver: nativeDriver }).start(() => setMounted(false));
    }
  }, [visible, mounted, progress, drag]);

  const pan = useRef(
    PanResponder.create({
      onMoveShouldSetPanResponder: (_, g) => g.dy > 6 && Math.abs(g.dy) > Math.abs(g.dx),
      onPanResponderMove: (_, g) => drag.setValue(Math.max(0, g.dy)),
      onPanResponderRelease: (_, g) => {
        if (g.dy > 110 || g.vy > 1.1) onClose();
        else Animated.spring(drag, { toValue: 0, useNativeDriver: nativeDriver }).start();
      },
    }),
  ).current;

  if (!mounted) return null;

  const translateY = Animated.add(progress.interpolate({ inputRange: [0, 1], outputRange: [height, 0] }), drag);

  return (
    <Modal transparent visible animationType="none" onRequestClose={onClose} statusBarTranslucent>
      <Animated.View style={[StyleSheet.absoluteFill, styles.backdrop, { opacity: progress }]}>
        <Pressable style={StyleSheet.absoluteFill} onPress={onClose} accessibilityLabel="Close" accessibilityRole="button" />
      </Animated.View>
      <Animated.View pointerEvents="box-none" style={[styles.dock, { transform: [{ translateY }] }]}>
        <View
          accessibilityViewIsModal
          accessibilityLabel={accessibilityLabel}
          style={[styles.sheet, { maxHeight: height * 0.9, paddingBottom: insets.bottom + Space.lg }]}
        >
          <View {...pan.panHandlers} style={styles.handleArea}>
            <View style={styles.handle} />
          </View>
          <ScrollView contentContainerStyle={styles.content} showsVerticalScrollIndicator={false} bounces={false}>
            {children}
          </ScrollView>
        </View>
      </Animated.View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  backdrop: {
    backgroundColor: Colors.overlay,
  },
  dock: {
    position: "absolute",
    left: 0,
    right: 0,
    bottom: 0,
    alignItems: "center",
  },
  sheet: {
    width: "100%",
    maxWidth: Layout.maxContentWidth + Layout.gutter * 2,
    backgroundColor: "rgba(12, 19, 36, 0.98)",
    borderTopLeftRadius: Radius.xl,
    borderTopRightRadius: Radius.xl,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: Colors.hairlineStrong,
  },
  handleArea: {
    alignItems: "center",
    paddingVertical: Space.md,
  },
  handle: {
    width: 40,
    height: 4,
    borderRadius: 2,
    backgroundColor: Colors.hairlineStrong,
  },
  content: {
    paddingHorizontal: Layout.gutter,
    gap: Space.lg,
  },
});
