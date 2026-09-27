/// The voice button. A glossy accent orb with a breathing halo when idle and
/// expanding rings while listening. Used at several sizes (tab bar, Home,
/// the full-screen voice mode) so voice always looks like the same control.

import React, { useEffect, useRef } from "react";
import { Animated, Easing, Platform, StyleSheet, View } from "react-native";
import { LinearGradient } from "expo-linear-gradient";

import { Icon, IconName } from "./Icon";
import { Touchable } from "./Touchable";
import { Colors } from "../theme/tokens";

export type OrbState = "idle" | "listening" | "thinking" | "speaking" | "error";

interface VoiceOrbProps {
  size?: number;
  state?: OrbState;
  onPress?: () => void;
  accessibilityLabel: string;
  /// Show the halo/rings. Off inside dense chrome such as the tab bar.
  ambient?: boolean;
}

const nativeDriver = Platform.OS !== "web";

const ICON: Record<OrbState, IconName> = {
  idle: "microphone",
  listening: "microphone",
  thinking: "dots-horizontal",
  speaking: "volume-high",
  error: "microphone-off",
};

export function VoiceOrb({ size = 72, state = "idle", onPress, accessibilityLabel, ambient = true }: VoiceOrbProps): React.ReactElement {
  const breathe = useRef(new Animated.Value(0)).current;
  const rings = useRef([0, 1, 2].map(() => new Animated.Value(0))).current;
  const active = state === "listening" || state === "speaking";

  useEffect(() => {
    if (!ambient) return;
    const loop = Animated.loop(
      Animated.sequence([
        Animated.timing(breathe, { toValue: 1, duration: 1300, easing: Easing.inOut(Easing.quad), useNativeDriver: nativeDriver }),
        Animated.timing(breathe, { toValue: 0, duration: 1300, easing: Easing.inOut(Easing.quad), useNativeDriver: nativeDriver }),
      ]),
    );
    loop.start();
    return () => loop.stop();
  }, [ambient, breathe]);

  useEffect(() => {
    if (!ambient || !active) {
      rings.forEach((r) => r.setValue(0));
      return;
    }
    const loops = rings.map((r, i) =>
      Animated.loop(
        Animated.sequence([
          Animated.delay(i * 450),
          Animated.timing(r, { toValue: 1, duration: 1350, easing: Easing.out(Easing.quad), useNativeDriver: nativeDriver }),
          Animated.timing(r, { toValue: 0, duration: 0, useNativeDriver: nativeDriver }),
        ]),
      ),
    );
    loops.forEach((l) => l.start());
    return () => loops.forEach((l) => l.stop());
  }, [ambient, active, rings]);

  const colors: [string, string] = state === "error" ? ["#FCA5A5", Colors.danger] : ["#99F6E4", Colors.accent];
  const haloScale = breathe.interpolate({ inputRange: [0, 1], outputRange: [1.05, 1.25] });
  const haloOpacity = breathe.interpolate({ inputRange: [0, 1], outputRange: [0.18, 0.32] });

  return (
    <View style={{ width: size, height: size, alignItems: "center", justifyContent: "center" }}>
      {ambient &&
        rings.map((r, i) => (
          <Animated.View
            key={i}
            pointerEvents="none"
            style={[
              styles.ring,
              {
                width: size,
                height: size,
                borderRadius: size / 2,
                borderColor: colors[1],
                opacity: r.interpolate({ inputRange: [0, 1], outputRange: [0.55, 0] }),
                transform: [{ scale: r.interpolate({ inputRange: [0, 1], outputRange: [1, 2.1] }) }],
              },
            ]}
          />
        ))}
      {ambient && (
        <Animated.View
          pointerEvents="none"
          style={[styles.ring, { width: size, height: size, borderRadius: size / 2, backgroundColor: colors[1], borderWidth: 0, opacity: haloOpacity, transform: [{ scale: haloScale }] }]}
        />
      )}
      <Touchable onPress={onPress} haptics="light" accessibilityLabel={accessibilityLabel} style={{ borderRadius: size / 2 }}>
        <LinearGradient colors={colors} start={{ x: 0.15, y: 0 }} end={{ x: 0.85, y: 1 }} style={[styles.orb, { width: size, height: size, borderRadius: size / 2 }]}>
          <Icon name={ICON[state]} size={Math.round(size * 0.42)} color={Colors.onAccent} />
        </LinearGradient>
      </Touchable>
    </View>
  );
}

const styles = StyleSheet.create({
  ring: {
    position: "absolute",
    borderWidth: 2,
  },
  orb: {
    alignItems: "center",
    justifyContent: "center",
    shadowColor: Colors.accent,
    shadowOpacity: 0.45,
    shadowRadius: 18,
    shadowOffset: { width: 0, height: 6 },
    elevation: 10,
  },
});
