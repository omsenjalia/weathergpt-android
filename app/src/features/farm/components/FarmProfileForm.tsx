/// Farm profile form shared by onboarding and the profile editor. Option
/// values are wire values (sent verbatim to /advisory and /chat), so they are
/// displayed as-is rather than translated.

import React, { useState } from "react";
import { StyleSheet, View } from "react-native";

import { AppText, Button, Card, ChipGroup, Colors, Space, TextField } from "../../../ui";
import { useTranslation } from "../../../i18n/useTranslation";
import { FarmProfile } from "../models/farmProfile";
import { FARM_CROPS, GROWTH_STAGES, IRRIGATION_TYPES, SOIL_TYPES, withCurrentOption } from "../models/farmOptions";
import { useFarmProfileStore } from "../farmStores";
import { useLocationStore } from "../../location/locationStore";

interface FarmProfileFormProps {
  initial: FarmProfile;
  submitLabel: string;
  onSaved: () => void;
  /// Rendered under the primary button (e.g. "Skip for now").
  secondaryAction?: React.ReactNode;
}

export function FarmProfileForm({ initial, submitLabel, onSaved, secondaryAction }: FarmProfileFormProps): React.ReactElement {
  const t = useTranslation();
  const [draft, setDraft] = useState<FarmProfile>(initial);
  const [sizeText, setSizeText] = useState(initial.farmSizeAcres > 0 ? String(initial.farmSizeAcres) : "");
  const [touched, setTouched] = useState(false);
  const [saving, setSaving] = useState(false);
  const [locating, setLocating] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);

  const size = Number(sizeText.replace(",", "."));
  const locationError = touched && draft.location.trim() === "" ? t("farmer.invalid_details") : null;
  const sizeError = touched && !(Number.isFinite(size) && size > 0) ? t("farmer.invalid_details") : null;

  const set = <K extends keyof FarmProfile>(key: K, value: FarmProfile[K]) => setDraft((d) => ({ ...d, [key]: value }));

  const useGps = async () => {
    setLocating(true);
    const loc = await useLocationStore.getState().selectFromGps();
    setLocating(false);
    if (loc !== null) set("location", loc.name);
    else setSaveError(t("location.not_available"));
  };

  const save = async () => {
    setTouched(true);
    setSaveError(null);
    if (draft.location.trim() === "" || !(Number.isFinite(size) && size > 0)) return;
    setSaving(true);
    try {
      await useFarmProfileStore.getState().save({ ...draft, farmSizeAcres: size });
      onSaved();
    } catch (error) {
      setSaveError(error instanceof Error ? error.message : t("voice.error"));
    } finally {
      setSaving(false);
    }
  };

  return (
    <View style={styles.root}>
      <Card style={styles.gap}>
        <TextField
          label={t("farmer.location")}
          placeholder={t("onboarding.farm_location_hint")}
          leadingIcon="map-marker-outline"
          value={draft.location}
          onChangeText={(v) => set("location", v)}
          error={locationError}
          autoCapitalize="words"
          returnKeyType="next"
        />
        <Button label={t("home.use_my_location")} icon="crosshairs-gps" variant="secondary" loading={locating} onPress={() => void useGps()} style={styles.gpsButton} />
        <TextField
          label={`${t("farmer.farm_size")} (${t("farmer.acres")})`}
          placeholder={t("onboarding.farm_size_hint")}
          leadingIcon="ruler-square"
          value={sizeText}
          onChangeText={setSizeText}
          keyboardType="decimal-pad"
          error={sizeError}
        />
      </Card>

      <Card style={styles.gap}>
        <Group label={t("farmer.crop")}>
          <ChipGroup options={withCurrentOption(FARM_CROPS, draft.crop)} value={draft.crop} onChange={(v) => set("crop", v)} accent={Colors.farmer} />
        </Group>
        <Group label={t("farmer.growth_stage")}>
          <ChipGroup options={withCurrentOption(GROWTH_STAGES, draft.growthStage)} value={draft.growthStage} onChange={(v) => set("growthStage", v)} accent={Colors.farmer} />
        </Group>
        <Group label={t("farmer.irrigation_type")}>
          <ChipGroup options={withCurrentOption(IRRIGATION_TYPES, draft.irrigationType)} value={draft.irrigationType} onChange={(v) => set("irrigationType", v)} accent={Colors.farmer} />
        </Group>
        <Group label={t("farmer.soil_type")}>
          <ChipGroup options={withCurrentOption(SOIL_TYPES, draft.soilType)} value={draft.soilType} onChange={(v) => set("soilType", v)} accent={Colors.farmer} />
        </Group>
      </Card>

      {saveError !== null && (
        <AppText variant="footnote" tone="danger" align="center" accessibilityLiveRegion="polite">
          {saveError}
        </AppText>
      )}
      <Button label={submitLabel} size="lg" fullWidth loading={saving} onPress={() => void save()} />
      {secondaryAction}
    </View>
  );
}

function Group({ label, children }: { label: string; children: React.ReactNode }): React.ReactElement {
  return (
    <View style={styles.group}>
      <AppText variant="footnote" tone="secondary">
        {label}
      </AppText>
      {children}
    </View>
  );
}

const styles = StyleSheet.create({
  root: {
    gap: Space.md,
  },
  gap: {
    gap: Space.lg,
  },
  gpsButton: {
    alignSelf: "flex-start",
    marginTop: -Space.sm,
  },
  group: {
    gap: Space.sm,
  },
});
