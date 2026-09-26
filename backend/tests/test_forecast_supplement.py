"""Offline tests for services.forecast_supplement.

The supplement fills *only* the fields the selected provider left ``None`` and
attributes every filled field. Primary WeatherNext values are never touched.
"""

from __future__ import annotations

import os
import sys
from datetime import datetime, timedelta, timezone

import pytest

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from services import forecast_supplement as fs  # noqa: E402
from services.forecast_models import (  # noqa: E402
    ForecastPoint,
    ForecastProvenance,
    NormalizedForecast,
    ProviderName,
)

NOW = datetime(2026, 9, 19, 10, 0, tzinfo=timezone.utc)


def _wn_forecast(hours: int = 48) -> NormalizedForecast:
    hourly = [
        ForecastPoint(
            time_utc=NOW + timedelta(hours=h),
            temperature_c=27.0 + h % 5,
            wind_speed_kmh=10.0,
            precipitation_mm=0.1,
            precipitation_probability=10.0,
            is_ensemble_mean=True,
            missing_reason="cloud_cover_not_selected",
        )
        for h in range(hours)
    ]
    current = hourly[0]
    daily = [
        {"date": "2026-09-19", "high_c": 31.1, "low_c": 24.9, "condition": None, "sunrise": None, "sunset": None},
        {"date": "2026-09-20", "high_c": 30.9, "low_c": 24.3, "condition": "Slight rain", "sunrise": None, "sunset": None},
    ]
    prov = ForecastProvenance(
        requested_source="auto",
        selected_source=ProviderName.WEATHERNEXT,
        model="weathernext_3_0_0",
        run_id="weathernext_3_0_0_2026091906",
        init_time_utc=NOW - timedelta(hours=4),
        methods={"temperature": "ensemble_mean"},
    )
    return NormalizedForecast(
        location={"lat": 22.3, "lon": 70.8, "timezone": "UTC+5 (solar approximation)"},
        current=current,
        hourly=hourly,
        daily=daily,
        provenance=prov,
    )


def _supplement_payload() -> dict:
    hourly = {}
    for h in range(48):
        t = NOW + timedelta(hours=h)
        hourly[t.isoformat()] = {
            "weather_code": 2,
            "condition": "Partly cloudy",
            "humidity_percent": 70.0,
            "cloud_cover_percent": 55.0,
            "uv_index": 4.0 if 3 <= t.hour <= 12 else 0.0,
            "feels_like_c": 31.0,
        }
    return {
        "provider": "open_meteo",
        "timezone": "Asia/Kolkata",
        "utc_offset_seconds": 19800,
        "current": {
            "feels_like_c": 31.2,
            "humidity_percent": 72.0,
            "pressure_hpa": 1006.5,
            "pressure_type": "msl",
            "wind_direction_deg": 250.0,
            "cloud_cover_percent": 60.0,
            "uv_index": 5.5,
            "weather_code": 2,
            "condition": "Partly cloudy",
        },
        "hourly": hourly,
        "daily": {
            "2026-09-19": {"sunrise": "2026-09-19T06:32", "sunset": "2026-09-19T18:47", "uv_index_max": 9.1, "weather_code": 2, "condition": "Partly cloudy"},
            "2026-09-20": {"sunrise": "2026-09-20T06:32", "sunset": "2026-09-20T18:46", "uv_index_max": 8.7, "weather_code": 61, "condition": "Slight rain"},
        },
        "air_quality": {"european_aqi": 42.0, "pm2_5": 18.3, "standard": "european", "source": "open_meteo"},
        "errors": [],
        "cache_hit": False,
    }


@pytest.fixture(autouse=True)
def _enabled(monkeypatch):
    monkeypatch.delenv("WEATHER_SUPPLEMENT_ENABLED", raising=False)
    fs.clear_cache()
    yield
    fs.clear_cache()


