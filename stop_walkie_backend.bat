@echo off
title Stop Walkie Talkie Backend
echo ===================================================
echo       STOPPING WALKIE TALKIE BACKEND ^& NGROK
echo ===================================================

echo Stopping ngrok tunnel...
taskkill /f /im ngrok.exe >nul 2>&1

echo Stopping backend server (port 8000)...
for /f "tokens=5" %%a in ('netstat -aon ^| findstr :8000 ^| findstr LISTENING') do (
    taskkill /f /pid %%a >nul 2>&1
)

echo.
echo All Walkie Talkie services stopped successfully.
ping 127.0.0.1 -n 2 >nul
