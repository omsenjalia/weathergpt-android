"""Mobile app REST endpoints (Flutter `weathergpt-app`).

Routes match `docs/web_app_api_contract.md` in weathergpt-app. Forecast structure, UV,
AQI and sun times come from shared forecast service with IMD ->
AccuWeather -> Open-Meteo priority. Legacy Open-Meteo direct path retained for
backward compatibility but now goes through forecast service.

Fixes:
- Heat handling uses worst-band merging, not unconditional caution override
- Hourly bands use data-sufficiency gate
- Advisory uses fixed deterministic baseline without an external decision overlay
"""

from __future__ import annotations

import os
from datetime import datetime, timezone
from typing import Any

from fastapi import APIRouter, HTTPException, Query
from fastapi.concurrency import run_in_threadpool

from services import advisory as advisory_ai
from services.fusion import fuse_current_weather
from services.open_meteo import (
    AIR_QUALITY_URL,
    ARCHIVE_URL,
    FORECAST_URL,
    UpstreamError,
    code_to_condition as _code_to_condition,
    extract_weather_code,
    get_json,
)
from services.forecast import get_forecast_service
from schemas import normalize_source

router = APIRouter(tags=["mobile"])


def _bounded(value: Any, low: float | None = None, high: float | None = None) -> float | None:
    """Return finite numeric upstream data, optionally constrained to a physical range."""
    try:
        number = float(value)
    except (TypeError, ValueError):
        return None
    if number != number or number in (float("inf"), float("-inf")):
        return None
    if low is not None and number < low or high is not None and number > high:
        return None
    return number


def _get_json(url: str, params: dict[str, Any], timeout: float = 12.0) -> dict[str, Any]:
    try:
        return get_json(url, params, timeout=timeout)
    except UpstreamError as exc:
        raise HTTPException(status_code=exc.status_code, detail=str(exc)) from exc


@router.get("/weather")
async def get_weather(
    lat: float = Query(..., ge=-90, le=90, description="Latitude (-90 to 90)"),
    lon: float = Query(..., ge=-180, le=180, description="Longitude (-180 to 180)"),
    language: str = Query("en", description="Preferred language code"),
    source: str = Query("auto", description="auto|imd|accuweather|open_meteo"),
    requested_source: str = Query("", description="Preferred alias of source (matches /v2/weather and /chat)"),
    mode: str = Query("everyone", description="everyone|farmer|researcher"),
    forecast_days: int = Query(7, ge=1, le=16),
    hourly_hours: int = Query(48, ge=1, le=168),
    supplement: bool = Query(True),
) -> dict[str, Any]:
    """Current conditions + today high/low + 3-day outlook for the Flutter home screens.

    Uses shared forecast service with IMD -> AccuWeather -> Open-Meteo.
    Explicit source pins bypass automatic substitution for researcher mode.
    """
    try:
        effective_source = normalize_source(requested_source or source or "auto")
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    return await run_in_threadpool(
        _build_weather_snapshot, lat, lon, language, effective_source, mode,
        forecast_days, hourly_hours, supplement,
    )