def test_fills_only_null_fields_and_attributes_them():
    fc = _wn_forecast()
    sources = fs.supplement_forecast(fc, 22.3, 70.8, supplement=_supplement_payload())

    # Primary values untouched
    assert fc.current.temperature_c == 27.0
    assert fc.current.wind_speed_kmh == 10.0
    assert fc.current.precipitation_mm == 0.1
    assert fc.provenance.selected_source == ProviderName.WEATHERNEXT
    assert fc.provenance.run_id == "weathernext_3_0_0_2026091906"

    # Gaps filled
    assert fc.current.humidity_percent == 72.0
    assert fc.current.pressure_hpa == 1006.5 and fc.current.pressure_type == "msl"
    assert fc.current.uv_index == 5.5
    assert fc.current.condition == "Partly cloudy" and fc.current.weather_code == 2
    assert fc.current.missing_reason is None
    assert fc.daily[0]["sunrise"] == "2026-09-19T06:32"
    assert fc.daily[0]["sunset"] == "2026-09-19T18:47"
    assert fc.daily[0]["uv_index_max"] == 9.1
    assert fc.daily[0]["condition"] == "Partly cloudy"
    assert fc.daily[1]["condition"] == "Slight rain"  # primary daily condition kept
    assert fc.air_quality["european_aqi"] == 42.0
    assert fc.location["timezone"] == "Asia/Kolkata"
    assert fc.location["timezone_approximation"] == "UTC+5 (solar approximation)"

    # Attribution
    assert sources["temperature_c"] == "weathernext"
    assert sources["wind_speed_kmh"] == "weathernext"
    assert sources["humidity_percent"] == "open_meteo"
    assert sources["uv_index"] == "open_meteo"
    assert sources["sunrise"] == "open_meteo"
    assert sources["air_quality"] == "open_meteo"
    assert sources["hourly_condition"] == "open_meteo"
    assert sources["_supplement"]["attempted"] is True
    assert "humidity_percent" in sources["_supplement"]["filled"]
    assert "supplement" in fc.provenance.methods
    assert fc.field_sources == sources

    # Hourly conditions filled by matching UTC hour
    assert all(p.condition == "Partly cloudy" for p in fc.hourly)
    assert all(p.missing_reason is None for p in fc.hourly)


def test_primary_values_are_never_overwritten():
    fc = _wn_forecast()
    fc.current.humidity_percent = 55.0
    fc.current.condition = "Overcast"
    fc.current.weather_code = 3
    fc.daily[0]["sunrise"] = "primary"
    sources = fs.supplement_forecast(fc, 22.3, 70.8, supplement=_supplement_payload())
    assert fc.current.humidity_percent == 55.0
    assert fc.current.condition == "Overcast" and fc.current.weather_code == 3
    assert fc.daily[0]["sunrise"] == "primary"
    assert sources["humidity_percent"] == "weathernext"
    assert sources["condition"] == "weathernext"
    assert sources["sunrise"] == "weathernext"


def test_open_meteo_primary_is_not_supplemented(monkeypatch):
    fc = _wn_forecast()
    fc.provenance = ForecastProvenance(requested_source="auto", selected_source=ProviderName.OPEN_METEO)
    called = []
    monkeypatch.setattr(fs, "fetch_supplement", lambda *a, **k: called.append(1) or _supplement_payload())
    sources = fs.supplement_forecast(fc, 22.3, 70.8)
    assert not called
    assert sources["_supplement"]["attempted"] is False
    assert fc.current.humidity_percent is None


def test_disabled_by_env(monkeypatch):
    monkeypatch.setenv("WEATHER_SUPPLEMENT_ENABLED", "0")
    fc = _wn_forecast()
    called = []
    monkeypatch.setattr(fs, "fetch_supplement", lambda *a, **k: called.append(1) or _supplement_payload())
    sources = fs.supplement_forecast(fc, 22.3, 70.8)
    assert not called and sources["_supplement"]["enabled"] is False
    assert sources["humidity_percent"] is None


