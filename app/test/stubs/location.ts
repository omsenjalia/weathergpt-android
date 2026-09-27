import { vi } from "vitest";
export const Accuracy = { Balanced: 3 };
export const requestForegroundPermissionsAsync = vi.fn(async () => ({ granted: true, canAskAgain: true }));
export const getForegroundPermissionsAsync = vi.fn(async () => ({ granted: true, canAskAgain: true }));
export const getCurrentPositionAsync = vi.fn(async () => ({ coords: { latitude: 23, longitude: 72 } }));
