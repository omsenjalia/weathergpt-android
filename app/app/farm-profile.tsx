import React, { useState } from "react";
import { router } from "expo-router";

import { Button, Screen, haptic } from "../src/ui";
import { useTranslation } from "../src/i18n/useTranslation";
import { useFarmProfileStore } from "../src/features/farm/farmStores";
import { FarmProfileForm } from "../src/features/farm/components/FarmProfileForm";
import { FarmVoiceFlow } from "../src/features/farm/components/FarmVoiceFlow";

export default function FarmProfileScreen(): React.ReactElement {
  const t = useTranslation();
  const profile = useFarmProfileStore((s) => s.profile);
  const [voice, setVoice] = useState(false);
  const saved = () => {
    haptic("success");
    router.back();
  };

  return (
    <Screen
      back
      keyboardAware
      title={t("farmer.farm_profile")}
      subtitle={voice ? undefined : t("farmer.profile_complete_hint")}
      trailing={
        voice ? undefined : <Button label={t("farm.voice_talk_instead")} icon="microphone" variant="secondary" onPress={() => setVoice(true)} />
      }
    >
      {voice ? (
        <FarmVoiceFlow language={t.language} initial={profile} onSaved={saved} onTypeInstead={() => setVoice(false)} />
      ) : (
        <FarmProfileForm initial={profile} submitLabel={t("farmer.save_changes")} onSaved={saved} />
      )}
    </Screen>
  );
}
