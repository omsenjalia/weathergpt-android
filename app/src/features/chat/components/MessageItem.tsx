import React, { useMemo, useState } from "react";
import { StyleSheet, View } from "react-native";
import * as Clipboard from "expo-clipboard";

import { AppText, Colors, Icon, IconButton, Radius, Space, haptic } from "../../../ui";
import { RichText } from "../../../ui/content/RichText";
import { useTranslation } from "../../../i18n/useTranslation";
import { MarkdownUtils } from "../../../core/utils/markdownUtils";
import { ChatMessage } from "../chatStore";
import { useVoiceStore } from "../../voice/voiceStore";
import { voiceCardFromJson } from "../../voice/models/voiceCard";
import { InsightCard, insightFromCard, insightHasContent } from "./InsightCard";

/// User turns are right-aligned accent bubbles; assistant turns are
/// full-width prose (easier to read long answers and tables) with an avatar,
/// optional structured card and copy / read-aloud actions.
export const MessageItem = React.memo(function MessageItem({ message }: { message: ChatMessage }): React.ReactElement {
  const t = useTranslation();
  const [copied, setCopied] = useState(false);
  const insight = useMemo(() => {
    const card = message.role === "assistant" ? voiceCardFromJson(message.card) : null;
    const value = card === null ? null : insightFromCard(card);
    return value !== null && insightHasContent(value) ? value : null;
  }, [message]);

  if (message.role === "user") {
    return (
      <View style={styles.userRow}>
        <View style={styles.userBubble}>
          <AppText variant="body" color={Colors.onAccent} selectable>
            {message.content}
          </AppText>
        </View>
      </View>
    );
  }

  const copy = () => {
    void Clipboard.setStringAsync(message.content);
    haptic("success");
    setCopied(true);
    setTimeout(() => setCopied(false), 1600);
  };
  const speak = () => void useVoiceStore.getState().speak(MarkdownUtils.spokenSummary("", message.content));

  return (
    <View style={styles.assistantRow}>
      <View style={styles.avatar}>
        <Icon name="weather-partly-cloudy" size={16} color={Colors.onAccent} />
      </View>
      <View style={styles.assistantBody}>
        {insight !== null && <InsightCard insight={insight} />}
        <RichText content={message.content} />
        <View style={styles.actions}>
          <IconButton icon={copied ? "check" : "content-copy"} size={32} accessibilityLabel={copied ? t("chat.copied") : t("chat.copy")} onPress={copy} color={Colors.textTertiary} />
          <IconButton icon="volume-high" size={32} accessibilityLabel={t("chat.read_aloud")} onPress={speak} color={Colors.textTertiary} />
        </View>
      </View>
    </View>
  );
});

export function TypingIndicator({ label }: { label: string }): React.ReactElement {
  return (
    <View style={styles.assistantRow} accessibilityLiveRegion="polite" accessibilityLabel={label}>
      <View style={styles.avatar}>
        <Icon name="weather-partly-cloudy" size={16} color={Colors.onAccent} />
      </View>
      <View style={styles.typing}>
        <AppText variant="subhead" tone="secondary">
          {label}
        </AppText>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  userRow: {
    flexDirection: "row",
    justifyContent: "flex-end",
    paddingLeft: Space.huge,
  },
  userBubble: {
    backgroundColor: Colors.accent,
    borderRadius: Radius.lg,
    borderBottomRightRadius: Radius.xs,
    paddingHorizontal: Space.lg,
    paddingVertical: Space.md,
  },
  assistantRow: {
    flexDirection: "row",
    gap: Space.md,
  },
  avatar: {
    width: 28,
    height: 28,
    borderRadius: 14,
    backgroundColor: Colors.accent,
    alignItems: "center",
    justifyContent: "center",
    marginTop: 2,
  },
  assistantBody: {
    flex: 1,
    gap: Space.sm,
  },
  actions: {
    flexDirection: "row",
    gap: Space.xs,
    marginLeft: -Space.sm,
  },
  typing: {
    justifyContent: "center",
    minHeight: 28,
  },
});
