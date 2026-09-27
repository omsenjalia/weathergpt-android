/// Test stub for AsyncStorage: in-memory map so store hydration works in
/// node-side vitest without the native module.

const memory = new Map<string, string>();

export const AsyncStorage = {
  async getItem(key: string): Promise<string | null> {
    return memory.get(key) ?? null;
  },
  async setItem(key: string, value: string): Promise<void> {
    memory.set(key, value);
  },
  async removeItem(key: string): Promise<void> {
    memory.delete(key);
  },
  async multiRemove(keys: string[]): Promise<void> {
    for (const key of keys) memory.delete(key);
  },
};

export default AsyncStorage;
