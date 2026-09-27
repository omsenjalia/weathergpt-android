// Convert only for presentation; backend values and chart ratios remain Celsius.
export function formatTemperature(celsius: number | null | undefined, unit: "celsius" | "fahrenheit"): string {
  if (celsius == null || !Number.isFinite(celsius)) return "—";
  return `${Math.round(unit === "fahrenheit" ? celsius * 9 / 5 + 32 : celsius)}°${unit === "fahrenheit" ? "F" : "C"}`;
}
