"""Shared multi-provider forecast service.

Implements selection priority: IMD -> AccuWeather -> Open-Meteo.
Ensures transparent fallback, provenance tracking, and data integrity.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any, Optional

from services.config import get_config
from services.forecast_models import (
    ForecastProvenance,
    FreshnessStatus,
    NormalizedForecast,
    ProductType,
    ProviderCapability,
    ProviderName,
    SELECTION_POLICY_VERSION,
)
from services.providers.base import BaseForecastProvider, ProviderResult
from services.providers.imd import IMDProvider
from services.providers.accuweather import AccuWeatherProvider
from services.providers.open_meteo import OpenMeteoProvider

logger = logging.getLogger(__name__)

@dataclass
class SelectionResult:
    """Outcome of provider selection."""
    selected_source: ProviderName
    forecast: Optional[NormalizedForecast] = None
    provenance: Optional[ForecastProvenance] = None
    fallback_reasons: list[dict] = field(default_factory=list)
    success: bool = False
    error: Optional[str] = None
    is_stale: bool = False

    @property
    def requested_source(self) -> str:
        return self.provenance.requested_source if self.provenance else "auto"

class ForecastService:
    """Implements ordered provider selection with freshness and capability checks."""

    def __init__(self):
        self.providers: dict[ProviderName, BaseForecastProvider] = {
            ProviderName.IMD: IMDProvider(),
            ProviderName.ACCUWEATHER: AccuWeatherProvider(),
            ProviderName.OPEN_METEO: OpenMeteoProvider(),
        }
        self.policy_version = SELECTION_POLICY_VERSION

    def _get_ordered_providers(self, requested_source: str = "auto") -> list[ProviderName]:
        """Get provider order based on requested source and defaults."""
        from schemas import normalize_source

        source = normalize_source(requested_source)
        if source != "auto":
            return [ProviderName(source)]
        return list(get_config().provider_priority)

    def select_forecast(
        self,
        lat: float,
        lon: float,
        product: str = "forecast",
        requested_source: str = "auto",
        mode: str = "everyone",
        forecast_days: int = 7,
        allow_stale: bool = False,
        **kwargs,
    ) -> SelectionResult:
        """Select forecast using ordered provider chain."""
        ordered = self._get_ordered_providers(requested_source)
        fallback_reasons: list[dict] = []
        last_stale_forecast: Optional[NormalizedForecast] = None
        last_stale_provider: Optional[ProviderName] = None

        for provider_name in ordered:
            provider = self.providers.get(provider_name)
            if not provider:
                continue

            if not provider.is_configured():
                fallback_reasons.append({
                    "provider": provider_name.value,
                    "reason_code": "not_configured",
                    "detail": f"{provider_name.value} API key/credentials not configured",
                })
                continue

            eligible, inelig_reason = provider.is_eligible(product, lat, lon)
            if not eligible:
                fallback_reasons.append({
                    "provider": provider_name.value,
                    "reason_code": "ineligible",
                    "detail": inelig_reason or "Location/product not eligible",
                })
                continue

            try:
                result = provider.fetch(lat=lat, lon=lon, product=product, forecast_days=forecast_days, **kwargs)
                if result.success and result.forecast:
                    if result.is_stale:
                        if allow_stale and last_stale_forecast is None:
                            last_stale_forecast = result.forecast
                            last_stale_provider = provider_name
                        fallback_reasons.append({
                            "provider": provider_name.value,
                            "reason_code": "stale",
                            "detail": "Data exceeded freshness budget",
                        })
                        continue

                    # Success with fresh data
                    provenance = ForecastProvenance(
                        requested_source=requested_source,
                        selected_source=provider_name,
                        selection_policy_version=self.policy_version,
                        product=ProductType(product) if product in [p.value for p in ProductType] else ProductType.FORECAST,
                        model=None,
                        init_time_utc=result.forecast.provenance.init_time_utc if result.forecast.provenance else None,
                        served_at_utc=datetime.now(timezone.utc),
                        requested_lat=lat,
                        requested_lon=lon,
                        sampled_lat=result.forecast.location.get("lat", lat) if result.forecast.location else lat,
                        sampled_lon=result.forecast.location.get("lon", lon) if result.forecast.location else lon,
                        is_stale=False,
                        freshness_status=FreshnessStatus.FRESH,
                        fallback_reasons=fallback_reasons,
                        sources=[provider_name.value],
                    )

                    result.forecast.provenance = provenance
                    result.forecast.mode = mode

                    return SelectionResult(
                        selected_source=provider_name,
                        forecast=result.forecast,
                        provenance=provenance,
                        fallback_reasons=fallback_reasons,
                        success=True,
                    )
                else:
                    fallback_reasons.append({
                        "provider": provider_name.value,
                        "reason_code": result.error_code or "fetch_failed",
                        "detail": result.error or "Unknown fetch error",
                    })
            except Exception as e:
                logger.warning(f"Error fetching from {provider_name.value}: {e}")
                fallback_reasons.append({
                    "provider": provider_name.value,
                    "reason_code": "exception",
                    "detail": str(e),
                })

        # Check stale fallback if allowed
        if allow_stale and last_stale_forecast and last_stale_provider:
            return SelectionResult(
                selected_source=last_stale_provider,
                forecast=last_stale_forecast,
                fallback_reasons=fallback_reasons,
                success=True,
                is_stale=True,
            )

        return SelectionResult(
            selected_source=ProviderName.UNAVAILABLE,
            fallback_reasons=fallback_reasons,
            success=False,
            error="All configured providers failed or were ineligible",
        )

_forecast_service: Optional[ForecastService] = None

def get_forecast_service() -> ForecastService:
    global _forecast_service
    if _forecast_service is None:
        _forecast_service = ForecastService()
    return _forecast_service
