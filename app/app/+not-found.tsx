import React from "react";
import { StyleSheet, View } from "react-native";
import { router } from "expo-router";

import { Button, Screen, StateView } from "../src/ui";
import { useTranslation } from "../src/i18n/useTranslation";

export default function NotFoundScreen(): React.ReactElement {
  const t = useTranslation();
  return (
    <Screen>
      <View style={styles.center}>
        <StateView icon="map-search-outline" title={t("notfound.title")} body={t("notfound.body")} />
        <Button label={t("common.today")} icon="weather-partly-cloudy" onPress={() => router.replace("/home")} />
      </View>
    </Screen>
  );
}

const styles = StyleSheet.create({
  center: {
    minHeight: 520,
    justifyContent: "center",
    alignItems: "center",
  },
});
