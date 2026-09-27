import { useMemo } from "react";
import { createTranslator, LanguageCode } from "./index";
import { useSettingsStore } from "../features/settings/settingsStore";

export function useTranslation(override?: LanguageCode) {
  const language = useSettingsStore((s) => s.language);
  return useMemo(() => createTranslator(override ?? language), [language, override]);
}
