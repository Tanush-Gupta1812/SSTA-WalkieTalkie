# Walkie-Talkie Server Integration Guide (for KalorTech / Any FastAPI Server)

All required backend files are bundled in the `walkie/` directory of this repository:
`C:\Users\gupta\Documents\Development\SSTA-WalkieTalkie\walkie`

---

## 1. Files to Copy to Your Server
Copy the **`walkie`** folder directly into your server's `app/` directory:
```
your-server/
└── app/
    ├── walkie/               <-- Copy this entire folder here
    │   ├── __init__.py
    │   ├── routes.py
    │   ├── models.py
    │   ├── database.py
    │   ├── connection_manager.py
    │   └── audio_history.py
    └── main.py
```

---

## 2. In your Server's `app/main.py`
Add these 2 small snippets:

### A. Register the Walkie Router
```python
from app.walkie.routes import router as walkie_router, init_walkie_db

# Include router (accessible via both /walkie/... and direct /groups)
app.include_router(walkie_router)
```

### B. Add Database Startup Hook
```python
@app.on_event("startup")
async def startup_walkie():
    try:
        await init_walkie_db()
        print("[WalkieTalkie] [OK] Walkie-Talkie database initialized.")
    except Exception as e:
        print(f"[WalkieTalkie] [WARN] Walkie-Talkie DB init warning: {e}")
```

---

## 3. Install Server Dependency
On your server (in your Python virtual environment):
```bash
pip install aiosqlite>=0.20.0
```

---

## 4. Restart Server
Restart your Uvicorn / FastAPI server.

### Verification:
```bash
curl http://YOUR-SERVER-IP:PORT/walkie/health
```
Expected response:
```json
{"status": "healthy", "service": "KalorTech WalkieTalkie", "db": "connected"}
```
*(The Walkie Talkie mobile app will automatically detect and connect to your server through its built-in auto-discovery handshake!)*
