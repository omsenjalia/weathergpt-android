/// Responsive SVG line chart. Multi-series, soft area fill for a single
/// series, gridlines with value labels, first/last x labels. Points are drawn
/// only where data exists — a missing year is a gap, never a zero.

import React, { useMemo, useState } from "react";
import { LayoutChangeEvent, StyleSheet, View } from "react-native";
import Svg, { Circle, Defs, Line, LinearGradient, Path, Stop, Text as SvgText } from "react-native-svg";

import { Colors, FontFamily } from "../theme/tokens";
import { AppText } from "../primitives/AppText";

export interface ChartSeries {
  points: Array<{ x: number; value: number }>;
  color: string;
  label?: string;
}

interface LineChartProps {
  series: ChartSeries[];
  height?: number;
  unit?: string;
  emptyLabel?: string;
  accessibilityLabel?: string;
}

const PAD = { left: 40, right: 12, top: 12, bottom: 24 };

export function LineChart({ series, height = 200, unit = "", emptyLabel = "—", accessibilityLabel }: LineChartProps): React.ReactElement {
  const [width, setWidth] = useState(0);
  const onLayout = (e: LayoutChangeEvent) => setWidth(Math.round(e.nativeEvent.layout.width));

  const bounds = useMemo(() => {
    const all = series.flatMap((s) => s.points);
    if (all.length === 0) return null;
    const xs = all.map((p) => p.x);
    const vs = all.map((p) => p.value);
    const lo = Math.min(...vs);
    const hi = Math.max(...vs);
    const pad = (hi - lo) * 0.12 || Math.abs(hi) * 0.1 || 1;
    return { xMin: Math.min(...xs), xMax: Math.max(...xs), yMin: lo - pad, yMax: hi + pad };
  }, [series]);

  if (bounds === null) {
    return (
      <View style={[styles.empty, { height }]}>
        <AppText variant="subhead" tone="tertiary">
          {emptyLabel}
        </AppText>
      </View>
    );
  }

  const plotW = Math.max(width - PAD.left - PAD.right, 1);
  const plotH = height - PAD.top - PAD.bottom;
  const toX = (x: number) => PAD.left + ((x - bounds.xMin) / Math.max(bounds.xMax - bounds.xMin, 1e-9)) * plotW;
  const toY = (v: number) => PAD.top + (1 - (v - bounds.yMin) / Math.max(bounds.yMax - bounds.yMin, 1e-9)) * plotH;
  const ticks = [0, 0.5, 1].map((r) => bounds.yMin + r * (bounds.yMax - bounds.yMin));
  const single = series.length === 1;

  return (
    <View style={{ height }} onLayout={onLayout} accessible accessibilityRole="image" accessibilityLabel={accessibilityLabel}>
      {width > 0 && (
        <Svg width={width} height={height}>
          <Defs>
            {series.map((s, i) => (
              <LinearGradient key={i} id={`fill-${i}`} x1="0" y1="0" x2="0" y2="1">
                <Stop offset="0" stopColor={s.color} stopOpacity={0.28} />
                <Stop offset="1" stopColor={s.color} stopOpacity={0} />
              </LinearGradient>
            ))}
          </Defs>
          {ticks.map((tick, i) => (
            <React.Fragment key={i}>
              <Line x1={PAD.left} x2={width - PAD.right} y1={toY(tick)} y2={toY(tick)} stroke={Colors.hairline} strokeWidth={1} />
              <SvgText x={PAD.left - 6} y={toY(tick) + 3} fontSize={10} fill={Colors.textTertiary} textAnchor="end" fontFamily={FontFamily.medium}>
                {formatTick(tick, unit)}
              </SvgText>
            </React.Fragment>
          ))}
          {series.map((s, i) => {
            const pts = [...s.points].sort((a, b) => a.x - b.x);
            if (pts.length === 0) return null;
            const line = pts.map((p, j) => `${j === 0 ? "M" : "L"}${toX(p.x).toFixed(1)},${toY(p.value).toFixed(1)}`).join(" ");
            const area = `${line} L${toX(pts[pts.length - 1]!.x).toFixed(1)},${PAD.top + plotH} L${toX(pts[0]!.x).toFixed(1)},${PAD.top + plotH} Z`;
            const lastPoint = pts[pts.length - 1]!;
            return (
              <React.Fragment key={i}>
                {single && <Path d={area} fill={`url(#fill-${i})`} />}
                <Path d={line} stroke={s.color} strokeWidth={2.25} fill="none" strokeLinejoin="round" strokeLinecap="round" />
                {pts.length <= 40 && pts.map((p, j) => <Circle key={j} cx={toX(p.x)} cy={toY(p.value)} r={2.25} fill={s.color} />)}
                <Circle cx={toX(lastPoint.x)} cy={toY(lastPoint.value)} r={4.5} fill={s.color} stroke={Colors.canvas} strokeWidth={2} />
              </React.Fragment>
            );
          })}
          <SvgText x={PAD.left} y={height - 6} fontSize={10} fill={Colors.textTertiary} fontFamily={FontFamily.medium}>
            {String(Math.trunc(bounds.xMin))}
          </SvgText>
          <SvgText x={width - PAD.right} y={height - 6} fontSize={10} fill={Colors.textTertiary} textAnchor="end" fontFamily={FontFamily.medium}>
            {String(Math.trunc(bounds.xMax))}
          </SvgText>
        </Svg>
      )}
    </View>
  );
}

