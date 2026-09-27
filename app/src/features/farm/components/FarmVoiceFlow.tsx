/// Farm profile by voice — port of the Flutter `farm_voice_screen` /
/// `farm_voice_provider`. Six spoken questions in the user's language; each
/// answer can be spoken (parsed with the multilingual voice parser) or
/// tapped. Ends on a review list that saves through the same store as the
/// typed form.

import React, { useEffect, useRef, useState } from "react";
import { StyleSheet, View } from "react-native";

import { AppText, Button, Card, Chip, Colors, Divider, Icon, ListRow, Radius, Space, Touchable, VoiceOrb, haptic } from "../../../ui";
import { createTranslator, LANGUAGE_META, LanguageCode } from "../../../i18n";
import { useVoiceStore, VoiceStatus } from "../../voice/voiceStore";
import { useLocationStore } from "../../location/locationStore";
import { useFarmProfileStore } from "../farmStores";
import { DEFAULT_FARM_PROFILE, FarmProfile } from "../models/farmProfile";
import { FARM_CROPS, GROWTH_STAGES, IRRIGATION_TYPES, SOIL_TYPES } from "../models/farmOptions";
import {
  formatVoiceFarmSize,
  normalizeVoiceInput,
  parseVoiceCrop,
  parseVoiceFarmSize,
  parseVoiceGrowthStage,
  parseVoiceIrrigation,
  parseVoiceSoil,
} from "../models/farmVoiceParser";

type Field = "location" | "crop" | "growthStage" | "farmSize" | "irrigation" | "soil";

interface Step {
  field: Field;
  question: string;
  label: string;
  chips: readonly string[] | null;
  parse: (input: string) => string | null;
}

const STEPS: readonly Step[] = [
  { field: "location", question: "farm.voice_q_location", label: "farmer.location", chips: null, parse: (s) => (normalizeVoiceInput(s) === "" ? null : s.trim()) },
  { field: "crop", question: "farm.voice_q_crop", label: "farmer.crop", chips: FARM_CROPS, parse: parseVoiceCrop },
  { field: "growthStage", question: "farm.voice_q_stage", label: "farmer.growth_stage", chips: GROWTH_STAGES, parse: parseVoiceGrowthStage },
  { field: "farmSize", question: "farm.voice_q_size", label: "farmer.farm_size", chips: ["1", "2", "4", "5", "10"], parse: (s) => { const v = parseVoiceFarmSize(s); return v === null ? null : formatVoiceFarmSize(v); } },
  { field: "irrigation", question: "farm.voice_q_irrigation", label: "farmer.irrigation_type", chips: IRRIGATION_TYPES, parse: parseVoiceIrrigation },
  { field: "soil", question: "farm.voice_q_soil", label: "farmer.soil_type", chips: SOIL_TYPES, parse: parseVoiceSoil },
];

interface FarmVoiceFlowProps {
  language: LanguageCode;
  initial?: FarmProfile;
  onSaved: () => void;
  onTypeInstead: () => void;
}

