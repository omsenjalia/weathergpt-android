/// One-tap "turn on location" bar, shown while Home is still on the default
/// city. Port of the Flutter `_LocationPromptBar`: if the OS can no longer
/// show its dialog (denied earlier), it explains and offers system settings.

import React, { useEffect, useState } from "react";
import { Linking, StyleSheet, View } from "react-native";

import { AppText, Button, Colors, Icon, IconButton, Radius, Space } from "../../../ui";
import { useTranslation } from "../../../i18n/useTranslation";
import { loadJson, saveJson, StorageKeys } from "../../../lib/persistence";
import { DEFAULT_LOCATION, useLocationStore } from "../locationStore";

export function LocationPromptBar(): React.ReactElement | null {
  const t = useTranslation();
  const location = useLocationStore((s) => s.location);
  const [dismissed, setDismissed] = useState(true);
  const [busy, setBusy] = useState(false);
  const [blocked, setBlocked] = useState(false);

  useEffect(() => {
    void loadJson<boolean | null>(StorageKeys.locationBannerDismissed).then((v) => setDismissed(v === true));
  }, []);

  if (dismissed || location.name !== DEFAULT_LOCATION.name) return null;

  const dismiss = () => {
    setDismissed(true);
    void saveJson(StorageKeys.locationBannerDismissed, true);
  };

  const enable = async () => {
    setBusy(true);
    const store = useLocationStore.getState();
    const place = await store.selectFromGps();
    setBusy(false);
    if (place === null) setBlocked(!(await store.canAskOs()));
  };

  return (
    <View style={styles.bar} accessibilityRole="alert">
      <Icon name={blocked ? "map-marker-off-outline" : "map-marker-radius-outline"} size={20} color={Colors.caution} />
      <View style={styles.flex}>
        <AppText variant="callout">{blocked ? t("location.settings_title") : t("location.banner")}</AppText>
        {blocked && (
          <AppText variant="footnote" tone="secondary">
            {t("location.settings_body")}
          </AppText>
        )}
      </View>
      {blocked ? (
        <Button label={t("location.open_settings")} onPress={() => void Linking.openSettings()} />
      ) : (
        <Button label={t("location.enable")} loading={busy} onPress={() => void enable()} />
      )}
      <IconButton icon="close" size={32} accessibilityLabel={t("location.cancel")} onPress={dismiss} color={Colors.textSecondary} />
    </View>
  );
}

const styles = StyleSheet.create({
  flex: {
    flex: 1,
  },
  bar: {
    flexDirection: "row",
    alignItems: "center",
    gap: Space.md,
    paddingLeft: Space.lg,
    paddingRight: Space.xs,
    paddingVertical: Space.sm,
    borderRadius: Radius.lg,
    borderWidth: 1,
    borderColor: "rgba(251, 191, 36, 0.4)",
    backgroundColor: Colors.surfaceStrong,
  },
});
