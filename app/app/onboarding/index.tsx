import React, { useState } from "react";
import { ScrollView, StyleSheet, View } from "react-native";
import { router } from "expo-router";
import { useSafeAreaInsets } from "react-native-safe-area-context";

import { AppText, Button, Colors, Icon, IconButton, IconName, Layout, Radius, Space, Touchable, textStyles } from "../../src/ui";
import { createTranslator, LANGUAGE_META, LanguageCode, SUPPORTED_LANGUAGES } from "../../src/i18n";
import { useOnboardingStore } from "../../src/features/onboarding/onboardingStore";
import { useLocationStore } from "../../src/features/location/locationStore";
import { DEFAULT_FARM_PROFILE } from "../../src/features/farm/models/farmProfile";
import { FarmProfileForm } from "../../src/features/farm/components/FarmProfileForm";
import { FarmVoiceFlow } from "../../src/features/farm/components/FarmVoiceFlow";

type Step = "welcome" | "language" | "persona" | "farm";

const PERSONAS: ReadonlyArray<{ id: "everyone" | "farmer" | "researcher"; icon: IconName; color: string }> = [
  { id: "everyone", icon: "account-outline", color: Colors.accent },
  { id: "farmer", icon: "sprout", color: Colors.farmer },
  { id: "researcher", icon: "flask-outline", color: Colors.researcher },
];

export default function OnboardingScreen(): React.ReactElement {
  const insets = useSafeAreaInsets();
  const [step, setStep] = useState<Step>("welcome");
  const [finishing, setFinishing] = useState(false);
  const [farmMode, setFarmMode] = useState<"choose" | "voice" | "form">("choose");
  const language = useOnboardingStore((s) => s.selectedLanguage);
  const persona = useOnboardingStore((s) => s.selectedPersona);
  // Render in the language being chosen, before settings are persisted.
  const t = createTranslator(language);

  const steps: Step[] = persona === "farmer" ? ["welcome", "language", "persona", "farm"] : ["welcome", "language", "persona"];
  const index = steps.indexOf(step);

  const finish = async () => {
    setFinishing(true);
    await useOnboardingStore.getState().completeOnboarding();
    void useLocationStore.getState().maybeAutoLocate();
    router.replace("/home");
  };

  const next = () => {
    if (step === "persona" && persona !== "farmer") void finish();
    else setStep(steps[index + 1]!);
  };

  if (step === "welcome") {
    return (
      <View style={[styles.root, { paddingTop: insets.top, paddingBottom: insets.bottom + Space.xl }]}>
        <View style={styles.welcome}>
          <View style={styles.logo}>
            <Icon name="weather-partly-cloudy" size={44} color={Colors.onAccent} />
          </View>
          <AppText variant="largeTitle" align="center" style={[styles.brand, textStyles.shadow]}>
            {t("common.weather_gpt")}
          </AppText>
          <AppText variant="headline" tone="secondary" align="center" style={textStyles.shadow}>
            {t("onboarding.splash_tagline")}
          </AppText>
        </View>
        <View style={styles.footer}>
          <Button label={t("onboarding.continue")} size="lg" fullWidth onPress={next} />
          <AppText variant="footnote" tone="tertiary" align="center">
            {t("onboarding.splash_footer")}
          </AppText>
        </View>
      </View>
    );
  }

  return (
    <View style={[styles.root, { paddingTop: insets.top + Space.sm }]}>
      <View style={styles.topBar}>
        <IconButton icon="chevron-left" variant="filled" accessibilityLabel={t("onboarding.back")} onPress={() => {
            if (step === "farm" && farmMode !== "choose") setFarmMode("choose");
            else setStep(steps[Math.max(0, index - 1)]!);
          }} />
        <Progress current={index} total={steps.length - 1} />
        <View style={styles.topSpacer} />
      </View>

      <ScrollView style={styles.flex} contentContainerStyle={[styles.content, { paddingBottom: step === "farm" ? insets.bottom + Space.xxxl : Space.xl }]} keyboardShouldPersistTaps="handled">
        {step === "language" && (
          <>
            <Heading title={t("onboarding.choose_language")} hint={t("onboarding.language_hint")} />
            <View style={styles.grid}>
              {SUPPORTED_LANGUAGES.map((code: LanguageCode) => (
                <OptionCard
                  key={code}
                  selected={language === code}
                  title={LANGUAGE_META[code].native}
                  subtitle={LANGUAGE_META[code].english}
                  onPress={() => useOnboardingStore.getState().selectLanguage(code)}
                  half
                />
              ))}
            </View>
          </>
        )}

        {step === "persona" && (
          <>
            <Heading title={t("onboarding.focus_headline")} hint={t("onboarding.focus_hint")} />
            <View style={styles.list}>
              {PERSONAS.map((p) => (
                <OptionCard
                  key={p.id}
                  selected={persona === p.id}
                  icon={p.icon}
                  iconColor={p.color}
                  title={t(`persona.${p.id}`)}
                  subtitle={t(`persona.${p.id}_description`)}
                  onPress={() => useOnboardingStore.getState().selectPersona(p.id)}
                />
              ))}
            </View>
          </>
        )}

        {step === "farm" && farmMode === "choose" && (
          <>
            <Heading title={t("onboarding.farm_choice_title")} hint={t("onboarding.farm_choice_subtitle")} />
            <View style={styles.list}>
              <OptionCard action selected={false} icon="microphone" iconColor={Colors.accent} title={t("onboarding.farm_choice_talk")} subtitle={t("onboarding.farm_choice_talk_desc")} onPress={() => setFarmMode("voice")} />
              <OptionCard action selected={false} icon="keyboard-outline" iconColor={Colors.farmer} title={t("onboarding.farm_choice_type")} subtitle={t("onboarding.farm_choice_type_desc")} onPress={() => setFarmMode("form")} />
            </View>
            <Button label={t("onboarding.skip_for_now")} variant="ghost" onPress={() => void finish()} />
          </>
        )}

        {step === "farm" && farmMode === "voice" && (
          <FarmVoiceFlow language={language} onSaved={() => void finish()} onTypeInstead={() => setFarmMode("form")} />
        )}

        {step === "farm" && farmMode === "form" && (
          <>
            <Heading title={t("onboarding.farm_headline")} hint={t("onboarding.farm_hint")} />
            <FarmProfileForm
              initial={{ ...DEFAULT_FARM_PROFILE, location: "", farmSizeAcres: 0 }}
              submitLabel={t("onboarding.continue")}
              onSaved={() => void finish()}
              secondaryAction={<Button label={t("onboarding.skip_for_now")} variant="ghost" onPress={() => void finish()} />}
            />
          </>
        )}
      </ScrollView>

      {step !== "farm" && (
        <View style={[styles.footer, styles.pinned, { paddingBottom: insets.bottom + Space.lg }]}>
          <Button label={t("onboarding.continue")} size="lg" fullWidth loading={finishing} onPress={next} />
        </View>
      )}
    </View>
  );
}

