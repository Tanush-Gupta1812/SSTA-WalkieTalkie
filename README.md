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

### 2. Connect Across Different Networks (Phone on Cellular or Different WiFi)

To connect when your laptop and phone are not on the same WiFi network, run the included tunnel script in a second terminal:

```bash
cd backend
python tunnel.py
```

This generates a public secure URL (e.g., `https://xxxx.loca.lt` or Cloudflare tunnel). 

On your phone:
1. Tap the **Server Connection** icon (`<->` in the top right of the channel list).
2. Paste the public tunnel URL and tap **Connect**.
3. The app saves this URL automatically and routes all REST and WebSocket audio traffic securely over the internet!

---

### 3. Run the Flutter Mobile App

```bash
cd frontend/walkie_talkie
flutter pub get
flutter run
```

> **Local Network Note**:
> If both devices *are* on the same WiFi, you can simply enter your computer's local IP (e.g. `192.168.1.15`). Android emulators automatically route to `10.0.2.2`.
