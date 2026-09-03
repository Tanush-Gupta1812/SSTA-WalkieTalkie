# SSTA-WalkieTalkie

A push-to-talk walkie-talkie mobile application built with **Flutter** and **Python (FastAPI)**, featuring real-time WebSocket audio relay, QR code channel joining, and presence detection.

---

## Architecture Overview

- **Frontend (`frontend/walkie_talkie/`)**: Flutter app (Android + iOS) styled with a clean Obsidian Audio dark minimalist UI.
  - Push-to-talk press & hold mic streaming using 40ms framed PCM16 16kHz audio.
  - Low-latency real-time PCM audio playback via `flutter_pcm_sound`.
  - Camera QR scanner (`mobile_scanner`) and QR code generator (`qr_flutter`).
  - Automatic WebSocket reconnect engine with exponential backoff (1s -> 2s -> 4s -> max 8s).
- **Backend (`backend/`)**: FastAPI server using WebSockets per channel.
  - Atomic PTT channel lock (enforcing only one speaker per group at a time).
  - High-speed binary audio chunk relay to connected group peers.
  - Async SQLite database (`aiosqlite`) storing groups and membership records.
  - REST API for group creation, token joining, member lists, and leaving channels.

---

## Getting Started

### 1. Start the Backend

```bash
cd backend
pip install -r requirements.txt
python run.py
```
The server will run at `http://0.0.0.0:8000`.

To run backend tests:
```bash
python -m pytest test_backend.py -v
```

### 2. Run the Flutter Mobile App

```bash
cd frontend/walkie_talkie
flutter pub get
flutter run
```

> **Network Configuration Note**:
> When testing on a physical mobile device, tap the **Ethernet / Server Config** icon in the top right of the channel list screen and enter your computer's local WiFi IP (e.g. `192.168.1.15`). Android emulators automatically route via `10.0.2.2`.
