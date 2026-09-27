import React from "react";
import { StyleSheet, View } from "react-native";
import { router } from "expo-router";
import Constants from "expo-constants";

import { AppText, Button, Card, ChipGroup, Colors, Divider, Icon, IconName, ListRow, Radius, Screen, Section, SegmentedControl, Space, SwitchRow, Touchable } from "../../src/ui";
import { useTranslation } from "../../src/i18n/useTranslation";
import { LANGUAGE_META, LanguageCode, SUPPORTED_LANGUAGES } from "../../src/i18n";
import { TemperatureUnit, useSettingsStore } from "../../src/features/settings/settingsStore";
import { DEV_SOURCE_PIN_LABEL, DevSourcePin, useDeveloperOptionsStore } from "../../src/features/settings/developerOptionsStore";
import { useSavedLocationsStore } from "../../src/features/explore/exploreStores";
import { useVoiceStore, VoiceStatus } from "../../src/features/voice/voiceStore";

const PERSONAS: ReadonlyArray<{ id: "everyone" | "farmer" | "researcher"; icon: IconName; color: string }> = [
  { id: "everyone", icon: "account-outline", color: Colors.accent },
  { id: "farmer", icon: "sprout", color: Colors.farmer },
  { id: "researcher", icon: "flask-outline", color: Colors.researcher },
];

const SPEEDS = { slow: 0.6, normal: 0.85, fast: 1 } as const;
type Speed = keyof typeof SPEEDS;

function speedFor(value: number): Speed {
  if (value <= 0.7) return "slow";
  if (value >= 0.95) return "fast";
  return "normal";
}