export function FarmVoiceFlow({ language, initial, onSaved, onTypeInstead }: FarmVoiceFlowProps): React.ReactElement {
  const t = createTranslator(language);
  const status = useVoiceStore((s) => s.status);
  const transcript = useVoiceStore((s) => s.transcript);
  const [step, setStep] = useState(0);
  const [values, setValues] = useState<Partial<Record<Field, string>>>({});
  const [heard, setHeard] = useState<string | null>(null);
  const [retry, setRetry] = useState(false);
  const [saving, setSaving] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);
  const advance = useRef<ReturnType<typeof setTimeout> | null>(null);
  const review = step >= STEPS.length;
  const current = STEPS[Math.min(step, STEPS.length - 1)]!;

  // Speak and listen in the onboarding language, not the (not yet saved) app language.
  useEffect(() => {
    const voice = useVoiceStore.getState();
    voice.setContext({ ...voice.context, language, ttsVoiceLocale: LANGUAGE_META[language].ttsLocale });
    return () => {
      if (advance.current) clearTimeout(advance.current);
      useVoiceStore.getState().cancel();
    };
  }, [language]);

  // Ask each question aloud when it appears.
  useEffect(() => {
    setHeard(null);
    setRetry(false);
    void useVoiceStore.getState().speak(review ? t("farm.voice_review_title") : t(current.question));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [step]);

  const goto = (next: number) => {
    if (advance.current) clearTimeout(advance.current);
    useVoiceStore.getState().cancel();
    setStep(Math.max(0, Math.min(next, STEPS.length)));
  };

  const accept = (value: string) => {
    haptic("success");
    setValues((v) => ({ ...v, [current.field]: value }));
    setHeard(value);
    setRetry(false);
    if (advance.current) clearTimeout(advance.current);
    const at = step;
    advance.current = setTimeout(() => setStep((s) => (s === at ? s + 1 : s)), 1100);
  };

  const listen = () => {
    const voice = useVoiceStore.getState();
    if (voice.status === VoiceStatus.Listening) {
      void voice.stopListening();
      return;
    }
    setRetry(false);
    void voice.startDictation((text) => {
      const parsed = current.parse(text);
      if (parsed === null) setRetry(true);
      else accept(parsed);
    });
  };

  const useGps = async () => {
    const place = await useLocationStore.getState().selectFromGps();
    if (place !== null) accept(place.name);
  };

  const draft = (): FarmProfile => {
    const base = initial ?? DEFAULT_FARM_PROFILE;
    const size = Number(values.farmSize);
    return {
      location: values.location ?? base.location,
      crop: values.crop ?? base.crop,
      growthStage: values.growthStage ?? base.growthStage,
      farmSizeAcres: Number.isFinite(size) && size > 0 ? size : base.farmSizeAcres,
      irrigationType: values.irrigation ?? base.irrigationType,
      soilType: values.soil ?? base.soilType,
    };
  };

  const save = async () => {
    setSaving(true);
    setSaveError(null);
    try {
      await useFarmProfileStore.getState().save(draft());
      onSaved();
    } catch (error) {
      setSaveError(error instanceof Error ? error.message : t("farmer.invalid_details"));
    } finally {
      setSaving(false);
    }
  };

  if (review) {
    const profile = draft();
    const shown: Record<Field, string> = {
      location: profile.location || "—",
      crop: profile.crop,
      growthStage: profile.growthStage,
      farmSize: `${formatVoiceFarmSize(profile.farmSizeAcres)} ${t("farmer.acres")}`,
      irrigation: profile.irrigationType,
      soil: profile.soilType,
    };
    return (
      <View style={styles.root}>
        <AppText variant="title">{t("farm.voice_review_title")}</AppText>
        <Card padded={false}>
          {STEPS.map((s, i) => (
            <View key={s.field}>
              {i > 0 && <Divider inset={Space.lg} />}
              <View style={styles.rowPad}>
                <ListRow label={t(s.label)} value={shown[s.field]} onPress={() => goto(i)} />
              </View>
            </View>
          ))}
        </Card>
        {saveError !== null && (
          <AppText variant="footnote" tone="danger" align="center">
            {saveError}
          </AppText>
        )}
        <Button label={t("farm.voice_save")} icon="check" size="lg" fullWidth loading={saving} onPress={() => void save()} />
        <Button label={t("farm.voice_start_over")} variant="ghost" onPress={() => { setValues({}); goto(0); }} />
      </View>
    );
  }

  const listening = status === VoiceStatus.Listening;
  return (
    <View style={styles.root}>
      <View style={styles.progressRow}>
        <AppText variant="footnote" tone="secondary" style={styles.flex}>
          {t("farm.voice_step_of", { step: step + 1, total: STEPS.length })}
        </AppText>
        <Touchable onPress={() => void useVoiceStore.getState().speak(t(current.question))} accessibilityLabel={t("farm.voice_repeat")} style={styles.repeat}>
          <Icon name="replay" size={16} color={Colors.accentText} />
          <AppText variant="footnote" tone="accent">
            {t("farm.voice_repeat")}
          </AppText>
        </Touchable>
      </View>
      <View style={styles.progress}>
        {STEPS.map((s, i) => (
          <View key={s.field} style={[styles.progressDot, i <= step && styles.progressDone]} />
        ))}
      </View>

      <AppText variant="largeTitle" accessibilityLiveRegion="polite">
        {t(current.question)}
      </AppText>

      <View style={styles.micArea}>
        <VoiceOrb
          size={104}
          state={listening ? "listening" : status === VoiceStatus.Processing ? "thinking" : status === VoiceStatus.Speaking ? "speaking" : "idle"}
          onPress={listen}
          accessibilityLabel={t("farm.voice_tap_to_speak")}
        />
        <AppText variant="headline" align="center" tone={heard !== null ? "accent" : transcript !== "" ? "primary" : "secondary"}>
          {heard !== null ? `✓ ${t("farm.voice_heard")}: ${heard}` : listening ? transcript || t("farm.voice_listening") : t("farm.voice_tap_to_speak")}
        </AppText>
        {retry && (
          <AppText variant="subhead" tone="danger" align="center">
            {t("farm.voice_not_caught")}
          </AppText>
        )}
      </View>

      {current.field === "location" ? (
        <Button label={t("farm.voice_use_my_location")} icon="crosshairs-gps" variant="secondary" onPress={() => void useGps()} />
      ) : (
        <View style={styles.chips}>
          {(current.chips ?? []).map((option) => (
            <Chip key={option} label={option} selected={values[current.field] === option} accent={Colors.farmer} onPress={() => accept(option)} />
          ))}
        </View>
      )}

      <View style={styles.nav}>
        <Button label={t("onboarding.back")} icon="chevron-left" variant="ghost" disabled={step === 0} onPress={() => goto(step - 1)} />
        <Button label={t("farm.voice_type_instead")} icon="keyboard-outline" variant="ghost" onPress={() => { useVoiceStore.getState().cancel(); onTypeInstead(); }} />
        <Button label={t("farm.voice_skip")} variant="ghost" onPress={() => goto(step + 1)} />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  root: {
    gap: Space.lg,
  },
  flex: {
    flex: 1,
  },
  rowPad: {
    paddingHorizontal: Space.lg,
  },
  progressRow: {
    flexDirection: "row",
    alignItems: "center",
  },
  repeat: {
    flexDirection: "row",
    alignItems: "center",
    gap: 4,
    minHeight: 36,
    paddingHorizontal: Space.sm,
  },
  progress: {
    flexDirection: "row",
    gap: 6,
  },
  progressDot: {
    flex: 1,
    height: 4,
    borderRadius: 2,
    backgroundColor: Colors.hairlineStrong,
  },
  progressDone: {
    backgroundColor: Colors.farmer,
  },
  micArea: {
    alignItems: "center",
    gap: Space.lg,
    paddingVertical: Space.xl,
  },
  chips: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: Space.sm,
  },
  nav: {
    flexDirection: "row",
    justifyContent: "space-between",
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: Colors.hairline,
    paddingTop: Space.sm,
    borderRadius: Radius.xs,
  },
});
