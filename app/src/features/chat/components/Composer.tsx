/// Chat composer, voice-first: an empty composer shows a large mic that
/// dictates straight into the conversation; typing swaps it for Send. While
/// listening the composer becomes a live transcript with a stop control.

import React, { useState } from "react";
import { StyleSheet, TextInput, View } from "react-native";

import { AppText, Colors, FontFamily, IconButton, Radius, Space, Touchable, VoiceOrb } from "../../../ui";
import { useVoiceStore, VoiceStatus } from "../../voice/voiceStore";

interface ComposerProps {
  placeholder: string;
  sending: boolean;
  onSend: (text: string, viaVoice: boolean) => void;
  labels: { mic: string; send: string; listening: string; stop: string; processing: string };
}

export function Composer({ placeholder, sending, onSend, labels }: ComposerProps): React.ReactElement {
  const [draft, setDraft] = useState("");
  const status = useVoiceStore((s) => s.status);
  const transcript = useVoiceStore((s) => s.transcript);
  const errorMessage = useVoiceStore((s) => s.errorMessage);
  const canSend = draft.trim() !== "" && !sending;
  const listening = status === VoiceStatus.Listening;
  const processing = status === VoiceStatus.Processing;

  const submit = () => {
    if (!canSend) return;
    onSend(draft.trim(), false);
    setDraft("");
  };

  const dictate = () => void useVoiceStore.getState().startDictation((text) => onSend(text, true));

  if (listening || processing) {
    return (
      <View style={[styles.box, styles.listening]} accessibilityLiveRegion="polite">
        <VoiceOrb size={44} state={listening ? "listening" : "thinking"} ambient={false} accessibilityLabel={labels.stop} onPress={() => void useVoiceStore.getState().stopListening()} />
        <View style={styles.flex}>
          <AppText variant="footnote" tone="accent">
            {listening ? labels.listening : labels.processing}
          </AppText>
          <AppText variant="body" tone={transcript === "" ? "tertiary" : "primary"} numberOfLines={3}>
            {transcript === "" ? "…" : transcript}
          </AppText>
        </View>
        <Touchable onPress={() => useVoiceStore.getState().cancel()} accessibilityLabel={labels.stop} style={styles.stop}>
          <AppText variant="footnote" tone="secondary">
            {labels.stop}
          </AppText>
        </Touchable>
      </View>
    );
  }

  return (
    <View style={styles.wrap}>
      {status === VoiceStatus.Error && errorMessage !== null && (
        <AppText variant="footnote" tone="danger" style={styles.error}>
          {errorMessage}
        </AppText>
      )}
      <View style={styles.row}>
        <View style={[styles.box, styles.flex]}>
          <TextInput
            value={draft}
            onChangeText={setDraft}
            placeholder={placeholder}
            placeholderTextColor={Colors.textTertiary}
            selectionColor={Colors.accent}
            style={styles.input}
            multiline
            // Start at one line (web textareas default to two rows); grows to maxHeight.
            numberOfLines={1}
            maxLength={2000}
            accessibilityLabel={placeholder}
            onSubmitEditing={submit}
            blurOnSubmit={false}
            submitBehavior="submit"
            returnKeyType="send"
          />
          {canSend && <IconButton icon="arrow-up" variant="accent" size={36} accessibilityLabel={labels.send} onPress={submit} />}
        </View>
        {!canSend && <VoiceOrb size={52} ambient={false} accessibilityLabel={labels.mic} onPress={dictate} />}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  flex: {
    flex: 1,
  },
  wrap: {
    paddingTop: Space.sm,
    gap: Space.xs,
  },
  row: {
    flexDirection: "row",
    alignItems: "flex-end",
    gap: Space.sm,
  },
  box: {
    flexDirection: "row",
    alignItems: "flex-end",
    gap: Space.sm,
    minHeight: 52,
    paddingLeft: Space.lg,
    paddingRight: 8,
    paddingVertical: 8,
    borderRadius: Radius.xl,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: Colors.hairlineStrong,
    backgroundColor: "rgba(8, 13, 26, 0.86)",
  },
  listening: {
    alignItems: "center",
    paddingLeft: 8,
    marginTop: Space.sm,
    borderColor: Colors.accent,
  },
  stop: {
    paddingHorizontal: Space.md,
    minHeight: 44,
    justifyContent: "center",
  },
  error: {
    paddingHorizontal: Space.sm,
  },
  input: {
    flex: 1,
    minHeight: 36,
    maxHeight: 132,
    paddingTop: 8,
    paddingBottom: 8,
    color: Colors.text,
    fontFamily: FontFamily.medium,
    fontSize: 15,
    lineHeight: 20,
    outlineStyle: "none",
  } as never,
});
