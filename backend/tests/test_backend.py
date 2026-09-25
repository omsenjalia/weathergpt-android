import pytest
from fastapi.testclient import TestClient
from main import app

client = TestClient(app)

def test_root():
    response = client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert data["service"] == "WeatherGPT API"
    assert data["status"] == "ok"
    assert "provider_priority" in data

def test_health():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"

def test_dev():
    response = client.get("/dev")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"

def test_chat_validation():
    response = client.post("/chat", json={})
    assert response.status_code == 422
