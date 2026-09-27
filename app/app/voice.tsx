import React, { useEffect, useRef } from "react";
import { ScrollView, StyleSheet, View } from "react-native";
import { router, useLocalSearchParams } from "expo-router";
import { useSafeAreaInsets } from "react-native-safe-area-context";

import { AppText, Button, Colors, IconButton, Layout, OrbState, Radius, Space, Touchable, VoiceOrb } from "../src/ui";
import { RichText } from "../src/ui/content/RichText";
import { useTranslation } from "../src/i18n/useTranslation";
import { useVoiceStore, VoiceStatus } from "../src/features/voice/voiceStore";
import { useSettingsStore, selectMode } from "../src/features/settings/settingsStore";
import { MarkdownUtils } from "../src/core/utils/markdownUtils";
import { InsightCard } from "../src/features/chat/components/InsightCard";

/// Full-screen voice assistant: listen → live transcript → answer, read
/// aloud. Opened from the mic in the tab bar, Home and Chat.
export default function VoiceScreen(): React.ReactElement {
  const t = useTranslation();
  const insets = useSafeAreaInsets();
  const { q } = useLocalSearchParams<{ q?: string }>();
  const status = useVoiceStore((s) => s.status);
  const transcript = useVoiceStore((s) => s.transcript);
  const response = useVoiceStore((s) => s.response);
  const errorMessage = useVoiceStore((s) => s.errorMessage);
  const spokenFor = useRef<unknown>(null);

  useEffect(() => {
    const voice = useVoiceStore.getState();
    if (typeof q === "string" && q.trim() !== "") void voice.submitQuery(q);
    else void voice.startListening();
    return () => useVoiceStore.getState().cancel();
  }, [q]);

  // Read each new answer aloud once.
  useEffect(() => {
    if (response === null || spokenFor.current === response) return;
    spokenFor.current = response;
    void useVoiceStore.getState().speak(MarkdownUtils.spokenSummary("", response.explanation));
  }, [response]);

  const close = () => {
    useVoiceStore.getState().cancel();
    if (router.canGoBack()) router.back();
    else router.replace("/home");
  };
  const askAgain = () => {
    spokenFor.current = null;
    void useVoiceStore.getState().startListening();
  };

  const hasAnswer = response !== null && (status === VoiceStatus.Done || status === VoiceStatus.Speaking);
  const orbState: OrbState =
    status === VoiceStatus.Listening
      ? "listening"
      : status === VoiceStatus.Processing
        ? "thinking"
        : status === VoiceStatus.Speaking
          ? "speaking"
          : status === VoiceStatus.Error
            ? "error"
            : "idle";

  return (
    <View style={[styles.root, { paddingTop: insets.top + Space.sm, paddingBottom: insets.bottom + Space.lg }]}>
      <View style={styles.topBar}>
        <IconButton icon="close" variant="filled" accessibilityLabel={t("location.cancel")} onPress={close} />
        <AppText variant="headline" style={styles.flex} align="center">
          {hasAnswer ? t("voice.result_title") : t("chat.voice")}
        </AppText>
        <View style={styles.topSpacer} />
      </View>

      {hasAnswer ? (
        <>
          <ScrollView style={styles.flex} contentContainerStyle={styles.answer}>
            {response.transcript.trim() !== "" && (
              <View style={styles.question}>
                <AppText variant="body" color={Colors.onAccent}>
                  {response.transcript}
                </AppText>
              </View>
            )}
            <View style={styles.answerCard}>
              {(response.stats.length > 0 || response.forecast.length > 0) && (
                <InsightCard insight={{ label: response.label, verdict: response.verdict, accent: response.accent, stats: response.stats, forecast: response.forecast, confidence: null, source: null }} />
              )}
              <RichText content={response.explanation.trim() === "" ? response.verdict : response.explanation} />
            </View>
          </ScrollView>
          <View style={styles.actions}>
            <Button
              label={status === VoiceStatus.Speaking ? t("voice_picker.stop") : t("chat.read_aloud")}
              icon={status === VoiceStatus.Speaking ? "stop" : "volume-high"}
              variant="secondary"
              onPress={() =>
                status === VoiceStatus.Speaking
                  ? useVoiceStore.getState().stopSpeaking()
                  : void useVoiceStore.getState().speak(MarkdownUtils.spokenSummary("", response.explanation))
              }
              style={styles.flex}
            />
            <VoiceOrb size={64} state={orbState === "speaking" ? "speaking" : "idle"} onPress={askAgain} accessibilityLabel={t("voice.ask_again")} ambient={false} />
            <Button label={t("nav.chat")} icon="chat-outline" variant="secondary" onPress={() => { useVoiceStore.getState().cancel(); router.replace("/chat"); }} style={styles.flex} />
          </View>
        </>
      ) : (
        <>
          <View style={styles.center}>
            <VoiceOrb
              size={112}
              state={orbState}
              onPress={() => (status === VoiceStatus.Listening ? void useVoiceStore.getState().stopListening() : askAgain())}
              accessibilityLabel={status === VoiceStatus.Listening ? t("voice.done_speaking") : t("chat.voice")}
            />
            <AppText variant="title" align="center" style={styles.status} accessibilityLiveRegion="polite">
              {status === VoiceStatus.Error
                ? t("voice.error")
                : status === VoiceStatus.Processing
                  ? t("voice.finding_answer")
                  : status === VoiceStatus.Listening
                    ? t("voice.listening")
                    : t("voice.speak_now")}
            </AppText>
            <AppText variant="title" tone={transcript === "" ? "tertiary" : "primary"} align="center" style={styles.transcript}>
              {status === VoiceStatus.Error ? errorMessage ?? "" : transcript === "" ? t("voice.hint") : `“${transcript}”`}
            </AppText>
          </View>

          <View style={styles.footer}>
            {status === VoiceStatus.Listening && <Button label={t("voice.done_speaking")} variant="secondary" size="lg" fullWidth onPress={() => void useVoiceStore.getState().stopListening()} />}
            {(status === VoiceStatus.Error || status === VoiceStatus.Idle) && (
              <>
                <Suggestions />
                <Button label={t("voice.try_again")} icon="microphone" size="lg" fullWidth onPress={askAgain} />
              </>
            )}
          </View>
        </>
      )}
    </View>
  );
}

