"""Shared backend services used by the web and mobile clients.

- `open_meteo`  — thin Open-Meteo client + WMO code table (single source of truth)
- `fusion`      — multi-provider current-conditions fusion engine
- `response`    — output gate: strips chain-of-thought, validates widgets
- `chat`        — routing policy: client detect, language normalise, fast/agent/fallback
"""
