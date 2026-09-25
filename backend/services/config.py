"""Application configuration loader."""

from __future__ import annotations

import os
from dataclasses import dataclass, field
from typing import Optional

from services.forecast_models import ProviderName

DEFAULT_PROVIDER_PRIORITY = [
    ProviderName.IMD,
    ProviderName.ACCUWEATHER,
    ProviderName.OPEN_METEO,
]

def _get_env(key: str, default: Optional[str] = None) -> Optional[str]:
    v = os.getenv(key)
    return v if v is not None and v != "" else default

def _int_env(key: str, default: int) -> int:
    try:
        return int(os.getenv(key, str(default)))
    except ValueError:
        return default

@dataclass(frozen=True)
class AppConfig:
    provider_priority: list[ProviderName] = field(default_factory=lambda: list(DEFAULT_PROVIDER_PRIORITY))
    open_meteo_url: str = "https://api.open-meteo.com/v1"
    groq_api_key: Optional[str] = None
    default_model: str = "openai/gpt-oss-120b"

def load_app_config() -> AppConfig:
    return AppConfig(
        groq_api_key=_get_env("GROQ_API_KEY"),
        default_model=_get_env("MODEL", "openai/gpt-oss-120b") or "openai/gpt-oss-120b",
    )

_config_cache: Optional[AppConfig] = None

def get_config() -> AppConfig:
    global _config_cache
    if _config_cache is None:
        _config_cache = load_app_config()
    return _config_cache

def reset_config_cache():
    global _config_cache
    _config_cache = None
