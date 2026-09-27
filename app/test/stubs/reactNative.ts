/// Test stub for the react-native runtime (Flow source is not parseable in
/// node-side vitest). Unit tests only touch pure TypeScript modules; anything
/// importing zustand stores just needs these symbols to exist.

export const Platform = {
  OS: "web",
  select: (options: Record<string, unknown>) => options.web ?? options.default,
};

export const StyleSheet = {
  create: <T,>(styles: T): T => styles,
  hairlineWidth: 1,
  absoluteFill: {},
  absoluteFillObject: {},
  flatten: (style: unknown) => style,
};

export class View {}
export class Text {}
export const AsyncStorage = {
  getItem: async () => null,
  setItem: async () => undefined,
};

export default {};
