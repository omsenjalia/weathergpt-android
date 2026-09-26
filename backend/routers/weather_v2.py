"""Android v2 facade over the shared, provider-aware weather service."""
from datetime import datetime, timezone

from fastapi import APIRouter, Query

from routers.mobile import get_weather
from services.config import get_config
from services.forecast import get_forecast_service
from services.forecast_models import SELECTION_POLICY_VERSION

router = APIRouter(prefix="/v2", tags=["weather_v2"])


@router.get("/weather")
async def v2_weather(
    lat: float = Query(..., ge=-90, le=90),
    lon: float = Query(..., ge=-180, le=180),
    language: str = Query("en"),
    mode: str = Query("everyone"),
    requested_source: str = Query("auto"),
    forecast_days: int = Query(7, ge=1, le=16),
    hourly_hours: int = Query(48, ge=1, le=168),
    supplement: bool = Query(True),
):
    # Supply EVERY argument: a direct Python call does not resolve Query defaults.
    return await get_weather(
        lat=lat, lon=lon, language=language, mode=mode,
        source="auto", requested_source=requested_source,
        forecast_days=forecast_days, hourly_hours=hourly_hours, supplement=supplement,
    )


@router.get("/weather/health")
async def weather_health(
    lat: float = Query(22, ge=-90, le=90),
    lon: float = Query(72, ge=-180, le=180),
):
    """Configuration/eligibility only; not proof of upstream connectivity."""
    providers = {}
    for name, provider in get_forecast_service().providers.items():
        eligible, reason = provider.is_eligible("forecast", lat, lon)
        capability = provider.capability
        providers[name.value] = {
            "configured": provider.is_configured(),
            "eligible": eligible,
            "reason": reason,
            "implementation": "pending" if name.value == "imd" else "available",
            "capability": {
                "max_days": capability.max_forecast_days,
                "has_ensemble": capability.has_ensemble,
                "freshness_budget_hours": capability.freshness_budget_hours,
            },
        }
    return {
        "status": "ok",
        "check": "configuration_only",
        "selection_policy_version": SELECTION_POLICY_VERSION,
        "provider_priority": [p.value for p in get_config().provider_priority],
        "provider_health": providers,
        "generated_at": datetime.now(timezone.utc).isoformat(),
    }