def test_fetch_failure_leaves_primary_intact(monkeypatch):
    fc = _wn_forecast()
    failing = {"provider": "open_meteo", "current": {}, "hourly": {}, "daily": {}, "air_quality": None,
               "timezone": None, "errors": [{"call": "forecast", "reason": "Weather upstream timed out", "status_code": 504}]}
    sources = fs.supplement_forecast(fc, 22.3, 70.8, supplement=failing)
    assert fc.current.temperature_c == 27.0
    assert fc.current.humidity_percent is None
    assert sources["humidity_percent"] is None
    assert sources["_supplement"]["errors"][0]["status_code"] == 504
    assert fc.location["timezone"] == "UTC+5 (solar approximation)"


def test_resupplementing_a_cached_forecast_keeps_attribution():
    fc = _wn_forecast()
    fs.supplement_forecast(fc, 22.3, 70.8, supplement=_supplement_payload())
    # Second request served from the shared cache object: values are already
    # present, so nothing is "filled" again — but attribution must survive.
    sources = fs.supplement_forecast(fc, 22.3, 70.8, supplement=_supplement_payload())
    assert sources["humidity_percent"] == "open_meteo"
    assert sources["sunrise"] == "open_meteo"
    assert sources["hourly_condition"] == "open_meteo"
    assert sources["temperature_c"] == "weathernext"


def test_fetch_supplement_parses_open_meteo_and_caches(monkeypatch):
    calls = []

    def fake_get_json(url, params, timeout=12.0):
        calls.append(url)
        if "air-quality" in url:
            return {"current": {"european_aqi": 37, "us_aqi": 51, "pm2_5": 12.1, "pm10": 30.0, "time": "2026-09-19T15:30"}}
        return {
            "timezone": "Asia/Kolkata",
            "utc_offset_seconds": 19800,
            "current": {"time": "2026-09-19T15:30", "apparent_temperature": 33.0, "relative_humidity_2m": 64,
                        "weather_code": 3, "wind_direction_10m": 240, "surface_pressure": 1001.0,
                        "pressure_msl": 1007.2, "cloud_cover": 90, "uv_index": 2.5},
            "hourly": {"time": ["2026-09-19T15:00", "2026-09-19T16:00"], "weather_code": [3, 61],
                       "relative_humidity_2m": [64, 70], "cloud_cover": [90, 95], "uv_index": [2.5, 1.0],
                       "apparent_temperature": [33.0, 31.5]},
            "daily": {"time": ["2026-09-19"], "sunrise": ["2026-09-19T06:32"], "sunset": ["2026-09-19T18:47"],
                      "uv_index_max": [9.2], "weather_code": [61]},
        }

    monkeypatch.setattr(fs, "get_json", fake_get_json)
    out = fs.fetch_supplement(22.3, 70.8, forecast_days=3)
    assert out["errors"] == []
    assert out["timezone"] == "Asia/Kolkata"
    assert out["current"]["pressure_hpa"] == 1007.2 and out["current"]["pressure_type"] == "msl"
    assert out["current"]["condition"] == "Overcast"
    # 15:30 IST == 10:00 UTC, 15:00 IST == 09:30 UTC -> local naive converted with the offset
    assert "2026-09-19T10:00:00+00:00" == out["current"]["time_utc"].isoformat()
    assert out["hourly"]["2026-09-19T09:30:00+00:00"]["condition"] == "Overcast"
    assert out["daily"]["2026-09-19"]["sunrise"] == "2026-09-19T06:32"
    assert out["air_quality"]["european_aqi"] == 37 and out["air_quality"]["pm2_5"] == 12.1
    assert len(calls) == 2

    again = fs.fetch_supplement(22.31, 70.79, forecast_days=3)  # same 0.1 deg cell
    assert again["cache_hit"] is True and len(calls) == 2


def test_is_degraded_ignores_unconfigured_providers():
    assert fs.is_degraded([{"provider": "imd", "reason": "missing_credentials"}]) is False
    assert fs.is_degraded([{"provider": "imd", "reason": "credentials_missing_credentials"}]) is False
    assert fs.is_degraded([{"provider": "weathernext", "reason": "permission_denied"}]) is True
    assert fs.is_degraded([{"provider": "weathernext", "reason": "query_timeout"}]) is True
    assert fs.is_degraded([], is_stale=True) is True
    assert fs.is_degraded([]) is False


# Route integration for installed providers is in test_mobile_contract.py.
