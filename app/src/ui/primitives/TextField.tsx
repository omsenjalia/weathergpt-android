import React, { forwardRef, useState } from "react";
import { ActivityIndicator, StyleSheet, TextInput, TextInputProps, View } from "react-native";

import { AppText } from "./AppText";
import { Icon, IconName } from "./Icon";
import { Touchable } from "./Touchable";
import { Colors, FontFamily, Radius, Space } from "../theme/tokens";

interface TextFieldProps extends Omit<TextInputProps, "style"> {
  label?: string;
  error?: string | null;
  hint?: string;
  leadingIcon?: IconName;
  busy?: boolean;
  /// Shows a clear button when there is text.
  clearable?: boolean;
  variant?: "field" | "search";
}

export const TextField = forwardRef<TextInput, TextFieldProps>(function TextField(
  { label, error, hint, leadingIcon, busy = false, clearable = false, variant = "field", value, onChangeText, ...rest },
  ref,
) {
  const [focused, setFocused] = useState(false);
  const hasError = error !== null && error !== undefined && error !== "";
  return (
    <View style={styles.wrap}>
      {label !== undefined && (
        <AppText variant="footnote" tone="secondary" nativeID={rest.nativeID ? `${rest.nativeID}-label` : undefined}>
          {label}
        </AppText>
      )}
      <View
        style={[
          styles.box,
          variant === "search" && styles.search,
          focused && styles.focused,
          hasError && styles.errored,
        ]}
      >
        {leadingIcon !== undefined && <Icon name={leadingIcon} size={18} color={Colors.textTertiary} />}
        <TextInput
          ref={ref}
          {...rest}
          value={value}
          onChangeText={onChangeText}
          accessibilityLabel={rest.accessibilityLabel ?? label ?? rest.placeholder}
          placeholderTextColor={Colors.textTertiary}
          selectionColor={Colors.accent}
          cursorColor={Colors.accent}
          onFocus={(e) => {
            setFocused(true);
            rest.onFocus?.(e);
          }}
          onBlur={(e) => {
            setFocused(false);
            rest.onBlur?.(e);
          }}
          style={styles.input}
        />
        {busy && <ActivityIndicator size="small" color={Colors.textSecondary} />}
        {!busy && clearable && value !== undefined && value !== "" && (
          <Touchable onPress={() => onChangeText?.("")} accessibilityLabel="Clear text" hitSlop={10}>
            <Icon name="close-circle" size={18} color={Colors.textTertiary} />
          </Touchable>
        )}
      </View>
      {hasError ? (
        <AppText variant="footnote" tone="danger" accessibilityLiveRegion="polite">
          {error}
        </AppText>
      ) : (
        hint !== undefined && (
          <AppText variant="footnote" tone="tertiary">
            {hint}
          </AppText>
        )
      )}
    </View>
  );
});

const styles = StyleSheet.create({
  wrap: {
    gap: 6,
  },
  box: {
    flexDirection: "row",
    alignItems: "center",
    gap: Space.sm,
    minHeight: 48,
    paddingHorizontal: Space.md + 2,
    borderRadius: Radius.md,
    borderWidth: 1,
    borderColor: Colors.hairline,
    backgroundColor: Colors.surfaceInset,
  },
  search: {
    borderRadius: Radius.pill,
    backgroundColor: Colors.surface,
    paddingHorizontal: Space.lg,
  },
  focused: {
    borderColor: Colors.accent,
  },
  errored: {
    borderColor: Colors.danger,
  },
  input: {
    flex: 1,
    color: Colors.text,
    fontFamily: FontFamily.medium,
    fontSize: 15,
    paddingVertical: 12,
    // Removes the web focus outline; the border colour carries focus state.
    outlineStyle: "none",
  } as never,
});
