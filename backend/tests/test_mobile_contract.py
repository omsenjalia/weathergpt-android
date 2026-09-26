"""Regression coverage for the Android/monorepo integration, without live APIs."""
from datetime import datetime, timezone
import json
from pathlib import Path
import re

import pytest
from fastapi.testclient import TestClient
from main import app
from services.forecast import get_forecast_service
from services.forecast_models import ProviderName
from services.providers.base import ProviderResult

client = TestClient(app)


@pytest.mark.parametrize("path", ["/weather", "/v2/weather"])
def test_home_contract_and_horizons(path, offline_weather):
    response = client.get(path, params={"lat": 23.02, "lon": 72.57, "forecast_days": 5, "hourly_hours": 48})
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["temperature_c"] == 25
    assert body["weather_code"] == 0  # clear sky is not missing
    assert body["uv_index"] == 6
    assert len(body["hourly"]) == 48 and len(body["forecast"]) == 5
    assert body["selected_source"] == "open_meteo"
    assert body["requested_source"] == "auto"
    assert body["location"]["utc_offset_seconds"] == 0
    assert body["provenance"]["selected_source"] == "open_meteo"
    assert response.headers["X-Request-ID"]


@pytest.mark.parametrize("path", ["/weather", "/v2/weather", "/advisory"])
def test_pins_never_silently_fall_back(path, offline_weather):
    key = "source" if path == "/advisory" else "requested_source"
    response = client.get(path, params={"lat": 23, "lon": 72, key: "imd"})
    assert response.status_code == 502
    assert response.json()["detail"]["requested_source"] == "imd"


@pytest.mark.parametrize("path", ["/weather", "/v2/weather", "/advisory"])
def test_removed_provider_is_rejected(path):
    key = "source" if path == "/advisory" else "requested_source"
    assert client.get(path, params={"lat": 23, "lon": 72, key: "weathernext"}).status_code == 422


def test_weather_health_and_app_endpoint_inventory():
    data = client.get("/v2/weather/health").json()
    assert data["check"] == "configuration_only"
    assert data["provider_priority"] == ["imd", "accuweather", "open_meteo"]
    assert data["provider_health"]["imd"]["implementation"] == "pending"
    endpoints = Path(__file__).parents[2] / "app/lib/core/constants/api_endpoints.dart"
    declared = re.findall(r"static const \w+ = '([^']+)'", endpoints.read_text())
    assert set(declared) <= set(app.openapi()["paths"])


def test_nullable_weather_and_advisory(offline_weather):
    offline_weather["current"].pop("weather_code")
    offline_weather["daily"]["precipitation_probability_max"] = [None] * 8
    body = client.get("/v2/weather", params={"lat": 23, "lon": 72}).json()
    assert body["rain_probability"] is None
    assert body["weather_code"] is None
    advisory = client.get("/advisory", params={"lat": 23, "lon": 72, "days": 3})
    assert advisory.status_code == 200
    first = advisory.json()["windows"][0]
    assert first["suitability"] == "neutral"
    assert first["reasons"] == ["insufficient_data"]
    assert advisory.json()["ai"]["applied"] is False


def test_location_local_hours_are_converted_to_utc(offline_weather):
    offline_weather["timezone"] = "Asia/Kolkata"
    offline_weather["utc_offset_seconds"] = 19800
    offline_weather["hourly"]["time"] = ["2026-09-26T12:00"]
    result = get_forecast_service().select_forecast(lat=23, lon=72, requested_source="open_meteo")
    assert result.forecast.hourly[0].time_utc == datetime(2026, 9, 26, 6, 30, tzinfo=timezone.utc)
    assert result.forecast.daily[0]["wind_kmh_max"] == 12


def test_total_upstream_failure_is_502(offline_weather, monkeypatch):
    provider = get_forecast_service().providers[ProviderName.OPEN_METEO]
    monkeypatch.setattr(provider, "fetch", lambda **kwargs: ProviderResult(success=False, error="offline"))
    response = client.get("/v2/weather", params={"lat": 23, "lon": 72})
    assert response.status_code == 502
    assert response.json()["detail"]["status"] == "unavailable"


def test_agent_success_path_preserves_reply_and_farm_context(monkeypatch):
    import agent
    seen = {}
    monkeypatch.setattr(agent, "has_llm", lambda: True)
    def answer(*args, **kwargs):
        seen.update(kwargs)
        return "**Forecast guidance**"
    monkeypatch.setattr(agent, "run_weather_agent", answer)
    response = client.post("/chat", json={
        "message": "Should I irrigate wheat?", "mode": "farmer", "crop": "Wheat",
        "growth_stage": "Flowering", "soil": "Clay", "irrigation": "Drip",
    })
    assert response.status_code == 200, response.text
    assert response.json()["meta"]["path"] == "agent"
    assert response.json()["response"] == "**Forecast guidance**"
    assert seen["farm_context"]["soil"] == "Clay"


