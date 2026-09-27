/// Markdown renderer for assistant replies. Covers the GFM subset the
/// backend emits: headings, paragraphs, bold/italic/code/links, bullet and
/// numbered lists, blockquotes, fenced code and pipe tables.
/// ```widget:*``` fences are native-card instructions and are dropped.

import React, { useMemo } from "react";
import { Linking, ScrollView, StyleSheet, Text, TextStyle, View } from "react-native";

import { Colors, FontFamily, Radius, Space, Type } from "../theme/tokens";
import { parseMarkdown } from "./markdown";

// `_italic_` is deliberately unsupported: it would mangle snake_case field
// names (weather_code, field_sources) that appear in technical answers.
const INLINE = /(\*\*[^*]+\*\*|__[^_]+__|\*[^*\s][^*]*\*|`[^`]+`|\[[^\]]+\]\([^)]+\))/g;

function renderInline(text: string, key: string, base: TextStyle, color: string): React.ReactNode[] {
  const nodes: React.ReactNode[] = [];
  let lastIndex = 0;
  let match: RegExpExecArray | null;
  let n = 0;
  INLINE.lastIndex = 0;
  while ((match = INLINE.exec(text)) !== null) {
    if (match.index > lastIndex) nodes.push(text.slice(lastIndex, match.index));
    const token = match[0];
    const k = `${key}-${n++}`;
    if (token.startsWith("**") || token.startsWith("__")) {
      nodes.push(<Text key={k} style={[base, styles.bold, { color }]}>{token.slice(2, -2)}</Text>);
    } else if (token.startsWith("`")) {
      nodes.push(<Text key={k} style={[base, styles.inlineCode]}>{token.slice(1, -1)}</Text>);
    } else if (token.startsWith("[")) {
      const link = /\[([^\]]+)\]\(([^)]+)\)/.exec(token)!;
      const url = link[2]!;
      nodes.push(
        <Text
          key={k}
          style={[base, styles.link]}
          accessibilityRole="link"
          onPress={() => {
            if (/^https?:\/\//i.test(url)) void Linking.openURL(url).catch(() => undefined);
          }}
        >
          {link[1]}
        </Text>,
      );
    } else {
      nodes.push(<Text key={k} style={[base, styles.italic]}>{token.slice(1, -1)}</Text>);
    }
    lastIndex = match.index + token.length;
  }
  if (lastIndex < text.length) nodes.push(text.slice(lastIndex));
  return nodes;
}

interface RichTextProps {
  content: string;
  color?: string;
}

export function RichText({ content, color = Colors.text }: RichTextProps): React.ReactElement {
  const blocks = useMemo(() => parseMarkdown(content), [content]);
  const body: TextStyle = { ...Type.body, color };

  return (
    <View style={styles.root}>
      {blocks.map((block, i) => {
        switch (block.kind) {
          case "heading":
            return (
              <Text key={i} accessibilityRole="header" style={[block.level <= 2 ? Type.title : Type.headline, { color }]}>
                {renderInline(block.text, `h${i}`, block.level <= 2 ? Type.title : Type.headline, color)}
              </Text>
            );
          case "bullets":
          case "numbers":
            return (
              <View key={i} style={styles.list}>
                {block.items.map((item, j) => (
                  <View key={j} style={styles.listItem}>
                    <Text style={[body, styles.marker]}>{block.kind === "bullets" ? "•" : `${block.start + j}.`}</Text>
                    <Text style={[body, styles.flex]}>{renderInline(item, `l${i}-${j}`, body, color)}</Text>
                  </View>
                ))}
              </View>
            );
          case "quote":
            return (
              <View key={i} style={styles.quote}>
                <Text style={[body, styles.quoteText]}>{renderInline(block.lines.join(" "), `q${i}`, body, Colors.textSecondary)}</Text>
              </View>
            );
          case "code":
            return (
              <ScrollView key={i} horizontal style={styles.codeBlock} contentContainerStyle={styles.codeContent}>
                <Text style={styles.codeText} selectable>
                  {block.text}
                </Text>
              </ScrollView>
            );
          case "table":
            return <Table key={i} header={block.header} rows={block.rows} color={color} />;
          case "paragraph":
            return (
              <Text key={i} style={body} selectable>
                {renderInline(block.lines.join(" "), `p${i}`, body, color)}
              </Text>
            );
        }
      })}
    </View>
  );
}

/// One width per column (from its longest cell) so rows line up.
function columnWidths(header: string[], rows: string[][]): number[] {
  return header.map((h, c) => {
    const longest = Math.max(h.length, ...rows.map((r) => (r[c] ?? "").replace(/[*`]/g, "").length));
    return Math.min(Math.max(Math.round(longest * 7.2) + 24, 88), 220);
  });
}

function Table({ header, rows, color }: { header: string[]; rows: string[][]; color: string }): React.ReactElement {
  const cell: TextStyle = { ...Type.subhead, color };
  const widths = columnWidths(header, rows);
  return (
    <ScrollView horizontal showsHorizontalScrollIndicator={false} style={styles.table}>
      <View>
        <View style={[styles.tr, styles.thead]}>
          {header.map((h, c) => (
            <Text key={c} style={[cell, styles.td, styles.th, { width: widths[c] }]}>
              {renderInline(h, `th${c}`, cell, color)}
            </Text>
          ))}
        </View>
        {rows.map((row, r) => (
          <View key={r} style={[styles.tr, r % 2 === 1 && styles.zebra]}>
            {header.map((_, c) => (
              <Text key={c} style={[cell, styles.td, { width: widths[c] }]}>
                {renderInline(row[c] ?? "", `td${r}-${c}`, cell, color)}
              </Text>
            ))}
          </View>
        ))}
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  root: {
    gap: Space.md,
  },
  flex: {
    flex: 1,
  },
  bold: {
    fontFamily: FontFamily.bold,
  },
  italic: {
    fontStyle: "italic",
  },
  inlineCode: {
    ...Type.mono,
    color: Colors.accentText,
    backgroundColor: Colors.surfaceInset,
  },
  link: {
    color: Colors.accentText,
    textDecorationLine: "underline",
  },
  list: {
    gap: Space.xs,
  },
  listItem: {
    flexDirection: "row",
    gap: Space.sm,
  },
  marker: {
    minWidth: 16,
    color: Colors.textSecondary,
  },
  quote: {
    borderLeftWidth: 3,
    borderLeftColor: Colors.accent,
    paddingLeft: Space.md,
  },
  quoteText: {
    color: Colors.textSecondary,
  },
  codeBlock: {
    borderRadius: Radius.sm,
    backgroundColor: Colors.surfaceStrong,
  },
  codeContent: {
    padding: Space.md,
  },
  codeText: {
    ...Type.mono,
    color: Colors.text,
  },
  table: {
    borderRadius: Radius.sm,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: Colors.hairlineStrong,
  },
  tr: {
    flexDirection: "row",
  },
  thead: {
    backgroundColor: Colors.surfaceInset,
  },
  zebra: {
    backgroundColor: "rgba(255, 255, 255, 0.03)",
  },
  td: {
    paddingHorizontal: Space.md,
    paddingVertical: Space.sm,
  },
  th: {
    fontFamily: FontFamily.semibold,
  },
});
