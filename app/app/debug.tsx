import React, { useState } from "react";
import { StyleSheet, View } from "react-native";

import { AppText, Button, Card, Colors, Divider, Screen, SegmentedControl, Space, StateView } from "../src/ui";
import { useWeatherStore } from "../src/features/weather/weatherStore";
import { requestLogOk, requestQueryString, useRequestLogStore } from "../src/core/services/requestLog";
import { ApiEndpoints } from "../src/core/config/apiEndpoints";
import { ApiClient } from "../src/core/services/apiClient";
import { realFailures, skippedUnconfigured, weatherNextFailed } from "../src/core/models/dataProvenance";
import { fieldSourcesContributors } from "../src/core/models/fieldSources";

type Tab = "snapshot" | "sources" | "providers" | "requests" | "health";

/// Developer diagnostics: what was requested, which provider answered each
/// field, provider failures, the request log and a backend health probe.
export default function DebugScreen(): React.ReactElement {
  const [tab, setTab] = useState<Tab>("snapshot");
  const snapshot = useWeatherStore((s) => s.snapshot);
  const lastRequest = useWeatherStore((s) => s.lastRequest);
  const lastError = useWeatherStore((s) => s.error);
  const entries = useRequestLogStore((s) => s.entries);
  const [health, setHealth] = useState<string | null>(null);
  const [probing, setProbing] = useState(false);

  const probe = async () => {
    setProbing(true);
    try {
      const data = await ApiClient.get(ApiEndpoints.v2WeatherHealth);
      setHealth(JSON.stringify(data, null, 2).slice(0, 2000));
    } catch (error) {
      setHealth(`probe failed: ${error instanceof Error ? error.message : String(error)}`);
    } finally {
      setProbing(false);
    }
  };

  const noSnapshot = <StateView compact icon="database-off-outline" title="No snapshot loaded" body="Open Home to fetch weather first." />;

  return (
    <Screen back title="Debug & state">
      <SegmentedControl
        value={tab}
        onChange={setTab}
        segments={[
          { value: "snapshot", label: "Snapshot" },
          { value: "sources", label: "Sources" },
          { value: "providers", label: "Providers" },
          { value: "requests", label: "Log" },
          { value: "health", label: "Health" },
        ]}
      />

      {tab === "snapshot" && (
        <Card>
          <Rows
            rows={[
              ["Endpoint", lastRequest?.endpoint ?? "—"],
              ["Query", lastRequest ? requestQueryString(lastRequest.query) : "—"],
              ["Legacy fallback", lastRequest?.usedLegacyFallback ? "yes" : "no"],
              ["City", snapshot?.cityName ?? "—"],
              ["Condition", snapshot?.condition ?? "—"],
              ["WMO code", snapshot?.weatherCode == null ? "not reported" : String(snapshot.weatherCode)],
              ["Hourly points", snapshot ? String(snapshot.hourly.length) : "—"],
              ["Forecast days", snapshot ? String(snapshot.forecast.length) : "—"],
              ["UTC offset", snapshot?.utcOffsetSeconds == null ? "not reported" : `${snapshot.utcOffsetSeconds}s`],
              ["Degraded", snapshot?.degraded == null ? "not reported" : snapshot.degraded ? "yes" : "no"],
              ...(lastError !== null ? [["Last error", lastError] as [string, string]] : []),
            ]}
          />
        </Card>
      )}

      {tab === "sources" && (
        <Card>
          {snapshot === null ? (
            noSnapshot
          ) : (
            <Rows
              rows={[
                ["Selected source", snapshot.provenance.selectedSource ?? snapshot.provenance.source ?? "not reported"],
                ["Requested source", snapshot.provenance.requestedSource ?? "—"],
                ["Run", snapshot.provenance.runId ?? "—"],
                ["Issued at", snapshot.provenance.issuedAtUtc?.toISOString() ?? "—"],
                ["Retrieved at", snapshot.provenance.retrievedAtUtc?.toISOString() ?? "—"],
                ["Contributors", fieldSourcesContributors(snapshot.fieldSources).join(", ") || "—"],
                ...Object.entries(snapshot.fieldSources.sources).map(([field, provider]) => [field, provider ?? "explicitly missing"] as [string, string]),
                ...(snapshot.fieldSources.supplementFilled.length > 0 ? [["Supplemented", snapshot.fieldSources.supplementFilled.join(", ")] as [string, string]] : []),
              ]}
            />
          )}
        </Card>
      )}

      {tab === "providers" && (
        <Card>
          {snapshot === null ? (
            noSnapshot
          ) : (
            <Rows
              rows={[
                ["Tried providers", snapshot.provenance.triedProviders.join(", ") || "—"],
                ["Real failures", realFailures(snapshot.provenance).map((r) => `${r.provider}: ${r.reason}`).join("; ") || "none"],
                ["Skipped (unconfigured)", skippedUnconfigured(snapshot.provenance).map((r) => r.provider).join(", ") || "none"],
                ["Missing fields", snapshot.provenance.missingFields.join(", ") || "none"],
                ["Policy version", snapshot.provenance.selectionPolicyVersion ?? "—"],
                ["Freshness", snapshot.provenance.freshnessStatus ?? "—"],
                ["WeatherNext failed", snapshot.provenance.fallbackReasons.length > 0 ? String(weatherNextFailed(snapshot.provenance)) : "—"],
              ]}
            />
          )}
        </Card>
      )}

      {tab === "requests" && (
        <Card style={styles.gap}>
          <View style={styles.logHeader}>
            <AppText variant="headline" style={styles.flex}>
              {entries.length} requests
            </AppText>
            <Button label="Clear" variant="danger" onPress={() => useRequestLogStore.getState().clear()} disabled={entries.length === 0} />
          </View>
          {entries.length === 0 && <StateView compact icon="format-list-bulleted" title="No requests yet" />}
          {entries.map((entry, i) => (
            <View key={entry.id}>
              {i > 0 && <Divider />}
              <View style={styles.logRow}>
                <AppText variant="mono" color={requestLogOk(entry) ? Colors.good : Colors.danger} style={styles.status}>
                  {entry.statusCode ?? "ERR"}
                </AppText>
                <View style={styles.flex}>
                  <AppText variant="mono" numberOfLines={2}>
                    {entry.method} {entry.path}
                  </AppText>
                  {entry.summary != null && (
                    <AppText variant="caption" tone="tertiary">
                      {entry.summary}
                    </AppText>
                  )}
                  {entry.error != null && (
                    <AppText variant="caption" tone="danger">
                      {entry.error}
                    </AppText>
                  )}
                </View>
                <AppText variant="caption" tone="tertiary">
                  {entry.durationMs ?? "?"} ms
                </AppText>
              </View>
            </View>
          ))}
        </Card>
      )}

      {tab === "health" && (
        <Card style={styles.gap}>
          <AppText variant="headline">{ApiEndpoints.v2WeatherHealth}</AppText>
          <Button label="Probe now" icon="heart-pulse" loading={probing} onPress={() => void probe()} />
          {health !== null && (
            <AppText variant="mono" tone="secondary" selectable>
              {health}
            </AppText>
          )}
        </Card>
      )}
    </Screen>
  );
}

function Rows({ rows }: { rows: Array<[string, string]> }): React.ReactElement {
  return (
    <View>
      {rows.map(([label, value], i) => (
        <View key={`${label}-${i}`}>
          {i > 0 && <Divider />}
          <View style={styles.row}>
            <AppText variant="footnote" tone="tertiary" style={styles.rowLabel}>
              {label}
            </AppText>
            <AppText variant="footnote" style={styles.rowValue} selectable>
              {value}
            </AppText>
          </View>
        </View>
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  flex: {
    flex: 1,
  },
  gap: {
    gap: Space.md,
  },
  row: {
    flexDirection: "row",
    gap: Space.md,
    paddingVertical: Space.sm,
  },
  rowLabel: {
    flex: 2,
  },
  rowValue: {
    flex: 3,
    textAlign: "right",
  },
  logHeader: {
    flexDirection: "row",
    alignItems: "center",
  },
  logRow: {
    flexDirection: "row",
    alignItems: "flex-start",
    gap: Space.sm,
    paddingVertical: Space.sm,
  },
  status: {
    width: 36,
  },
});
