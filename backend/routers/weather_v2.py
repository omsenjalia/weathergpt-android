"""V2 Weather routes providing unified endpoint for mobile client."""

from __future__ import annotations

from typing import Any, Optional
from fastapi import APIRouter, HTTPException, Query
from fastapi.concurrency import run_in_threadpool

from routers.mobile import get_weather

router = APIRouter(prefix="/v2", tags=["weather_v2"])

@router.get("/weather")
async def v2_weather(
    lat: float = Query(..., ge=-90.0, le=90.0),
    lon: float = Query(..., ge=-180.0, le=180.0),
    language: str = Query("en"),
    mode: str = Query("everyone"),
    requested_source: str = Query("auto"),
    forecast_days: int = Query(7, ge=1, le=16),
):
    """V2 weather endpoint routing directly to the mobile weather service with full provenance."""
    return await get_weather(
        lat=lat,
        lon=lon,
        language=language,
        mode=mode,
        source=requested_source,
    )