def test_chat_pin_propagates_to_both_tools(offline_weather):
    response = client.post("/chat", json={
        "message": "weather now", "location": "Ahmedabad", "lat": 23, "lon": 72,
        "requested_source": "imd",
    })
    assert response.status_code == 200
    body = response.json()
    assert body["meta"]["path"] == "pinned"
    assert "trouble reaching" in body["response"]
    assert "open_meteo" not in body["response"]


def test_config_matches_actual_selection(monkeypatch):
    from services.config import load_app_config
    monkeypatch.setenv("GROQ_MODEL", "configured-model")
    monkeypatch.setenv("WEATHER_PROVIDER_PRIORITY", "open_meteo,accuweather")
    assert load_app_config().default_model == "configured-model"
    assert get_forecast_service()._get_ordered_providers() == [ProviderName.OPEN_METEO, ProviderName.ACCUWEATHER]
    with pytest.raises(ValueError):
        get_forecast_service()._get_ordered_providers("weathernext")


def test_research_archive_and_comparison(offline_weather):
    response = client.get("/historical", params={"lat": 23, "lon": 72, "start_year": 2020, "end_year": 2020})
    assert response.status_code == 200
    assert response.json()["points"] == [{"year": 2020, "value": 6}]
    response = client.get("/comparison", params={"locations": "A,23,72;B,22,73", "start_year": 2020, "end_year": 2020})
    assert response.status_code == 200
    assert len(response.json()["locations"]) == 2


def test_vercel_entrypoint_and_routing():
    from api.index import app as vercel_app
    assert vercel_app is app
    config = json.loads((Path(__file__).parents[1] / "vercel.json").read_text())
    assert config["rewrites"][0]["destination"] == "/api/index"


def test_comparison_preserves_geocoder_labels_with_commas(offline_weather):
    response = client.get("/comparison", params={
        "locations": "Ahmedabad, Gujarat, India,23,72;Pune, Maharashtra, India,18,74",
        "start_year": 2020, "end_year": 2020,
    })
    assert response.status_code == 200
    assert response.json()["locations"][0]["name"] == "Ahmedabad, Gujarat, India"


def test_explicit_persona_is_authoritative():
    from schemas import ChatRequest
    assert ChatRequest(message="hello", farmer_mode=True).mode == "farmer"
    everyone = ChatRequest(message="hello", mode="everyone", farmer_mode=True)
    assert everyone.mode == "everyone" and everyone.farmer_mode is False
    assert ChatRequest(message="hello", mode="farmer").farmer_mode is True


def test_supplement_switch_reaches_shared_service(monkeypatch, offline_weather):
    from services import forecast_supplement
    calls = []
    monkeypatch.setattr(forecast_supplement, "supplement_forecast", lambda *args, **kwargs: calls.append(kwargs) or {"test": "open_meteo"})
    raw = client.get("/v2/weather", params={"lat": 23, "lon": 72, "supplement": "false"})
    assert raw.status_code == 200 and not calls
    assert raw.json()["field_sources"] == {}
    enriched = client.get("/v2/weather", params={"lat": 23, "lon": 72, "forecast_days": 3})
    assert enriched.status_code == 200
    assert calls == [{"forecast_days": 3}]
    assert enriched.json()["field_sources"] == {"test": "open_meteo"}


def test_agent_timeout_does_not_wait_for_worker(monkeypatch):
    import agent
    from schemas import ChatRequest
    from services.chat import run_chat
    import time
    monkeypatch.setattr(agent, "has_llm", lambda: True)
    monkeypatch.setenv("CHAT_TIMEOUT_SECONDS", "0.01")
    monkeypatch.setattr(agent, "run_weather_agent", lambda *args, **kwargs: time.sleep(0.3) or "late")
    monkeypatch.setattr(agent, "run_deterministic_telemetry_fallback", lambda *args, **kwargs: "fallback")
    started = time.monotonic()
    result = run_chat(ChatRequest(message="Explain why the forecast changed"))
    assert time.monotonic() - started < 0.2
    assert result.response == "fallback"


def test_flutter_fixture_matches_backend_wire_fields(offline_weather):
    fixture = json.loads((Path(__file__).parents[2] / "app/test/fixtures/weather_android.json").read_text())
    body = client.get("/v2/weather", params={"lat": 23.02, "lon": 72.57, "forecast_days": 1, "hourly_hours": 2}).json()
    assert body.keys() == fixture.keys()
    for key in ("temperature_c", "weather_code", "humidity", "wind_kmh", "uv_index", "aqi", "selected_source"):
        assert body[key] == fixture[key]
    assert body["hourly"][0].keys() == fixture["hourly"][0].keys()
    assert body["forecast"][0].keys() == fixture["forecast"][0].keys()
