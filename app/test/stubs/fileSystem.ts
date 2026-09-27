export const written = new Map<string, string>();

export class File {
  readonly uri: string;
  constructor(...parts: unknown[]) {
    this.uri = parts.map((p) => (typeof p === "string" ? p : (p as { uri?: string }).uri ?? "")).join("/");
  }
  write(content: string): void {
    written.set(this.uri, content);
  }
  async base64(): Promise<string> {
    return written.get(this.uri) ?? "UklGRg==";
  }
  delete(): void {
    written.delete(this.uri);
  }
}

export const Paths = { cache: { uri: "file:///cache" } };
