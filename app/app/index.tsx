import React, { useEffect, useState } from "react";
import { Redirect } from "expo-router";

import { loadJson, StorageKeys } from "../src/lib/persistence";
import { useLocationStore } from "../src/features/location/locationStore";

type Target = "/home" | "/onboarding";

/// Entry route: sends first-time users to onboarding, everyone else home.
export default function Index(): React.ReactElement | null {
  const [target, setTarget] = useState<Target | null>(null);

  useEffect(() => {
    let active = true;
    void loadJson<boolean | null>(StorageKeys.onboardingComplete).then((complete) => {
      if (!active) return;
      const next: Target = complete === true ? "/home" : "/onboarding";
      // Returning users: ask the OS for location once (no-op after the first time).
      if (next === "/home") void useLocationStore.getState().maybeAutoLocate();
      setTarget(next);
    });
    return () => {
      active = false;
    };
  }, []);

  return target === null ? null : <Redirect href={target} />;
}
