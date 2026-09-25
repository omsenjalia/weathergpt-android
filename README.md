# WeatherGPT — Monorepo

AI-Powered Weather Intelligence Assistant for Android and Mobile Devices.

## Repository Structure

```
weathergpt-android/
├── app/                  # Flutter Android Mobile Application
│   ├── android/          # Android project configuration & native runner
│   ├── assets/           # Multilingual translation resources
│   ├── lib/              # Application source code (Riverpod, Clean Architecture)
│   └── pubspec.yaml      # Flutter dependencies and configuration
└── backend/              # Python FastAPI Shared Backend
    ├── routers/          # API route definitions (chat, mobile, weather v2, dev)
    ├── services/         # Forecast aggregation, advisory engine, fusion
    ├── agent.py          # Conversational LangGraph AI agent
    ├── tools.py          # Weather telemetry and geocoding tools
    ├── main.py           # Application entrypoint
    └── requirements.txt  # Python backend dependencies
```

## Getting Started

### 1. Backend Service

The backend is built with **FastAPI** and **LangGraph**, providing multi-source forecast blending across IMD, AccuWeather, and Open-Meteo with LangGraph ReAct conversational reasoning.

```bash
cd backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
uvicorn main:app --host 0.0.0.0 --port 8888 --reload
```

### 2. Android Mobile Application

The mobile app is built with **Flutter 3.x** and **Material 3**, featuring persona modes (Citizen, Farmer / Krishi, and Researcher), dynamic atmospheric sky gradients, interactive GIS radar maps, and regional language translations.

```bash
cd app
cp .env.example .env
flutter pub get
flutter run
```

To build a release APK for Android:
```bash
cd app
flutter build apk --release
```
The compiled binary will be placed at `app/build/app/outputs/flutter-apk/app-release.apk`.
