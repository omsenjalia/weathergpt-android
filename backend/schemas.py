"""Shared Pydantic models for WeatherGPT API contracts.

Single source of truth for both web and mobile clients.
Validated with parity against OpenAPI specs and client expectations.
"""

from __future__ import annotations

from typing import Any, Literal, Optional
from pydantic import BaseModel, Field, model_validator

LanguageKind = Literal["English", "Hindi", "Gujarati", "Marathi", "Tamil", "Telugu", "Bengali", "Kannada", "Malayalam", "Punjabi", "en", "hi", "gu", "mr", "ta", "te", "bn", "kn", "ml"]

ClientKind = Literal["web", "mobile", "unknown"]

AppMode = Literal["everyone", "farmer", "researcher"]

class ChatRequest(BaseModel):
    """Unified request contract."""
    message: Optional[str] = Field(None, description="Mobile / single-turn user query")
    messages: Optional[list[dict[str, Any]]] = Field(None, description="Web / multi-turn history: [{role, content}]")
    location: Optional[str] = Field(None, description="City / state / country label")
    lat: Optional[float] = Field(None, ge=-90.0, le=90.0, description="Latitude")
    lon: Optional[float] = Field(None, ge=-180.0, le=180.0, description="Longitude")
    language: Optional[str] = Field("English", description="Language name or BCP-47 / ISO code")
    farmer_mode: Optional[bool] = Field(False, description="Legacy flag; true maps to mode='farmer'")
    crop: Optional[str] = Field(None, description="Active crop context")
    growth_stage: Optional[str] = None
    soil: Optional[str] = None
    irrigation: Optional[str] = None
    client: Optional[str] = Field("auto", description="Client identifier: 'web' | 'mobile' | 'auto'")
    mode: Optional[str] = Field("everyone", description="Target experience mode: everyone | farmer | researcher")
    requested_source: str = Field(default="auto", description="auto|imd|accuweather|open_meteo")

    @model_validator(mode="after")
    def validate_request(self) -> "ChatRequest":
        msg = (self.message or "").strip()
        has_history = bool(self.messages and len(self.messages) > 0)
        if not msg and not has_history:
            raise ValueError("Either 'message' or non-empty 'messages' must be provided")

        if "mode" not in self.model_fields_set or self.mode is None:
            self.mode = "farmer" if self.farmer_mode else "everyone"
        elif self.mode not in ("everyone", "farmer", "researcher"):
            raise ValueError("mode must be everyone, farmer or researcher")

        self.farmer_mode = self.mode == "farmer"

        self.requested_source = normalize_source(self.requested_source)
        return self

class ChatMeta(BaseModel):
    path: str
    intent: Optional[str] = None
    intent_engine: Optional[str] = None
    intent_confidence: Optional[float] = None
    client: str
    language: str
    location: Optional[str] = None
    requested_source: Optional[str] = None
    selected_source: Optional[str] = None
    provenance: Optional[dict[str, Any]] = None

class ChatResponse(BaseModel):
    response: str
    meta: ChatMeta

class SandboxRequest(BaseModel):
    prompt: str = Field(..., min_length=1, max_length=2000)
    location: str = Field("Ahmedabad, Gujarat", max_length=200)
    language: str = Field("English", max_length=50)

SourceKind = Literal["auto", "imd", "accuweather", "open_meteo"]


def normalize_source(value: str) -> str:
    source = value.strip().lower().replace("-", "_")
    if source == "openmeteo":
        source = "open_meteo"
    if source not in ("auto", "imd", "accuweather", "open_meteo"):
        raise ValueError(f"Unsupported forecast source: {value}")
    return source
