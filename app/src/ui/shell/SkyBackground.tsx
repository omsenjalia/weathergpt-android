/// Static sky behind every screen, bottom to top:
///   1. palette gradient (time-of-day × weather)
///   2. horizon warmth at dawn/dusk and a soft sun/moon glow
///   3. a fixed readability veil so white copy stays legible on any sky
/// Nothing animates: the gradient only changes when the time or weather does.

import React from "react";
import { StyleSheet, View } from "react-native";
import { LinearGradient } from "expo-linear-gradient";
import Svg, { Defs, RadialGradient, Rect, Stop } from "react-native-svg";

import { SkyScene } from "../../features/weather/weatherStore";

interface SkyBackgroundProps {
  scene: SkyScene;
  children?: React.ReactNode;
}

export function SkyBackground({ scene, children }: SkyBackgroundProps): React.ReactElement {
  const { palette } = scene;
  const showOrb = (palette.showSun || palette.showMoon);
  const orbY = palette.showSun ? palette.sunY : palette.moonY;
  const orbColor = palette.showSun ? palette.orbEnd : palette.orbStart;

  return (
    <View style={[styles.root, { backgroundColor: palette.bottom }]}>
      <LinearGradient colors={[palette.top, palette.mid, palette.bottom]} locations={[0, 0.55, 1]} style={StyleSheet.absoluteFill} />

      {palette.horizonWarmth > 0 && (
        <LinearGradient
          pointerEvents="none"
          colors={["transparent", `rgba(251, 146, 60, ${0.3 * palette.horizonWarmth})`, `rgba(234, 88, 12, ${0.45 * palette.horizonWarmth})`]}
          style={styles.horizon}
        />
      )}

      {/* Ambient sun/moon light: a soft radial glow, not a solid disk, so it
          never reads as an object sitting behind translucent cards. */}
      {showOrb && orbY < 1.1 && (
        <Svg pointerEvents="none" style={StyleSheet.absoluteFill} width="100%" height="100%">
          <Defs>
            <RadialGradient id="sky-glow" cx="80%" cy={`${Math.round(orbY * 100)}%`} r="45%" fx="80%" fy={`${Math.round(orbY * 100)}%`}>
              <Stop offset="0" stopColor={orbColor} stopOpacity={0.35} />
              <Stop offset="1" stopColor={orbColor} stopOpacity={0} />
            </RadialGradient>
          </Defs>
          <Rect x="0" y="0" width="100%" height="100%" fill="url(#sky-glow)" />
        </Svg>
      )}

      <LinearGradient
        pointerEvents="none"
        colors={["rgba(4, 8, 18, 0.34)", "rgba(4, 8, 18, 0.14)", "rgba(4, 8, 18, 0.30)", "rgba(4, 8, 18, 0.66)"]}
        locations={[0, 0.28, 0.62, 1]}
        style={StyleSheet.absoluteFill}
      />
      <View style={StyleSheet.absoluteFill}>{children}</View>
    </View>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    overflow: "hidden",
  },
  horizon: {
    position: "absolute",
    left: 0,
    right: 0,
    bottom: 0,
    height: "55%",
  },
});
