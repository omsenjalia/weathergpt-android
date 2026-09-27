import React from "react";
import { ScrollView, StyleSheet, View } from "react-native";
import { router } from "expo-router";

import { AppText, Card, Colors, Icon, Radius, Space, Touchable, VoiceOrb } from "../../../ui";
import { useTranslation } from "../../../i18n/useTranslation";
import { AppMode } from "../../../core/models/appMode";

/// Voice-first entry to the assistant: a large mic that opens voice mode,
/// persona-specific spoken questions, and a quieter path to typed chat.
export function AskCard({ mode }: { mode: AppMode }): React.ReactElement {
  const t = useTranslation();
  const prefix = mode === "farmer" ? "home.farmer" : mode === "researcher" ? "home.researcher" : "home.everyone";
  const prompts = [1, 2, 3].map((n) => t(`${prefix}_prompt_${n}`));

  return (
    <Card style={styles.card}>
      <View style={styles.top}>
        <VoiceOrb size={76} accessibilityLabel={t("chat.voice")} onPress={() => router.push("/voice")} />
        <View style={styles.flex}>
          <AppText variant="headline">{t("chat.voice")}</AppText>
          <AppText variant="subhead" tone="secondary">
            {t(`${prefix}_hint`)}
          </AppText>
        </View>
      </View>
      <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.prompts}>
        {prompts.map((prompt) => (
          <Touchable
            key={prompt}
            onPress={() => router.push({ pathname: "/voice", params: { q: prompt } })}
            haptics="selection"
            accessibilityLabel={prompt}
            style={styles.prompt}
          >
            <Icon name="volume-high" size={15} color={Colors.accentText} />
            <AppText variant="footnote" numberOfLines={1}>
              {prompt}
            </AppText>
          </Touchable>
        ))}
      </ScrollView>
      <Touchable onPress={() => router.navigate("/chat")} scale={false} accessibilityLabel={t("home.ask_something_else")} style={styles.typeRow}>
        <Icon name="keyboard-outline" size={18} color={Colors.textTertiary} />
        <AppText variant="footnote" tone="tertiary" style={styles.flex}>
          {t("home.ask_something_else")}
        </AppText>
        <Icon name="chevron-right" size={18} color={Colors.textTertiary} />
      </Touchable>
    </Card>
  );
}

const styles = StyleSheet.create({
  card: {
    gap: Space.lg,
  },
  flex: {
    flex: 1,
  },
  top: {
    flexDirection: "row",
    alignItems: "center",
    gap: Space.lg,
  },
  prompts: {
    gap: Space.sm,
  },
  prompt: {
    flexDirection: "row",
    alignItems: "center",
    gap: 6,
    minHeight: 40,
    paddingHorizontal: 14,
    borderRadius: Radius.pill,
    backgroundColor: Colors.surfaceInset,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: Colors.hairlineStrong,
  },
  typeRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: Space.sm,
    minHeight: 40,
    paddingHorizontal: Space.md,
    borderRadius: Radius.md,
    backgroundColor: "rgba(255, 255, 255, 0.04)",
  },
});
