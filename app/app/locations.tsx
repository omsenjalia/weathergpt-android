import React, { useEffect, useRef, useState } from "react";
import { StyleSheet, View } from "react-native";
import { router } from "expo-router";

import { AppText, Card, Colors, Divider, Icon, IconButton, InlineBanner, ListRow, Screen, Section, Space, TextField, Touchable, haptic } from "../src/ui";
import { useTranslation } from "../src/i18n/useTranslation";
import { useLocationStore } from "../src/features/location/locationStore";
import { useSavedLocationsStore } from "../src/features/explore/exploreStores";
import { AppLocation, PRESET_LOCATIONS, SavedLocation } from "../src/models/location";
import { GeocodingService } from "../src/core/services/geocodingService";

const SEARCH_DEBOUNCE_MS = 300;

type Place = { name: string; lat: number; lon: number };

/// Location picker (modal): search, device location, saved places.
export default function LocationsScreen(): React.ReactElement {
  const t = useTranslation();
  const current = useLocationStore((s) => s.location);
  const saved = useSavedLocationsStore((s) => s.locations);

  const [query, setQuery] = useState("");
  const [results, setResults] = useState<AppLocation[]>([]);
  const [searching, setSearching] = useState(false);
  const [locating, setLocating] = useState(false);
  const [gpsError, setGpsError] = useState(false);
  const generation = useRef(0);

  // Debounced search; a newer keystroke always wins over an older response.
  useEffect(() => {
    const run = ++generation.current;
    const trimmed = query.trim();
    if (trimmed.length < 2) {
      setResults([]);
      setSearching(false);
      return;
    }
    setSearching(true);
    const timer = setTimeout(() => {
      void GeocodingService.searchMany(trimmed, 6).then((places) => {
        if (run !== generation.current) return;
        setResults(places);
        setSearching(false);
      });
    }, SEARCH_DEBOUNCE_MS);
    return () => clearTimeout(timer);
  }, [query]);

  const choose = (place: Place) => {
    haptic("selection");
    void useLocationStore.getState().select(new AppLocation(place.name, place.lat, place.lon));
    router.back();
  };

  const useDevice = async () => {
    setGpsError(false);
    setLocating(true);
    const place = await useLocationStore.getState().selectFromGps();
    setLocating(false);
    if (place === null) setGpsError(true);
    else router.back();
  };

  const isSaved = (name: string) => saved.some((s) => s.name === name);
  const toggleSaved = (place: Place) => {
    haptic("light");
    const store = useSavedLocationsStore.getState();
    if (isSaved(place.name)) void store.remove(new SavedLocation(place.name, place.lat, place.lon));
    else void store.add(new SavedLocation(place.name, place.lat, place.lon));
  };

  const showingSearch = query.trim().length >= 2;

  return (
    <Screen
      keyboardAware
      title={t("home.choose_location")}
      trailing={<IconButton icon="close" variant="filled" accessibilityLabel={t("location.cancel")} onPress={() => router.back()} />}
    >
      <TextField
        variant="search"
        leadingIcon="magnify"
        placeholder={t("location.search_hint")}
        value={query}
        onChangeText={setQuery}
        busy={searching}
        clearable
        autoFocus
        autoCorrect={false}
        returnKeyType="search"
      />

      {showingSearch ? (
        <Card padded={false}>
          {!searching && results.length === 0 ? (
            <View style={styles.empty}>
              <AppText variant="subhead" tone="secondary" align="center">
                {t("location.no_results")}
              </AppText>
            </View>
          ) : (
            results.map((place, i) => (
              <View key={`${place.name}-${place.lat}-${place.lon}`}>
                {i > 0 && <Divider inset={Space.lg + 44} />}
                <PlaceRow place={place} saved={isSaved(place.name)} onPress={() => choose(place)} onToggleSave={() => toggleSaved(place)} />
              </View>
            ))
          )}
        </Card>
      ) : (
        <>
          <Card padded={false}>
            <View style={styles.rowPad}>
              <ListRow icon="crosshairs-gps" label={t("home.use_my_location")} onPress={() => void useDevice()} trailing={locating ? <AppText variant="footnote" tone="tertiary">{t("loading")}</AppText> : undefined} />
            </View>
            <Divider inset={Space.lg + 44} />
            <View style={styles.rowPad}>
              <ListRow icon="map-marker" label={current.name} description={`${current.lat.toFixed(3)}, ${current.lon.toFixed(3)}`} trailing={<Icon name="check" size={20} color={Colors.accentText} />} />
            </View>
          </Card>
          {gpsError && <InlineBanner tone="caution" icon="map-marker-off-outline" message={t("location.not_available")} />}

          {saved.length > 0 && (
            <Section title={t("settings.saved_locations")}>
              <Card padded={false}>
                {saved.map((place, i) => (
                  <View key={place.name}>
                    {i > 0 && <Divider inset={Space.lg + 44} />}
                    <PlaceRow place={place} saved onPress={() => choose(place)} onToggleSave={() => toggleSaved(place)} />
                  </View>
                ))}
              </Card>
            </Section>
          )}

          <Section title={t("location.popular")}>
            <Card padded={false}>
              {PRESET_LOCATIONS.filter((p) => p.name !== current.name).map((place, i) => (
                <View key={place.name}>
                  {i > 0 && <Divider inset={Space.lg + 44} />}
                  <PlaceRow place={place} saved={isSaved(place.name)} onPress={() => choose(place)} onToggleSave={() => toggleSaved(place)} />
                </View>
              ))}
            </Card>
          </Section>
        </>
      )}
    </Screen>
  );
}

interface PlaceRowProps {
  place: Place;
  saved: boolean;
  onPress: () => void;
  onToggleSave: () => void;
}

function PlaceRow({ place, saved, onPress, onToggleSave }: PlaceRowProps): React.ReactElement {
  const t = useTranslation();
  const [head, ...rest] = place.name.split(",");
  return (
    <View style={styles.place}>
      <Touchable scale={false} onPress={onPress} accessibilityLabel={place.name} style={styles.placeMain}>
        <View style={styles.placeIcon}>
          <Icon name="map-marker-outline" size={18} color={Colors.textSecondary} />
        </View>
        <View style={styles.flex}>
          <AppText variant="callout" numberOfLines={1}>
            {head!.trim()}
          </AppText>
          {rest.length > 0 && (
            <AppText variant="footnote" tone="tertiary" numberOfLines={1}>
              {rest.join(",").trim()}
            </AppText>
          )}
        </View>
      </Touchable>
      <IconButton
        icon={saved ? "star" : "star-outline"}
        color={saved ? Colors.caution : Colors.textSecondary}
        accessibilityLabel={saved ? t("location.saved") : t("location.save")}
        onPress={onToggleSave}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  flex: {
    flex: 1,
  },
  rowPad: {
    paddingHorizontal: Space.lg,
  },
  empty: {
    padding: Space.xl,
  },
  place: {
    flexDirection: "row",
    alignItems: "center",
    paddingLeft: Space.lg,
    paddingRight: Space.sm,
  },
  placeMain: {
    flex: 1,
    flexDirection: "row",
    alignItems: "center",
    gap: Space.md,
    minHeight: 56,
  },
  placeIcon: {
    width: 32,
    height: 32,
    borderRadius: 10,
    backgroundColor: Colors.surfaceInset,
    alignItems: "center",
    justifyContent: "center",
  },
});