def _build_weather_snapshot(lat: float, lon: float, language: str, source: str = "auto", mode: str = "everyone", forecast_days: int = 7, hourly_hours: int = 48, supplement: bool = True) -> dict[str, Any]:
    # Try new forecast service first
    forecast_service = get_forecast_service()
    selection = forecast_service.select_forecast(
        lat=lat,
        lon=lon,
        product="forecast",
        requested_source=source,
        mode=mode,
        forecast_days=max(forecast_days, (hourly_hours + 23) // 24 + 1),
    )

    # If new service succeeds, use it
    if selection.forecast:
        fc = selection.forecast
        field_sources: dict[str, Any] = {}
        try:
            from services.forecast_supplement import supplement_forecast
            if supplement:
                field_sources = supplement_forecast(fc, lat, lon, forecast_days=forecast_days)
        except Exception as exc:  # secondary data must never break the primary answer
            field_sources = {"_supplement": {"attempted": True, "errors": [{"reason": f"exception_{type(exc).__name__}"}]}}
        # Build response from normalized forecast
        current = fc.current
        daily_list = fc.daily
        hourly_list = fc.hourly

        # Legacy compatibility: map to old structure but with provenance
        temp_c = current.temperature_c if current else None
        feels_c = current.feels_like_c if current else None
        humidity = current.humidity_percent if current else None
        wind_kmh = current.wind_speed_kmh if current else None
        pressure = current.pressure_hpa if current else None
        condition = current.condition if current else "Unknown"
        weather_code = current.weather_code if current else None

        # Air quality from forecast or best-effort
        aqi = None
        pm25 = None
        if fc.air_quality:
            aqi = fc.air_quality.get("european_aqi")
            pm25 = fc.air_quality.get("pm2_5")
        elif supplement:
            try:
                aq = _get_json(
                    AIR_QUALITY_URL,
                    {"latitude": lat, "longitude": lon, "current": "european_aqi,pm2_5", "timezone": "auto"},
                    timeout=8.0,
                )
                cur_aq = aq.get("current") or {}
                aqi = cur_aq.get("european_aqi")
                pm25 = cur_aq.get("pm2_5")
            except Exception:
                pass

        # Build hourly_out for legacy
        hourly_out = []
        cutoff = datetime.now(timezone.utc).replace(minute=0, second=0, microsecond=0)
        upcoming = [p for p in hourly_list if p.time_utc >= cutoff]
        for p in upcoming[:hourly_hours]:
            hourly_out.append({
                "time": p.time_utc.isoformat(),
                "temperature_c": p.temperature_c,
                "rain_probability": p.precipitation_probability,
                "precipitation_mm": p.precipitation_mm,
                "wind_kmh": p.wind_speed_kmh,
                "humidity": p.humidity_percent,
                "condition": p.condition,
                "weather_code": p.weather_code,
            })

        # Forecast 3-day
        forecast = []
        for d in daily_list[:forecast_days]:
            forecast.append({
                "date": d.get("date"),
                "high_c": d.get("high_c"),
                "low_c": d.get("low_c"),
                "rain_probability": d.get("rain_probability"),
                "rain_mm": d.get("rain_mm"),
                "condition": d.get("condition"),
                "weather_code": d.get("weather_code"),
                "wind_kmh_max": d.get("wind_kmh_max"),
                "sunrise": d.get("sunrise"),
                "sunset": d.get("sunset"),
                "uv_index_max": d.get("uv_index_max"),
                "covers_full_day": d.get("covers_full_day"),
                "precipitation_interval": d.get("precipitation_interval"),
            })

        # UV, sunrise/sunset from daily
        uv_index = None
        sunrise = None
        sunset = None
        if daily_list:
            uv_index = daily_list[0].get("uv_index") or daily_list[0].get("uv_index_max")
            sunrise = daily_list[0].get("sunrise")
            sunset = daily_list[0].get("sunset")

        temp_c = _bounded(temp_c, -100, 70)
        feels_c = _bounded(feels_c, -100, 80)
        humidity = _bounded(humidity, 0, 100)
        wind_kmh = _bounded(wind_kmh, 0, 500)
        pressure = _bounded(pressure, 800, 1200)

        return {
            "lat": lat,
            "lon": lon,
            "language": language,
            "temperature_c": temp_c,
            "feels_like_c": feels_c,
            "condition": condition,
            "weather_code": weather_code,
            "high_c": daily_list[0].get("high_c") if daily_list else None,
            "low_c": daily_list[0].get("low_c") if daily_list else None,
            "rain_probability": _bounded(daily_list[0].get("rain_probability") if daily_list else None, 0, 100),
            "wind_kmh": wind_kmh,
            "wind_direction": current.wind_direction_deg if current else None,
            "humidity": humidity,
            "pressure_hpa": pressure,
            "precipitation_mm": current.precipitation_mm if current else None,
            "uv_index": uv_index,
            "sunrise": sunrise,
            "sunset": sunset,
            "aqi": aqi,
            "pm2_5": pm25,
            "hourly": hourly_out,
            "timezone": fc.location.get("timezone", "auto"),
            "location": fc.location,
            "status": "ok",
            "selected_source": selection.selected_source.value,
            "forecast": forecast,
            "source": selection.selected_source.value,
            "requested_source": source,
            "selection_policy_version": fc.provenance.selection_policy_version,
            "providers_used": fc.provenance.sources,
            "fallback_reasons": selection.fallback_reasons,
            "provenance": fc.provenance.to_dict(),
            "field_sources": field_sources,
            "fetched_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
            "mode": mode,
        }

    # Never replace an explicit pin or conceal total upstream failure.
    raise HTTPException(status_code=502, detail={
        "status": "unavailable",
        "error": selection.error or "No forecast provider available",
        "requested_source": source,
        "fallback_reasons": selection.fallback_reasons,
    })


@router.get("/advisory")
async def get_advisory(
    lat: float = Query(..., ge=-90, le=90),
    lon: float = Query(..., ge=-180, le=180),
    crop: str = Query("", description="Optional crop name"),
    days: int = Query(3, ge=1, le=7),
    growth_stage: str = Query("", description="Optional crop growth stage (e.g. Flowering)"),
    soil: str = Query("", description="Optional soil type"),
    irrigation: str = Query("", description="Optional irrigation type"),
    source: str = Query("auto", description="Forecast source"),
    mode: str = Query("farmer", description="Mode for advisory"),
) -> dict[str, Any]:
    """Threshold-based farm advisory; no TypeSafe service is installed here."""
    try:
        source = normalize_source(source)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    # Use forecast service for data
    def _fetch_forecast():
        service = get_forecast_service()
        result = service.select_forecast(
            lat=lat,
            lon=lon,
            product="forecast",
            requested_source=source,
            mode=mode,
            forecast_days=days,
        )
        return result

    forecast_result = await run_in_threadpool(_fetch_forecast)

    if not forecast_result.forecast:
        raise HTTPException(status_code=502, detail={
            "status": "unavailable", "error": forecast_result.error,
            "requested_source": source,
            "fallback_reasons": forecast_result.fallback_reasons,
        })
    else:
        # Build data structure compatible with existing advisory code from normalized forecast
        fc = forecast_result.forecast
        # Map to old structure
        daily_time = [d.get("date") for d in fc.daily]
        daily_data = {
            "time": daily_time,
            "temperature_2m_max": [d.get("high_c") for d in fc.daily],
            "temperature_2m_min": [d.get("low_c") for d in fc.daily],
            "precipitation_probability_max": [d.get("rain_probability") for d in fc.daily],
            "rain_sum": [d.get("rain_mm") for d in fc.daily],
            "wind_speed_10m_max": [d.get("wind_kmh_max", d.get("wind_max")) for d in fc.daily],
            "weather_code": [d.get("weather_code") for d in fc.daily],
        }
        # Hourly
        # Group action windows in the forecast location's civil time, not UTC.
        from zoneinfo import ZoneInfo, ZoneInfoNotFoundError
        try:
            local_tz = ZoneInfo(fc.location.get("timezone") or "UTC")
        except (ZoneInfoNotFoundError, ValueError):
            local_tz = timezone.utc
        hourly_time = [p.time_utc.astimezone(local_tz).isoformat() for p in fc.hourly]
        hourly_data = {
            "time": hourly_time,
            "temperature_2m": [p.temperature_c for p in fc.hourly],
            "precipitation_probability": [p.precipitation_probability for p in fc.hourly],
            "precipitation": [p.precipitation_mm for p in fc.hourly],
            "wind_speed_10m": [p.wind_speed_kmh for p in fc.hourly],
            "weather_code": [p.weather_code for p in fc.hourly],
        }
        data = {"daily": daily_data, "hourly": hourly_data}

    daily = data.get("daily") or {}
    dates = daily.get("time") or []
    rain_probs = daily.get("precipitation_probability_max") or []
    rain_sums = daily.get("rain_sum") or []
    wind_max = daily.get("wind_speed_10m_max") or []
    highs = daily.get("temperature_2m_max") or []

    windows = []
    for i, date in enumerate(dates):
        rp = rain_probs[i] if i < len(rain_probs) else None
        rs = rain_sums[i] if i < len(rain_sums) else None
        wind = wind_max[i] if i < len(wind_max) else None
        high = highs[i] if i < len(highs) else None

        # Fixed: use worst-band merging, not unconditional override
        # Start with good, then apply worst of rain, wind, heat
        suitability = "good"
        notes = []
        best = "Best: 6–10 AM"

        if any(value is None for value in (rp, rs, wind, high)):
            windows.append({
                "date": date, "suitability": "neutral",
                "summary": "Insufficient forecast data — action suitability unavailable.",
                "best_window": "Unavailable", "rain_probability": rp,
                "rain_mm": rs, "wind_kmh_max": wind, "high_c": high,
                "reasons": ["insufficient_data"],
            })
            continue

        # Rain check
        if rp >= 70 or (isinstance(rs, (int, float)) and rs >= 10):
            suitability = advisory_ai.worse(suitability, "poor")
            notes.append("Heavy rain likely")
        elif rp >= 40 or (isinstance(wind, (int, float)) and wind >= 25):
            suitability = advisory_ai.worse(suitability, "caution")
            notes.append("Watch wind and showers")

        # Heat check - use worse merging, not unconditional
        if high is not None and high >= 40:
            suitability = advisory_ai.worse(suitability, "caution")
            notes.append("Heat stress risk")

        # Determine summary based on final suitability (worst)
        if suitability == "poor":
            note = "Heavy rain likely — avoid spraying and limit field work." if "Heavy rain" in " ".join(notes) else "Conditions unsafe — avoid spraying and limit field work."
            best = "Indoor / planning tasks"
        elif suitability == "caution":
            if "Heat stress" in " ".join(notes):
                note = "Heat stress risk — irrigate early morning or evening."
                best = "Avoid midday field work"
            else:
                note = "Workable with caution — watch wind and showers."
                best = "Plan for afternoon gaps"
        else:
            note = "Good day for field work."
            best = "Best: 6–10 AM"

        windows.append(
            {
                "date": date,
                "suitability": suitability,
                "summary": note,
                "best_window": best,
                "rain_probability": rp,
                "rain_mm": rs,
                "wind_kmh_max": wind,
                "high_c": high,
                "reasons": notes,
            }
        )

    crop_label = crop.strip() or "general crops"

    # Hourly activity bands for first two days
    hourly_by_date = advisory_ai.build_hourly_by_date((data.get("hourly") or {}), dates)
    for window in windows[:2]:
        window["hourly"] = hourly_by_date.get(str(window.get("date"))) or {}

    # AI advisory meta
    ai_meta: dict[str, Any] = {"enabled": False, "applied": False, "model": None}

    good_days = sum(1 for w in windows if w["suitability"] == "good")
    summary = (
        f"Advisory for {crop_label}: {good_days}/{len(windows)} day(s) look favourable "
        f"near ({lat:.2f}, {lon:.2f})."
    )
    return {
        "lat": lat,
        "lon": lon,
        "crop": crop_label,
        "summary": summary,
        "windows": windows,
        "advisory_engine": "system-one+thresholds" if ai_meta.get("applied") else "thresholds",
        "ai": ai_meta,
        "source": forecast_result.selected_source.value if 'forecast_result' in locals() and forecast_result.forecast else "open-meteo",
        "requested_source": source,
        "fallback_reasons": forecast_result.fallback_reasons if 'forecast_result' in locals() else [],
        "provenance": forecast_result.forecast.provenance.to_dict() if 'forecast_result' in locals() and forecast_result.forecast else None,
        "mode": mode,
    }


@router.get("/historical")
async def get_historical(
    lat: float = Query(..., ge=-90, le=90),
    lon: float = Query(..., ge=-180, le=180),
    metric: str = Query("rainfall", description="rainfall | temperature | humidity"),
    start_year: int = Query(2000, ge=1940, le=2100),
    end_year: int = Query(2024, ge=1940, le=2100),
) -> dict[str, Any]:
    """Yearly historical series via Open-Meteo archive (mobile researcher screens)."""
    if end_year < start_year:
        raise HTTPException(status_code=400, detail="end_year must be >= start_year")
    if end_year - start_year > 40:
        raise HTTPException(status_code=400, detail="Maximum range is 40 years")

    metric_key = metric.lower().strip()
    daily_var = {
        "rainfall": "precipitation_sum",
        "temperature": "temperature_2m_mean",
        "humidity": "relative_humidity_2m_mean",
    }.get(metric_key)
    if not daily_var:
        raise HTTPException(
            status_code=400,
            detail="metric must be one of: rainfall, temperature, humidity",
        )

    data = await run_in_threadpool(
        _get_json,
        ARCHIVE_URL,
        {
            "latitude": lat,
            "longitude": lon,
            "start_date": f"{start_year}-01-01",
            "end_date": f"{end_year}-12-31",
            "daily": daily_var,
            "timezone": "auto",
        },
        timeout=30.0,
    )
    daily = data.get("daily") or {}
    times = daily.get("time") or []
    values = daily.get(daily_var) or []

    buckets: dict[int, list[float]] = {}
    for t, v in zip(times, values):
        if v is None:
            continue
        try:
            year = int(str(t)[:4])
            buckets.setdefault(year, []).append(float(v))
        except (TypeError, ValueError):
            continue

    points = []
    for year in range(start_year, end_year + 1):
        vals = buckets.get(year)
        if not vals:
            continue
        if metric_key == "rainfall":
            value = round(sum(vals), 1)
        else:
            value = round(sum(vals) / len(vals), 2)
        points.append({"year": year, "value": value})

    return {
        "lat": lat,
        "lon": lon,
        "metric": metric_key,
        "start_year": start_year,
        "end_year": end_year,
        "points": points,
        "source": "open-meteo-archive",
    }


@router.get("/comparison")
async def get_comparison(
    locations: str = Query(
        ...,
        description="Semicolon-separated list: name,lat,lon;name2,lat2,lon2",
    ),
    metric: str = Query("rainfall"),
    start_year: int = Query(2015, ge=1940, le=2100),
    end_year: int = Query(2024, ge=1940, le=2100),
) -> dict[str, Any]:
    """Compare yearly metric across multiple named locations."""
    series = []
    for chunk in locations.split(";"):
        parts = [p.strip() for p in chunk.rsplit(",", 2)]
        if len(parts) != 3:
            continue
        name, lat_s, lon_s = parts
        try:
            lat_f, lon_f = float(lat_s), float(lon_s)
        except (TypeError, ValueError):
            continue
        if not (-90 <= lat_f <= 90 and -180 <= lon_f <= 180):
            continue
        hist = await get_historical(
            lat=lat_f,
            lon=lon_f,
            metric=metric,
            start_year=start_year,
            end_year=end_year,
        )
        series.append({"name": name, "lat": lat_f, "lon": lon_f, "points": hist["points"]})

    if not series:
        raise HTTPException(
            status_code=400,
            detail="Provide locations as name,lat,lon;name2,lat2,lon2",
        )

    return {
        "metric": metric.lower().strip(),
        "start_year": start_year,
        "end_year": end_year,
        "locations": series,
        "source": "open-meteo-archive",
    }