function Heading({ title, hint }: { title: string; hint: string }): React.ReactElement {
  return (
    <View style={styles.heading}>
      <AppText variant="largeTitle" accessibilityRole="header">
        {title}
      </AppText>
      <AppText variant="body" tone="secondary">
        {hint}
      </AppText>
    </View>
  );
}

function Progress({ current, total }: { current: number; total: number }): React.ReactElement {
  return (
    <View style={styles.progress} accessibilityRole="progressbar" accessibilityValue={{ min: 0, max: total, now: current }}>
      {Array.from({ length: total }, (_, i) => (
        <View key={i} style={[styles.progressDot, i < current && styles.progressDone]} />
      ))}
    </View>
  );
}

interface OptionCardProps {
  selected: boolean;
  title: string;
  subtitle?: string;
  icon?: IconName;
  iconColor?: string;
  onPress: () => void;
  half?: boolean;
  /// Navigational choice: shows a chevron instead of a radio circle.
  action?: boolean;
}

function OptionCard({ selected, title, subtitle, icon, iconColor = Colors.accent, onPress, half = false, action = false }: OptionCardProps): React.ReactElement {
  return (
    <Touchable
      haptics="selection"
      accessibilityRole={action ? "button" : "radio"}
      accessibilityState={action ? undefined : { checked: selected }}
      accessibilityLabel={subtitle ? `${title}, ${subtitle}` : title}
      onPress={onPress}
      style={[styles.option, half && styles.half, selected && styles.optionSelected]}
    >
      {icon !== undefined && (
        <View style={[styles.optionIcon, { backgroundColor: `${iconColor}22` }]}>
          <Icon name={icon} size={22} color={iconColor} />
        </View>
      )}
      <View style={styles.flex}>
        <AppText variant="headline" numberOfLines={1}>
          {title}
        </AppText>
        {subtitle !== undefined && (
          <AppText variant="footnote" tone="secondary" numberOfLines={2}>
            {subtitle}
          </AppText>
        )}
      </View>
      <Icon name={action ? "chevron-right" : selected ? "check-circle" : "circle-outline"} size={22} color={selected ? Colors.accent : Colors.textTertiary} />
    </Touchable>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
  },
  flex: {
    flex: 1,
  },
  welcome: {
    flex: 1,
    alignItems: "center",
    justifyContent: "center",
    paddingHorizontal: Layout.gutter,
    gap: Space.md,
  },
  logo: {
    width: 88,
    height: 88,
    borderRadius: 28,
    backgroundColor: Colors.accent,
    alignItems: "center",
    justifyContent: "center",
    marginBottom: Space.md,
  },
  brand: {
    fontSize: 40,
    lineHeight: 46,
  },
  footer: {
    paddingHorizontal: Layout.gutter,
    gap: Space.md,
    width: "100%",
    maxWidth: Layout.maxContentWidth,
    alignSelf: "center",
  },
  pinned: {
    paddingTop: Space.md,
  },
  topBar: {
    flexDirection: "row",
    alignItems: "center",
    paddingHorizontal: Layout.gutter,
    gap: Space.md,
  },
  topSpacer: {
    width: 40,
  },
  progress: {
    flex: 1,
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
    backgroundColor: Colors.accent,
  },
  content: {
    paddingHorizontal: Layout.gutter,
    paddingTop: Space.xl,
    gap: Space.xl,
    width: "100%",
    maxWidth: Layout.maxContentWidth,
    alignSelf: "center",
  },
  heading: {
    gap: Space.sm,
  },
  grid: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: Space.md,
  },
  list: {
    gap: Space.md,
  },
  option: {
    flexDirection: "row",
    alignItems: "center",
    gap: Space.md,
    minHeight: 64,
    padding: Space.lg,
    borderRadius: Radius.lg,
    borderWidth: 1.5,
    borderColor: Colors.hairline,
    backgroundColor: Colors.surface,
  },
  half: {
    flexBasis: "46%",
    flexGrow: 1,
  },
  optionSelected: {
    borderColor: Colors.accent,
    backgroundColor: Colors.accentSoft,
  },
  optionIcon: {
    width: 44,
    height: 44,
    borderRadius: 14,
    alignItems: "center",
    justifyContent: "center",
  },
});
