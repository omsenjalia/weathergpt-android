"""Offline boundaries: exercise real routes, selection, normalization and parsing."""
from copy import deepcopy
from datetime import datetime, timedelta, timezone

import pytest


@pytest.fixture(autouse=True)
def isolated_config(monkeypatch):
    from services import config, forecast
    for key in ("GROQ_API_KEY", "ACCUWEATHER_KEY", "VITE_ACCUWEATHER_KEY", "IMD_API_KEY", "IMD_JWT_TOKEN", "WEATHER_PROVIDER_PRIORITY"):
        monkeypatch.delenv(key, raising=False)
    config.reset_config_cache()
    monkeypatch.setattr(forecast, "_forecast_service", None)
    yield
    config.reset_config_cache()


@pytest.fixture
def offline_weather(monkeypatch):
    from services.providers import open_meteo
    from services import forecast_supplement
    from routers import mobile, dev
    import tools

    now = datetime.now(timezone.utc).replace(minute=0, second=0, microsecond=0)
    times = [now + timedelta(hours=h) for h in range(192)]
    dates = [(now + timedelta(days=d)).date().isoformat() for d in range(8)]
    raw = {
        "timezone": "UTC", "utc_offset_seconds": 0,
        "current": {"temperature_2m": 25, "relative_humidity_2m": 65,
                    "weather_code": 0, "wind_speed_10m": 8},
        "hourly": {
            "time": [t.isoformat() for t in times],
            "temperature_2m": [25] * 192, "relative_humidity_2m": [65] * 192,
            "precipitation_probability": [10] * 192, "precipitation": [0] * 192,
            "wind_speed_10m": [8] * 192, "weather_code": [0] * 192,
        },
        "daily": {
            "time": dates, "temperature_2m_max": [30] * 8,
            "temperature_2m_min": [20] * 8, "precipitation_probability_max": [10] * 8,
            "rain_sum": [0] * 8, "wind_speed_10m_max": [12] * 8,
            "weather_code": [0] * 8, "uv_index_max": [6] * 8,
            "sunrise": [f"{d}T06:00" for d in dates],
            "sunset": [f"{d}T18:00" for d in dates],
        },
    }

    def get_json(url, params, **kwargs):
        if "air-quality" in url:
            return {"current": {"european_aqi": 30, "pm2_5": 8}}
        if "archive" in url:
            return {"daily": {"time": ["2020-01-01", "2020-01-02"], params["daily"]: [2, 4]}}
        return deepcopy(raw)

    monkeypatch.setattr(open_meteo, "get_json", get_json)
    monkeypatch.setattr(forecast_supplement, "get_json", get_json)
    monkeypatch.setattr(mobile, "get_json", get_json)
    monkeypatch.setattr(tools, "_geocode", lambda city: {"latitude": 23.02, "longitude": 72.57, "city": city})
    monkeypatch.setattr(dev, "fuse_current_weather", lambda *a: {
        "temperature_2m": 25, "providers": ["Open-Meteo (ECMWF)"],
        "weights": {"Open-Meteo (ECMWF)": 2.0},
    })
    return raw
