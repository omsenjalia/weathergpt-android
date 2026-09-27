/// Live particles over the sky: rain streaks, twinkling stars and lightning
/// flashes. Driven by a handful of looping native-driver animations, so the
/// cost stays flat regardless of how many screens sit on top.

import React, { useEffect, useMemo, useRef } from "react";
import { Animated, Easing, Platform, StyleSheet, useWindowDimensions, View } from "react-native";

import { SkyCondition, SkyPeriod } from "../../features/weather/theme/atmosphereTheme";

const nativeDriver = Platform.OS !== "web";

export function isNightPeriod(period: SkyPeriod): boolean {
  return period === SkyPeriod.Night || period === SkyPeriod.Midnight || period === SkyPeriod.Evening;
}

// Deterministic pseudo-random so layouts don't reshuffle on every render.
function seeded(n: number): () => number {
  let x = n;
  return () => {
    x = (x * 16807) % 2147483647;
    return (x - 1) / 2147483646;
  };
}

export function SkyParticles({ period, sky }: { period: SkyPeriod; sky: SkyCondition }): React.ReactElement | null {
  const rain = sky === SkyCondition.Rain || sky === SkyCondition.HeavyRain || sky === SkyCondition.Drizzle || sky === SkyCondition.Thunder;
  const stars = isNightPeriod(period) && (sky === SkyCondition.Clear || sky === SkyCondition.PartlyCloudy);
  if (!rain && !stars) return null;
  return (
    <View pointerEvents="none" style={StyleSheet.absoluteFill}>
      {stars && <Stars />}
      {rain && <Rain density={sky === SkyCondition.HeavyRain || sky === SkyCondition.Thunder ? 70 : sky === SkyCondition.Drizzle ? 28 : 48} />}
      {sky === SkyCondition.Thunder && <Lightning />}
    </View>
  );
}

function Rain({ density }: { density: number }): React.ReactElement {
  const { width, height } = useWindowDimensions();
  const drops = useMemo(() => {
    const rnd = seeded(7);
    return Array.from({ length: density }, () => ({
      x: rnd() * width,
      y: rnd() * height,
      len: 14 + rnd() * 22,
      opacity: 0.18 + rnd() * 0.3,
    }));
  }, [density, width, height]);
  // Two offset sheets fall continuously; the second covers the seam.
  const fall = useRef(new Animated.Value(0)).current;
  useEffect(() => {
    const loop = Animated.loop(Animated.timing(fall, { toValue: 1, duration: 900, easing: Easing.linear, useNativeDriver: nativeDriver }));
    loop.start();
    return () => loop.stop();
  }, [fall]);
  const translateY = fall.interpolate({ inputRange: [0, 1], outputRange: [-height, 0] });

  return (
    <Animated.View style={[styles.sheet, { height: height * 2, transform: [{ translateY }, { rotate: "8deg" }] }]}>
      {[0, height].map((offset) =>
        drops.map((d, i) => (
          <View key={`${offset}-${i}`} style={[styles.drop, { left: d.x, top: d.y + offset, height: d.len, opacity: d.opacity }]} />
        )),
      )}
    </Animated.View>
  );
}

function Stars(): React.ReactElement {
  const { width, height } = useWindowDimensions();
  const stars = useMemo(() => {
    const rnd = seeded(42);
    return Array.from({ length: 46 }, () => ({ x: rnd() * width, y: rnd() * height * 0.55, size: 1 + rnd() * 1.8, group: Math.floor(rnd() * 3) }));
  }, [width, height]);
  const twinkle = useRef([0, 1, 2].map(() => new Animated.Value(0.4))).current;
  useEffect(() => {
    const loops = twinkle.map((v, i) =>
      Animated.loop(
        Animated.sequence([
          Animated.delay(i * 700),
          Animated.timing(v, { toValue: 1, duration: 1600, useNativeDriver: nativeDriver }),
          Animated.timing(v, { toValue: 0.35, duration: 1600, useNativeDriver: nativeDriver }),
        ]),
      ),
    );
    loops.forEach((l) => l.start());
    return () => loops.forEach((l) => l.stop());
  }, [twinkle]);

  return (
    <>
      {twinkle.map((opacity, group) => (
        <Animated.View key={group} style={[StyleSheet.absoluteFill, { opacity }]}>
          {stars
            .filter((s) => s.group === group)
            .map((s, i) => (
              <View key={i} style={[styles.star, { left: s.x, top: s.y, width: s.size, height: s.size, borderRadius: s.size }]} />
            ))}
        </Animated.View>
      ))}
    </>
  );
}

function Lightning(): React.ReactElement {
  const flash = useRef(new Animated.Value(0)).current;
  useEffect(() => {
    const loop = Animated.loop(
      Animated.sequence([
        Animated.delay(5200),
        Animated.timing(flash, { toValue: 0.55, duration: 60, useNativeDriver: nativeDriver }),
        Animated.timing(flash, { toValue: 0.1, duration: 90, useNativeDriver: nativeDriver }),
        Animated.timing(flash, { toValue: 0.45, duration: 50, useNativeDriver: nativeDriver }),
        Animated.timing(flash, { toValue: 0, duration: 380, useNativeDriver: nativeDriver }),
      ]),
    );
    loop.start();
    return () => loop.stop();
  }, [flash]);
  return <Animated.View style={[StyleSheet.absoluteFill, styles.flash, { opacity: flash }]} />;
}

const styles = StyleSheet.create({
  sheet: {
    position: "absolute",
    left: -40,
    right: -40,
    top: 0,
  },
  drop: {
    position: "absolute",
    width: 1.2,
    borderRadius: 1,
    backgroundColor: "#DCEBFF",
  },
  star: {
    position: "absolute",
    backgroundColor: "#FFFFFF",
  },
  flash: {
    backgroundColor: "#E0E7FF",
  },
});
