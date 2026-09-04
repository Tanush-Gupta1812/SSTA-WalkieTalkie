@echo off
title Walkie Talkie Launcher (ngrok)
echo ===================================================
echo     STARTING WALKIE TALKIE BACKEND ^& NGROK TUNNEL
echo ===================================================
cd /d "%~dp0"

echo.
echo [0/2] Cleaning up previous ngrok and backend instances...
taskkill /f /im ngrok.exe >nul 2>&1
for /f "tokens=5" %%a in ('netstat -aon ^| findstr :8000 ^| findstr LISTENING') do (
    taskkill /f /pid %%a >nul 2>&1
)
ping 127.0.0.1 -n 2 >nul

echo.
echo [1/2] Launching FastAPI Backend Server...
start "Walkie Talkie - Backend" cmd /k "cd /d "%~dp0" && .\.venv\Scripts\python.exe -m uvicorn main:app --app-dir backend --host 0.0.0.0 --port 8000"

ping 127.0.0.1 -n 3 >nul

echo [2/2] Launching ngrok Tunnel (kenneth-nonfortuitous-unthreateningly.ngrok-free.dev)...
start "Walkie Talkie - ngrok Tunnel" cmd /k "cd /d "%~dp0" && .\ngrok.exe http --domain=kenneth-nonfortuitous-unthreateningly.ngrok-free.dev 8000"

echo.
echo Both servers launched!
echo Domain: https://kenneth-nonfortuitous-unthreateningly.ngrok-free.dev
ping 127.0.0.1 -n 4 >nul
