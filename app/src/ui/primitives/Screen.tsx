/// Screen scaffold: safe-area aware, large-title header, consistent gutters,
/// max content width on tablets/web, and clearance for the floating tab bar.

import React from "react";
import { KeyboardAvoidingView, Platform, RefreshControlProps, ScrollView, StyleProp, StyleSheet, View, ViewStyle } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { router } from "expo-router";

import { AppText } from "./AppText";
import { IconButton } from "./Button";
import { Layout, Space } from "../theme/tokens";

interface ScreenProps {
  title?: string;
  subtitle?: string;
  /// Shows a back button (stack screens outside the tab shell).
  back?: boolean;
  trailing?: React.ReactNode;
  /// Custom header replacing the title block.
  header?: React.ReactNode;
  children: React.ReactNode;
  /// Set false for screens that manage their own scrolling (chat, lists).
  scroll?: boolean;
  /// Reserves room for the floating tab bar.
  inTabs?: boolean;
  refreshControl?: React.ReactElement<RefreshControlProps>;
  contentStyle?: StyleProp<ViewStyle>;
  keyboardAware?: boolean;
}

export function Screen({
  title,
  subtitle,
  back = false,
  trailing,
  header,
  children,
  scroll = true,
  inTabs = false,
  refreshControl,
  contentStyle,
  keyboardAware = false,
}: ScreenProps): React.ReactElement {
  const insets = useSafeAreaInsets();
  const bottom = inTabs ? Layout.tabBarClearance + insets.bottom : insets.bottom + Space.xxxl;

  const headerBlock =
    header ??
    (title !== undefined || back ? (
      <View style={styles.header}>
        {back && (
          <View style={styles.backRow}>
            <IconButton
              icon="chevron-left"
              variant="filled"
              accessibilityLabel="Go back"
              onPress={() => (router.canGoBack() ? router.back() : router.replace("/home"))}
            />
            {trailing}
          </View>
        )}
        {title !== undefined && (
          <View style={styles.titleRow}>
            <View style={styles.flex}>
              <AppText variant="largeTitle" accessibilityRole="header" numberOfLines={2}>
                {title}
              </AppText>
              {subtitle !== undefined && (
                <AppText variant="subhead" tone="secondary" style={styles.subtitle}>
                  {subtitle}
                </AppText>
              )}
            </View>
            {!back && trailing}
          </View>
        )}
      </View>
    ) : null);

  const body = scroll ? (
    <ScrollView
      style={styles.flex}
      contentContainerStyle={[styles.content, { paddingTop: insets.top + Space.md, paddingBottom: bottom }]}
      refreshControl={refreshControl}
      keyboardShouldPersistTaps="handled"
      keyboardDismissMode="on-drag"
      showsVerticalScrollIndicator={false}
    >
      <View style={[styles.column, contentStyle]}>
        {headerBlock}
        {children}
      </View>
    </ScrollView>
  ) : (
    <View style={[styles.flex, { paddingTop: insets.top + Space.md }]}>
      <View style={[styles.flex, styles.column, styles.fixedColumn, contentStyle]}>
        {headerBlock !== null && <View style={styles.fixedHeader}>{headerBlock}</View>}
        {children}
      </View>
    </View>
  );

  if (!keyboardAware) return body;
  return (
    <KeyboardAvoidingView style={styles.flex} behavior={Platform.OS === "ios" ? "padding" : undefined}>
      {body}
    </KeyboardAvoidingView>
  );
}

interface SectionProps {
  title?: string;
  footer?: string;
  children: React.ReactNode;
  style?: StyleProp<ViewStyle>;
}

/// Titled group of content (settings-style). Title sits outside the card.
export function Section({ title, footer, children, style }: SectionProps): React.ReactElement {
  return (
    <View style={[styles.section, style]}>
      {title !== undefined && (
        <AppText variant="eyebrow" tone="tertiary" style={styles.sectionTitle} accessibilityRole="header">
          {title}
        </AppText>
      )}
      {children}
      {footer !== undefined && (
        <AppText variant="footnote" tone="tertiary" style={styles.sectionFooter}>
          {footer}
        </AppText>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  flex: {
    flex: 1,
  },
  content: {
    paddingHorizontal: Layout.gutter,
    alignItems: "center",
  },
  column: {
    width: "100%",
    maxWidth: Layout.maxContentWidth,
    gap: Space.md,
  },
  fixedColumn: {
    alignSelf: "center",
  },
  fixedHeader: {
    paddingHorizontal: Layout.gutter,
  },
  header: {
    gap: Space.md,
    marginBottom: Space.sm,
  },
  backRow: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
  },
  titleRow: {
    flexDirection: "row",
    alignItems: "flex-end",
    gap: Space.md,
  },
  subtitle: {
    marginTop: 2,
  },
  section: {
    gap: Space.sm,
    marginTop: Space.sm,
  },
  sectionTitle: {
    paddingHorizontal: Space.xs,
  },
  sectionFooter: {
    paddingHorizontal: Space.xs,
  },
});
