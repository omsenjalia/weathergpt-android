"""Health, diagnostics, and telemetry endpoints."""

from __future__ import annotations

import os
import platform
import sys
import time
from datetime import datetime

from fastapi import APIRouter, HTTPException, Query, Request
from fastapi.concurrency import run_in_threadpool
from fastapi.responses import JSONResponse

from schemas import SandboxRequest
from services.fusion import PROVIDER_WEIGHTS, configured_providers, fuse_current_weather
from services.config import get_config
from services.forecast import get_forecast_service
from services.forecast_cache import get_cache as get_forecast_cache
from state import RECENT_LOGS, START_DATETIME, START_TIME

try:
    import psutil
except ImportError:
    psutil = None

router = APIRouter(tags=["dev"])

CLIENTS = ["weathergpt-android"]

@router.get("/health")
@router.get("/health/", include_in_schema=False)
async def health():
    return {"status": "ok", "clients": CLIENTS, "uptime_s": round(time.time() - START_TIME, 1)}

@router.get("/fusion")
async def fusion_inspector(
    lat: float = Query(..., description="Latitude"),
    lon: float = Query(..., description="Longitude"),
):
    """Server-side ensemble fusion for the given coordinates."""
    fused = await run_in_threadpool(fuse_current_weather, lat, lon)
    if fused.get("error"):
        raise HTTPException(status_code=502, detail=fused["error"])
    return {
        "lat": lat,
        "lon": lon,
        "priority_legacy": ["Open-Meteo (ECMWF)", "AccuWeather", "WeatherAPI.com", "Tomorrow.io", "OpenWeatherMap"],
        "priority_new": [p.value for p in get_config().provider_priority],
        "configured_providers": configured_providers(),
        **fused,
    }

@router.get("/dev/forecast")
async def dev_forecast_health(
    lat: float = Query(22.0, description="Sample lat"),
    lon: float = Query(72.0, description="Sample lon"),
):
    """Source health, freshness/coverage, fallback reasons, cache diagnostics."""
    def _check():
        service = get_forecast_service()
        cache = get_forecast_cache()
        result = service.select_forecast(lat=lat, lon=lon, product="forecast", requested_source="auto", mode="everyone")
        return {
            "sample_location": {"lat": lat, "lon": lon},
            "selection": {
                "selected_source": result.selected_source.value,
                "fallback_reasons": result.fallback_reasons,
                "is_stale": result.is_stale,
                "error": result.error,
                "has_forecast": result.forecast is not None,
                "provenance": result.forecast.provenance.to_dict() if result.forecast else None,
            },
            "provider_health": {
                name.value: {
                    "configured": provider.is_configured(),
                    "consecutive_failures": provider._consecutive_failures,
                    "circuit_breaker": provider.should_circuit_break(),
                }
                for name, provider in service.providers.items()
            },
            "cache": cache.stats(),
            "generated_at": datetime.now().isoformat(),
        }
    return await run_in_threadpool(_check)

@router.post("/dev/sandbox")
@router.post("/dev/sandbox/", include_in_schema=False)
async def sandbox_test(request: SandboxRequest):
    from agent import GROQ_MODEL, run_weather_agent

    start = time.time()
    try:
        response = await run_in_threadpool(
            run_weather_agent, request.prompt, request.location, request.language
        )
        return {
            "status": "success",
            "duration_ms": round((time.time() - start) * 1000, 2),
            "prompt": request.prompt,
            "location": request.location,
            "language": request.language,
            "response": response,
            "model_used": GROQ_MODEL,
            "timestamp": datetime.now().isoformat(),
        }
    except Exception as exc:
        return JSONResponse(
            status_code=500,
            content={
                "status": "error",
                "duration_ms": round((time.time() - start) * 1000, 2),
                "error": str(exc),
                "timestamp": datetime.now().isoformat(),
            },
        )

@router.get("/dev")
@router.get("/dev/", include_in_schema=False)
async def dev_diagnostics(http_request: Request):
    from agent import GROQ_MODEL, TOOLS

    mem_mb: float | str = "N/A"
    cpu_pct: float | str = "N/A"
    if psutil:
        try:
            proc = psutil.Process(os.getpid())
            mem_mb = round(proc.memory_info().rss / (1024 * 1024), 2)
            cpu_pct = proc.cpu_percent(interval=None)
        except Exception:
            pass

    app = http_request.app
    endpoints = []
    for route in app.routes:
        path = getattr(route, "path", None)
        if not path or not getattr(route, "include_in_schema", True):
            continue
        methods = getattr(route, "methods", None)
        endpoints.append(f"{path} [{','.join(sorted(methods)) if methods else 'GET'}]")

    def _has(*names: str) -> bool:
        return any(os.getenv(n) and not os.getenv(n, "").startswith("your_") for n in names)

    cfg = get_config()

    return {
        "status": "ok",
        "timestamp": datetime.now().isoformat(),
        "server_start_time": START_DATETIME,
        "uptime_seconds": round(time.time() - START_TIME, 2),
        "clients": CLIENTS,
        "system": {
            "platform": platform.platform(),
            "python_version": sys.version.split()[0],
            "process_pid": os.getpid(),
            "memory_usage_mb": mem_mb,
            "cpu_percent": cpu_pct,
        },
        "llm_config": {"model": GROQ_MODEL, "has_groq_key": _has("GROQ_API_KEY")},
        "provider_keys_status": {
            "groq_api_key": _has("GROQ_API_KEY"),
            "weatherapi_key": _has("WEATHERAPI_KEY", "VITE_WEATHERAPI_KEY"),
            "tomorrow_key": _has("TOMORROW_KEY", "VITE_TOMORROW_KEY"),
            "openweather_key": _has("OPENWEATHER_KEY", "VITE_OPENWEATHER_KEY"),
            "accuweather_key": _has("ACCUWEATHER_KEY", "VITE_ACCUWEATHER_KEY"),
            "imd_api_key": _has("IMD_API_KEY"),
            "imd_jwt_token": _has("IMD_JWT_TOKEN"),
        },
        "fusion": {
            "weights": PROVIDER_WEIGHTS,
            "configured_providers": configured_providers(),
            "priority": [p.value for p in cfg.provider_priority],
        },
        "forecast_cache": get_forecast_cache().stats(),
        "registered_endpoints": endpoints,
        "registered_ai_tools": [getattr(t, "name", str(t)) for t in TOOLS],
        "recent_logs": list(RECENT_LOGS),
    }