export default function SettingsScreen(): React.ReactElement {
  const t = useTranslation();
  const language = useSettingsStore((s) => s.language);
  const persona = useSettingsStore((s) => s.userPersona);
  const units = useSettingsStore((s) => s.units);
  const ttsSpeed = useSettingsStore((s) => s.ttsSpeed);
  const savedCount = useSavedLocationsStore((s) => s.locations.length);
  const devEnabled = useDeveloperOptionsStore((s) => s.enabled);
  const sourcePin = useDeveloperOptionsStore((s) => s.sourcePin);
  const showProvenance = useDeveloperOptionsStore((s) => s.showProvenanceOnHome);
  const animationOff = useDeveloperOptionsStore((s) => s.disableAnimatedSky);
  const previewing = useVoiceStore((s) => s.status === VoiceStatus.Speaking);
  const settings = useSettingsStore.getState;
  const dev = useDeveloperOptionsStore.getState;

  return (
    <Screen inTabs title={t("settings.title")}>
      <Section title={t("settings.user_type")}>
        <Card padded={false}>
          {PERSONAS.map((p, i) => {
            const selected = persona === p.id;
            return (
              <View key={p.id}>
                {i > 0 && <Divider inset={Space.lg + 44} />}
                <Touchable
                  scale={false}
                  haptics="selection"
                  accessibilityRole="radio"
                  accessibilityState={{ checked: selected }}
                  accessibilityLabel={t(`persona.${p.id}`)}
                  onPress={() => void settings().updatePersona(p.id)}
                  style={styles.persona}
                >
                  <View style={[styles.personaIcon, { backgroundColor: `${p.color}22` }]}>
                    <Icon name={p.icon} size={20} color={p.color} />
                  </View>
                  <View style={styles.flex}>
                    <AppText variant="callout">{t(`persona.${p.id}`)}</AppText>
                    <AppText variant="footnote" tone="tertiary">
                      {t(`persona.${p.id}_description`)}
                    </AppText>
                  </View>
                  <Icon name={selected ? "check-circle" : "circle-outline"} size={22} color={selected ? Colors.accent : Colors.textTertiary} />
                </Touchable>
              </View>
            );
          })}
        </Card>
        {persona === "farmer" && (
          <Card padded={false}>
            <View style={styles.rowPad}>
              <ListRow icon="sprout-outline" iconColor={Colors.farmer} label={t("farmer.edit_farm_profile")} onPress={() => router.push("/farm-profile")} />
            </View>
          </Card>
        )}
      </Section>

      <Section title={t("settings.language")}>
        <Card>
          <ChipGroup<LanguageCode>
            options={SUPPORTED_LANGUAGES}
            value={language}
            onChange={(code) => void settings().updateLanguage(code)}
            labelFor={(code) => LANGUAGE_META[code].native}
          />
        </Card>
      </Section>

      <Section title={t("settings.units")}>
        <Card padded={false}>
          <View style={styles.rowPad}>
            <SwitchRow
              icon="thermometer"
              label={t("settings.use_fahrenheit")}
              description={units === TemperatureUnit.Fahrenheit ? "°F" : "°C"}
              value={units === TemperatureUnit.Fahrenheit}
              onValueChange={(v) => void settings().updateUnits(v ? TemperatureUnit.Fahrenheit : TemperatureUnit.Celsius)}
            />
          </View>
        </Card>
      </Section>

      <Section title={t("settings.voice_title")} footer={t("settings.voice_engine_device")}>
        <Card style={styles.gap}>
          <AppText variant="callout">{t("voice_picker.title")}</AppText>
          <View style={styles.voiceRow}>
            <Button
              label={previewing ? t("voice_picker.stop") : t("voice_picker.preview")}
              icon={previewing ? "stop" : "play"}
              variant="secondary"
              onPress={() => (previewing ? useVoiceStore.getState().stopSpeaking() : void useVoiceStore.getState().speak(t("voice_picker.sample")))}
            />
          </View>
          <Divider />
          <AppText variant="callout">{t("settings.tts_speed")}</AppText>
          <SegmentedControl<Speed>
            value={speedFor(ttsSpeed)}
            onChange={(s) => void settings().updateTtsSpeed(SPEEDS[s])}
            segments={[
              { value: "slow", label: t("settings.speed_slow") },
              { value: "normal", label: t("settings.speed_normal") },
              { value: "fast", label: t("settings.speed_fast") },
            ]}
          />
        </Card>
      </Section>

      <Section title={t("settings.section_data")}>
        <Card padded={false}>
          <View style={styles.rowPad}>
            <ListRow icon="star-outline" label={t("settings.saved_locations")} value={String(savedCount)} onPress={() => router.push("/locations")} />
          </View>
          <Divider inset={Space.lg + 44} />
          <View style={styles.rowPad}>
            <ListRow icon="map-outline" label={t("settings.open_map")} onPress={() => router.navigate("/explore")} />
          </View>
        </Card>
      </Section>

      <Section title="Developer">
        <Card padded={false}>
          <View style={styles.rowPad}>
            <SwitchRow icon="code-braces" label="Developer mode" description="Provider pinning, request log and diagnostics" value={devEnabled} onValueChange={(v) => void dev().patch({ enabled: v })} />
          </View>
          {devEnabled && (
            <>
              <Divider inset={Space.lg + 44} />
              <View style={styles.rowPad}>
                <SwitchRow icon="source-branch" label="Show provenance on Home" value={showProvenance} onValueChange={(v) => void dev().patch({ showProvenanceOnHome: v })} />
              </View>
              <Divider inset={Space.lg + 44} />
              <View style={styles.rowPad}>
                <SwitchRow icon="motion-pause-outline" label="Disable animated sky" description="Gradient-only background" value={animationOff} onValueChange={(v) => void dev().patch({ disableAnimatedSky: v })} />
              </View>
              <Divider inset={Space.lg} />
              <View style={styles.devBlock}>
                <AppText variant="footnote" tone="secondary">
                  Source · {DEV_SOURCE_PIN_LABEL[sourcePin]}
                </AppText>
                <ChipGroup<DevSourcePin> layout="scroll" options={Object.values(DevSourcePin)} value={sourcePin} onChange={(pin) => void dev().patch({ sourcePin: pin })} />
              </View>
              <Divider inset={Space.lg + 44} />
              <View style={styles.rowPad}>
                <ListRow icon="bug-outline" label="Debug & state" onPress={() => router.push("/debug")} />
              </View>
            </>
          )}
        </Card>
      </Section>

      <View style={styles.footer}>
        <AppText variant="caption" tone="tertiary" align="center">
          {t("app_name")} {Constants.expoConfig?.version ?? ""}
        </AppText>
        <AppText variant="caption" tone="tertiary" align="center">
          {t("settings.footer")}
        </AppText>
      </View>
    </Screen>
  );
}

const styles = StyleSheet.create({
  flex: {
    flex: 1,
  },
  gap: {
    gap: Space.md,
  },
  rowPad: {
    paddingHorizontal: Space.lg,
  },
  persona: {
    flexDirection: "row",
    alignItems: "center",
    gap: Space.md,
    paddingHorizontal: Space.lg,
    paddingVertical: Space.md,
    minHeight: 64,
  },
  personaIcon: {
    width: 32,
    height: 32,
    borderRadius: Radius.sm,
    alignItems: "center",
    justifyContent: "center",
  },
  voiceRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: Space.sm,
  },
  devBlock: {
    padding: Space.lg,
    gap: Space.sm,
  },
  footer: {
    paddingTop: Space.xl,
    gap: 2,
  },
});
