/// Pure markdown block parser for assistant replies (no React Native
/// imports, so it is unit-testable). ```widget:*``` fences are native-card
/// instructions and are dropped.

export type Block =
  | { kind: "heading"; level: number; text: string }
  | { kind: "paragraph"; lines: string[] }
  | { kind: "bullets"; items: string[] }
  | { kind: "numbers"; items: string[]; start: number }
  | { kind: "quote"; lines: string[] }
  | { kind: "code"; text: string }
  | { kind: "table"; header: string[]; rows: string[][] };

const TABLE_DIVIDER = /^\s*\|?\s*:?-{2,}:?\s*(\|\s*:?-{2,}:?\s*)*\|?\s*$/;

/// Native-card payloads: ```widget:*``` fences, or JSON fences carrying a
/// `widget_type` key (how the backend attaches weather cards).
function isWidgetFence(info: string, body: string[]): boolean {
  if (info.toLowerCase().startsWith("widget")) return true;
  return /"widget(_type)?"\s*:/.test(body.join("\n"));
}

function splitRow(line: string): string[] {
  return line.trim().replace(/^\|/, "").replace(/\|$/, "").split("|").map((c) => c.trim());
}

export function parseMarkdown(source: string): Block[] {
  const blocks: Block[] = [];
  const lines = source.replace(/\r\n/g, "\n").split("\n");
  let i = 0;
  const last = () => blocks[blocks.length - 1];

  while (i < lines.length) {
    const line = lines[i]!.replace(/\s+$/, "");

    const fence = /^```\s*(\S*)/.exec(line);
    if (fence !== null) {
      const body: string[] = [];
      i++;
      while (i < lines.length && !/^```/.test(lines[i]!)) body.push(lines[i++]!);
      i++;
      if (!isWidgetFence(fence[1]!, body)) blocks.push({ kind: "code", text: body.join("\n") });
      continue;
    }

    if (line.includes("|") && i + 1 < lines.length && TABLE_DIVIDER.test(lines[i + 1]!)) {
      const header = splitRow(line);
      const rows: string[][] = [];
      i += 2;
      while (i < lines.length && lines[i]!.includes("|") && lines[i]!.trim() !== "") rows.push(splitRow(lines[i++]!));
      blocks.push({ kind: "table", header, rows });
      continue;
    }

    const heading = /^(#{1,6})\s+(.*)$/.exec(line);
    const bullet = /^\s*[-*•]\s+(.*)$/.exec(line);
    const numbered = /^\s*(\d+)[.)]\s+(.*)$/.exec(line);
    const quote = /^\s*>\s?(.*)$/.exec(line);
    const prev = last();

    if (/^\s*(-{3,}|\*{3,}|_{3,})\s*$/.test(line)) blocks.push({ kind: "paragraph", lines: [] }); // horizontal rule
    else if (heading !== null) blocks.push({ kind: "heading", level: heading[1]!.length, text: heading[2]! });
    else if (bullet !== null) {
      if (prev?.kind === "bullets") prev.items.push(bullet[1]!);
      else blocks.push({ kind: "bullets", items: [bullet[1]!] });
    } else if (numbered !== null) {
      if (prev?.kind === "numbers") prev.items.push(numbered[2]!);
      else blocks.push({ kind: "numbers", items: [numbered[2]!], start: parseInt(numbered[1]!, 10) });
    } else if (quote !== null) {
      if (prev?.kind === "quote") prev.lines.push(quote[1]!);
      else blocks.push({ kind: "quote", lines: [quote[1]!] });
    } else if (line.trim() === "") {
      blocks.push({ kind: "paragraph", lines: [] }); // paragraph break marker
    } else if (prev?.kind === "paragraph" && prev.lines.length > 0) {
      prev.lines.push(line);
    } else {
      blocks.push({ kind: "paragraph", lines: [line] });
    }
    i++;
  }
  return blocks.filter((b) => !(b.kind === "paragraph" && b.lines.length === 0));
}