interface DeviationBarsProps {
  points: Array<{ x: number; value: number }>;
  height?: number;
  accessibilityLabel?: string;
}

/// Bars above/below a zero line, e.g. percent deviation from the mean.
export function DeviationBars({ points, height = 140, accessibilityLabel }: DeviationBarsProps): React.ReactElement {
  const [width, setWidth] = useState(0);
  const max = Math.max(...points.map((p) => Math.abs(p.value)), 1);
  const mid = height / 2 - 8;
  const slot = points.length > 0 ? (width - PAD.left) / points.length : 0;
  const barW = Math.max(Math.min(slot * 0.6, 18), 2);

  return (
    <View style={{ height }} onLayout={(e) => setWidth(Math.round(e.nativeEvent.layout.width))} accessible accessibilityRole="image" accessibilityLabel={accessibilityLabel}>
      {width > 0 && (
        <Svg width={width} height={height}>
          <Line x1={PAD.left} x2={width} y1={mid} y2={mid} stroke={Colors.hairlineStrong} strokeWidth={1} />
          <SvgText x={PAD.left - 6} y={mid + 3} fontSize={10} fill={Colors.textTertiary} textAnchor="end" fontFamily={FontFamily.medium}>
            0%
          </SvgText>
          {points.map((p, i) => {
            const h = (Math.abs(p.value) / max) * (mid - 8);
            const x = PAD.left + i * slot + (slot - barW) / 2;
            return (
              <Path
                key={p.x}
                d={p.value >= 0 ? `M${x},${mid} h${barW} v${-h} h${-barW} Z` : `M${x},${mid} h${barW} v${h} h${-barW} Z`}
                fill={p.value >= 0 ? Colors.tempWarm : Colors.tempCool}
              />
            );
          })}
          {points.length > 0 && (
            <>
              <SvgText x={PAD.left} y={height - 4} fontSize={10} fill={Colors.textTertiary} fontFamily={FontFamily.medium}>
                {String(Math.trunc(points[0]!.x))}
              </SvgText>
              <SvgText x={width} y={height - 4} fontSize={10} fill={Colors.textTertiary} textAnchor="end" fontFamily={FontFamily.medium}>
                {String(Math.trunc(points[points.length - 1]!.x))}
              </SvgText>
            </>
          )}
        </Svg>
      )}
    </View>
  );
}

function formatTick(value: number, unit: string): string {
  const rounded = Math.abs(value) >= 100 ? Math.round(value) : Math.round(value * 10) / 10;
  return `${rounded}${unit}`;
}

const styles = StyleSheet.create({
  empty: {
    alignItems: "center",
    justifyContent: "center",
  },
});
