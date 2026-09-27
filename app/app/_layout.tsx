import React from "react";
import { StyleSheet, View } from "react-native";
import { Stack } from "expo-router";
import { DarkTheme, ThemeProvider } from "@react-navigation/native";
import { StatusBar } from "expo-status-bar";
import { GestureHandlerRootView } from "react-native-gesture-handler";
import { SafeAreaProvider } from "react-native-safe-area-context";

import { useAgentContextSync, useAppReady, useSkyScene } from "../src/features/app/bootstrap";
import { useDeveloperOptionsStore } from "../src/features/settings/developerOptionsStore";
import { SkyBackground } from "../src/ui/shell/SkyBackground";
import { Colors, Icon } from "../src/ui";

/// Transparent navigation theme so the live sky shows through every screen.
const NAV_THEME = {
  ...DarkTheme,
  colors: { ...DarkTheme.colors, background: "transparent", card: Colors.canvas, primary: Colors.accent, text: Colors.text, border: Colors.hairline },
};

export default function RootLayout(): React.ReactElement {
  const ready = useAppReady();
  useAgentContextSync(ready);
  const scene = useSkyScene();
  const animationOff = useDeveloperOptionsStore((s) => s.enabled && s.disableAnimatedSky);

  return (
    <GestureHandlerRootView style={styles.root}>
      <SafeAreaProvider>
        <StatusBar style="light" />
        <SkyBackground scene={scene} animated={ready && !animationOff}>
          {ready ? (
            <ThemeProvider value={NAV_THEME}>
              <Stack
                screenOptions={{
                  headerShown: false,
                  contentStyle: { backgroundColor: "transparent" },
                  animation: "slide_from_right",
                }}
              >
                <Stack.Screen name="index" options={{ animation: "none" }} />
                <Stack.Screen name="(tabs)" options={{ animation: "fade" }} />
                <Stack.Screen name="onboarding/index" options={{ animation: "fade", gestureEnabled: false }} />
                <Stack.Screen name="locations" options={{ presentation: "modal", animation: "slide_from_bottom" }} />
                <Stack.Screen name="voice" options={{ presentation: "transparentModal", animation: "fade", gestureEnabled: false }} />
              </Stack>
            </ThemeProvider>
          ) : (
            <View style={styles.boot} accessibilityLabel="Loading WeatherGPT">
              <Icon name="weather-partly-cloudy" size={56} color={Colors.text} />
            </View>
          )}
        </SkyBackground>
      </SafeAreaProvider>
    </GestureHandlerRootView>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: Colors.canvas,
  },
  boot: {
    flex: 1,
    alignItems: "center",
    justifyContent: "center",
  },
});
