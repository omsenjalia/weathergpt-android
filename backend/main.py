"""WeatherGPT API — single FastAPI app serving mobile client.

    weathergpt-app (mobile, Flutter)   → POST /chat, GET /weather, /advisory, /historical, /comparison, /health

Layout
------
    main.py            app factory + middleware (this file)
    schemas.py         shared pydantic contracts
    state.py           uptime + recent-log ring buffer
    services/          open_meteo (baseline), fusion, forecast (IMD->AccuWeather->Open-Meteo),
                       config, chat, advisory
    routers/           chat, mobile, dev
    agent.py, tools.py LangGraph agent + telemetry tools

Run locally:  uvicorn main:app --host 0.0.0.0 --port 8888
"""

from __future__ import annotations

import time
import uuid

from dotenv import load_dotenv

load_dotenv()

from fastapi import FastAPI, Request  # noqa: E402
from fastapi.middleware.cors import CORSMiddleware  # noqa: E402
from fastapi.responses import JSONResponse  # noqa: E402

from routers import chat as chat_router  # noqa: E402
from routers import dev as dev_router  # noqa: E402
from routers import mobile as mobile_router
from routers import weather_v2 as weather_v2_router  # noqa: E402
from state import log_event  # noqa: E402
from services.config import get_config  # noqa: E402

API_VERSION = "2.1.0"
QUIET_PATHS = {"/health", "/health/", "/dev", "/dev/"}

CHAT_CONTRACT = {
    "request": {
        "message": "string (mobile single turn)",
        "messages": "[{role, content}] (conversation history)",
        "location": "string",
        "lat": "number optional (mobile)",
        "lon": "number optional (mobile)",
        "language": "en | hi | gu | mr | ta | te | bn | kn | ml",
        "farmer_mode": "bool",
        "crop": "string",
        "client": "mobile optional hint",
        "mode": "everyone|farmer|researcher",
        "requested_source": "auto|imd|accuweather|open_meteo",
    },
    "response": {
        "response": "markdown string",
        "meta": "{path, client, language, location, requested_source, selected_source, provenance}",
    },
}

def create_app() -> FastAPI:
    app = FastAPI(
        title="WeatherGPT API",
        version=API_VERSION,
        description=(
            "Backend server for **WeatherGPT Mobile** (Flutter).\n\n"
            "Forecast provider priority: **IMD → AccuWeather → Open-Meteo (fallback)**.\n"
            "Includes LangGraph Conversational ReAct Agent, Farmer Advisory Engine, "
            "and Multi-lingual weather telemetry."
        ),
    )

    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=False,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    @app.middleware("http")
    async def log_requests(request: Request, call_next):
        start = time.time()
        request_id = request.headers.get("x-request-id") or uuid.uuid4().hex
        try:
            response = await call_next(request)
        except Exception as exc:
            duration_ms = round((time.time() - start) * 1000, 2)
            log_event("ERROR", f"HTTP {request.method} {request.url.path} failed",
                      {"duration_ms": duration_ms, "request_id": request_id, "error": str(exc)})
            return JSONResponse(
                status_code=500,
                content={"detail": "Internal server error", "request_id": request_id},
                headers={"Access-Control-Allow-Origin": "*", "X-Request-ID": request_id},
            )
        if request.url.path not in QUIET_PATHS:
            log_event(
                "INFO",
                f"HTTP {request.method} {request.url.path} -> {response.status_code}",
                {"duration_ms": round((time.time() - start) * 1000, 2), "request_id": request_id},
            )
        response.headers["X-Request-ID"] = request_id
        return response

    app.include_router(chat_router.router)
    app.include_router(mobile_router.router)
    app.include_router(weather_v2_router.router)
    app.include_router(dev_router.router)

    @app.get("/", tags=["meta"])
    async def root():
        """Service index."""
        cfg = get_config()
        return {
            "service": "WeatherGPT API",
            "version": API_VERSION,
            "status": "ok",
            "clients": {
                "mobile": {"repo": "weathergpt-android",
                           "endpoints": ["/chat", "/weather", "/v2/weather", "/v2/weather/health", "/advisory", "/historical",
                                         "/comparison", "/fusion", "/health"]},
            },
            "provider_priority": {
                "current": [p.value for p in cfg.provider_priority],
                "default": ["imd", "accuweather", "open_meteo"],
                "policy_version": "1.0.0",
                "legacy_fusion": ["Open-Meteo (ECMWF)", "AccuWeather", "WeatherAPI.com",
                                  "Tomorrow.io", "OpenWeatherMap"],
            },
            "fusion_priority": ["Open-Meteo (ECMWF)", "AccuWeather", "WeatherAPI.com", "Tomorrow.io", "OpenWeatherMap"],
            "chat_contract": CHAT_CONTRACT,
        }

    log_event("INFO", "Backend server starting up...")
    return app

app = create_app()

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8888, reload=True)