/// Tappable example questions — a typed path when speech is unavailable.
function Suggestions(): React.ReactElement {
  const t = useTranslation();
  const mode = useSettingsStore(selectMode);
  const prefix = mode === "farmer" ? "home.farmer" : mode === "researcher" ? "home.researcher" : "home.everyone";
  return (
    <View style={styles.suggestions}>
      {[1, 2, 3].map((n) => {
        const prompt = t(`${prefix}_prompt_${n}`);
        return (
          <Touchable key={n} haptics="selection" onPress={() => void useVoiceStore.getState().submitQuery(prompt)} accessibilityLabel={prompt} style={styles.suggestion}>
            <AppText variant="callout" numberOfLines={1}>
              {prompt}
            </AppText>
          </Touchable>
        );
      })}
    </View>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: "rgba(4, 8, 18, 0.9)",
  },
  flex: {
    flex: 1,
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
  center: {
    flex: 1,
    alignItems: "center",
    justifyContent: "center",
    paddingHorizontal: Layout.gutter,
    gap: Space.lg,
  },
  status: {
    marginTop: Space.xxl,
  },
  transcript: {
    maxWidth: 520,
    fontSize: 24,
    lineHeight: 32,
  },
  footer: {
    paddingHorizontal: Layout.gutter,
    gap: Space.md,
    width: "100%",
    maxWidth: Layout.maxContentWidth,
    alignSelf: "center",
  },
  suggestions: {
    gap: Space.sm,
  },
  suggestion: {
    minHeight: 48,
    justifyContent: "center",
    paddingHorizontal: Space.lg,
    borderRadius: Radius.md,
    backgroundColor: Colors.surface,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: Colors.hairline,
  },
  answer: {
    paddingHorizontal: Layout.gutter,
    paddingTop: Space.lg,
    gap: Space.md,
    width: "100%",
    maxWidth: Layout.maxContentWidth,
    alignSelf: "center",
  },
  question: {
    alignSelf: "flex-end",
    maxWidth: "85%",
    backgroundColor: Colors.accent,
    borderRadius: Radius.lg,
    borderBottomRightRadius: Radius.xs,
    paddingHorizontal: Space.lg,
    paddingVertical: Space.md,
  },
  answerCard: {
    gap: Space.md,
    padding: Space.lg,
    borderRadius: Radius.lg,
    backgroundColor: Colors.surfaceStrong,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: Colors.hairline,
  },
  actions: {
    flexDirection: "row",
    alignItems: "center",
    gap: Space.md,
    paddingHorizontal: Layout.gutter,
    paddingTop: Space.md,
    width: "100%",
    maxWidth: Layout.maxContentWidth,
    alignSelf: "center",
  },
});
